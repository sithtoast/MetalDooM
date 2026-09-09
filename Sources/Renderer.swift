import AppKit
import MetalKit
import simd

final class GameView: MTKView {
    var keys = Set<UInt16>()
    private var movementQueued = Set<UInt16>()
    var mouseMotion = SIMD2<Float>.zero
    var captured = false
    var running = false
    var useQueued = false
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.isARepeat { return }
        if [0,1,2,13,123,124,125,126].contains(Int(event.keyCode)) { movementQueued.insert(event.keyCode) }
        if event.keyCode == 14 || event.keyCode == 49 { useQueued = true }
        if event.keyCode == 53 { releaseMouse() } else { keys.insert(event.keyCode) }
    }
    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }
    override func flagsChanged(with event: NSEvent) { running = event.modifierFlags.contains(.shift) }
    func consumeMovement() -> Set<UInt16> {
        let result = keys.union(movementQueued); movementQueued.removeAll(); return result
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if !captured {
            captured = true
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
        }
    }
    override func mouseMoved(with event: NSEvent) {
        if captured { mouseMotion += SIMD2(Float(event.deltaX),Float(event.deltaY)) }
    }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with:event) }
    func releaseMouse() {
        keys.removeAll(); movementQueued.removeAll(); mouseMotion = .zero; running = false; useQueued = false
        if captured { captured = false; CGAssociateMouseAndMouseCursorPosition(1); NSCursor.unhide() }
    }
}

private struct GPUBatch { let vertices: MTLBuffer, texture: MTLTexture; let count: Int }
private struct Uniforms { var matrix: simd_float4x4 }

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice, queue: MTLCommandQueue, pipeline: MTLRenderPipelineState, skyPipeline: MTLRenderPipelineState, spritePipeline: MTLRenderPipelineState, depth: MTLDepthStencilState
    private var batches: [GPUBatch] = []
    private var sky: MTLTexture?
    private var map: DoomMap?
    private var wad: WAD?
    private var sprites: SpriteRenderer?
    private var hud = MD_HUD()
    private var messageSerial: Int32 = 0, messageUntil: Int32 = 0
    var pickupMessage: String {
        guard engineReady, hud.tick < messageUntil else { return "" }
        var value = hud.message
        return withUnsafePointer(to:&value) { pointer in
            pointer.withMemoryRebound(to:CChar.self,capacity:128) { String(cString:$0) }
        }
    }
    private var textures: [MaterialKey: MTLTexture] = [:]
    private var engineReady = false
    private var previousPlayer = MD_Player(), currentPlayer = MD_Player()
    private var accumulator: Double = 0
    private var pendingTurn: Float = 0
    private var turnHeld = 0
    private var eyeZ: Float = 41
    private var position = SIMD2<Float>.zero
    private var yaw: Float = 0, pitch: Float = 0
    private var lastTime = CACurrentMediaTime()
    private let inFlight = DispatchSemaphore(value: 3)
    private var frames = 0
    private var reportTime = CACurrentMediaTime()
    var onFrame: ((Double) -> Void)?
    var onError: ((Error) -> Void)?
    var playerStatus: String {
        guard engineReady else { return "" }
        if currentPlayer.exitRequested != 0 { return "Exit reached — next level is not connected yet; R to restart" }
        if currentPlayer.health <= 0 { return "You died — R to restart" }
        let names = ["Blue card","Yellow card","Red card","Blue skull","Yellow skull","Red skull"]
        let keys = names.indices.filter { hud.keys & (1 << $0) != 0 }.map { names[$0] }
        return "Health \(hud.health) · Armor \(hud.armor) · Ammo \(hud.readyAmmo >= 0 ? String(hud.readyAmmo) : "—") · Keys: \(keys.isEmpty ? "none" : keys.joined(separator:", "))"
    }
    var renderedFrames = 0
    init(view: GameView) throws {
        guard let device = view.device, let queue = device.makeCommandQueue() else { throw PortError("Metal is unavailable on this Mac.") }
        self.device = device; self.queue = queue
        let shader = """
        #include <metal_stdlib>
        using namespace metal;
        struct Vertex { float4 position; float4 uvLight; };
        struct Out { float4 position [[position]]; float2 uv; float light; float distance; float fullbright; };
        vertex Out worldVertex(uint id [[vertex_id]], const device Vertex *v [[buffer(0)]],
                               constant float4x4 &matrix [[buffer(1)]]) {
            Out o; o.position = matrix * v[id].position; o.uv = v[id].uvLight.xy;
            o.light = v[id].uvLight.z; o.distance = o.position.w; o.fullbright = v[id].uvLight.w; return o;
        }
        fragment float4 worldFragment(Out in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
            constexpr sampler s(coord::normalized, address::repeat, filter::nearest);
            float4 c = tex.sample(s, in.uv / float2(tex.get_width(),tex.get_height()));
            if (c.a < 0.5) discard_fragment();
            float shade = in.light * clamp(1.0 - in.distance / 3200.0, 0.3, 1.0);
            return float4(c.rgb * shade, 1.0);
        }
        fragment float4 spriteFragment(Out in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
            constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);
            float4 c = tex.sample(s,in.uv / float2(tex.get_width(),tex.get_height()));
            if (c.a < 0.5) discard_fragment();
            float shade = in.fullbright > 0.5 ? 1.0 : in.light*clamp(1.0-in.distance/3200.0,0.3,1.0);
            return float4(c.rgb*shade,1.0);
        }
        struct SkyOut { float4 position [[position]]; float2 uv; };
        vertex SkyOut skyVertex(uint id [[vertex_id]]) {
            float2 p = float2((id << 1) & 2, id & 2);
            SkyOut o; o.position = float4(p*2.0-1.0,0.999999,1.0); o.uv = p; return o;
        }
        fragment float4 skyFragment(SkyOut in [[stage_in]], constant float4 &camera [[buffer(0)]],
                                    texture2d<float> tex [[texture(0)]]) {
            float x = (in.uv.x*2.0-1.0)*camera.z*0.57735027;
            float y = (in.uv.y*2.0-1.0)*0.57735027;
            float f = cos(camera.y)-y*sin(camera.y), h = sin(camera.y)+y*cos(camera.y);
            float angle = camera.x-atan2(x,f);
            float elevation = atan2(h,length(float2(x,f)));
            float2 uv = float2(-angle * (2.0/M_PI_F),clamp(0.5-elevation/M_PI_F*2.0,0.0,1.0));
            constexpr sampler s(coord::normalized, s_address::repeat, t_address::clamp_to_edge, filter::nearest);
            return float4(tex.sample(s,uv).rgb,1.0);
        }
        """
        let library = try device.makeLibrary(source:shader,options:nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name:"worldVertex")
        descriptor.fragmentFunction = library.makeFunction(name:"worldFragment")
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor:descriptor)
        descriptor.fragmentFunction = library.makeFunction(name:"spriteFragment")
        spritePipeline = try device.makeRenderPipelineState(descriptor:descriptor)
        descriptor.vertexFunction = library.makeFunction(name:"skyVertex")
        descriptor.fragmentFunction = library.makeFunction(name:"skyFragment")
        skyPipeline = try device.makeRenderPipelineState(descriptor:descriptor)
        let state = MTLDepthStencilDescriptor(); state.depthCompareFunction = .less; state.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create Metal depth state.") }
        self.depth = depth
        super.init()
    }
    func load(wad: WAD, map name: String) throws -> (triangles:Int,missing:[String]) {
        guard wad.signature == "IWAD" else { throw PortError("The gameplay prototype requires a standalone Doom IWAD. PWAD merging is not connected yet.") }
        let map = try DoomMap(wad:wad,name:name), geometry = try Geometry(map:map), art = try Art(wad:wad)
        let loadedSprites = try SpriteRenderer(device:device,wad:wad)
        var materials = Set(geometry.batches.map(\.material))
        for side in map.sides {
            for name in [side.upper,side.lower,side.middle] where name != "-" && !name.isEmpty {
                materials.insert(MaterialKey(name:name,flat:false))
            }
        }
        var cached: [MaterialKey:MTLTexture] = [:], missing: [String] = []
        for material in materials {
            let source = try art.image(material)
            if source == nil { missing.append(material.name) }
            let pixels = source ?? Art.fallback
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:pixels.width,height:pixels.height,mipmapped:false)
            descriptor.usage = .shaderRead; descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor:descriptor) else {
                throw PortError("Cannot allocate Metal map resources.")
            }
            pixels.rgba.withUnsafeBytes { bytes in
                texture.replace(region:MTLRegionMake2D(0,0,pixels.width,pixels.height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:pixels.width*4)
            }
            cached[material] = texture
        }
        let loaded = try makeBatches(geometry,textures:cached)
        let skyName: String
        if name.hasPrefix("E2") { skyName = "SKY2" }
        else if name.hasPrefix("E3") { skyName = "SKY3" }
        else if name.hasPrefix("E4") { skyName = "SKY4" }
        else if name.hasPrefix("MAP"), let number = Int(name.dropFirst(3)), number > 20 { skyName = "SKY3" }
        else if name.hasPrefix("MAP"), let number = Int(name.dropFirst(3)), number > 11 { skyName = "SKY2" }
        else { skyName = "SKY1" }
        var loadedSky: MTLTexture?
        if let pixels = try art.image(MaterialKey(name:skyName,flat:false)) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:pixels.width,height:pixels.height,mipmapped:false)
            descriptor.usage = .shaderRead; descriptor.storageMode = .shared
            loadedSky = device.makeTexture(descriptor:descriptor)
            pixels.rgba.withUnsafeBytes { bytes in
                loadedSky?.replace(region:MTLRegionMake2D(0,0,pixels.width,pixels.height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:pixels.width*4)
            }
        }
        let episode = name.hasPrefix("E") ? Int(String(name.dropFirst().prefix(1))) ?? 1 : 1
        let number = name.hasPrefix("MAP") ? Int(name.dropFirst(3)) ?? 1 : Int(name.suffix(1)) ?? 1
        guard MD_Load(wad.url.path,Int32(episode),Int32(number)) != 0 else {
            if MD_SectorCount() == 0 { engineReady = false }
            throw PortError(String(cString:MD_LastError()))
        }
        guard MD_SectorCount() == map.sectors.count else { engineReady = false; throw PortError("Engine and Metal sector counts differ.") }
        self.map = map; self.wad = wad; textures = cached; batches = loaded; sky = loadedSky; sprites = loadedSprites; pitch = 0
        hud = MD_GetHUD(); messageSerial = hud.messageSerial; messageUntil = hud.messageSerial > 0 ? hud.tick+140 : 0
        currentPlayer = MD_GetPlayer(); previousPlayer = currentPlayer
        position = SIMD2(currentPlayer.x,currentPlayer.y); yaw = currentPlayer.angle; eyeZ = currentPlayer.eyeZ
        accumulator = 0; pendingTurn = 0; turnHeld = 0; lastTime = CACurrentMediaTime(); engineReady = true
        try syncGeometry()
        return (geometry.triangleCount,Array(Set(missing)).sorted())
    }
    func reset() throws { if let wad, let map { _ = try load(wad:wad,map:map.name) } }
    private func makeBatches(_ geometry: Geometry, textures: [MaterialKey:MTLTexture]) throws -> [GPUBatch] {
        try geometry.batches.map { batch in
            guard let texture = textures[batch.material],
                  let buffer = device.makeBuffer(bytes:batch.vertices,length:batch.vertices.count*MemoryLayout<WorldVertex>.stride,options:.storageModeShared) else {
                throw PortError("Unable to update moving sector geometry (\(batch.material.name)).")
            }
            return GPUBatch(vertices:buffer,texture:texture,count:batch.vertices.count)
        }
    }
    private func syncGeometry() throws {
        guard var map else { return }
        var changed = false
        for index in map.sectors.indices {
            let state = MD_GetSector(Int32(index)), old = map.sectors[index]
            if state.floor != old.floor || state.ceiling != old.ceiling || state.light != old.light {
                map.sectors[index] = Sector(floor:state.floor,ceiling:state.ceiling,light:state.light,floorTexture:old.floorTexture,ceilingTexture:old.ceilingTexture)
                changed = true
            }
        }
        if changed {
            batches = try makeBatches(Geometry(map:map),textures:textures)
            self.map = map
        }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in mtkView: MTKView) {
        guard let view = mtkView as? GameView else { return }
        let time = CACurrentMediaTime(), delta = min(time-lastTime,0.25); lastTime = time
        do { try update(view:view,delta:delta) }
        catch { engineReady = false; view.releaseMouse(); DispatchQueue.main.async { [weak self] in self?.onError?(error) } }
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer() else { return }
        inFlight.wait()
        let semaphore = inFlight
        command.addCompletedHandler { buffer in
            if let error = buffer.error { fputs("Metal command error: \(error)\n",stderr) }
            semaphore.signal()
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor:pass) else { inFlight.signal(); return }
        encoder.setRenderPipelineState(pipeline); encoder.setDepthStencilState(depth); encoder.setCullMode(.none)
        if map != nil {
            let width = max(1,view.drawableSize.width), height = max(1,view.drawableSize.height)
            let worldHeight = max(1,height-SpriteRenderer.hudHeight(width:width))
            encoder.setViewport(MTLViewport(originX:0,originY:0,width:width,height:worldHeight,znear:0,zfar:1))
            let aspect = Float(width/worldHeight)
            if let sky {
                var camera = SIMD4(yaw,pitch,aspect,0)
                encoder.setRenderPipelineState(skyPipeline)
                encoder.setFragmentBytes(&camera,length:MemoryLayout<SIMD4<Float>>.stride,index:0)
                encoder.setFragmentTexture(sky,index:0)
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
                encoder.setRenderPipelineState(pipeline)
            }
            let eye = SIMD3(position.x,eyeZ,-position.y)
            let forward = SIMD3(cos(yaw)*cos(pitch),sin(pitch),-sin(yaw)*cos(pitch))
            var uniform = Uniforms(matrix:perspective(aspect:aspect) * look(eye:eye,forward:forward))
            encoder.setVertexBytes(&uniform,length:MemoryLayout<Uniforms>.stride,index:1)
            for batch in batches {
                encoder.setVertexBuffer(batch.vertices,offset:0,index:0); encoder.setFragmentTexture(batch.texture,index:0)
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:batch.count)
            }
            if let sprites, engineReady {
                encoder.setRenderPipelineState(spritePipeline)
                do { try sprites.drawWorld(encoder:encoder,camera:position,yaw:yaw) }
                catch { engineReady = false; DispatchQueue.main.async { [weak self] in self?.onError?(error) } }
                sprites.drawHUD(encoder:encoder,state:hud,width:width,height:height)
            }
        }
        encoder.endEncoding(); command.present(drawable); command.commit(); renderedFrames += 1
        frames += 1
        if time-reportTime >= 0.5 { onFrame?(Double(frames)/(time-reportTime)); frames = 0; reportTime = time }
    }
    private func update(view: GameView, delta: Double) throws {
        guard engineReady else { return }
        guard NSApp.isActive, view.window?.isKeyWindow == true, view.window?.attachedSheet == nil else {
            accumulator = 0; pendingTurn = 0; previousPlayer = currentPlayer; return
        }
        if view.keys.remove(15) != nil { view.releaseMouse(); try reset(); return }
        pendingTurn -= view.mouseMotion.x*0.0025
        pitch = (pitch-view.mouseMotion.y*0.0025).clamped(-1.2,1.2); view.mouseMotion = .zero
        accumulator += delta
        let step = 1.0/35.0
        while accumulator >= step {
            let movement = view.consumeMovement()
            var forward: Int32 = 0, side: Int32 = 0
            let speed: Int32 = view.running ? 50 : 25, strafe: Int32 = view.running ? 40 : 24
            if movement.contains(13) || movement.contains(126) { forward += speed }
            if movement.contains(1) || movement.contains(125) { forward -= speed }
            if movement.contains(0) { side -= strafe }
            if movement.contains(2) { side += strafe }
            let mouseTurn = Int32((pendingTurn * 65536/(2 * .pi)).clamped(-30000,30000))
            pendingTurn -= Float(mouseTurn)*(2 * .pi)/65536
            var turn = mouseTurn
            if movement.contains(123) || movement.contains(124) { turnHeld += 1 } else { turnHeld = 0 }
            let turnSpeed: Int32 = turnHeld < 6 ? 320 : view.running ? 1280 : 640
            if movement.contains(123) { turn += turnSpeed }
            if movement.contains(124) { turn -= turnSpeed }
            let use: Int32 = view.useQueued || view.keys.contains(14) || view.keys.contains(49) ? 1 : 0
            view.useQueued = false
            previousPlayer = currentPlayer
            guard MD_Tick(forward,side,turn,use) != 0 else { throw PortError(String(cString:MD_LastError())) }
            currentPlayer = MD_GetPlayer(); accumulator -= step
            hud = MD_GetHUD()
            if hud.messageSerial != messageSerial { messageSerial = hud.messageSerial; messageUntil = hud.tick+140 }
        }
        try syncGeometry()
        let blend = Float(accumulator/step)
        position = SIMD2(previousPlayer.x,previousPlayer.y)+(SIMD2(currentPlayer.x,currentPlayer.y)-SIMD2(previousPlayer.x,previousPlayer.y))*blend
        eyeZ = previousPlayer.eyeZ+(currentPlayer.eyeZ-previousPlayer.eyeZ)*blend
        let angleDelta = atan2(sin(currentPlayer.angle-previousPlayer.angle),cos(currentPlayer.angle-previousPlayer.angle))
        yaw = previousPlayer.angle+angleDelta*blend
    }
}

private func perspective(aspect: Float) -> simd_float4x4 {
    let scale: Float = 1/tan(Float.pi/6), near: Float = 1, far: Float = 32768
    return simd_float4x4(columns:(SIMD4(scale/aspect,0,0,0),SIMD4(0,scale,0,0),SIMD4(0,0,far/(near-far),-1),SIMD4(0,0,near*far/(near-far),0)))
}
private func look(eye: SIMD3<Float>, forward: SIMD3<Float>) -> simd_float4x4 {
    let z = -simd_normalize(forward), x = simd_normalize(simd_cross(SIMD3(0,1,0),z)), y = simd_cross(z,x)
    return simd_float4x4(columns:(SIMD4(x.x,y.x,z.x,0),SIMD4(x.y,y.y,z.y,0),SIMD4(x.z,y.z,z.z,0),SIMD4(-simd_dot(x,eye),-simd_dot(y,eye),-simd_dot(z,eye),1)))
}
