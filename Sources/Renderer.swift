import AppKit
import MetalKit
import simd

final class GameView: MTKView {
    var onBlockedClick: (() -> Void)?
    var inputBlocked = false
    var keys = Set<UInt16>()
    private var movementQueued = Set<UInt16>()
    var mouseMotion = SIMD2<Float>.zero
    var captured = false
    var running = false
    var useQueued = false
    var attackQueued = false, mouseFire = false
    var weaponQueued: Int32 = -1
    var continueQueued = false
    var onEscape: (() -> Void)?
    var renderScale: CGFloat = 1 { didSet { updateResolution() } }
    func updateResolution() {
        autoResizeDrawable=false
        let scale=(window?.backingScaleFactor ?? 2)*renderScale
        drawableSize=CGSize(width:max(1,(bounds.width*scale).rounded()),height:max(1,(bounds.height*scale).rounded()))
    }
    override func layout() { super.layout(); updateResolution() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); updateResolution() }
    func consumeAttack() -> Int32 {
        let fire = attackQueued || mouseFire || keys.contains(3)
        attackQueued = false; return fire ? 1 : 0
    }
    func consumeWeapon() -> Int32 { let value = weaponQueued; weaponQueued = -1; return value }
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if inputBlocked || event.isARepeat { return }
        if event.keyCode == 36 { continueQueued = true }
        if event.keyCode == 3 { attackQueued = true } // F: keyboard fire
        let slots: [UInt16:Int32] = [18:0,19:1,20:2,21:3,23:4,22:5,26:6]
        if let slot = slots[event.keyCode] { weaponQueued = slot }
        if [0,1,2,13,123,124,125,126].contains(Int(event.keyCode)) { movementQueued.insert(event.keyCode) }
        if event.keyCode == 14 || event.keyCode == 49 { useQueued = true }
        if event.keyCode == 53 { releaseMouse(); onEscape?() } else { keys.insert(event.keyCode) }
    }
    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }
    override func flagsChanged(with event: NSEvent) { running = event.modifierFlags.contains(.shift) }
    func consumeMovement() -> Set<UInt16> {
        let result = keys.union(movementQueued); movementQueued.removeAll(); return result
    }
    override func mouseDown(with event: NSEvent) {
        guard !inputBlocked else { onBlockedClick?();return }
        window?.makeFirstResponder(self)
        if !captured {
            captured = true
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
        } else { mouseFire = true; attackQueued = true }
    }
    override func mouseUp(with event: NSEvent) { mouseFire = false }
    override func mouseMoved(with event: NSEvent) {
        if captured { mouseMotion += SIMD2(Float(event.deltaX),Float(event.deltaY)) }
    }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with:event) }
    func releaseMouse() {
        attackQueued = false; mouseFire = false; weaponQueued = -1; continueQueued = false
        keys.removeAll(); movementQueued.removeAll(); mouseMotion = .zero; running = false; useQueued = false
        if captured { captured = false; CGAssociateMouseAndMouseCursorPosition(1); NSCursor.unhide() }
    }
}

private struct GPUBatch { let vertices: MTLBuffer, texture: MTLTexture; let material: MaterialKey; let count: Int }
private struct Uniforms { var matrix: simd_float4x4 }

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice, queue: MTLCommandQueue, depth: MTLDepthStencilState, fuzzDepth: MTLDepthStencilState, visibleDepth: MTLDepthStencilState
    private var programs: WorldPrograms
    var pipeline: MTLRenderPipelineState { programs.world }
    var skyPipeline: MTLRenderPipelineState { programs.sky }
    var skySurfacePipeline: MTLRenderPipelineState { programs.skySurface }
    var spritePipeline: MTLRenderPipelineState { programs.sprite }
    var tintPipeline: MTLRenderPipelineState { programs.tint }
    var fuzzPipeline: MTLRenderPipelineState { programs.fuzz }
    private(set) var highRayQuality=false
    func setHighRayQuality(_ enabled:Bool) { highRayQuality=enabled }
    private var hdrOutput: HDROutput?
    var hdrEnabled: Bool { hdrOutput != nil }
    private(set) var hdrPeak: Float = 4
    private(set) var fogDensity: Float = 0.003
    func setHDRPeak(_ value: Float) { hdrPeak=value.isFinite ? min(8,max(1,value)):4 }
    func setFogDensity(_ value: Float) { fogDensity=value.isFinite ? min(0.01,max(0,value)):0.003 }
    private var volume: VolumetricLighting?
    private var effectDepth: MTLTexture?
    func setHDR(_ enabled: Bool, view: GameView) throws {
        guard enabled != hdrEnabled else { return }
        var preset=EffectsPreset(renderer:self);preset.hdr=enabled
        try applyEffectsPreset(preset,view:view)
    }

    func applyEffectsPreset(_ preset: EffectsPreset, view: GameView) throws {
        let format:MTLPixelFormat=preset.hdr ? .rgba16Float:.bgra8Unorm
        let switches=preset.switches
        let nextPrograms=try WorldPrograms(device:device,shader:worldShader,format:format)
        let nextOutput=preset.hdr ? try HDROutput(device:device):nil
        let nextAO=(preset.ao || preset.testLight || switches.contains(where: { $0.needsRays }))
            ? try AmbientOcclusion(device:device,shader:worldShader,format:format):nil
        let nextBloom=switches.contains(.bloom) ? try Bloom(device:device,format:format):nil
        let nextParticles=switches.contains(.particles) ? try ParticleRenderer(device:device,format:format):nil
        let nextVolume=switches.contains(.volumetrics) ? try VolumetricLighting(device:device,shader:worldShader,format:format):nil
        programs=nextPrograms;hdrOutput=nextOutput;ambientOcclusion=nextAO;bloom=nextBloom;particles=nextParticles;volume=nextVolume
        ambientOcclusionEnabled=preset.ao;dynamicLightEnabled=preset.testLight;dynamicLightShadows=preset.testShadows
        highRayQuality=preset.highRayQuality == true
        sceneEffects=switches;setAOSettings(strength:preset.strength,radius:preset.radius)
        setFogDensity(preset.density);setHDRPeak(preset.peak)
        worldFormat=format;aoGeometryDirty=true;sceneSnapshot=nil
        view.releaseDrawables();view.colorPixelFormat=format
        view.colorspace=preset.hdr ? CGColorSpace(name:CGColorSpace.extendedLinearSRGB):nil
        (view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent=preset.hdr
    }
    private var batches: [GPUBatch] = []
    private var worldShader = ""
    private var worldFormat: MTLPixelFormat = .bgra8Unorm
    private var opaqueMaterials = Set<MaterialKey>()
    private var aoGeometryDirty = true
    private var aoAlphaBuffer: MTLBuffer?
    private var aoAlphaInfo: [ObjectIdentifier:SIMD4<UInt32>] = [:]
    private(set) var aoSettings=AOSettings()
    func setAOSettings(strength: Float? = nil, radius: Float? = nil) {
        aoSettings=AOSettings(strength:strength ?? aoSettings.strength,radius:radius ?? aoSettings.radius)
    }
    // The optional ray pipeline/mesh is shared by AO and all world lights.
    private(set) var ambientOcclusion: AmbientOcclusion?
    private(set) var ambientOcclusionEnabled = false
    private(set) var dynamicLightEnabled = false
    private(set) var dynamicLightShadows = true
    var ambientOcclusionSupported: Bool { device.supportsRaytracing && device.supportsRaytracingFromRender }
    var onGPUFrame: ((Double) -> Void)?
    private(set) var recentGPUTime: Double = 0
    func setAmbientOcclusion(_ enabled: Bool) throws {
        try configureRayEffects(ao:enabled,light:dynamicLightEnabled)
    }
    func setDynamicLight(_ enabled: Bool) throws {
        try configureRayEffects(ao:ambientOcclusionEnabled,light:enabled)
    }
    func setDynamicLightShadows(_ enabled: Bool) { dynamicLightShadows=enabled }
    private(set) var sceneEffects=Set<SceneEffect>()
    private var bloom: Bloom?
    private var particles: ParticleRenderer?
    private var surfaceColors:[MaterialKey:SIMD4<Float>]=[:]
    private var surfaceLights:[DynamicLightUniforms]=[]
    private var surfaceLightsDirty=true
    private func rebuildSurfaceLights() {
        guard surfaceLightsDirty, let map else { return }
        var collector=SurfaceLightCollector()
        for batch in batches {
            guard let color=surfaceColors[batch.material], color.w>0 else { continue }
            let vertices=batch.vertices.contents().bindMemory(to:WorldVertex.self,capacity:batch.count)
            for i in stride(from:0,to:batch.count,by:3) {
                let triangle=[vertices[i],vertices[i+1],vertices[i+2]]
                let a=SIMD3(triangle[0].position.x,triangle[0].position.y,triangle[0].position.z)
                let b=SIMD3(triangle[1].position.x,triangle[1].position.y,triangle[1].position.z)
                let c=SIMD3(triangle[2].position.x,triangle[2].position.y,triangle[2].position.z)
                let cross=simd_cross(b-a,c-a)
                guard simd_length_squared(cross)>0.0001 else { continue }
                var normal=simd_normalize(cross)
                if batch.material.flat {
                    let center=(a+b+c)/3
                    let sector=map.sectors[map.sector(at:SIMD2(center.x,-center.z))]
                    normal=SIMD3(0,abs(center.y-sector.floor)<abs(center.y-sector.ceiling) ? 1:-1,0)
                }
                collector.add(triangle,material:batch.material,color:color,normal:normal)
            }
        }
        surfaceLights=collector.lights();surfaceLightsDirty=false
    }
    private var lightThings:[MD_Thing]=[]
    var sceneEffectsKey: String { SceneEffect.allCases.map { sceneEffects.contains($0) ? "1":"0" }.joined() }
    func setSceneEffect(_ effect: SceneEffect, enabled: Bool) throws {
        var next=sceneEffects
        if enabled { next.insert(effect) } else { next.remove(effect) }
        if next.contains(where: { $0.needsRays }) && ambientOcclusion == nil {
            ambientOcclusion=try AmbientOcclusion(device:device,shader:worldShader,format:worldFormat)
            aoGeometryDirty=true
        }
        if effect == .bloom {
            bloom=enabled ? try Bloom(device:device,format:worldFormat):nil
        }
        if effect == .volumetrics { volume=enabled ? try VolumetricLighting(device:device,shader:worldShader,format:worldFormat):nil }
        if effect == .particles { particles=enabled ? try ParticleRenderer(device:device,format:worldFormat):nil }
        sceneEffects=next
        if !ambientOcclusionEnabled && !dynamicLightEnabled && !next.contains(where: { $0.needsRays }) { ambientOcclusion=nil }
    }
    private func sceneLights() -> [DynamicLightUniforms] {
        var lights:[DynamicLightUniforms]=[]
        if dynamicLightEnabled { lights.append(movingLightUniforms()) }
        if sceneEffects.contains(where: { $0.needsRays }) {
            if sceneEffects.contains(.torches) || sceneEffects.contains(.projectiles) {
                lightThings=Array(repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,position.x,position.y)))
                _=MD_CopyThings(&lightThings,Int32(lightThings.count),position.x,position.y)
            } else { lightThings=[] }
            lights += DynamicLightUniforms.gameplay(things:lightThings,hud:hud,
                eye:SIMD3(position.x,eyeZ,-position.y),effects:sceneEffects)
        }
        if sceneEffects.contains(.surfaceLighting) {
            rebuildSurfaceLights()
            let eye=SIMD3(position.x,eyeZ,-position.y)
            var candidates:[(Int,DynamicLightUniforms,Float)]=[]
            for (index,light) in surfaceLights.enumerated() {
                let point=SIMD3<Float>(light.positionRadius.x,light.positionRadius.y,light.positionRadius.z)
                let distance=simd_length_squared(point-eye)
                if distance<1_048_576 { candidates.append((index,light,distance)) }
            }
            candidates.sort { $0.2==$1.2 ? $0.0<$1.0:$0.2<$1.2 }
            let nearest=candidates.prefix(4).map { $0.1 }
            lights=Array(lights.prefix(DynamicLightUniforms.limit-nearest.count))+nearest
        }
        lights=Array(lights.prefix(DynamicLightUniforms.limit))
        if sceneEffects.contains(.softShadows) {
            for i in lights.indices { lights[i].options.y=lights[i].facing == .zero ? 6:12 }
        }
        for i in lights.indices { lights[i].options.z=highRayQuality ? 8:4 }
        // Keep decoration emitters inside their actual sector, including low ceilings.
        if let map {
            for i in lights.indices {
                let s=map.sectors[map.sector(at:SIMD2(lights[i].positionRadius.x,-lights[i].positionRadius.z))]
                if s.ceiling-s.floor>2 { lights[i].positionRadius.y=min(s.ceiling-1,max(s.floor+1,lights[i].positionRadius.y)) }
                else { lights[i].colorIntensity.w=0 }
            }
        }
        return lights
    }
    private func configureRayEffects(ao: Bool, light: Bool) throws {
        if (ao || light || sceneEffects.contains(where: { $0.needsRays })) && ambientOcclusion == nil {
            ambientOcclusion=try AmbientOcclusion(device:device,shader:worldShader,format:worldFormat)
            aoGeometryDirty=true
        }
        ambientOcclusionEnabled=ao;dynamicLightEnabled=light
        if !ao && !light && !sceneEffects.contains(where: { $0.needsRays }) { ambientOcclusion=nil }
    }
    private func disableRayEffects() {
        ambientOcclusion=nil;ambientOcclusionEnabled=false;dynamicLightEnabled=false;volume=nil
        sceneEffects=sceneEffects.filter { !$0.needsRays }
    }
    private func movingLightUniforms() -> DynamicLightUniforms {
        guard dynamicLightEnabled else { return DynamicLightUniforms() }
        var light=DynamicLightUniforms.moving(eye:SIMD3(position.x,eyeZ,-position.y),yaw:yaw,
                                             tics:hud.levelTics,shadows:dynamicLightShadows)
        if let map {
            let sector=map.sectors[map.sector(at:SIMD2(light.positionRadius.x,-light.positionRadius.z))]
            guard sector.ceiling-sector.floor>16 else { return DynamicLightUniforms() }
            light.positionRadius.y=min(sector.ceiling-8,max(sector.floor+8,light.positionRadius.y))
        }
        return light
    }
    private func prepareAmbientOcclusion(command: MTLCommandBuffer) throws {
        guard let ao=ambientOcclusion else { return }
        if aoGeometryDirty {
            let geometry=batches.map { batch in
                let source=batch.vertices.contents().bindMemory(to:WorldVertex.self,capacity:batch.count)
                let vertices=(0..<batch.count).map { AOVertex(position:source[$0].position,uv:SIMD4(source[$0].uvLight.x,source[$0].uvLight.y,0,0)) }
                return AOGeometry(vertices:vertices,opaque:opaqueMaterials.contains(batch.material))
            }
            try ao.prepare(geometry:geometry,device:device,command:command)
            aoGeometryDirty=false
        }
        // Texture translation can change every tic without any geometry change.
        // Publish a fresh immutable mapping only when the selected frames change.
        let info=try batches.enumerated().map { index,batch -> SIMD4<UInt32> in
            guard var material=aoAlphaInfo[ObjectIdentifier(animatedTexture(batch))] else {
                throw PortError("Missing ambient occlusion alpha mask.")
            }
            material.w=ao.baseVertices[index];return material
        }
        try ao.updateMaterials(info,device:device)
    }
    private var sceneSnapshot: MTLTexture?
    private var sky: MTLTexture?
    private var skyGeometry: MTLBuffer?
    private var skyVertexCount = 0
    private var textureHeights: [String:Float] = [:]
    private var map: DoomMap?
    private var wad: WAD?
    private var sprites: SpriteRenderer?
    private var sound: SoundPlayer?
    private var music: MusicPlayer?
    private var castAttackQueued=false
    private var demoPlayback=false
    var paused = false { didSet { if paused { pauseAudio() } } }
    var skill: Int32 = 2
    var effectsVolume: Float = Float(UserDefaults.standard.object(forKey:"effectsVolume") as? Double ?? 0.7) {
        didSet { sound?.volume=effectsVolume; UserDefaults.standard.set(Double(effectsVolume),forKey:"effectsVolume") }
    }
    var musicVolume: Float = Float(UserDefaults.standard.object(forKey:"musicVolume") as? Double ?? 0.7) {
        didSet { music?.volume=musicVolume; UserDefaults.standard.set(Double(musicVolume),forKey:"musicVolume") }
    }
    var musicEnabled = !UserDefaults.standard.bool(forKey:"musicMuted") {
        didSet { music?.enabled=musicEnabled; UserDefaults.standard.set(!musicEnabled,forKey:"musicMuted") }
    }
    private var intermissionArt: IntermissionRenderer?
    private var progress = MD_Progress()
    private var intermission = IntermissionSequence()
    private var intermissionTime: Double = 0
    private var finale = FinaleSequence()
    private var deathTime: Double = 0
    private var lastGeometryTick: Int32 = -1
    var onMapChanged: ((String) -> Void)?
    func releaseMusic() { music?.update(active:false);music=nil }
    func pauseAudio() { try? sound?.setActive(false); music?.update(active:false) }
    private var hud = MD_HUD()
    private var secretNotice = SecretNotice()
    var levelHUD: MD_HUD? { engineReady && progress.phase == 0 && !demoPlayback ? hud : nil }
    var secretFound: Bool { levelHUD != nil && secretNotice.visible(at:hud.levelTics) }
    var onHUDFrame: (() -> Void)?
    var notice = ""
    var noticeUntil: Double = 0
    private var messageSerial: Int32 = 0, messageUntil: Int32 = 0
    var pickupMessage: String {
        if CACurrentMediaTime() < noticeUntil { return notice }
        guard engineReady, hud.tick < messageUntil else { return "" }
        var value = hud.message
        return withUnsafePointer(to:&value) { pointer in
            pointer.withMemoryRebound(to:CChar.self,capacity:128) { String(cString:$0) }
        }
    }
    private var textures: [MaterialKey: MTLTexture] = [:]
    private var animatedIDs: [MaterialKey:Int32] = [:]
    private var animatedWalls: [Int32:MTLTexture] = [:], animatedFlats: [Int32:MTLTexture] = [:]
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
    var onSubmittedFrame: ((Double) -> Void)?
    var onWarning: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    var playerStatus: String {
        guard engineReady else { return "" }
        if progress.phase != 0 {
            if progress.phase==3 { return "\(wad?.gameName ?? "Campaign") story · Enter / Use to reveal text, then continue · Esc for menu" }
            if progress.phase==4 { return "The cast · Fire / Enter to play death animation · Esc for menu" }
            if progress.phase == 2 { return "Episode complete · Kills \(progress.kills)/\(progress.maxKills) · Items \(progress.items)/\(progress.maxItems) · Secrets \(progress.secrets)/\(progress.maxSecrets) · Esc for menu · Enter / Use to advance story" }
            return "\(intermission.entering ? "Entering next level" : "Level complete") · Kills \(progress.kills)/\(progress.maxKills) · Items \(progress.items)/\(progress.maxItems) · Secrets \(progress.secrets)/\(progress.maxSecrets) · Time \(progress.seconds)s · Enter to continue"
        }
        if currentPlayer.health <= 0 { return "You died — E / Space / Enter to restart · Esc to load a game" }
        let names = ["Blue card","Yellow card","Red card","Blue skull","Yellow skull","Red skull"]
        let keys = names.indices.filter { hud.keys & (1 << $0) != 0 }.map { names[$0] }
        return "Kills \(hud.kills)/\(hud.totalKills) · Health \(hud.health) · Armor \(hud.armor) · Ammo \(hud.readyAmmo >= 0 ? String(hud.readyAmmo) : "—") · Keys: \(keys.isEmpty ? "none" : keys.joined(separator:", "))"
    }
    var renderedFrames = 0
    init(view: GameView) throws {
        guard let device = view.device, let queue = device.makeCommandQueue() else { throw PortError("Metal is unavailable on this Mac.") }
        self.device = device; self.queue = queue
        let shader = """
        #include <metal_stdlib>
        using namespace metal;
        \(WorldSampling.shader)
        struct Vertex { float4 position; float4 uvLight; };
        struct Out { float4 position [[position]]; float2 uv; float light; float distance; float fullbright; float3 world; };
        vertex Out worldVertex(uint id [[vertex_id]], const device Vertex *v [[buffer(0)]],
                               constant float4x4 &matrix [[buffer(1)]]) {
            Out o; o.position = matrix * v[id].position; o.uv = v[id].uvLight.xy;
            o.world = v[id].position.xyz; o.light = v[id].uvLight.z; o.distance = o.position.w; o.fullbright = v[id].uvLight.w; return o;
        }
        float3 powerColor(float3 rgb, float4 power) {
            if (power.x > 0) return float3(floor((1.0-dot(rgb,float3(0.299,0.587,0.114)))*31.0)/31.0);
            return rgb;
        }
        float3 emissiveColor(float3 color, float3 lit, float4 emission, float4 power) {
            if (emission.y<=0 || power.x>0 || power.y>0) return lit;
            float mask=smoothstep(emission.x,min(1.0,emission.x+0.25),max(color.r,max(color.g,color.b)));
            if (emission.z>0) {
                float saturation=max(color.r,max(color.g,color.b))-min(color.r,min(color.g,color.b));
                mask*=smoothstep(0.15,0.4,saturation);
            }
            return mix(lit,max(lit,color*emission.y),mask);
        }
        fragment void visibilityFragment(Out in [[stage_in]],bool front [[front_facing]],texture2d<float> tex [[texture(0)]]) {
            if (in.fullbright>0.5 && !front) discard_fragment();
            constexpr sampler s(coord::normalized,address::repeat,filter::nearest);
            if (tex.sample(s,in.uv/float2(tex.get_width(),tex.get_height())).a<0.5) discard_fragment();
        }
        fragment float4 worldFragment(Out in [[stage_in]], bool front [[front_facing]], texture2d<float> tex [[texture(0)]], constant float4 &power [[buffer(2)]], constant float4 &emission [[buffer(11)]]) {
            if (in.fullbright > 0.5 && !front) discard_fragment();
            constexpr sampler s(coord::normalized, address::repeat, filter::nearest);
            float4 c = sampleWorld(tex,in.uv,power);
            if (c.a < 0.5) discard_fragment();
            float shade = (power.x>0 || power.y>0) ? 1.0 : in.light * clamp(1.0 - in.distance / 3200.0, 0.3, 1.0);
            return float4(powerColor(emissiveColor(c.rgb,c.rgb*shade,emission,power),power), 1.0);
        }
        fragment float4 spriteFragment(Out in [[stage_in]], texture2d<float> tex [[texture(0)]], constant float4 &power [[buffer(2)]]) {
            constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);
            float4 c = tex.sample(s,in.uv / float2(tex.get_width(),tex.get_height()));
            if (c.a < 0.5) discard_fragment();
            float shade = (in.fullbright > 0.5 || power.x>0 || power.y>0) ? 1.0 : in.light*clamp(1.0-in.distance/3200.0,0.3,1.0);
            return float4(powerColor(c.rgb*shade,power),1.0);
        }
        fragment float4 fuzzFragment(Out in [[stage_in]], texture2d<float> tex [[texture(0)]],
                texture2d<float, access::read> scene [[texture(1)]], constant float4 &power [[buffer(2)]]) {
            constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::nearest);
            if(tex.sample(s,in.uv/float2(tex.get_width(),tex.get_height())).a<0.5) discard_fragment();
            float step=max(1.0,float(scene.get_width())/320.0);
            uint seed=uint(floor(in.position.x/step))+uint(floor(in.position.y/step))*3+uint(power.z)*7;
            float shift=((seed*1103515245u+12345u)&0x100u) ? step:-step;
            uint2 pixel=uint2(clamp(in.position.xy+float2(0,shift),float2(0),float2(scene.get_width()-1,scene.get_height()-1)));
            return float4(scene.read(pixel).rgb*0.65,1);
        }
        float4 skyColor(float3 direction, texture2d<float> tex) {
            float angle = atan2(-direction.z,direction.x);
            float slope = direction.y / max(length(direction.xz),0.0001);
            // Doom uses 1024 columns per revolution and a sky midpoint of 100.
            float2 uv = float2(angle*(512.0/M_PI_F)/tex.get_width(),
                               (100.0-160.0*slope)/tex.get_height());
            constexpr sampler s(coord::normalized, s_address::repeat, t_address::clamp_to_edge, filter::nearest);
            return float4(tex.sample(s,uv).rgb,1);
        }
        fragment float4 skySurfaceFragment(Out in [[stage_in]], bool front [[front_facing]],
                    constant float4 &eye [[buffer(0)]], texture2d<float> tex [[texture(0)]], constant float4 &power [[buffer(2)]]) {
            if (in.fullbright > 0.5 && !front) discard_fragment();
            return float4(powerColor(skyColor(in.world-eye.xyz,tex).rgb,power),1);
        }
        struct SkyOut { float4 position [[position]]; float2 uv; };
        vertex SkyOut skyVertex(uint id [[vertex_id]]) {
            float2 p = float2((id << 1) & 2, id & 2);
            SkyOut o; o.position = float4(p*2.0-1.0,0.999999,1.0); o.uv = p; return o;
        }
        fragment float4 tintFragment(SkyOut in [[stage_in]], constant float4 &color [[buffer(0)]]) { return color; }
        fragment float4 skyFragment(SkyOut in [[stage_in]], constant float4 &camera [[buffer(0)]],
                                    texture2d<float> tex [[texture(0)]], constant float4 &power [[buffer(2)]]) {
            float x = (in.uv.x*2.0-1.0)*camera.z*0.57735027;
            float y = (in.uv.y*2.0-1.0)*0.57735027;
            float f = cos(camera.y)-y*sin(camera.y), h = sin(camera.y)+y*cos(camera.y);
            return float4(powerColor(skyColor(float3(cos(camera.x)*f+sin(camera.x)*x,h,-sin(camera.x)*f+cos(camera.x)*x),tex).rgb,power),1);
        }
        """
        worldShader=shader;worldFormat=view.colorPixelFormat
        programs=try WorldPrograms(device:device,shader:shader,format:view.colorPixelFormat)
        let state = MTLDepthStencilDescriptor(); state.depthCompareFunction = .less; state.isDepthWriteEnabled = true
        guard let depth = device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create Metal depth state.") }
        self.depth = depth
        state.isDepthWriteEnabled=false;state.depthCompareFunction = .lessEqual
        guard let fuzzDepth=device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create fuzz depth state.") };self.fuzzDepth=fuzzDepth
        state.depthCompareFunction = .equal
        guard let visibleDepth=device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create visible-surface depth state.") }
        self.visibleDepth=visibleDepth
        super.init()
    }
    func load(wad: WAD, map name: String, continuing: Bool = false, restorePath: String? = nil, demo: String? = nil) throws -> (triangles:Int,missing:[String]) {
        if let current=self.wad, current.sourceURLs != wad.sourceURLs || current.sourceData != wad.sourceData {
            throw PortError("Restart MetalDooM to change the WAD stack.")
        }
        guard wad.signature == "IWAD" else { throw PortError("Choose a base IWAD before adding PWADs.") }
        if wad.sourceURLs.count>1 {
            let configured=wad.sourceURLs.map(\.path).joined(separator:"\n").withCString { paths in
                wad.engineOrder.withUnsafeBufferPointer { MD_ConfigureWADStack(paths,$0.baseAddress,Int32($0.count)) }
            }
            guard configured != 0 else { throw PortError(String(cString:MD_LastError())) }
        }
        let map = try DoomMap(wad:wad,name:name), art = try Art(wad:wad)
        let heights = try art.textureHeights(), geometry = try Geometry(map:map,textureHeights:heights)
        let loadedSprites = try SpriteRenderer(device:device,wad:wad)
        let loadedSound = try SoundPlayer(wad:wad)
        let loadedIntermission = try IntermissionRenderer(device:device,wad:wad)
        var materials = Set(geometry.batches.map(\.material))
        for side in map.sides {
            for name in [side.upper,side.lower,side.middle] where name != "-" && !name.isEmpty {
                materials.insert(MaterialKey(name:name,flat:false))
                if name.hasPrefix("SW1") || name.hasPrefix("SW2") {
                    let alternate = (name.hasPrefix("SW1") ? "SW2" : "SW1")+name.dropFirst(3)
                    if art.definitions[alternate] != nil { materials.insert(MaterialKey(name:alternate,flat:false)) }
                }
            }
        }
        var cached: [MaterialKey:MTLTexture] = [:], missing: [String] = []
        var emissionColors:[MaterialKey:SIMD4<Float>]=[:]
        var opaque = Set<MaterialKey>()
        var alphaBytes:[UInt8]=[255], alphaInfo:[ObjectIdentifier:SIMD4<UInt32>]=[:]
        func cacheMaterial(_ material: MaterialKey) throws {
            if cached[material] != nil { return }
            let source = try art.image(material)
            if source == nil { missing.append(material.name) }
            let pixels = source ?? Art.fallback
            emissionColors[material]=source == nil ? .zero:SurfaceLightCollector.color(material:material,pixels:pixels)
            if stride(from:3,to:pixels.rgba.count,by:4).allSatisfy({ pixels.rgba[$0] >= 128 }) { opaque.insert(material) }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:pixels.width,height:pixels.height,mipmapped:true)
            descriptor.usage = .shaderRead; descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor:descriptor) else {
                throw PortError("Cannot allocate Metal map resources.")
            }
            pixels.rgba.withUnsafeBytes { bytes in
                texture.replace(region:MTLRegionMake2D(0,0,pixels.width,pixels.height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:pixels.width*4)
            }
            if opaque.contains(material) { alphaInfo[ObjectIdentifier(texture)]=SIMD4(0,1,1,0) }
            else {
                guard alphaBytes.count+pixels.width*pixels.height<=Int(UInt32.max) else { throw PortError("AO alpha masks are too large.") }
                alphaInfo[ObjectIdentifier(texture)]=SIMD4(UInt32(alphaBytes.count),UInt32(pixels.width),UInt32(pixels.height),0)
                alphaBytes.append(contentsOf:stride(from:3,to:pixels.rgba.count,by:4).map { pixels.rgba[$0] })
            }
            cached[material] = texture
        }
        for material in materials { try cacheMaterial(material) }
        let loaded = try makeBatches(geometry,textures:cached)
        let skyName = wad.skyName(for:name)
        var loadedSky: MTLTexture?
        if let pixels = try art.image(MaterialKey(name:skyName,flat:false)) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:pixels.width,height:pixels.height,mipmapped:false)
            descriptor.usage = .shaderRead; descriptor.storageMode = .shared
            loadedSky = device.makeTexture(descriptor:descriptor)
            pixels.rgba.withUnsafeBytes { bytes in
                loadedSky?.replace(region:MTLRegionMake2D(0,0,pixels.width,pixels.height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:pixels.width*4)
            }
        }
        let loadedMusic = try MusicPlayer(wad:wad,map:name)
        let episode = name.hasPrefix("E") ? Int(String(name.dropFirst().prefix(1))) ?? 1 : 1
        let number = name.hasPrefix("MAP") ? Int(name.dropFirst(3)) ?? 1 : Int(name.suffix(1)) ?? 1
        let result = restorePath.map { MD_ReadSave($0) } ?? (continuing ? MD_Continue() : MD_LoadSkill(wad.url.path,Int32(episode),Int32(number),skill))
        guard result != 0 else {
            if MD_SectorCount() == 0 { engineReady = false }
            throw PortError(String(cString:MD_LastError()))
        }
        if let demo, MD_StartDemo(demo)==0 { throw PortError(String(cString:MD_LastError())) }
        guard MD_SectorCount() == map.sectors.count else { engineReady = false; throw PortError("Engine and Metal sector counts differ.") }
        var animationIDs: [MaterialKey:Int32]=[:], walls: [Int32:MTLTexture]=[:], flats: [Int32:MTLTexture]=[:]
        var frames=Array(repeating:MD_Material(),count:Int(MD_CopyAnimatedMaterials(nil,0)))
        _ = MD_CopyAnimatedMaterials(&frames,Int32(frames.count))
        for var frame in frames {
            let frameName=withUnsafePointer(to:&frame.name) { $0.withMemoryRebound(to:CChar.self,capacity:9) { String(cString:$0) } }
            let key=MaterialKey(name:frameName,flat:frame.flat != 0)
            try cacheMaterial(key); animationIDs[key]=frame.index
            if key.flat { flats[frame.index]=cached[key] } else { walls[frame.index]=cached[key] }
        }
        guard let mipCommand=queue.makeCommandBuffer(), let mipEncoder=mipCommand.makeBlitCommandEncoder() else {
            throw PortError("Cannot prepare world texture mipmaps.")
        }
        for texture in cached.values { mipEncoder.generateMipmaps(for:texture) }
        mipEncoder.endEncoding();mipCommand.commit();mipCommand.waitUntilCompleted()
        guard mipCommand.status == .completed else { throw PortError("World texture mipmap generation failed.") }
        // Conservatively alpha-test animated walls if any animation frame is masked.
        let maskedWallAnimation=animationIDs.contains { !$0.key.flat && !opaque.contains($0.key) }
        if maskedWallAnimation { for key in animationIDs.keys where !key.flat { opaque.remove(key) } }
        animatedIDs=animationIDs; animatedWalls=walls; animatedFlats=flats
        demoPlayback = demo != nil
        skill=MD_GetSkill()
        progress = MD_GetProgress(); intermission = IntermissionSequence(progress); intermissionTime = 0; deathTime = 0; finale = FinaleSequence(); lastGeometryTick = -1
        intermissionArt = loadedIntermission
        textureHeights = heights
        guard let alphaBuffer=device.makeBuffer(bytes:alphaBytes,length:alphaBytes.count,options:.storageModeShared) else { throw PortError("Cannot allocate AO alpha masks.") }
        aoAlphaBuffer=alphaBuffer;aoAlphaInfo=alphaInfo
        opaqueMaterials=opaque;aoGeometryDirty=true
        surfaceColors=emissionColors;surfaceLights=[];surfaceLightsDirty=true
        self.map = map; self.wad = wad; textures = cached; batches = loaded; sky = loadedSky; sprites = loadedSprites; pitch = 0
        music?.update(active:false); music=loadedMusic; music?.enabled=musicEnabled; music?.volume=musicVolume
        sound = loadedSound; sound?.volume=effectsVolume; sound?.drain()
        hud = MD_GetHUD(); messageSerial = hud.messageSerial; messageUntil = hud.messageSerial > 0 ? hud.tick+140 : 0
        secretNotice.reset(hud)
        currentPlayer = MD_GetPlayer(); previousPlayer = currentPlayer
        position = SIMD2(currentPlayer.x,currentPlayer.y); yaw = currentPlayer.angle; eyeZ = currentPlayer.eyeZ
        accumulator = 0; pendingTurn = 0; turnHeld = 0; lastTime = CACurrentMediaTime(); engineReady = true
        try uploadSkyGeometry(geometry)
        try syncGeometry()
        return (geometry.triangleCount,Array(Set(missing)).sorted())
    }
    func saveGame(to url: URL, title: String? = nil) throws {
        guard engineReady, let wad, let map else { throw PortError("Open a WAD before saving.") }
        try SaveStore.write(to:url,wad:wad,map:map.name,pitch:pitch,title:title)
        notice = "Game saved"; noticeUntil = CACurrentMediaTime()+3
    }
    func loadGame(from url: URL) throws {
        guard let wad else { throw PortError("Open the matching WAD before loading a save.") }
        let save = try SaveStore.read(from:url,wad:wad)
        let temporary = SaveStore.temporaryURL(); defer { try? FileManager.default.removeItem(at:temporary) }
        try save.payload.write(to:temporary,options:.atomic)
        _ = try load(wad:wad,map:save.map,restorePath:temporary.path)
        pitch = save.pitch; onMapChanged?(save.map)
        notice = "Game loaded"; noticeUntil = CACurrentMediaTime()+3
    }
    func reset() throws { if let wad, let map { _ = try load(wad:wad,map:map.name) } }
    private func makeBatches(_ geometry: Geometry, textures: [MaterialKey:MTLTexture]) throws -> [GPUBatch] {
        try geometry.batches.map { batch in
            guard let texture = textures[batch.material],
                  let buffer = device.makeBuffer(bytes:batch.vertices,length:batch.vertices.count*MemoryLayout<WorldVertex>.stride,options:.storageModeShared) else {
                throw PortError("Unable to update moving sector geometry (\(batch.material.name)).")
            }
            return GPUBatch(vertices:buffer,texture:texture,material:batch.material,count:batch.vertices.count)
        }
    }
    private func animatedTexture(_ batch: GPUBatch) -> MTLTexture {
        guard let index=animatedIDs[batch.material] else { return batch.texture }
        let translated=MD_TranslatedMaterial(index,batch.material.flat ? 1 : 0)
        return (batch.material.flat ? animatedFlats[translated] : animatedWalls[translated]) ?? batch.texture
    }
    private func uploadSkyGeometry(_ geometry: Geometry) throws {
        skyVertexCount = geometry.skyVertices.count
        skyGeometry = nil
        if skyVertexCount > 0 {
            skyGeometry = device.makeBuffer(bytes:geometry.skyVertices,length:skyVertexCount*MemoryLayout<WorldVertex>.stride,options:.storageModeShared)
            guard skyGeometry != nil else { throw PortError("Cannot allocate sky boundaries.") }
        }
    }
    private func syncGeometry() throws {
        guard var map, lastGeometryTick != currentPlayer.tick else { return }
        lastGeometryTick = currentPlayer.tick
        var changed = false, surfacesChanged = false
        func name<T>(_ tuple: T) -> String {
            var value = tuple
            return withUnsafePointer(to:&value) { $0.withMemoryRebound(to:CChar.self,capacity:9) { String(cString:$0).uppercased() } }
        }
        for index in map.sides.indices {
            let state = MD_GetSide(Int32(index)), old = map.sides[index]
            let upper = name(state.upper), lower = name(state.lower), middle = name(state.middle)
            if old.x != state.x || old.y != state.y || old.upper != upper || old.lower != lower || old.middle != middle {
                map.sides[index] = Side(sector:old.sector,x:state.x,y:state.y,upper:upper,lower:lower,middle:middle); changed = true
                surfacesChanged = surfacesChanged || old.upper != upper || old.lower != lower || old.middle != middle
            }
        }
        for index in map.sectors.indices {
            let state = MD_GetSector(Int32(index)), old = map.sectors[index]
            if state.floor != old.floor || state.ceiling != old.ceiling || state.light != old.light {
                surfacesChanged = surfacesChanged || state.floor != old.floor || state.ceiling != old.ceiling
                map.sectors[index] = Sector(floor:state.floor,ceiling:state.ceiling,light:state.light,floorTexture:old.floorTexture,ceilingTexture:old.ceilingTexture)
                changed = true
            }
        }
        if changed {
            let geometry = try Geometry(map:map,textureHeights:textureHeights)
            batches = try makeBatches(geometry,textures:textures)
            aoGeometryDirty=true;surfaceLightsDirty = surfaceLightsDirty || surfacesChanged
            try uploadSkyGeometry(geometry)
            self.map = map
        }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in mtkView: MTKView) {
        guard let view = mtkView as? GameView else { return }
        // Occluded/minimized windows must not compete with the active game for GPU time.
        if !view.isPaused && (view.window?.isMiniaturized == true || view.window?.occlusionState.contains(.visible) == false) {
            lastTime=CACurrentMediaTime();pauseAudio();return
        }
        let time = CACurrentMediaTime(), delta = min(time-lastTime,0.25); lastTime = time
        do { try update(view:view,delta:delta) }
        catch { engineReady = false; view.releaseMouse(); DispatchQueue.main.async { [weak self] in self?.onError?(error) } }
        onHUDFrame?()
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer() else { return }
        inFlight.wait()
        let semaphore = inFlight
        command.addCompletedHandler { [weak self] buffer in
            if let error = buffer.error {
                DispatchQueue.main.async { [weak self] in
                    self?.disableRayEffects()
                    self?.bloom=nil;self?.sceneEffects.remove(.bloom)
                    self?.particles=nil;self?.sceneEffects.remove(.particles)
                    self?.onWarning?("Metal command error (ray-traced effects, bloom and particles disabled): \(error)")
                }
            }
            let gpuTime=max(0,buffer.gpuEndTime-buffer.gpuStartTime)
            DispatchQueue.main.async { [weak self] in
                self?.recentGPUTime=gpuTime
                self?.onGPUFrame?(gpuTime)
            }
            semaphore.signal()
        }
        do { try prepareAmbientOcclusion(command:command) }
        catch {
            disableRayEffects()
            DispatchQueue.main.async { [weak self] in self?.onWarning?("Ray-traced effects disabled: \(error)") }
        }
        // HDR retains the original palette shading in an extended floating-point scene.
        // Presentation converts its transfer function to linear EDR after the HUD.
        var sceneTarget=drawable.texture
        do {
            if let hdrOutput {
                sceneTarget=try hdrOutput.scene(width:drawable.texture.width,height:drawable.texture.height)
                pass.colorAttachments[0].texture=sceneTarget
            }
            if volume != nil {
                if effectDepth?.width != sceneTarget.width || effectDepth?.height != sceneTarget.height {
                    let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:sceneTarget.width,height:sceneTarget.height,mipmapped:false)
                    d.storageMode = .private;d.usage = [.renderTarget,.shaderRead]
                    guard let texture=device.makeTexture(descriptor:d) else { throw PortError("Cannot allocate volumetric depth.") }
                    effectDepth=texture
                }
                pass.depthAttachment.texture=effectDepth
            }
        } catch {
            command.commit()
            DispatchQueue.main.async { [weak self] in self?.onWarning?("Cannot allocate effects frame: \(error)") }
            return
        }
        pass.depthAttachment.storeAction = .store
        // A BVH build may already be encoded. Submit it even if the render
        // encoder fails, so the next frame never consumes an unbuilt structure.
        guard var encoder = command.makeRenderCommandEncoder(descriptor:pass) else { command.commit(); return }
        var power=SIMD4<Float>(hud.fixedColorMap==32 ? 1:0,hud.fixedColorMap==1 ? 1:0,Float(hud.tick),sceneEffects.contains(.textureFiltering) ? 1:0)
        var noPower=SIMD4<Float>.zero
        encoder.setFragmentBytes(&power,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
        encoder.setRenderPipelineState(pipeline); encoder.setDepthStencilState(depth); encoder.setCullMode(.none); encoder.setFrontFacing(.counterClockwise)
        if progress.phase != 0, let intermissionArt {
            encoder.setRenderPipelineState(spritePipeline)
            encoder.setFragmentBytes(&noPower,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
            intermissionArt.draw(encoder:encoder,state:progress,sequence:intermission,finale:finale,width:max(1,view.drawableSize.width),height:max(1,view.drawableSize.height))
        } else if map != nil {
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
            if let skyGeometry, let sky {
                var skyEye = SIMD4(eye,1)
                encoder.setRenderPipelineState(skySurfacePipeline)
                encoder.setVertexBuffer(skyGeometry,offset:0,index:0)
                encoder.setFragmentBytes(&skyEye,length:MemoryLayout<SIMD4<Float>>.stride,index:0)
                encoder.setFragmentTexture(sky,index:0)
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:skyVertexCount)
                encoder.setRenderPipelineState(pipeline)
            }
            if let ao=ambientOcclusion, let structure=ao.structure, let vertices=ao.vertices, let materials=ao.materials, let alpha=aoAlphaBuffer {
                // Resolve exact world visibility cheaply before running any per-pixel rays.
                // Alpha coverage matches the shading pass; this pass never writes color.
                encoder.setRenderPipelineState(programs.visibility);encoder.setDepthStencilState(depth)
                for batch in batches {
                    encoder.setVertexBuffer(batch.vertices,offset:0,index:0);encoder.setFragmentTexture(animatedTexture(batch),index:0)
                    encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:batch.count)
                }
                encoder.setDepthStencilState(visibleDepth)
                var aoEye=SIMD4(eye,1)
                encoder.setRenderPipelineState(ao.pipeline)
                encoder.setFragmentBytes(&aoEye,length:MemoryLayout<SIMD4<Float>>.stride,index:3)
                encoder.setFragmentAccelerationStructure(structure,bufferIndex:4)
                encoder.setFragmentBuffer(vertices,offset:0,index:5)
                encoder.setFragmentBuffer(materials,offset:0,index:6)
                encoder.setFragmentBuffer(alpha,offset:0,index:7)
                var settings=aoSettings.uniform
                settings.z=highRayQuality ? 16:8
                if !ambientOcclusionEnabled { settings.y=0 }
                encoder.setFragmentBytes(&settings,length:MemoryLayout<SIMD4<Float>>.stride,index:8)
                var lights=sceneLights()
                var count=UInt32(lights.count)
                if lights.isEmpty { lights=[DynamicLightUniforms()] }
                lights.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!,length:$0.count,index:9) }
                encoder.setFragmentBytes(&count,length:MemoryLayout<UInt32>.stride,index:10)
            }
            for batch in batches {
                var emission=sceneEffects.contains(.emissive) ? emissionSettings(batch.material):.zero
                encoder.setFragmentBytes(&emission,length:MemoryLayout<SIMD4<Float>>.stride,index:11)
                encoder.setVertexBuffer(batch.vertices,offset:0,index:0); encoder.setFragmentTexture(animatedTexture(batch),index:0)
                encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:batch.count)
            }
            encoder.setDepthStencilState(depth)
            if let sprites, engineReady {
                encoder.setRenderPipelineState(sceneEffects.contains(.spriteLighting) && ambientOcclusion?.structure != nil
                    ? ambientOcclusion!.spritePipeline:spritePipeline)
                do { try sprites.drawWorld(encoder:encoder,camera:position,yaw:yaw) }
                catch { engineReady = false; DispatchQueue.main.async { [weak self] in self?.onError?(error) } }
                if sprites.hasFuzz || hud.invisibility>128 || (hud.invisibility&8) != 0 {
                    if sceneSnapshot?.width != Int(width) || sceneSnapshot?.height != Int(height) {
                        let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:view.colorPixelFormat,width:Int(width),height:Int(height),mipmapped:false)
                        d.storageMode = .private;d.usage = .shaderRead;sceneSnapshot=device.makeTexture(descriptor:d)
                    }
                    if let snapshot=sceneSnapshot {
                        encoder.endEncoding()
                        if let blit=command.makeBlitCommandEncoder() {
                            blit.copy(from:sceneTarget,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:Int(width),height:Int(height),depth:1),to:snapshot,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0));blit.endEncoding()
                        }
                        pass.colorAttachments[0].loadAction = .load;pass.depthAttachment.loadAction = .load
                        guard let resumed=command.makeRenderCommandEncoder(descriptor:pass) else { command.commit();return }
                        encoder=resumed;encoder.setViewport(MTLViewport(originX:0,originY:0,width:width,height:worldHeight,znear:0,zfar:1))
                        encoder.setFrontFacing(.counterClockwise);encoder.setCullMode(.none)
                        encoder.setVertexBytes(&uniform,length:MemoryLayout<Uniforms>.stride,index:1)
                        encoder.setFragmentBytes(&power,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                        encoder.setFragmentTexture(snapshot,index:1);encoder.setRenderPipelineState(fuzzPipeline);encoder.setDepthStencilState(fuzzDepth)
                        try? sprites.drawWorld(encoder:encoder,camera:position,yaw:yaw,fuzz:true)
                    }
                }
                if let particles, power.x==0 && power.y==0 {
                    do { try particles.draw(encoder:encoder,camera:position,eye:eye,yaw:yaw,pitch:pitch,tics:hud.levelTics,matrix:uniform.matrix) }
                    catch {
                        self.particles=nil;sceneEffects.remove(.particles)
                        DispatchQueue.main.async { [weak self] in self?.onWarning?("Particles disabled: \(error)") }
                    }
                }
                if let volume, let ao=ambientOcclusion, let alpha=aoAlphaBuffer,
                   let depthTexture=effectDepth, power.x==0 && power.y==0 {
                    encoder.endEncoding()
                    var ready=false
                    do {
                        try volume.prepare(command:command,depth:depthTexture,worldHeight:Int(worldHeight),
                            inverse:uniform.matrix.inverse,eye:eye,lights:sceneLights(),ao:ao,alpha:alpha,density:fogDensity,steps:highRayQuality ? 32:16)
                        ready=true
                    } catch {
                        self.volume=nil;sceneEffects.remove(.volumetrics)
                        DispatchQueue.main.async { [weak self] in self?.onWarning?("Volumetric lighting disabled: \(error)") }
                    }
                    pass.colorAttachments[0].loadAction = .load;pass.depthAttachment.loadAction = .load
                    guard let resumed=command.makeRenderCommandEncoder(descriptor:pass) else { command.commit();return }
                    encoder=resumed;encoder.setViewport(MTLViewport(originX:0,originY:0,width:width,height:worldHeight,znear:0,zfar:1))
                    if ready { volume.draw(encoder:encoder) }
                    encoder.setFragmentBytes(&power,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                }
                // Complete world effects before either weapon pass and the HUD.
                if let bloom, power.x==0 && power.y==0 {
                    encoder.endEncoding()
                    var ready=false
                    do { try bloom.prepare(command:command,source:sceneTarget,worldHeight:Int(worldHeight));ready=true }
                    catch {
                        self.bloom=nil;sceneEffects.remove(.bloom)
                        DispatchQueue.main.async { [weak self] in self?.onWarning?("Bloom disabled: \(error)") }
                    }
                    pass.colorAttachments[0].loadAction = .load;pass.depthAttachment.loadAction = .load
                    guard let resumed=command.makeRenderCommandEncoder(descriptor:pass) else { command.commit();return }
                    encoder=resumed;encoder.setViewport(MTLViewport(originX:0,originY:0,width:width,height:worldHeight,znear:0,zfar:1))
                    encoder.setCullMode(.none);encoder.setFrontFacing(.counterClockwise)
                    if ready { bloom.draw(encoder:encoder,width:width,height:worldHeight) }
                    encoder.setFragmentBytes(&power,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                }
                // Weapons and HUD stay at standard white in HDR.
                power.w=0;encoder.setFragmentBytes(&power,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                if (hud.invisibility>128 || (hud.invisibility&8) != 0), let snapshot=sceneSnapshot {
                    encoder.setFragmentTexture(snapshot,index:1);encoder.setRenderPipelineState(fuzzPipeline)
                    sprites.drawWeapon(encoder:encoder,width:width,height:worldHeight,fuzz:true)
                }
                encoder.setRenderPipelineState(spritePipeline)
                sprites.drawWeapon(encoder:encoder,width:width,height:worldHeight)
                if hud.damageFlash > 0 || hud.bonusFlash > 0 || hud.suitFlash != 0 || hud.berserkFlash>0 {
                    var tint: SIMD4<Float> = max(hud.damageFlash,hud.berserkFlash)>0
                        ? SIMD4(1,0,0,min(0.45,Float(max(hud.damageFlash,hud.berserkFlash))/80))
                        : hud.bonusFlash>0 ? SIMD4(1,0.8,0.1,min(0.15,Float(hud.bonusFlash)/160)) : SIMD4(0,1,0,0.18)
                    encoder.setRenderPipelineState(tintPipeline)
                    encoder.setFragmentBytes(&tint,length:MemoryLayout<SIMD4<Float>>.stride,index:0)
                    encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
                    encoder.setRenderPipelineState(spritePipeline)
                }
                encoder.setFragmentBytes(&noPower,length:MemoryLayout<SIMD4<Float>>.stride,index:2)
                sprites.drawHUD(encoder:encoder,state:hud,width:width,height:height)
            }
        }
        encoder.endEncoding()
        if let hdrOutput {
            hdrOutput.present(command:command,source:sceneTarget,target:drawable.texture,
                headroom:Float(view.window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1),peak:hdrPeak)
        }
        command.present(drawable); command.commit(); renderedFrames += 1
        onSubmittedFrame?(CACurrentMediaTime())
        frames += 1
        if time-reportTime >= 0.5 { onFrame?(Double(frames)/(time-reportTime)); frames = 0; reportTime = time }
    }
    private func update(view: GameView, delta: Double) throws {
        guard engineReady else { return }
        guard !paused, NSApp.isActive, view.window?.isKeyWindow == true, view.window?.attachedSheet == nil else {
            try sound?.setActive(false); music?.update(active:false)
            accumulator = 0; pendingTurn = 0; previousPlayer = currentPlayer; return
        }
        try sound?.setActive(true); music?.update(active:true)
        if view.keys.remove(15) != nil { view.releaseMouse(); try reset(); return }
        if progress.phase != 0 {
            intermissionTime += delta
            let pressed = (view.continueQueued || view.useQueued) && intermissionTime >= 0.3
            view.continueQueued = false; view.useQueued = false
            if progress.phase==4 {
                accumulator += delta
                let attack=view.consumeAttack() != 0
                castAttackQueued = castAttackQueued || pressed || attack
                while accumulator>=1.0/35.0 {
                    guard MD_CastTick(castAttackQueued ? 1:0) != 0 else { throw PortError(String(cString:MD_LastError())) }
                    castAttackQueued=false; accumulator -= 1.0/35.0
                }
            } else if progress.phase==3 {
                _ = finale.update(seconds:delta,pressed:pressed)
                if finale.art {
                    if progress.map==30 {
                        guard MD_StartCast() != 0 else { throw PortError("Cannot begin the cast ending.") }
                        progress=MD_GetProgress(); accumulator=0; castAttackQueued=false; try music?.select("D_EVIL")
                    } else if let wad {
                        let name=String(format:"MAP%02d",progress.nextMap)
                        view.releaseMouse(); _ = try load(wad:wad,map:name,continuing:true); onMapChanged?(name)
                    }
                }
            } else if progress.phase==2 && progress.commercial==0 {
                for event in finale.update(seconds:delta,pressed:pressed) {
                    if event==3 { try music?.select("D_BUNNY") } else { MD_IntermissionSound(event) }
                }
            } else {
                for event in intermission.update(seconds:delta,pressed:pressed) { MD_IntermissionSound(event) }
            }
            sound?.drain()
            if progress.phase==1 && intermission.advance, let wad {
                if MD_BeginStory() != 0 {
                    progress=MD_GetProgress(); intermissionTime=0
                    finale=FinaleSequence(textLength:String(cString:MD_StoryText()).count,commercial:true)
                    try music?.select("D_READ_M");return
                }
                let name = progress.commercial != 0 ? String(format:"MAP%02d",progress.nextMap) : "E\(progress.episode)M\(progress.nextMap)"
                view.releaseMouse(); _ = try load(wad:wad,map:name,continuing:true); onMapChanged?(name)
            }
            return
        }
        if currentPlayer.health <= 0 && !demoPlayback {
            deathTime += delta
            let restart = (view.useQueued || view.continueQueued) && deathTime >= 0.75
            view.useQueued=false; view.continueQueued=false
            if restart { view.releaseMouse(); try reset(); return }
        }
        view.continueQueued = false
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
            guard MD_CombatTick(forward,side,turn,use,view.consumeAttack(),view.consumeWeapon()) != 0 else { throw PortError(String(cString:MD_LastError())) }
            sound?.drain()
            currentPlayer = MD_GetPlayer(); accumulator -= step
            hud = MD_GetHUD(); progress = MD_GetProgress()
            secretNotice.update(hud)
            if previousPlayer.health > 0 && currentPlayer.health <= 0 && !demoPlayback {
                view.releaseMouse(); deathTime=0
            }
            if demoPlayback && MD_DemoPlaying()==0 { paused=true;accumulator=0;break }
            if progress.phase != 0 {
                view.releaseMouse(); accumulator = 0; intermissionTime = 0; messageUntil = 0
                intermission = IntermissionSequence(progress)
                finale = FinaleSequence(episode:progress.episode,textLength:(progress.episode==5 ? (wad?.sigilStory ?? "") : String(cString:MD_FinaleText(progress.episode))).count)
                try music?.select(MusicPlayer.endTrack(progress))
                break
            }
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
