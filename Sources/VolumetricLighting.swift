// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

private struct VolumeUniforms {
    var inverse: simd_float4x4
    var eye: SIMD4<Float>
    var settings: SIMD4<Float> // density, light count, world width, world height
}

/// Thirty-two midpoint samples at quarter resolution, four lights, alpha-tested world shadows.
/// Raster depth bounds the march, so fog stops at walls and ordinary sprites.
final class VolumetricLighting {
    private let device: MTLDevice
    private let march, resolve: MTLComputePipelineState
    private let composite: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private var volume, resolved: MTLTexture?
    init(device:MTLDevice,shader:String,format:MTLPixelFormat) throws {
        self.device=device
        let library=try device.makeLibrary(source:shader+AmbientOcclusion.shader+Self.shader,options:nil)
        march=try device.makeComputePipelineState(function:library.makeFunction(name:"volumeMarch")!)
        resolve=try device.makeComputePipelineState(function:library.makeFunction(name:"volumeResolve")!)
        let d=MTLRenderPipelineDescriptor()
        d.vertexFunction=library.makeFunction(name:"skyVertex");d.fragmentFunction=library.makeFunction(name:"volumeFragment")
        d.colorAttachments[0].pixelFormat=format;d.depthAttachmentPixelFormat = .depth32Float
        d.colorAttachments[0].isBlendingEnabled=true
        d.colorAttachments[0].sourceRGBBlendFactor = .one;d.colorAttachments[0].destinationRGBBlendFactor = .one
        d.colorAttachments[0].sourceAlphaBlendFactor = .zero;d.colorAttachments[0].destinationAlphaBlendFactor = .one
        composite=try device.makeRenderPipelineState(descriptor:d)
        let ds=MTLDepthStencilDescriptor();ds.depthCompareFunction = .always;ds.isDepthWriteEnabled=false
        guard let depth=device.makeDepthStencilState(descriptor:ds) else { throw PortError("Cannot create volume depth state.") }
        depthState=depth
    }
    func prepare(command:MTLCommandBuffer,depth:MTLTexture,worldHeight:Int,inverse:simd_float4x4,
                 eye:SIMD3<Float>,lights:[DynamicLightUniforms],ao:AmbientOcclusion,alpha:MTLBuffer,density:Float) throws {
        guard let structure=ao.structure, let vertices=ao.vertices, let materials=ao.materials else {
            throw PortError("Volumetric world is not ready.")
        }
        if resolved?.width != depth.width || resolved?.height != worldHeight {
            func make(_ w:Int,_ h:Int) throws -> MTLTexture {
                let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:w,height:h,mipmapped:false)
                d.storageMode = .private;d.usage = [.shaderRead,.shaderWrite]
                guard let t=device.makeTexture(descriptor:d) else { throw PortError("Cannot allocate volumetric textures.") }
                return t
            }
            let a=try make((depth.width+3)/4,(worldHeight+3)/4), b=try make(depth.width,worldHeight)
            volume=a;resolved=b
        }
        guard let volume, let resolved else { return }
        var selected=lights.enumerated().sorted { a,b in
            func distance(_ l:DynamicLightUniforms) -> Float {
                simd_length_squared(SIMD3(l.positionRadius.x,l.positionRadius.y,l.positionRadius.z)-eye)
            }
            let da=distance(a.element),db=distance(b.element)
            return da==db ? a.offset<b.offset:da<db
        }.prefix(4).map(\.element)
        var uniforms=VolumeUniforms(inverse:inverse,eye:SIMD4(eye,1),settings:SIMD4(density,Float(selected.count),Float(depth.width),Float(worldHeight)))
        if selected.isEmpty { selected=[DynamicLightUniforms()] }
        guard let e=command.makeComputeCommandEncoder() else { throw PortError("Cannot encode volume march.") }
        e.label="Quarter-resolution volumetric light march";e.setComputePipelineState(march)
        e.setTexture(depth,index:0);e.setTexture(volume,index:1)
        e.setBytes(&uniforms,length:MemoryLayout<VolumeUniforms>.stride,index:0)
        selected.withUnsafeBytes { e.setBytes($0.baseAddress!,length:$0.count,index:1) }
        e.setAccelerationStructure(structure,bufferIndex:4)
        e.setBuffer(vertices,offset:0,index:5);e.setBuffer(materials,offset:0,index:6);e.setBuffer(alpha,offset:0,index:7)
        e.dispatchThreads(MTLSize(width:volume.width,height:volume.height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1))
        e.endEncoding()
        guard let r=command.makeComputeCommandEncoder() else { throw PortError("Cannot resolve volumetric lighting.") }
        r.label="Depth-aware volumetric upsample";r.setComputePipelineState(resolve)
        r.setTexture(depth,index:0);r.setTexture(volume,index:1);r.setTexture(resolved,index:2)
        r.setBytes(&uniforms,length:MemoryLayout<VolumeUniforms>.stride,index:0)
        r.dispatchThreads(MTLSize(width:resolved.width,height:resolved.height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1))
        r.endEncoding()
    }
    func draw(encoder:MTLRenderCommandEncoder) {
        guard let resolved else { return }
        encoder.setRenderPipelineState(composite);encoder.setDepthStencilState(depthState)
        encoder.setFragmentTexture(resolved,index:0);encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
    }
    static let shader="""
    struct VolumeUniforms { float4x4 inverse; float4 eye; float4 settings; };
    float3 volumeEndpoint(float2 pixel,float depth,constant VolumeUniforms &u) {
        float2 ndc=(pixel+0.5)/u.settings.zw*2.0-1.0;
        float4 world=u.inverse*float4(ndc.x,-ndc.y,depth,1);
        return world.xyz/world.w;
    }
    kernel void volumeMarch(depth2d<float,access::read> depth [[texture(0)]],
        texture2d<float,access::write> target [[texture(1)]], constant VolumeUniforms &u [[buffer(0)]],
        constant DynamicLight *lights [[buffer(1)]], primitive_acceleration_structure world [[buffer(4)]],
        const device AOVertex *vertices [[buffer(5)]],const device uint4 *materials [[buffer(6)]],
        const device uchar *alpha [[buffer(7)]],uint2 p [[thread_position_in_grid]]) {
        if (p.x>=target.get_width() || p.y>=target.get_height()) return;
        uint2 pixel=min(p*4+2,uint2(u.settings.zw)-1);
        float3 delta=volumeEndpoint(float2(pixel),depth.read(pixel),u)-u.eye.xyz;
        float distance=min(length(delta),768.0), step=distance/32.0;
        float3 direction=normalize(delta), sum=0;
        // Midpoints replace pixel-random offsets: no screen-space grain pattern.
        for (uint k=0;k<32;k++) {
            float t=(float(k)+0.5)*step;
            float3 point=u.eye.xyz+direction*t;
            for (uint i=0;i<uint(u.settings.y);i++) {
                DynamicLight light=lights[i];float3 offset=light.positionRadius.xyz-point;
                float d=length(offset),radius=light.positionRadius.w;
                if (d<0.1 || d>=radius) continue;
                float3 toLight=offset/d;
                float facing=dot(light.facing.xyz,light.facing.xyz)>0.5 ? max(0.0,dot(light.facing.xyz,-toLight)):1.0;
                if (facing<=0) continue;
                if (light.options.x>0) {
                    ray shadow;shadow.origin=point;shadow.direction=toLight;shadow.min_distance=0.05;shadow.max_distance=max(0.06,d-0.5);
                    if (aoHitDistance(shadow,world,vertices,materials,alpha)<shadow.max_distance) continue;
                }
                float attenuation=1.0-d/radius;
                sum+=light.colorIntensity.rgb*light.colorIntensity.w*attenuation*attenuation*facing
                     *step*u.settings.x*exp(-u.settings.x*t);
            }
        }
        target.write(float4(sum,distance),p);
    }
    kernel void volumeResolve(depth2d<float,access::read> depth [[texture(0)]],
        texture2d<float,access::read> volume [[texture(1)]],texture2d<float,access::write> target [[texture(2)]],
        constant VolumeUniforms &u [[buffer(0)]],uint2 p [[thread_position_in_grid]]) {
        if (p.x>=target.get_width() || p.y>=target.get_height()) return;
        float distance=min(length(volumeEndpoint(float2(p),depth.read(p),u)-u.eye.xyz),768.0);
        float2 q=(float2(p)+0.5)/4.0-0.5, f=fract(q);int2 base=int2(floor(q));
        float3 sum=0;float weight=0;
        for (int y=0;y<2;y++) for (int x=0;x<2;x++) {
            int2 v=clamp(base+int2(x,y),int2(0),int2(volume.get_width()-1,volume.get_height()-1));
            float4 sample=volume.read(uint2(v));
            float w=(x ? f.x:1-f.x)*(y ? f.y:1-f.y)*exp(-abs(sample.a-distance)/max(2.0,distance*0.025));
            sum+=sample.rgb*w;weight+=w;
        }
        target.write(float4(sum/max(weight,0.0001),0),p);
    }
    fragment float4 volumeFragment(SkyOut in [[stage_in]],texture2d<float,access::read> volume [[texture(0)]]) {
        return float4(volume.read(uint2(in.position.xy)).rgb,0);
    }
    """
}
