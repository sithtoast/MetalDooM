// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import MetalFX

/// A complete set prevents mixing SDR and HDR attachment formats during toggles.
struct WorldPrograms {
    let world, sky, skySurface, sprite, translucentSprite, palette, tint, fuzz, visibility: MTLRenderPipelineState
    init(device: MTLDevice, shader: String, format: MTLPixelFormat) throws {
        let library=try device.makeLibrary(source:shader,options:nil)
        let d=MTLRenderPipelineDescriptor()
        d.colorAttachments[0].pixelFormat=format;d.depthAttachmentPixelFormat = .depth32Float
        func make(_ fragment:String,_ vertex:String="worldVertex") throws -> MTLRenderPipelineState {
            d.vertexFunction=library.makeFunction(name:vertex);d.fragmentFunction=library.makeFunction(name:fragment)
            return try device.makeRenderPipelineState(descriptor:d)
        }
        d.colorAttachments[0].writeMask=[]
        visibility=try make("visibilityFragment")
        d.colorAttachments[0].writeMask = .all
        world=try make("worldFragment");skySurface=try make("skySurfaceFragment")
        sprite=try make("spriteFragment");fuzz=try make("fuzzFragment");sky=try make("skyFragment","skyVertex")
        translucentSprite=try make("translucentSpriteFragment")
        palette=try make("paletteFragment","skyVertex")
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

/// Scale only the world; weapons, intermissions and HUD are composed at display resolution.
final class WorldResolution {
    private let device: MTLDevice
    private let pipeline: MTLRenderPipelineState
    private let linearize: MTLComputePipelineState
    let color, depth: MTLTexture
    private let scaler: MTLFXSpatialScaler?
    private let linearColor: MTLTexture?
    private let scaled: MTLTexture?
    let outputWidth, outputHeight: Int
    let useMetalFX: Bool
    init(device: MTLDevice, width: Int, height: Int, outputWidth: Int, outputHeight: Int,
         format: MTLPixelFormat, metalFX: Bool) throws {
        self.device=device;self.outputWidth=outputWidth;self.outputHeight=outputHeight
        useMetalFX=metalFX && width<outputWidth && MTLFXSpatialScalerDescriptor.supportsDevice(device)
        let hdr=format == .rgba16Float
        let descriptor=MTLFXSpatialScalerDescriptor()
        descriptor.inputWidth=width;descriptor.inputHeight=height
        descriptor.outputWidth=outputWidth;descriptor.outputHeight=outputHeight
        descriptor.colorTextureFormat=format;descriptor.outputTextureFormat=format
        descriptor.colorProcessingMode=hdr ? .hdr:.perceptual
        scaler=useMetalFX ? descriptor.makeSpatialScaler(device:device):nil
        if useMetalFX && scaler == nil { throw PortError("MetalFX spatial scaling is unavailable for this resolution.") }
        func texture(_ w:Int,_ h:Int,_ f:MTLPixelFormat,_ usage:MTLTextureUsage) throws -> MTLTexture {
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:f,width:w,height:h,mipmapped:false)
            d.storageMode = .private;d.usage=usage
            guard let t=device.makeTexture(descriptor:d) else { throw PortError("Cannot allocate world resolution buffers.") };return t
        }
        color=try texture(width,height,format,MTLTextureUsage([.renderTarget,.shaderRead]).union(scaler?.colorTextureUsage ?? []))
        depth=try texture(width,height,.depth32Float,[.renderTarget,.shaderRead])
        linearColor=useMetalFX && hdr ? try texture(width,height,format,MTLTextureUsage([.shaderRead,.shaderWrite]).union(scaler!.colorTextureUsage)):nil
        scaled=useMetalFX ? try texture(outputWidth,outputHeight,format,MTLTextureUsage.shaderRead.union(scaler!.outputTextureUsage)):nil
        let lib=try device.makeLibrary(source:Self.shader,options:nil)
        linearize=try device.makeComputePipelineState(function:lib.makeFunction(name:"resolutionLinearize")!)
        let d=MTLRenderPipelineDescriptor();d.vertexFunction=lib.makeFunction(name:"resolutionVertex")
        d.fragmentFunction=lib.makeFunction(name:"resolutionFragment");d.colorAttachments[0].pixelFormat=format
        d.depthAttachmentPixelFormat = .depth32Float
        pipeline=try device.makeRenderPipelineState(descriptor:d)
    }
    func prepare(command:MTLCommandBuffer) {
        if let linearColor,let e=command.makeComputeCommandEncoder() {
            e.setComputePipelineState(linearize);e.setTexture(color,index:0);e.setTexture(linearColor,index:1)
            e.dispatchThreads(MTLSize(width:color.width,height:color.height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
        }
        if let scaler {
            scaler.colorTexture=linearColor ?? color;scaler.outputTexture=scaled
            scaler.inputContentWidth=color.width;scaler.inputContentHeight=color.height;scaler.encode(commandBuffer:command)
        }
    }
    func draw(encoder:MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(pipeline);encoder.setFragmentTexture(scaled ?? color,index:0)
        // x/y: output extent; z: decode MetalFX HDR back to the palette scene; w: supersampling.
        var settings=SIMD4(Float(outputWidth),Float(outputHeight),linearColor == nil ? 0:1,color.width>outputWidth ? 1:0)
        encoder.setFragmentBytes(&settings,length:16,index:0)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
    }
    static let shader="""
    #include <metal_stdlib>
    using namespace metal;
    float3 resolutionLinear(float3 c) { c=max(c,0.0);return select(c/12.92,pow((c+0.055)/1.055,float3(2.4)),c>0.04045); }
    kernel void resolutionLinearize(texture2d<float,access::read> src [[texture(0)]],texture2d<float,access::write> dst [[texture(1)]],uint2 p [[thread_position_in_grid]]) {
        if(p.x<src.get_width() && p.y<src.get_height()) dst.write(float4(resolutionLinear(src.read(p).rgb),1),p);
    }
    vertex float4 resolutionVertex(uint id [[vertex_id]]) { float2 p=float2((id<<1)&2,id&2);return float4(p*2-1,0,1); }
    fragment float4 resolutionFragment(float4 p [[position]],texture2d<float> src [[texture(0)]],constant float4 &s [[buffer(0)]]) {
        constexpr sampler nearest(coord::normalized,filter::nearest,address::clamp_to_edge);
        constexpr sampler smooth(coord::normalized,filter::linear,address::clamp_to_edge);
        float2 uv=p.xy/s.xy;float3 c;
        if(s.w>0) {
            float2 d=0.25/s.xy;
            c=(src.sample(smooth,uv+d).rgb+src.sample(smooth,uv-d).rgb+src.sample(smooth,uv+float2(d.x,-d.y)).rgb+src.sample(smooth,uv+float2(-d.x,d.y)).rgb)*0.25;
        } else c=src.sample(nearest,uv).rgb;
        if(s.z>0) { c=max(c,0.0);c=select(c*12.92,1.055*pow(c,float3(1.0/2.4))-0.055,c>0.0031308); }
        return float4(c,1);
    }
    """
}
