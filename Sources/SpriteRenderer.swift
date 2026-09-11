// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

private struct GPUPatch {
    let texture: MTLTexture
    let width: Float, height: Float, left: Float, top: Float
}

enum HUDStyle: Int, CaseIterable {
    case classic, minimal
    var title: String { self == .classic ? "Classic" : "Minimal" }
}

final class SpriteRenderer {
    private let device: MTLDevice
    private let art: Art
    private var patches: [Int:GPUPatch] = [:]
    private var hudPatches: [String:GPUPatch] = [:]
    private var things: [MD_Thing] = []
    private let hudDepth: MTLDepthStencilState
    init(device: MTLDevice, wad: WAD) throws {
        self.device = device; art = try Art(wad:wad)
        let state = MTLDepthStencilDescriptor(); state.depthCompareFunction = .always; state.isDepthWriteEnabled = false
        guard let depth = device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create HUD depth state.") }
        hudDepth = depth
        let names = ["STBAR","STARMS","STTPRCNT","STFDEAD0","STFGOD0"]
            + (0...9).flatMap { ["STTNUM\($0)","STYSNUM\($0)"] }
            + (2...7).map { "STGNUM\($0)" }
            + (0...5).map { "STKEYS\($0)" }
            + (0...4).flatMap { ["STFEVL\($0)","STFTR\($0)0","STFTL\($0)0","STFOUCH\($0)","STFKILL\($0)"] }
            + (0...4).flatMap { pain in (0...2).map { "STFST\(pain)\($0)" } }
        for name in names {
            guard let patch = try art.patch(named:name) else { throw PortError("Missing HUD art: \(name).") }
            hudPatches[name] = try upload(patch)
        }
        // Minimal HUD labels reuse the WAD font. Shadow textures retain only alpha;
        // uploads happen once, never in the frame loop.
        let labelNames=Set("HEALTHARMOM".unicodeScalars.map { String(format:"STCFN%03d",$0.value) })
        for name in labelNames {
            if let patch=try art.patch(named:name) { hudPatches[name]=try upload(patch) }
        }
        for name in Array(hudPatches.keys) where name.hasPrefix("STT") || name.hasPrefix("STKEYS") || labelNames.contains(name) {
            guard let patch=try art.patch(named:name) else { continue }
            var rgba=patch.image.rgba
            for i in stride(from:0,to:rgba.count,by:4) { rgba[i]=0;rgba[i+1]=0;rgba[i+2]=0 }
            hudPatches["shadow:"+name]=try upload(PatchImage(image:PixelImage(width:patch.image.width,height:patch.image.height,rgba:rgba),left:patch.left,top:patch.top))
        }
        // Decode all original sprite frames once, so engine animation changes do
        // not cause frame-time texture uploads or invisible missing frames.
        var inSprites = false
        for (index,lump) in wad.lumps.enumerated() {
            if lump.name == "S_START" || lump.name == "SS_START" { inSprites = true; continue }
            if lump.name == "S_END" || lump.name == "SS_END" { inSprites = false; continue }
            if inSprites && lump.bytes.count > 0 { patches[index] = try upload(art.patch(lump:index)) }
        }
    }
    private func upload(_ patch: PatchImage) throws -> GPUPatch {
        let image = patch.image
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:image.width,height:image.height,mipmapped:false)
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor:descriptor) else { throw PortError("Cannot allocate sprite texture.") }
        image.rgba.withUnsafeBytes { bytes in
            texture.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:image.width*4)
        }
        return GPUPatch(texture:texture,width:Float(image.width),height:Float(image.height),left:Float(patch.left),top:Float(patch.top))
    }
    var hasFuzz: Bool { things.contains { $0.shadow != 0 } }
    func drawWorld(encoder: MTLRenderCommandEncoder, camera: SIMD2<Float>, yaw: Float, fuzz: Bool=false, fullbrightGain: Float=1) throws {
        let count = Int(MD_CopyThings(nil,0,camera.x,camera.y))
        if things.count != count { things = [MD_Thing](repeating:MD_Thing(),count:count) }
        if count > 0 { _ = things.withUnsafeMutableBufferPointer { MD_CopyThings($0.baseAddress,Int32(count),camera.x,camera.y) } }
        let right = SIMD3(sin(yaw),0,cos(yaw))
        for thing in things where (thing.shadow != 0)==fuzz {
            guard let patch = patches[Int(thing.lump)] else { throw PortError("Missing sprite frame \(thing.lump).") }
            let center = SIMD3(thing.x,thing.z,-thing.y)
            let left = center-right*patch.left
            // Doom's patch origins can put artwork below the object's feet.
            // Unlike the software renderer, Metal's floor depth test clips it.
            // Lift only the visual quad, retaining offsets above the live floor.
            let bottom = max(patch.top-patch.height,thing.floorZ-thing.z)
            let a = left+SIMD3(0,bottom,0), b = a+right*patch.width
            let c = b+SIMD3(0,patch.height,0), d = a+SIMD3(0,patch.height,0)
            let u0: Float = thing.flip != 0 ? patch.width : 0, u1: Float = thing.flip != 0 ? 0 : patch.width
            let light = max(0.12,thing.light), fullbright = Float(thing.fullbright)*fullbrightGain
            func vertex(_ position: SIMD3<Float>, _ u: Float, _ v: Float) -> WorldVertex {
                WorldVertex(position:SIMD4(position,1),uvLight:SIMD4(u,v,light,fullbright))
            }
            let vertices = [vertex(a,u0,patch.height),vertex(b,u1,patch.height),vertex(c,u1,0),
                            vertex(a,u0,patch.height),vertex(c,u1,0),vertex(d,u0,0)]
            encoder.setVertexBytes(vertices,length:MemoryLayout<WorldVertex>.stride*6,index:0)
            encoder.setFragmentTexture(patch.texture,index:0)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6)
        }
    }
    func drawWeapon(encoder: MTLRenderCommandEncoder, width: Double, height: Double, fuzz: Bool=false, overlay: Bool=false) {
        var frames = [MD_WeaponSprite](repeating:MD_WeaponSprite(),count:2)
        let count = frames.withUnsafeMutableBufferPointer { MD_CopyWeaponSprites($0.baseAddress,2) }
        encoder.setDepthStencilState(hudDepth)
        var matrix = matrix_identity_float4x4
        encoder.setVertexBytes(&matrix,length:MemoryLayout<simd_float4x4>.stride,index:1)
        // Match the classic 320x168 view: the weapon is centered and clipped at
        // the status bar. Widescreen adds space beside it, not a stretched gun.
        let scale = Float(height/(overlay ? 200:168)), originX = (Float(width)-320*scale)/2
        // Fullscreen HUD uses the 200-line canvas and bottom-anchors the weapon.
        // Its scale is independent of the selected HUD percentage.
        let originY: Float = overlay ? Float(height)-168*scale:0
        for frame in frames.prefix(Int(count)) where (frame.shadow != 0)==fuzz {
            guard let patch = patches[Int(frame.lump)] else { continue }
            let x0 = originX+(frame.x-patch.left)*scale
            let y0 = originY+(frame.y-patch.top-16)*scale
            let x1 = x0+patch.width*scale, y1 = y0+patch.height*scale
            let u0: Float = frame.flip != 0 ? patch.width : 0, u1: Float = frame.flip != 0 ? 0 : patch.width
            func vertex(_ x: Float, _ y: Float, _ u: Float, _ v: Float) -> WorldVertex {
                WorldVertex(position:SIMD4(x/Float(width)*2-1,1-y/Float(height)*2,0,1),uvLight:SIMD4(u,v,max(0.12,frame.light),Float(frame.fullbright)))
            }
            let a = vertex(x0,y1,u0,patch.height), b = vertex(x1,y1,u1,patch.height)
            let c = vertex(x1,y0,u1,0), d = vertex(x0,y0,u0,0)
            encoder.setVertexBytes([a,b,c,a,c,d],length:MemoryLayout<WorldVertex>.stride*6,index:0)
            encoder.setFragmentTexture(patch.texture,index:0)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6)
        }
    }
    // Percent of the classic width-based size. Keep a one-pixel artwork minimum
    // and a whole-pixel bar height so the world/HUD boundary cannot leave a seam.
    static let hudSizes = [25,50,75,100]
    static func hudPixelScale(width: Double, percent: Int = 100) -> Double {
        let factor=Double(hudSizes.contains(percent) ? percent:100)/100
        return max(1,(max(1,floor(width/320))*factor*32).rounded()/32)
    }
    static func hudHeight(width: Double, percent: Int = 100) -> Double { 32*hudPixelScale(width:width,percent:percent) }
    func drawHUD(encoder: MTLRenderCommandEncoder, state: MD_HUD, width: Double, height: Double, percent: Int = 100, style: HUDStyle = .classic) {
        encoder.setDepthStencilState(hudDepth)
        encoder.setViewport(MTLViewport(originX:0,originY:0,width:width,height:height,znear:0,zfar:1))
        let scale = Float(Self.hudPixelScale(width:width,percent:percent))
        let originX: Float = style == .minimal ? 0:(Float(width)-320*scale)/2
        let originY: Float = style == .minimal ? 0:Float(height)-32*scale
        // Identity transform lets the shared vertex shader draw screen-space quads.
        var matrix = matrix_identity_float4x4
        encoder.setVertexBytes(&matrix,length:MemoryLayout<simd_float4x4>.stride,index:1)
        func patch(_ name: String, _ x: Float, _ y: Float) {
            guard let patch = hudPatches[name] else { return }
            let x0 = originX+(x-patch.left)*scale, y0 = originY+(y-patch.top)*scale
            let x1 = x0+patch.width*scale, y1 = y0+patch.height*scale
            func vertex(_ x: Float, _ y: Float, _ u: Float, _ v: Float) -> WorldVertex {
                WorldVertex(position:SIMD4(x/Float(width)*2-1,1-y/Float(height)*2,0,1),uvLight:SIMD4(u,v,1,1))
            }
            let a = vertex(x0,y1,0,patch.height), b = vertex(x1,y1,patch.width,patch.height)
            let c = vertex(x1,y0,patch.width,0), d = vertex(x0,y0,0,0)
            encoder.setVertexBytes([a,b,c,a,c,d],length:MemoryLayout<WorldVertex>.stride*6,index:0)
            encoder.setFragmentTexture(patch.texture,index:0)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6)
        }
        func draw(_ name: String, _ x: Float, _ y: Float) {
            if style == .minimal { patch("shadow:"+name,x+1,y+1) }
            patch(name,x,y)
        }
        func number(_ value: Int32, _ right: Float, _ y: Float, _ prefix: String) {
            guard value >= 0 else { return }
            var x = right
            for digit in String(min(value,999)).reversed() {
                let name = "\(prefix)\(digit)"
                x -= hudPatches[name]?.width ?? 0; draw(name,x,y)
            }
        }
        if style == .minimal {
            let w=Float(width)/scale, h=Float(height)/scale
            func label(_ text: String, _ x: Float, _ y: Float) {
                var cursor=x
                for code in text.unicodeScalars {
                    let name=String(format:"STCFN%03d",code.value)
                    draw(name,cursor,y);cursor += (hudPatches[name]?.width ?? 4)
                }
            }
            label("HEALTH",8,h-38);number(max(0,state.health),50,h-26,"STTNUM");draw("STTPRCNT",50,h-26)
            label("ARMOR",82,h-38);number(state.armor,124,h-26,"STTNUM");draw("STTPRCNT",124,h-26)
            // Melee weapons have readyAmmo < 0: omit the ammo group entirely.
            if state.readyAmmo >= 0 {
                label("AMMO",w-50,h-38);number(state.readyAmmo,w-8,h-26,"STTNUM")
            }
            // Show both card and skull when owned; no opaque backing panels.
            for color in 0..<3 {
                for kind in 0..<2 where state.keys & (1 << (color+kind*3)) != 0 {
                    draw("STKEYS\(color+kind*3)",w-18-Float(2-color)*12,h-54-Float(kind)*10)
                }
            }
            return
        }
        // Rerelease IWADs extend STBAR on both sides of the classic 320-wide
        // layout. Center that artwork without scaling its labels or moving the
        // foreground widgets. The viewport clips the extra side decoration;
        // original 320-wide patches retain their existing position and offsets.
        let backgroundX = min(0, (320 - (hudPatches["STBAR"]?.width ?? 320)) / 2)
        draw("STBAR",backgroundX,0); draw("STARMS",104,0)
        number(state.readyAmmo,44,3,"STTNUM")
        number(max(0,state.health),90,3,"STTNUM"); draw("STTPRCNT",90,3)
        number(state.armor,221,3,"STTNUM"); draw("STTPRCNT",221,3)
        let index=max(0,min(41,Int(state.faceIndex))), pain=index/8, expression=index%8
        let face: String
        if index==41 { face="STFDEAD0" }
        else if index==40 { face="STFGOD0" }
        else if expression<3 { face="STFST\(pain)\(expression)" }
        else { face=["STFTR\(pain)0","STFTL\(pain)0","STFOUCH\(pain)","STFEVL\(pain)","STFKILL\(pain)"][expression-3] }
        draw(face,143,0)
        for i in 0..<6 {
            let owned = state.weapons & (1 << (i+1)) != 0
            draw("\(owned ? "STYSNUM" : "STGNUM")\(i+2)",Float(111+(i%3)*12),Float(4+(i/3)*10))
        }
        for color in 0..<3 {
            let skull = state.keys & (1 << (color+3)) != 0, card = state.keys & (1 << color) != 0
            if skull || card { draw("STKEYS\(color+(skull ? 3 : 0))",239,Float(3+color*10)) }
        }
        for (value,maximum,y) in [(state.bullets,state.maxBullets,5),(state.shells,state.maxShells,11),
                                   (state.rockets,state.maxRockets,17),(state.cells,state.maxCells,23)] {
            number(value,288,Float(y),"STYSNUM"); number(maximum,314,Float(y),"STYSNUM")
        }
    }
}
