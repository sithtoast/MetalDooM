// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

final class IntermissionRenderer {
    private struct Patch { let texture: MTLTexture; let width, height, left, top: Float }
    private var patches: [String:Patch] = [:]
    private let depth: MTLDepthStencilState
    private let ultimate: Bool
    private let stories = (1...4).map { String(cString:MD_FinaleText(Int32($0))) }
    init(device: MTLDevice, wad: WAD) throws {
        ultimate = wad.lump("E4M1") != nil
        let descriptor = MTLDepthStencilDescriptor(); descriptor.depthCompareFunction = .always
        depth = device.makeDepthStencilState(descriptor:descriptor)!
        let art = try Art(wad:wad)
        let flats = ["FLOOR4_8","SFLR6_1","MFLR8_4","MFLR8_3"]
        let names = ["WISPLAT","WIURH0","WIURH1","WISUCKS","INTERPIC","WIMAP0","WIMAP1","WIMAP2","WIF","WIENTER","WIOSTK","WIOSTI","WISCRT2","WITIME","WIPAR","WIPCNT","WICOLON"]
            + (0...9).map { "WINUM\($0)" }
            + (0...3).flatMap { episode in (0...8).map { "WILV\(episode)\($0)" } }
            + (0...31).map { String(format:"CWILV%02d",$0) }
            + ["CREDIT","HELP2","VICTORY2","ENDPIC","PFUB1","PFUB2"] + flats
            + (0...6).map { "END\($0)" }
            + wad.lumps.map(\.name).filter { $0.hasPrefix("WIA") || $0.hasPrefix("STCFN") }
        for name in names {
            let patch = flats.contains(name) ? nil : try art.patch(named:name)
            guard let image = flats.contains(name) ? try art.image(MaterialKey(name:name,flat:true)) : patch?.image else { continue }
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:image.width,height:image.height,mipmapped:false)
            desc.storageMode = .shared; desc.usage = .shaderRead
            guard let texture = device.makeTexture(descriptor:desc) else { throw PortError("Cannot allocate intermission art.") }
            image.rgba.withUnsafeBytes { texture.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:image.width*4) }
            patches[name] = Patch(texture:texture,width:Float(image.width),height:Float(image.height),left:Float(patch?.left ?? 0),top:Float(patch?.top ?? 0))
        }
        for name in ["WIF","WIENTER","WIOSTK","WIOSTI","WISCRT2","WITIME","WIPCNT","WICOLON"] + (0...9).map({"WINUM\($0)"}) {
            guard patches[name] != nil else { throw PortError("Missing intermission art: \(name)") }
        }
    }
    func draw(encoder: MTLRenderCommandEncoder, state: MD_Progress, sequence: IntermissionSequence, finale: FinaleSequence, width: Double, height: Double) {
        encoder.setDepthStencilState(depth)
        encoder.setViewport(MTLViewport(originX:0,originY:0,width:width,height:height,znear:0,zfar:1))
        var matrix = matrix_identity_float4x4
        encoder.setVertexBytes(&matrix,length:MemoryLayout<simd_float4x4>.stride,index:1)
        let scale = Float(min(width/320,height/240)), ox = (Float(width)-320*scale)/2, oy = (Float(height)-240*scale)/2
        func draw(_ name: String, _ x: Float, _ y: Float) {
            guard let patch = patches[name] else { return }
            let x0 = ox+x*scale, y0 = oy+y*scale*1.2, x1 = x0+patch.width*scale, y1 = y0+patch.height*scale*1.2
            func v(_ x: Float,_ y: Float,_ u: Float,_ v: Float) -> WorldVertex {
                WorldVertex(position:SIMD4(x/Float(width)*2-1,1-y/Float(height)*2,0,1),uvLight:SIMD4(u,v,1,1))
            }
            let a=v(x0,y1,0,patch.height),b=v(x1,y1,patch.width,patch.height),c=v(x1,y0,patch.width,0),d=v(x0,y0,0,0)
            encoder.setVertexBytes([a,b,c,a,c,d],length:MemoryLayout<WorldVertex>.stride*6,index:0)
            encoder.setFragmentTexture(patch.texture,index:0); encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6)
        }
        func center(_ name: String,_ y: Float) { draw(name,(320-(patches[name]?.width ?? 0))/2,y) }
        func number(_ text: String,_ right: Float,_ y: Float) {
            var x=right
            for character in text.reversed() {
                let name = character == ":" ? "WICOLON" : "WINUM\(character)"
                x -= patches[name]?.width ?? 0; draw(name,x,y)
            }
        }
        if state.phase==2 && state.commercial==0 && (1...4).contains(state.episode) {
            // Clip tiled flats and scrolling artwork to the original logical screen.
            encoder.setScissorRect(MTLScissorRect(x:Int(ox),y:Int(oy),width:max(1,Int(320*scale)),height:max(1,Int(240*scale))))
            defer { encoder.setScissorRect(MTLScissorRect(x:0,y:0,width:Int(width),height:Int(height))) }
            if !finale.art {
                let flat=["FLOOR4_8","SFLR6_1","MFLR8_4","MFLR8_3"][Int(state.episode)-1]
                for y in stride(from:0,to:200,by:64) { for x in stride(from:0,to:320,by:64) { draw(flat,Float(x),Float(y)) } }
                var x: Float=10, y: Float=10
                for character in stories[Int(state.episode)-1].prefix(finale.visibleCharacters).uppercased().unicodeScalars {
                    if character.value==10 { x=10; y += 11; continue }
                    let name=String(format:"STCFN%03d",character.value)
                    let size=patches[name]?.width ?? 4
                    if x+size>320 { break }
                    draw(name,x,y); x += size
                }
            } else if state.episode==3 {
                draw("PFUB2",-Float(finale.scroll),0); draw("PFUB1",320-Float(finale.scroll),0)
                if let frame=finale.endFrame { draw("END\(frame)",108,68) }
            } else {
                draw(state.episode==1 ? (ultimate ? "CREDIT":"HELP2") : state.episode==2 ? "VICTORY2":"ENDPIC",0,0)
            }
            return
        }
        func level(_ map: Int32) -> String { state.commercial != 0 ? String(format:"CWILV%02d",map-1) : "WILV\(state.episode-1)\(map-1)" }
        let background = state.commercial == 0 && state.episode <= 3 ? "WIMAP\(state.episode-1)" : "INTERPIC"
        draw(background,0,0)
        for animation in sequence.animations(state) {
            let patch=patches[animation.name]
            draw(animation.name,animation.x-(patch?.left ?? 0),animation.y-(patch?.top ?? 0))
        }
        if sequence.entering {
            if state.commercial == 0, (1...3).contains(state.episode) {
                let nodes = IntermissionSequence.nodes[Int(state.episode)-1]
                func marker(_ names: [String], _ index: Int) {
                    guard nodes.indices.contains(index) else { return }
                    let (x,y) = nodes[index]
                    for name in names {
                        guard let patch = patches[name] else { continue }
                        let left=x-patch.left, top=y-patch.top
                        if left >= 0 && top >= 0 && left+patch.width < 320 && top+patch.height < 200 {
                            draw(name,left,top); return
                        }
                    }
                }
                for index in IntermissionSequence.completedNodes(state) { marker(["WISPLAT"],index) }
                if sequence.pointerVisible { marker(["WIURH0","WIURH1"],Int(state.nextMap)-1) }
            }
            center("WIENTER",30); center(level(state.nextMap),50); return
        }
        center(level(state.map),2); center("WIF",22)
        for (i,row) in [("WIOSTK",55),("WIOSTI",85),("WISCRT2",115)].enumerated() {
            let (name,y) = row
            draw(name,45,Float(y))
            if sequence.values[i] >= 0 { number(String(sequence.values[i]),255,Float(y)); draw("WIPCNT",255,Float(y)) }
        }
        func time(_ seconds: Int32,_ right: Float) {
            guard seconds >= 0 else { return }
            if seconds > 3599 { draw("WISUCKS",right-(patches["WISUCKS"]?.width ?? 0),165) }
            else { number(String(format:"%d:%02d",seconds/60,seconds%60),right,165) }
        }
        draw("WITIME",25,165); time(sequence.values[3],155)
        if (state.commercial != 0 || state.episode < 4) && state.phase != 2 { draw("WIPAR",175,165); time(sequence.values[4],305) }
    }
}
