// SPDX-License-Identifier: GPL-2.0-or-later
import Metal

/// World-only LDR bloom. Quarter-resolution extraction and separable blur, no history.
final class Bloom {
    private let device: MTLDevice
    private let extract, blur: MTLComputePipelineState
    private let composite: MTLRenderPipelineState
    private let depth: MTLDepthStencilState
    private var scene, a, b: MTLTexture?
    init(device: MTLDevice, format: MTLPixelFormat) throws {
        self.device=device
        let library=try device.makeLibrary(source:Self.shader,options:nil)
        extract=try device.makeComputePipelineState(function:library.makeFunction(name:"extractBloom")!)
        blur=try device.makeComputePipelineState(function:library.makeFunction(name:"blurBloom")!)
        let d=MTLRenderPipelineDescriptor()
        d.vertexFunction=library.makeFunction(name:"bloomVertex")
        d.fragmentFunction=library.makeFunction(name:"bloomFragment")
        d.colorAttachments[0].pixelFormat=format;d.depthAttachmentPixelFormat = .depth32Float
        d.colorAttachments[0].isBlendingEnabled=true
        d.colorAttachments[0].sourceRGBBlendFactor = .one
        d.colorAttachments[0].destinationRGBBlendFactor = .one
        d.colorAttachments[0].sourceAlphaBlendFactor = .zero
        d.colorAttachments[0].destinationAlphaBlendFactor = .one
        composite=try device.makeRenderPipelineState(descriptor:d)
        let state=MTLDepthStencilDescriptor();state.depthCompareFunction = .always;state.isDepthWriteEnabled=false
        guard let depth=device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create bloom depth state.") }
        self.depth=depth
    }
    func prepare(command: MTLCommandBuffer, source: MTLTexture, worldHeight: Int) throws {
        let height=max(1,min(source.height,worldHeight)), width=source.width
        if scene?.width != width || scene?.height != height {
            func texture(_ w:Int,_ h:Int,_ format:MTLPixelFormat) throws -> MTLTexture {
                let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:w,height:h,mipmapped:false)
                d.storageMode = .private;d.usage = [.shaderRead,.shaderWrite]
                guard let t=device.makeTexture(descriptor:d) else { throw PortError("Cannot allocate bloom textures.") }
                return t
            }
            let next=try texture(width,height,source.pixelFormat)
            let nextA=try texture((width+3)/4,(height+3)/4,.rgba16Float)
            let nextB=try texture(nextA.width,nextA.height,.rgba16Float)
            scene=next;a=nextA;b=nextB
        }
        guard let scene, let a, let b, let copy=command.makeBlitCommandEncoder() else { throw PortError("Cannot copy bloom scene.") }
        copy.copy(from:source,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),
                  sourceSize:MTLSize(width:width,height:height,depth:1),to:scene,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        copy.endEncoding()
        func compute(_ pipeline:MTLComputePipelineState,_ source:MTLTexture,_ target:MTLTexture,_ direction:SIMD2<Int32>) throws {
            guard let e=command.makeComputeCommandEncoder() else { throw PortError("Cannot encode bloom pass.") }
            e.setComputePipelineState(pipeline);e.setTexture(source,index:0);e.setTexture(target,index:1)
            var direction=direction;e.setBytes(&direction,length:8,index:0)
            e.dispatchThreads(MTLSize(width:target.width,height:target.height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1))
            e.endEncoding()
        }
        try compute(extract,scene,a,.zero)
        try compute(blur,a,b,SIMD2(1,0))
        try compute(blur,b,a,SIMD2(0,1))
    }
    func draw(encoder:MTLRenderCommandEncoder,width:Double,height:Double) {
        guard let a else { return }
        encoder.setRenderPipelineState(composite);encoder.setDepthStencilState(depth)
        encoder.setFragmentTexture(a,index:0)
        var size=SIMD2(Float(width),Float(height));encoder.setFragmentBytes(&size,length:8,index:0)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
    }
    static let shader="""
    #include <metal_stdlib>
    using namespace metal;
    kernel void extractBloom(texture2d<float,access::read> source [[texture(0)]],
            texture2d<float,access::write> target [[texture(1)]], uint2 p [[thread_position_in_grid]]) {
        if (p.x>=target.get_width() || p.y>=target.get_height()) return;
        float3 sum=0;
        for (uint y=0;y<4;y++) for (uint x=0;x<4;x++) {
            uint2 q=min(p*4+uint2(x,y),uint2(source.get_width()-1,source.get_height()-1));
            float3 c=source.read(q).rgb;
            float brightness=max(c.r,max(c.g,c.b));
            sum+=c*smoothstep(0.65,1.0,brightness);
        }
        target.write(float4(sum/16,1),p);
    }
    kernel void blurBloom(texture2d<float,access::read> source [[texture(0)]],
            texture2d<float,access::write> target [[texture(1)]],
            constant int2 &direction [[buffer(0)]], uint2 p [[thread_position_in_grid]]) {
        if (p.x>=target.get_width() || p.y>=target.get_height()) return;
        const float weights[5]={0.227027,0.194595,0.121622,0.054054,0.016216};
        float3 sum=source.read(p).rgb*weights[0];
        for (int i=1;i<=4;i++) for (int sign=-1;sign<=1;sign+=2) {
            int2 q=clamp(int2(p)+direction*i*sign,int2(0),int2(source.get_width()-1,source.get_height()-1));
            sum+=source.read(uint2(q)).rgb*weights[i];
        }
        target.write(float4(sum,1),p);
    }
    vertex float4 bloomVertex(uint id [[vertex_id]]) {
        float2 p=float2((id<<1)&2,id&2);return float4(p*2-1,0,1);
    }
    fragment float4 bloomFragment(float4 position [[position]],texture2d<float> glow [[texture(0)]],constant float2 &size [[buffer(0)]]) {
        constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);
        return float4(glow.sample(s,position.xy/size).rgb*0.3,0);
    }
    """
}
