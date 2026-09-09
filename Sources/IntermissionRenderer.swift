// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

final class IntermissionRenderer {
    private struct Patch { let texture: MTLTexture; let width, height: Float }
    private var patches: [String:Patch] = [:]
    private let depth: MTLDepthStencilState
    init(device: MTLDevice, wad: WAD) throws {
        let descriptor = MTLDepthStencilDescriptor(); descriptor.depthCompareFunction = .always
        depth = device.makeDepthStencilState(descriptor:descriptor)!
        let art = try Art(wad:wad)
        let names = ["INTERPIC","WIMAP0","WIMAP1","WIMAP2","WIF","WIENTER","WIOSTK","WIOSTI","WISCRT2","WITIME","WIPAR","WIPCNT","WICOLON"]
            + (0...9).map { "WINUM\($0)" }
            + (0...3).flatMap { episode in (0...8).map { "WILV\(episode)\($0)" } }
            + (0...31).map { String(format:"CWILV%02d",$0) }
        for name in names {
            guard let patch = try art.patch(named:name) else { continue }
            let image = patch.image
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:image.width,height:image.height,mipmapped:false)
            desc.storageMode = .shared; desc.usage = .shaderRead
            guard let texture = device.makeTexture(descriptor:desc) else { throw PortError("Cannot allocate intermission art.") }
            image.rgba.withUnsafeBytes { texture.replace(region:MTLRegionMake2D(0,0,image.width,image.height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:image.width*4) }
            patches[name] = Patch(texture:texture,width:Float(image.width),height:Float(image.height))
        }
        for name in ["WIF","WIENTER","WIOSTK","WIOSTI","WISCRT2","WITIME","WIPCNT","WICOLON"] + (0...9).map({"WINUM\($0)"}) {
            guard patches[name] != nil else { throw PortError("Missing intermission art: \(name)") }
        }
    }
    func draw(encoder: MTLRenderCommandEncoder, state: MD_Progress, entering: Bool, width: Double, height: Double) {
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
        func level(_ map: Int32) -> String { state.commercial != 0 ? String(format:"CWILV%02d",map-1) : "WILV\(state.episode-1)\(map-1)" }
        let background = state.commercial == 0 && state.episode <= 3 ? "WIMAP\(state.episode-1)" : "INTERPIC"
        draw(background,0,0)
        if entering { center("WIENTER",30); center(level(state.nextMap),50); return }
        center(level(state.map),2); center("WIF",22)
        for (name,value,total,y) in [("WIOSTK",state.kills,state.maxKills,55),("WIOSTI",state.items,state.maxItems,85),("WISCRT2",state.secrets,state.maxSecrets,115)] {
            draw(name,45,Float(y)); number(String(total > 0 ? Int64(value)*100/Int64(total) : 0),255,Float(y)); draw("WIPCNT",255,Float(y))
        }
        func time(_ seconds: Int32) -> String { String(format:"%d:%02d",seconds/60,seconds%60) }
        draw("WITIME",25,165); number(time(state.seconds),155,165)
        if state.episode < 4 && state.phase != 2 { draw("WIPAR",175,165); number(time(state.parSeconds),305,165) }
    }
}
