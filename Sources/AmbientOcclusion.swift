// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

/// Optional world-only experiment. Each changed mesh gets a fresh acceleration
/// structure so queued frames never observe resources being modified underneath them.
final class AmbientOcclusion {
    let pipeline: MTLRenderPipelineState
    private(set) var structure: MTLAccelerationStructure?
    private var positions: [SIMD4<Float>] = []
    private(set) var buildCount = 0
    var triangleCount: Int { positions.count / 3 }

    init(device: MTLDevice, shader: String, format: MTLPixelFormat) throws {
        guard device.supportsRaytracing && device.supportsRaytracingFromRender else {
            throw PortError("Ray-traced ambient occlusion is unavailable on this GPU.")
        }
        let library = try device.makeLibrary(source:shader + Self.shader,options:nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name:"worldVertex")
        descriptor.fragmentFunction = library.makeFunction(name:"aoFragment")
        descriptor.colorAttachments[0].pixelFormat = format
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor:descriptor)
    }

    func prepare(positions next: [SIMD4<Float>], device: MTLDevice, command: MTLCommandBuffer) throws {
        // Sector light/UV/texture changes rebuild raster batches too, but do not
        // require rebuilding the BVH when the opaque triangles are unchanged.
        guard next != positions else { return }
        guard !next.isEmpty else { positions=[];structure=nil;return }
        guard let vertices=device.makeBuffer(bytes:next,length:next.count*MemoryLayout<SIMD4<Float>>.stride,options:.storageModeShared) else {
            throw PortError("Cannot allocate ambient occlusion vertices.")
        }
        let geometry=MTLAccelerationStructureTriangleGeometryDescriptor()
        geometry.vertexBuffer=vertices;geometry.vertexStride=MemoryLayout<SIMD4<Float>>.stride
        geometry.vertexFormat = .float3;geometry.triangleCount=next.count/3;geometry.opaque=true
        let descriptor=MTLPrimitiveAccelerationStructureDescriptor()
        descriptor.geometryDescriptors=[geometry]
        let sizes=device.accelerationStructureSizes(descriptor:descriptor)
        guard let fresh=device.makeAccelerationStructure(size:sizes.accelerationStructureSize),
              let scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate),
              let encoder=command.makeAccelerationStructureCommandEncoder() else {
            throw PortError("Cannot allocate ambient occlusion acceleration structure.")
        }
        fresh.label="AO world triangles"
        encoder.build(accelerationStructure:fresh,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0)
        encoder.endEncoding()
        structure=fresh;positions=next;buildCount += 1
    }

    static let shader = """

    #include <metal_raytracing>
    using namespace raytracing;
    fragment float4 aoFragment(Out in [[stage_in]], bool front [[front_facing]],
            texture2d<float> tex [[texture(0)]], constant float4 &power [[buffer(2)]],
            constant float4 &eye [[buffer(3)]], primitive_acceleration_structure world [[buffer(4)]]) {
        if (in.fullbright > 0.5 && !front) discard_fragment();
        constexpr sampler s(coord::normalized, address::repeat, filter::nearest);
        float4 c=tex.sample(s,in.uv/float2(tex.get_width(),tex.get_height()));
        if (c.a < 0.5) discard_fragment();
        // Derivatives recover each flat surface normal without changing the
        // classic vertex layout. Orient it toward the visible side of the plane.
        float3 n=normalize(cross(dfdx(in.world),dfdy(in.world)));
        if (dot(n,eye.xyz-in.world)<0) n=-n;
        float shade=(power.x>0 || power.y>0) ? 1.0 : in.light*clamp(1.0-in.distance/3200.0,0.3,1.0);
        if (power.x==0 && power.y==0) {
            float3 axis=abs(n.y)<0.9 ? float3(0,1,0):float3(1,0,0);
            float3 tangent=normalize(cross(axis,n)), bitangent=cross(n,tangent);
            intersector<triangle_data> trace;
            trace.assume_geometry_type(geometry_type::triangle);
            trace.force_opacity(forced_opacity::opaque);
            float occlusion=0;
            // Fixed cosine-weighted hemisphere directions: stable while paused
            // or moving, without temporal history, noise or a denoising pass.
            for (uint i=0;i<8;i++) {
                float r=sqrt((float(i)+0.5)/8.0), angle=float(i)*2.39996323;
                ray query;
                query.origin=in.world+n*0.15;
                query.direction=tangent*(r*cos(angle))+bitangent*(r*sin(angle))+n*sqrt(1-r*r);
                query.min_distance=0.05;query.max_distance=48.0;
                auto hit=trace.intersect(query,world);
                if (hit.type!=intersection_type::none) occlusion+=1.0-smoothstep(0.0,48.0,hit.distance);
            }
            shade*=1.0-0.5*(occlusion/8.0);
        }
        return float4(powerColor(c.rgb*shade,power),1);
    }
    """
}
