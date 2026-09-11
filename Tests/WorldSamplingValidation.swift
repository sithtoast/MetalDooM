// SPDX-License-Identifier: GPL-2.0-or-later
func validateWorldSampling(device:MTLDevice,queue:MTLCommandQueue) throws {
    let shader="""
    #include <metal_stdlib>
    using namespace metal;
    \(WorldSampling.shader)
    vertex float4 samplingVertex(uint i [[vertex_id]]) {
        return float4(float2((i<<1)&2,i&2)*2-1,0,1);
    }
    fragment float4 samplingFragment(float4 p [[position]],texture2d<float> texture [[texture(0)]],constant float4 &power [[buffer(0)]]) {
        return sampleWorld(texture,p.xy*4.37,power);
    }
    """
    let library=try device.makeLibrary(source:shader,options:nil)
    let descriptor=MTLRenderPipelineDescriptor()
    descriptor.vertexFunction=library.makeFunction(name:"samplingVertex")
    descriptor.fragmentFunction=library.makeFunction(name:"samplingFragment")
    descriptor.colorAttachments[0].pixelFormat = .rgba16Float
    let pipeline=try device.makeRenderPipelineState(descriptor:descriptor)
    let sourceDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:64,height:64,mipmapped:true)
    sourceDescriptor.storageMode = .shared;sourceDescriptor.usage = .shaderRead
    let source=device.makeTexture(descriptor:sourceDescriptor)!
    let targetDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:16,height:16,mipmapped:false)
    targetDescriptor.storageMode = .shared;targetDescriptor.usage = .renderTarget
    let target=device.makeTexture(descriptor:targetDescriptor)!
    func render(_ filtering:Bool,_ powerup:Bool=false) -> [Float] {
        let command=queue.makeCommandBuffer()!,blit=command.makeBlitCommandEncoder()!
        blit.generateMipmaps(for:source);blit.endEncoding()
        let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=target
        pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
        let encoder=command.makeRenderCommandEncoder(descriptor:pass)!
        encoder.setRenderPipelineState(pipeline);encoder.setFragmentTexture(source,index:0)
        var power=SIMD4<Float>(powerup ? 1:0,0,0,filtering ? 1:0)
        encoder.setFragmentBytes(&power,length:16,index:0)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding()
        command.commit();command.waitUntilCompleted()
        validationRequire(command.status == .completed,"World sampling GPU probe failed")
        var result=[Float16](repeating:0,count:16*16*4)
        target.getBytes(&result,bytesPerRow:16*8,from:MTLRegionMake2D(0,0,16,16),mipmapLevel:0)
        return result.map(Float.init)
    }
    for masked in [false,true] {
        var pixels=[UInt8](repeating:0,count:64*64*4)
        for y in 0..<64 { for x in 0..<64 {
            let white=(x+y)%2==0, i=(y*64+x)*4
            for c in 0..<3 { pixels[i+c]=white ? 255:0 }
            pixels[i+3]=masked && !white ? 0:255
        } }
        pixels.withUnsafeBytes { source.replace(region:MTLRegionMake2D(0,0,64,64),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:64*4) }
        let classic=render(false),smooth=render(true)
        validationRequire(render(true,true)==classic,"Filtering altered power-up sampling")
        for i in stride(from:0,to:classic.count,by:4) {
            validationRequire(classic[i]==0 || classic[i]==1,"Classic sampling stopped being nearest")
            validationRequire(smooth[i+3]==classic[i+3],"Filtering changed binary ray/raster alpha coverage")
            validationRequire(abs(smooth[i]-(masked ? 1:0.5))<0.01,"Minification aliases or masked edges have dark fringes")
        }
    }
    print("PASS: mipmapped minification removes checker aliasing, preserves nearest Classic/power-up sampling and exact masked alpha without dark fringes")
}
