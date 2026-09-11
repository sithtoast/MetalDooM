// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

struct SceneParticle {
    var positionSize:SIMD4<Float>
    var color:SIMD4<Float>
}
final class ParticleRenderer {
    private let device:MTLDevice
    private let pipeline:MTLRenderPipelineState
    private let depth:MTLDepthStencilState
    static let limit=128
    init(device:MTLDevice,format:MTLPixelFormat) throws {
        self.device=device
        let library=try device.makeLibrary(source:Self.shader,options:nil)
        let d=MTLRenderPipelineDescriptor()
        d.vertexFunction=library.makeFunction(name:"particleVertex");d.fragmentFunction=library.makeFunction(name:"particleFragment")
        d.colorAttachments[0].pixelFormat=format;d.depthAttachmentPixelFormat = .depth32Float
        d.colorAttachments[0].isBlendingEnabled=true
        d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;d.colorAttachments[0].destinationRGBBlendFactor = .one
        d.colorAttachments[0].sourceAlphaBlendFactor = .zero;d.colorAttachments[0].destinationAlphaBlendFactor = .one
        pipeline=try device.makeRenderPipelineState(descriptor:d)
        let state=MTLDepthStencilDescriptor();state.depthCompareFunction = .lessEqual;state.isDepthWriteEnabled=false
        guard let depth=device.makeDepthStencilState(descriptor:state) else { throw PortError("Cannot create particle depth state.") }
        self.depth=depth
    }
    static func generate(things:[MD_Thing],eye:SIMD3<Float>,tics:Int32) -> [SceneParticle] {
        var eligible:[(Int,MD_Thing,Float)]=[]
        for (index,t) in things.enumerated() where t.lightKind>0 && t.lightKind<=6 {
            let point=SIMD3<Float>(t.x,t.lightZ,-t.y)
            let distance=simd_length_squared(point-eye)
            if distance<768*768 { eligible.append((index,t,distance)) }
        }
        eligible.sort { $0.2==$1.2 ? $0.0<$1.0:$0.2<$1.2 }
        var particles:[SceneParticle]=[]
        for (_,thing,_) in eligible.prefix(22) {
            let torch=thing.lightKind<=3
            let color:SIMD3<Float> = thing.lightKind==1 || thing.lightKind==4 ? SIMD3(0.2,0.5,1)
                : thing.lightKind==2 || thing.lightKind==5 ? SIMD3(0.25,1,0.2):SIMD3(1,0.45,0.1)
            for i in 0..<6 {
                guard particles.count<Self.limit else { return particles }
                let age=Float((tics+Int32(i*6))%35)/35
                let angle=Float(i)*2.39996323
                let origin=SIMD3<Float>(thing.x,thing.lightZ,-thing.y)
                var point:SIMD3<Float>
                if torch {
                    // Light centers sit below flame tips. Start embers at the
                    // visible flame instead of halfway down tall torch poles.
                    let lift:Float = [44,45,46].contains(thing.doomedType) ? 24
                        : [55,56,57].contains(thing.doomedType) ? 12:0
                    point=origin+SIMD3(cos(angle)*(2+age*4),lift+age*28,sin(angle)*(2+age*4))
                } else {
                    let velocity=SIMD3<Float>(thing.velocityX,thing.velocityZ,-thing.velocityY)
                    point=origin-velocity*(age*4)+SIMD3(cos(angle)*3,sin(angle)*3,cos(angle*2)*3)
                }
                particles.append(SceneParticle(positionSize:SIMD4(point,torch ? 1.5:2.5),color:SIMD4(color,(1-age)*0.7)))
            }
        }
        return particles
    }
    func draw(encoder:MTLRenderCommandEncoder,camera:SIMD2<Float>,eye:SIMD3<Float>,yaw:Float,pitch:Float,tics:Int32,matrix:simd_float4x4) throws {
        var things=Array(repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,camera.x,camera.y)))
        _=MD_CopyThings(&things,Int32(things.count),camera.x,camera.y)
        let particles=Self.generate(things:things,eye:eye,tics:tics)
        guard !particles.isEmpty else { return }
        guard let buffer=device.makeBuffer(bytes:particles,length:particles.count*MemoryLayout<SceneParticle>.stride,options:.storageModeShared) else { throw PortError("Cannot allocate particle vertices.") }
        var matrix=matrix
        let right=SIMD3(sin(yaw),Float(0),cos(yaw))
        let forward=SIMD3(cos(yaw)*cos(pitch),sin(pitch),-sin(yaw)*cos(pitch))
        let up=simd_normalize(simd_cross(right,forward))
        let basis=[SIMD4(right,0),SIMD4(up,0)]
        encoder.setRenderPipelineState(pipeline);encoder.setDepthStencilState(depth)
        encoder.setVertexBuffer(buffer,offset:0,index:0)
        encoder.setVertexBytes(&matrix,length:MemoryLayout<simd_float4x4>.stride,index:1)
        encoder.setVertexBytes(basis,length:32,index:2)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6,instanceCount:particles.count)
    }
    static let shader="""
    #include <metal_stdlib>
    using namespace metal;
    struct Particle { float4 positionSize; float4 color; };
    struct ParticleOut { float4 position [[position]]; float2 uv; float4 color; };
    vertex ParticleOut particleVertex(uint id [[vertex_id]],uint instance [[instance_id]],
            const device Particle *particles [[buffer(0)]],constant float4x4 &matrix [[buffer(1)]],constant float4 *basis [[buffer(2)]]) {
        const float2 corners[6]={float2(-1,-1),float2(1,-1),float2(1,1),float2(-1,-1),float2(1,1),float2(-1,1)};
        Particle p=particles[instance];float2 uv=corners[id];
        ParticleOut o;o.position=matrix*float4(p.positionSize.xyz+(basis[0].xyz*uv.x+basis[1].xyz*uv.y)*p.positionSize.w,1);
        o.uv=uv;o.color=p.color;return o;
    }
    fragment float4 particleFragment(ParticleOut in [[stage_in]]) {
        float alpha=max(0.0,1-dot(in.uv,in.uv))*in.color.a;
        if (alpha<0.01) discard_fragment();
        return float4(in.color.rgb,alpha);
    }
    """
}
