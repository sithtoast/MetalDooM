// Appended to Renderer.swift by the native test runner for private shader access.
extension Renderer {
    func validateIndexedLighting(_ wad:WAD)throws {
        let palette=[UInt8](wad.lump("PLAYPAL")!.data.prefix(768)),maps=[UInt8](wad.lump("COLORMAP")!.data)
        guard maps.count>=33*256 else {throw PortError("Lighting oracle requires 33 colormap rows")}
        var rgba=[UInt8]();for i in 0..<256 {rgba += [palette[i*3],palette[i*3+1],palette[i*3+2],255]}
        func texture(_ format:MTLPixelFormat,_ width:Int,_ bytes:[UInt8],_ row:Int)throws->MTLTexture {
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:1,mipmapped:false)
            d.storageMode = .shared;d.usage = [.shaderRead,.renderTarget]
            let t=device.makeTexture(descriptor:d)!
            bytes.withUnsafeBytes{t.replace(region:MTLRegionMake2D(0,0,width,1),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:row)};return t
        }
        let source=try texture(.rgba8Unorm,256,rgba,1024),indices=try texture(.r8Uint,256,Array(UInt8(0)...UInt8(255)),256)
        let background=17
        let bgRGB=Array(palette[background*3..<background*3+3])
        let canonicalBG=(0..<256).first{Array(palette[$0*3..<$0*3+3])==bgRGB}!
        var blendBytes=[UInt8]()
        for bg in 0..<256 {for fg in 0..<256 {
            let entry=((bg+fg)%256)*3;blendBytes += [palette[entry],palette[entry+1],palette[entry+2],255]
        }}
        let blendDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:256,height:256,mipmapped:false)
        blendDescriptor.storageMode = .shared;blendDescriptor.usage = .shaderRead
        let blendTexture=device.makeTexture(descriptor:blendDescriptor)!
        blendBytes.withUnsafeBytes{blendTexture.replace(region:MTLRegionMake2D(0,0,256,256),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:1024)}
        let output=try texture(.bgra8Unorm,256,[UInt8](repeating:0,count:1024),1024)
        let paletteBuffer=device.makeBuffer(bytes:palette,length:palette.count,options:.storageModeShared)!
        let mapBuffer=device.makeBuffer(bytes:maps,length:maps.count,options:.storageModeShared)!
        let depthDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:256,height:1,mipmapped:false)
        depthDescriptor.storageMode = .private;depthDescriptor.usage = .renderTarget
        let depthTexture=device.makeTexture(descriptor:depthDescriptor)!
        var samples=0
        // Independent integer light-table oracle: native shaders provide output.
        for kind in 1...4 {for level in [0,1,4,8,12,15] {for distance in [16,64,128,256,512,1024,2048] {for fixed in [0,1,32] {
            for fullbright in (kind>=3 ? [false,true]:[false]) {for blended in [false,true] {
                var row:Int
                if fixed>0 {row=fixed}
                else if fullbright {row=0}
                else {
                    let scale:Int
                    if kind==1 {
                        let bucket=min(127,(distance*65536)>>20)
                        let fixedScale=(160*65536*65536)/((bucket+1)<<20)
                        scale=fixedScale>>12
                    } else {scale=kind==4 ? 47:min(47,(160*65536/distance)>>12)}
                    row=max(0,min(31,(15-level)*4-scale/2))
                }
                let d=Float(distance)
                func v(_ x:Float,_ y:Float,_ u:Float,_ z:Float)->WorldVertex {
                    WorldVertex(position:SIMD4(x*d,y*d,0,d),uvLight:SIMD4(u,z,0.5,fullbright ? 1:0),lighting:SIMD4(Float(level),Float(kind),0,0))
                }
                let vertices=[v(-1,-1,0,1),v(1,-1,256,1),v(1,1,256,0),v(-1,-1,0,1),v(1,1,256,0),v(-1,1,0,0)]
                let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=output;pass.colorAttachments[0].clearColor=MTLClearColorMake(Double(bgRGB[0])/255,Double(bgRGB[1])/255,Double(bgRGB[2])/255,1);pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
                pass.depthAttachment.texture=depthTexture;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare
                let command=queue.makeCommandBuffer()!,e=command.makeRenderCommandEncoder(descriptor:pass)!
                e.setFrontFacing(.counterClockwise)
                e.setRenderPipelineState(blended ? programs.translucentSprite:kind<=2 ? pipeline:spritePipeline)
                e.setVertexBytes(vertices,length:vertices.count*MemoryLayout<WorldVertex>.stride,index:0)
                var matrix=matrix_identity_float4x4,power=SIMD4<Float>(-Float(fixed),0,0,-1),emission=SIMD4<Float>.zero
                e.setVertexBytes(&matrix,length:64,index:1);e.setFragmentBytes(&power,length:16,index:2);e.setFragmentBytes(&emission,length:16,index:11)
                e.setFragmentBuffer(paletteBuffer,offset:0,index:3);e.setFragmentBuffer(mapBuffer,offset:0,index:4)
                e.setFragmentTexture(source,index:0);e.setFragmentTexture(indices,index:3);e.setFragmentTexture(blendTexture,index:2)
                var wall:UInt32=kind<=2 ? 1:0;e.setFragmentBytes(&wall,length:4,index:5)
                e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6);e.endEncoding();command.commit();command.waitUntilCompleted()
                guard command.status == .completed else {throw PortError("Lighting GPU command failed")}
                var result=[UInt8](repeating:0,count:1024);output.getBytes(&result,bytesPerRow:1024,from:MTLRegionMake2D(0,0,256,1),mipmapLevel:0)
                for i in 0..<256 {
                    let mapped=Int(maps[row*256+i]),entry=(blended ? (canonicalBG+mapped)%256:mapped)*3
                    for c in 0..<3 where result[i*4+c] != palette[entry+2-c] {
                        throw PortError("Indexed light mismatch kind\(kind) level\(level) depth\(distance) fixed\(fixed) full\(fullbright) index\(i) row\(row): \(result[i*4+c]) != \(palette[entry+2-c])")
                    }
                    samples+=1
                }
            }}
        }}}}
        print("PASS \(samples) native indexed plane/wall/actor/weapon samples, discrete distance tables, fullbright, fixed-map and blend-table precedence")
    }
}
