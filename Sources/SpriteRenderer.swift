// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

private struct GPUPatch {
    let texture: MTLTexture
    let indices:MTLTexture?
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
    private var previewWeapons:[MD_WeaponSprite]?
    private var previewBlend:[Int]=[],previewWeaponBlend:[Int]=[]
    private var previewClips:[SIMD2<Float>]=[]
    private var blendPalette:MTLBuffer?
    private var blendTextures:[MTLTexture]=[]
    private let hudDepth: MTLDepthStencilState
    init(device: MTLDevice, wad: WAD, preload: Bool = true, hudOnly:Bool=false) throws {
        self.device = device; art = try Art(wad:wad)
        let state = MTLDepthStencilDescriptor(); state.depthCompareFunction = .always; state.isDepthWriteEnabled = false
        guard let depth = device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create HUD depth state.") }
        hudDepth = depth
        if !preload && !hudOnly { return }
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
        let labelNames=Set((hudOnly ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ":"HEALTHARMOM").unicodeScalars.map { String(format:"STCFN%03d",$0.value) })
        for name in labelNames {
            if let patch=try art.patch(named:name) { hudPatches[name]=try upload(patch) }
        }
        for name in Array(hudPatches.keys) where name.hasPrefix("STT") || name.hasPrefix("STKEYS") || name.hasPrefix("STF") || labelNames.contains(name) {
            guard let patch=try art.patch(named:name) else { continue }
            var rgba=patch.image.rgba
            for i in stride(from:0,to:rgba.count,by:4) { rgba[i]=0;rgba[i+1]=0;rgba[i+2]=0 }
            hudPatches["shadow:"+name]=try upload(PatchImage(image:PixelImage(width:patch.image.width,height:patch.image.height,rgba:rgba),left:patch.left,top:patch.top))
        }
        if !preload { return }
        // Decode all original sprite frames once, so engine animation changes do
        // not cause frame-time texture uploads or invisible missing frames.
        var inSprites = false
        for (index,lump) in wad.lumps.enumerated() {
            if lump.name == "S_START" || lump.name == "SS_START" { inSprites = true; continue }
            if lump.name == "S_END" || lump.name == "SS_END" { inSprites = false; continue }
            if inSprites && lump.bytes.count > 0 { patches[index] = try upload(art.patch(lump:index)) }
        }
    }
    func setPreviewActorPositions(_ actors:[ExtendedSprite],fraction:Float,map:DoomMap) {
        guard actors.count==things.count else {return}
        for i in things.indices {
            let value=actors[i].position(fraction:fraction)
            things[i].x=value.x;things[i].y=value.y;things[i].z=value.z;things[i].floorZ=value.w
            previewClips[i]=map.sectors[map.sector(at:SIMD2(value.x,value.y))].spriteClip
        }
    }
    func setPreviewWeaponPositions(_ positions:[SIMD2<Float>]) {
        guard var weapons=previewWeapons,weapons.count==positions.count else {return}
        for i in weapons.indices {weapons[i].x=positions[i].x;weapons[i].y=positions[i].y}
        previewWeapons=weapons
    }
    func setPreview(things:[MD_Thing],weapons:[MD_WeaponSprite],images:[Int:PatchImage],blend:[Int]=[],weaponBlend:[Int]=[],clips:[SIMD2<Float>]=[],tables:ExtendedBlendTables?=nil) throws {
        guard blend.isEmpty || blend.count==things.count && blend.allSatisfy({(0...64).contains($0)}) else {throw PortError("Invalid sprite blend modes.")}
        if blendTextures.isEmpty,let tables {
            guard let palette=device.makeBuffer(bytes:tables.palette,length:768,options:.storageModeShared) else {throw PortError("Cannot allocate blend palette.")}
            var textures:[MTLTexture]=[]
            for index in tables.tables.indices {
                let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:256,height:256,mipmapped:false)
                d.storageMode = .shared;d.usage = .shaderRead
                guard let texture=device.makeTexture(descriptor:d) else {throw PortError("Cannot allocate blend table.")}
                tables.rgba(index:index).withUnsafeBytes {texture.replace(region:MTLRegionMake2D(0,0,256,256),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:1024)}
                textures.append(texture)
            }
            blendPalette=palette;blendTextures=textures
        }
        guard blend.allSatisfy({$0<=blendTextures.count}) else {throw PortError("Missing actor blend tables.")}
        guard clips.isEmpty || clips.count==things.count else {throw PortError("Invalid actor clipping count")}
        guard weaponBlend.isEmpty || weaponBlend.count==weapons.count && weaponBlend.allSatisfy({(0...blendTextures.count).contains($0)}) else {throw PortError("Missing weapon blend tables")}
        previewBlend=blend;previewWeaponBlend=weaponBlend;previewClips=clips
        for (index,image) in images where patches[index] == nil { patches[index]=try upload(image) }
        self.things=things;previewWeapons=weapons
    }
    private func upload(_ patch: PatchImage) throws -> GPUPatch {
        let image = patch.image
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:image.width,height:image.height,mipmapped:false)
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor:descriptor) else { throw PortError("Cannot allocate sprite texture.") }
        image.rgba.withUnsafeBytes { bytes in
            texture.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:image.width*4)
        }
        var indices:MTLTexture?
        if let values=patch.paletteIndices {
            guard values.count==image.width*image.height else {throw PortError("Invalid sprite palette indices.")}
            descriptor.pixelFormat = .r8Uint
            guard let t=device.makeTexture(descriptor:descriptor) else {throw PortError("Cannot allocate sprite indices.")}
            values.withUnsafeBytes {t.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:image.width)}
            indices=t
        }
        return GPUPatch(texture:texture,indices:indices,width:Float(image.width),height:Float(image.height),left:Float(patch.left),top:Float(patch.top))
    }
    private func worldVertices(_ thing:MD_Thing,patch:GPUPatch,yaw:Float,gain:Float,clip:SIMD2<Float>?=nil)->[WorldVertex] {
        let right=SIMD3(sin(yaw),0,cos(yaw))
        let center = SIMD3(thing.x,thing.z,-thing.y)
        let left = center-right*patch.left
        // Doom's patch origins can put artwork below the object's feet.
        // Unlike the software renderer, Metal's floor depth test clips it.
        // Lift only the visual quad, retaining offsets above the live floor.
        let bottom = max(patch.top-patch.height,thing.floorZ-thing.z)
        let low=max(thing.z+bottom,clip?.x ?? -Float.infinity)
        let high=min(thing.z+bottom+patch.height,clip?.y ?? Float.infinity)
        guard high>low else {return []}
        let a = left+SIMD3(0,low-thing.z,0), b = a+right*patch.width
        let c = b+SIMD3(0,high-low,0), d = a+SIMD3(0,high-low,0)
        let vBottom=patch.height-(low-thing.z-bottom),vTop=patch.height-(high-thing.z-bottom)
        let u0: Float = thing.flip != 0 ? patch.width : 0, u1: Float = thing.flip != 0 ? 0 : patch.width
        let light = max(0.12,thing.light), fullbright = Float(thing.fullbright)*gain
        func vertex(_ position: SIMD3<Float>, _ u: Float, _ v: Float) -> WorldVertex {
            WorldVertex(position:SIMD4(position,1),uvLight:SIMD4(u,v,light,fullbright))
        }
        return [vertex(a,u0,vBottom),vertex(b,u1,vBottom),vertex(c,u1,vTop),
                    vertex(a,u0,vBottom),vertex(c,u1,vTop),vertex(d,u0,vTop)]
    }
    func transparentActors(yaw:Float)throws->[TransparentPolygon] {
        try things.indices.filter {things[$0].shadow != 0 || !previewBlend.isEmpty && previewBlend[$0]>0}.compactMap {i -> TransparentPolygon? in
            guard let p=patches[Int(things[i].lump)],let indices=p.indices else {throw PortError("Missing translucent actor patch")}
            let v=worldVertices(things[i],patch:p,yaw:yaw,gain:1,clip:previewClips.isEmpty ? nil:previewClips[i])
            guard !v.isEmpty else {return nil}
            return TransparentPolygon(vertices:[v[0],v[1],v[2],v[5]],material:nil,texture:p.texture,indices:indices,blend:things[i].shadow != 0 ? -1:previewBlend[i],wall:false)
        }
    }
    func bindBlend(_ index:Int,encoder:MTLRenderCommandEncoder)throws {
        guard (1...blendTextures.count).contains(index) else {throw PortError("Missing transparent surface blend table")}
        encoder.setFragmentTexture(blendTextures[index-1],index:2)
        encoder.setFragmentBuffer(blendPalette,offset:0,index:3)
    }
    var hasFuzz: Bool { things.contains { $0.shadow != 0 } }
    var hasTranslucency:Bool {zip(things,previewBlend).contains {$0.0.shadow==0 && $0.1>0}}
    func drawWorld(encoder: MTLRenderCommandEncoder, camera: SIMD2<Float>, yaw: Float, fuzz: Bool=false, translucent:Bool=false, fullbrightGain: Float=1) throws {
        if previewWeapons == nil {
            let count = Int(MD_CopyThings(nil,0,camera.x,camera.y))
            if things.count != count { things = [MD_Thing](repeating:MD_Thing(),count:count) }
            if count > 0 { _ = things.withUnsafeMutableBufferPointer { MD_CopyThings($0.baseAddress,Int32(count),camera.x,camera.y) } }
        }
        var order=things.indices.filter { i in
            (things[i].shadow != 0)==fuzz && (fuzz || ((previewBlend.isEmpty ? 0:previewBlend[i])>0)==translucent)
        }
        if translucent {
            let forward=SIMD2(cos(yaw),sin(yaw))
            order.sort { a,b in
                let da=simd_dot(SIMD2(things[a].x,things[a].y)-camera,forward)
                let db=simd_dot(SIMD2(things[b].x,things[b].y)-camera,forward)
                return da==db ? a<b:da>db
            }
        }
        for index in order {
            let thing=things[index]
            guard let patch = patches[Int(thing.lump)] else { throw PortError("Missing sprite frame \(thing.lump).") }
            if translucent {
                guard let indices=patch.indices else {throw PortError("Missing translucent sprite indices.")}
                var kind:UInt32=0;encoder.setFragmentBytes(&kind,length:4,index:5)
                encoder.setFragmentTexture(blendTextures[previewBlend[index]-1],index:2)
                encoder.setFragmentTexture(indices,index:3)
                encoder.setFragmentBuffer(blendPalette,offset:0,index:3)
            }
            let vertices=worldVertices(thing,patch:patch,yaw:yaw,gain:fullbrightGain,clip:previewClips.isEmpty ? nil:previewClips[index])
            guard !vertices.isEmpty else {continue}
            encoder.setVertexBytes(vertices,length:MemoryLayout<WorldVertex>.stride*6,index:0)
            encoder.setFragmentTexture(patch.texture,index:0)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6)
        }
    }
    var weaponBlendModes:[Int] {previewWeaponBlend}
    func bindWeaponBlend(_ index:Int,encoder:MTLRenderCommandEncoder)throws {
        try bindBlend(previewWeaponBlend[index],encoder:encoder)
        guard let frame=previewWeapons?[index],let indices=patches[Int(frame.lump)]?.indices else {throw PortError("Missing weapon palette indices")}
        encoder.setFragmentTexture(indices,index:3)
        var kind:UInt32=0;encoder.setFragmentBytes(&kind,length:4,index:5)
    }
    func drawWeapon(encoder: MTLRenderCommandEncoder, width: Double, height: Double, fuzz: Bool=false, overlay: Bool=false,slot:Int?=nil) {
        var frames:[MD_WeaponSprite]
        let count:Int
        if let previewWeapons { frames=previewWeapons;count=frames.count }
        else {
            frames=[MD_WeaponSprite](repeating:MD_WeaponSprite(),count:2)
            count=Int(frames.withUnsafeMutableBufferPointer { MD_CopyWeaponSprites($0.baseAddress,2) })
        }
        encoder.setDepthStencilState(hudDepth)
        var matrix = matrix_identity_float4x4
        encoder.setVertexBytes(&matrix,length:MemoryLayout<simd_float4x4>.stride,index:1)
        // Match the classic 320x168 view: the weapon is centered and clipped at
        // the status bar. Widescreen adds space beside it, not a stretched gun.
        let scale = Float(height/(overlay ? 200:168)), originX = (Float(width)-320*scale)/2
        // Fullscreen HUD uses the 200-line canvas and bottom-anchors the weapon.
        // Its scale is independent of the selected HUD percentage.
        let originY: Float = overlay ? Float(height)-168*scale:0
        for (index,frame) in frames.prefix(Int(count)).enumerated() where (frame.shadow != 0)==fuzz && (slot==nil || slot==index) {
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
    func drawHUD(encoder: MTLRenderCommandEncoder, state: MD_HUD, width: Double, height: Double, percent: Int = 100, style: HUDStyle = .classic, portrait: Bool = false,weaponLabel:String?=nil,ammoLabel:String?=nil) {
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
        let index=max(0,min(41,Int(state.faceIndex))), pain=index/8, expression=index%8
        let face: String
        if index==41 { face="STFDEAD0" }
        else if index==40 { face="STFGOD0" }
        else if expression<3 { face="STFST\(pain)\(expression)" }
        else { face=["STFTR\(pain)0","STFTL\(pain)0","STFOUCH\(pain)","STFEVL\(pain)","STFKILL\(pain)"][expression-3] }
        if style == .minimal {
            let w=Float(width)/scale, h=Float(height)/scale
            func label(_ text: String, _ x: Float, _ y: Float) {
                var cursor=x
                for code in text.unicodeScalars {
                    let name=String(format:"STCFN%03d",code.value)
                    draw(name,cursor,y);cursor += (hudPatches[name]?.width ?? 4)
                }
            }
            // Keep the animated portrait beside health, clear of the centered gun.
            // Switching it off restores the original Minimal layout exactly.
            let shift: Float = portrait ? 36:0
            if portrait { draw(face,8,h-36) }
            label("HEALTH",8+shift,h-38);number(max(0,state.health),50+shift,h-26,"STTNUM");draw("STTPRCNT",50+shift,h-26)
            label("ARMOR",82+shift,h-38);number(state.armor,124+shift,h-26,"STTNUM");draw("STTPRCNT",124+shift,h-26)
            func rightLabel(_ text:String,_ y:Float) {
                let span=text.unicodeScalars.reduce(Float(0)) { $0+(hudPatches[String(format:"STCFN%03d",$1.value)]?.width ?? 4) }
                label(text,w-8-span,y)
            }
            if let weaponLabel { rightLabel(weaponLabel,h-52) }
            // Melee weapons have readyAmmo < 0: omit the ammo group entirely.
            if state.readyAmmo >= 0 {
                if let ammoLabel { rightLabel(ammoLabel,h-38) } else { label("AMMO",w-50,h-38) };number(state.readyAmmo,w-8,h-26,"STTNUM")
            }
            // Show both card and skull when owned; no opaque backing panels.
            for color in 0..<3 {
                for kind in 0..<2 where state.keys & (1 << (color+kind*3)) != 0 {
                    draw("STKEYS\(color+kind*3)",w-18-Float(2-color)*12,h-(weaponLabel == nil ? 54:68)-Float(kind)*10)
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
