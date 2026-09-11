// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit

/// A complete set prevents mixing SDR and HDR attachment formats during toggles.
struct WorldPrograms {
    let world, sky, skySurface, sprite, tint, fuzz: MTLRenderPipelineState
    init(device: MTLDevice, shader: String, format: MTLPixelFormat) throws {
        let library=try device.makeLibrary(source:shader,options:nil)
        let d=MTLRenderPipelineDescriptor()
        d.colorAttachments[0].pixelFormat=format;d.depthAttachmentPixelFormat = .depth32Float
        func make(_ fragment:String,_ vertex:String="worldVertex") throws -> MTLRenderPipelineState {
            d.vertexFunction=library.makeFunction(name:vertex);d.fragmentFunction=library.makeFunction(name:fragment)
            return try device.makeRenderPipelineState(descriptor:d)
        }
        world=try make("worldFragment");skySurface=try make("skySurfaceFragment")
        sprite=try make("spriteFragment");fuzz=try make("fuzzFragment");sky=try make("skyFragment","skyVertex")
        d.colorAttachments[0].isBlendingEnabled=true
        d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        tint=try make("tintFragment","skyVertex")
    }
}

/// Keep Doom's palette lighting, but preserve over-range radiance until display mapping.
/// The layer receives linear sRGB; 1 is standard white, not the panel's peak luminance.
final class HDROutput {
    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private var texture: MTLTexture?
    init(device: MTLDevice) throws {
        self.device=device
        let lib=try device.makeLibrary(source:Self.shader,options:nil)
        let d=MTLRenderPipelineDescriptor()
        d.vertexFunction=lib.makeFunction(name:"hdrVertex");d.fragmentFunction=lib.makeFunction(name:"hdrFragment")
        d.colorAttachments[0].pixelFormat = .rgba16Float
        pipeline=try device.makeRenderPipelineState(descriptor:d)
    }
    func scene(width:Int,height:Int) throws -> MTLTexture {
        if texture?.width != width || texture?.height != height {
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
            d.storageMode = .private;d.usage = [.renderTarget,.shaderRead]
            guard let next=device.makeTexture(descriptor:d) else { throw PortError("Cannot allocate HDR scene.") }
            next.label="Extended palette scene";texture=next
        }
        return texture!
    }
    func present(command:MTLCommandBuffer,source:MTLTexture,target:MTLTexture,headroom:Float,peak:Float) {
        let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=target
        pass.colorAttachments[0].loadAction = .dontCare;pass.colorAttachments[0].storeAction = .store
        guard let e=command.makeRenderCommandEncoder(descriptor:pass) else { return }
        e.label="Linear EDR display mapping";e.setRenderPipelineState(pipeline);e.setFragmentTexture(source,index:0)
        var settings=SIMD2(max(1,min(headroom.isFinite ? headroom:1,peak)),peak)
        e.setFragmentBytes(&settings,length:8,index:0)
        e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);e.endEncoding()
    }
    static let shader="""
    #include <metal_stdlib>
    using namespace metal;
    vertex float4 hdrVertex(uint id [[vertex_id]]) {
        float2 p=float2((id<<1)&2,id&2);return float4(p*2-1,0,1);
    }
    fragment float4 hdrFragment(float4 p [[position]],texture2d<float,access::read> scene [[texture(0)]],
                               constant float2 &settings [[buffer(0)]]) {
        float3 encoded=max(scene.read(uint2(p.xy)).rgb,0.0);
        float3 linear=select(encoded/12.92,pow((encoded+0.055)/1.055,float3(2.4)),encoded>0.04045);
        float brightness=max(linear.r,max(linear.g,linear.b));
        // Unit slope at standard white avoids amplifying fine texture contrast.
        // Peak is a ceiling, not an exposure multiplier.
        if (brightness>1.0) {
            float room=settings.x-1.0;
            float mapped=1.0+room*(1.0-exp(-(brightness-1.0)/max(room,0.001)));
            linear*=mapped/brightness;
        }
        return float4(linear,1);
    }
    """
}
