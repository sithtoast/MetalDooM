// SPDX-License-Identifier: GPL-2.0-or-later
import MetalKit
import simd

struct AOSettings: Equatable {
    let strength: Float
    let radius: Float
    init(strength: Float = 0.5, radius: Float = 48) {
        self.strength = strength.isFinite ? min(1,max(0,strength)) : 0.5
        self.radius = radius.isFinite ? min(96,max(16,radius)) : 48
    }
    var uniform: SIMD4<Float> { SIMD4(radius,strength,0,0) }
}

struct AOVertex: Equatable {
    var position: SIMD4<Float>
    var uv: SIMD4<Float>
}
struct AOGeometry {
    let vertices: [AOVertex]
    let opaque: Bool
}

/// Resources are immutable after submission, including animated alpha mappings.
final class AmbientOcclusion {
    let pipeline, spritePipeline: MTLRenderPipelineState
    private(set) var structure: MTLAccelerationStructure?
    private(set) var vertices: MTLBuffer?
    private(set) var materials: MTLBuffer?
    private var mesh: [AOVertex] = []
    private var counts: [Int] = []
    private var opacity: [Bool] = []
    private var materialInfo: [SIMD4<UInt32>] = []
    private(set) var baseVertices: [UInt32] = []
    private(set) var buildCount = 0
    var triangleCount: Int { mesh.count / 3 }

    init(device: MTLDevice, shader: String, format: MTLPixelFormat) throws {
        guard device.supportsRaytracing && device.supportsRaytracingFromRender else {
            throw PortError("Ray-traced effects are unavailable on this GPU.")
        }
        let library = try device.makeLibrary(source:shader + Self.shader,options:nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name:"worldVertex")
        descriptor.fragmentFunction = library.makeFunction(name:"aoFragment")
        descriptor.colorAttachments[0].pixelFormat = format
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try device.makeRenderPipelineState(descriptor:descriptor)
        descriptor.fragmentFunction=library.makeFunction(name:"litSpriteFragment")
        spritePipeline=try device.makeRenderPipelineState(descriptor:descriptor)
    }

    func prepare(geometry batches: [AOGeometry], device: MTLDevice, command: MTLCommandBuffer) throws {
        let next=batches.flatMap(\.vertices), nextCounts=batches.map { $0.vertices.count }, nextOpacity=batches.map(\.opaque)
        guard next != mesh || nextCounts != counts || nextOpacity != opacity else { return }
        guard !next.isEmpty else {
            mesh=[];counts=[];opacity=[];baseVertices=[];structure=nil;vertices=nil;return
        }
        guard let freshVertices=device.makeBuffer(bytes:next,length:next.count*MemoryLayout<AOVertex>.stride,options:.storageModeShared) else {
            throw PortError("Cannot allocate ray-traced world vertices.")
        }
        let rebuild=structure == nil || nextCounts != counts || nextOpacity != opacity || next.count != mesh.count || zip(next,mesh).contains { $0.position != $1.position }
        var starts:[UInt32]=[], start=0
        var descriptors:[MTLAccelerationStructureGeometryDescriptor]=[]
        for batch in batches {
            starts.append(UInt32(start))
            let geometry=MTLAccelerationStructureTriangleGeometryDescriptor()
            geometry.vertexBuffer=freshVertices;geometry.vertexBufferOffset=start*MemoryLayout<AOVertex>.stride
            geometry.vertexStride=MemoryLayout<AOVertex>.stride
            geometry.vertexFormat = .float3;geometry.triangleCount=batch.vertices.count/3;geometry.opaque=batch.opaque
            descriptors.append(geometry);start += batch.vertices.count
        }
        if rebuild {
            let descriptor=MTLPrimitiveAccelerationStructureDescriptor()
            descriptor.geometryDescriptors=descriptors
            let sizes=device.accelerationStructureSizes(descriptor:descriptor)
            guard let fresh=device.makeAccelerationStructure(size:sizes.accelerationStructureSize),
                  let scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate),
                  let encoder=command.makeAccelerationStructureCommandEncoder() else {
                throw PortError("Cannot allocate ray-traced world acceleration structure.")
            }
            fresh.label="Shared AO/light world triangles (alpha-tested)"
            encoder.build(accelerationStructure:fresh,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0)
            encoder.endEncoding();structure=fresh;buildCount += 1
        }
        // UV changes replace this buffer but do not rebuild unchanged positions.
        vertices=freshVertices;mesh=next;counts=nextCounts;opacity=nextOpacity;baseVertices=starts
    }

    func updateMaterials(_ next: [SIMD4<UInt32>], device: MTLDevice) throws {
        guard next != materialInfo else { return }
        guard !next.isEmpty else { materials=nil;materialInfo=[];return }
        guard let fresh=device.makeBuffer(bytes:next,length:next.count*MemoryLayout<SIMD4<UInt32>>.stride,options:.storageModeShared) else {
            throw PortError("Cannot allocate ray-traced world material mappings.")
        }
        materials=fresh;materialInfo=next
    }

    static let shader = """

    #include <metal_raytracing>
    using namespace raytracing;
    struct AOVertex { float4 position; float4 uv; };
    struct DynamicLight { float4 positionRadius; float4 colorIntensity; float4 options; float4 facing; };
    float aoHitDistance(ray r, primitive_acceleration_structure world,
            const device AOVertex *vertices, const device uint4 *materials, const device uchar *alpha, bool anyHit=false) {
        intersection_params params;
        params.accept_any_intersection(anyHit);
        params.assume_geometry_type(geometry_type::triangle);
        intersection_query<triangle_data> hits(r,world,params);
        while (hits.next()) {
            // Fully opaque batches commit in hardware. For masked candidates,
            // interpolate the exact raster UV, repeat in texels, then test alpha.
            uint4 material=materials[hits.get_candidate_geometry_id()];
            uint base=material.w+hits.get_candidate_primitive_id()*3;
            float2 bary=hits.get_candidate_triangle_barycentric_coord();
            float2 uv=vertices[base].uv.xy*(1-bary.x-bary.y)
                    +vertices[base+1].uv.xy*bary.x+vertices[base+2].uv.xy*bary.y;
            float2 size=float2(material.yz);
            uint2 pixel=uint2(floor(fract(uv/size)*size));
            if (alpha[material.x+pixel.y*material.y+pixel.x]>=128) hits.commit_triangle_intersection();
        }
        return hits.get_committed_intersection_type()==intersection_type::none ? r.max_distance:hits.get_committed_distance();
    }
    float3 directLight(float3 surface, float3 normal, DynamicLight light,
            primitive_acceleration_structure world, const device AOVertex *vertices,
            const device uint4 *materials, const device uchar *alpha) {
        float3 offset=light.positionRadius.xyz-surface;
        float distance=length(offset), radius=light.positionRadius.w;
        if (light.colorIntensity.w<=0 || distance>=radius || distance<=0.2) return float3(0);
        float cosine=max(0.0,dot(normal,offset/distance));
        if (cosine<=0) return float3(0);
        if (dot(light.facing.xyz,light.facing.xyz)>0.5)
            cosine*=max(0.0,dot(light.facing.xyz,-offset/distance));
        if (cosine<=0) return float3(0);
        float visibility=1;
        if (light.options.x>0) {
            float3 direction=offset/distance;
            float3 sampleNormal=dot(light.facing.xyz,light.facing.xyz)>0.5 ? light.facing.xyz:direction;
            float3 tangent=normalize(cross(sampleNormal,abs(sampleNormal.y)<0.9 ? float3(0,1,0):float3(1,0,0)));
            float3 bitangent=cross(sampleNormal,tangent);
            uint samples=light.options.y>0 ? (light.options.z>0 ? uint(clamp(light.options.z,1.0,8.0)):8u):1u;
            visibility=0;
            for (uint i=0;i<samples;i++) {
                float3 target=light.positionRadius.xyz;
                if (samples>1) {
                    float r=sqrt((float(i)+0.5)/float(samples))*light.options.y, angle=float(i)*2.39996323;
                    target+=tangent*(r*cos(angle))+bitangent*(r*sin(angle));
                }
                ray shadow;
                shadow.origin=surface+normal*0.15;
                float3 toLight=target-shadow.origin;
                shadow.max_distance=length(toLight);shadow.min_distance=0.05;
                shadow.direction=toLight/shadow.max_distance;
                visibility+=aoHitDistance(shadow,world,vertices,materials,alpha,true)>=shadow.max_distance ? 1.0:0.0;
            }
            visibility/=float(samples);
        }
        float falloff=1.0-distance/radius;
        return light.colorIntensity.rgb*(light.colorIntensity.w*cosine*falloff*falloff*visibility);
    }
    fragment float4 litSpriteFragment(Out in [[stage_in]],texture2d<float> tex [[texture(0)]],
            constant float4 &power [[buffer(2)]], primitive_acceleration_structure world [[buffer(4)]],
            const device AOVertex *vertices [[buffer(5)]], const device uint4 *materials [[buffer(6)]],
            const device uchar *alpha [[buffer(7)]], constant DynamicLight *lights [[buffer(9)]],
            constant uint &lightCount [[buffer(10)]]) {
        constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::nearest);
        float4 c=tex.sample(s,in.uv/float2(tex.get_width(),tex.get_height()));
        if (c.a<0.5) discard_fragment();
        bool fullbright=in.fullbright>0.5 || power.x>0 || power.y>0;
        float shade=fullbright ? 1.0:in.light*clamp(1.0-in.distance/3200.0,0.3,1.0);
        float3 illumination=float3(shade);
        if (!fullbright) for (uint i=0;i<min(lightCount,16u);i++) {
            float3 delta=lights[i].positionRadius.xyz-in.world;
            // Isotropic reception avoids billboard-facing brightness changes.
            if (length(delta)>0.2) illumination+=directLight(in.world,normalize(delta),lights[i],world,vertices,materials,alpha);
        }
        return float4(powerColor(litPalette(c.rgb,shade,illumination-float3(shade)),power),1);
    }
    [[early_fragment_tests]] fragment float4 aoFragment(Out in [[stage_in]], bool front [[front_facing]],
            texture2d<float> tex [[texture(0)]], constant float4 &power [[buffer(2)]],
            constant float4 &eye [[buffer(3)]], primitive_acceleration_structure world [[buffer(4)]],
            const device AOVertex *vertices [[buffer(5)]], const device uint4 *materials [[buffer(6)]],
            const device uchar *alpha [[buffer(7)]], constant float4 &settings [[buffer(8)]],
            constant DynamicLight *lights [[buffer(9)]], constant uint &lightCount [[buffer(10)]],
            constant float4 &emission [[buffer(11)]]) {
        if (in.fullbright > 0.5 && !front) discard_fragment();
        constexpr sampler s(coord::normalized, address::repeat, filter::nearest);
        float4 c=sampleWorld(tex,in.uv,power);
        if (c.a < 0.5) discard_fragment();
        // Derivatives recover each flat surface normal without changing the
        // classic vertex layout. Orient it toward the visible side of the plane.
        float3 n=normalize(cross(dfdx(in.world),dfdy(in.world)));
        if (dot(n,eye.xyz-in.world)<0) n=-n;
        float shade=(power.x>0 || power.y>0) ? 1.0 : in.light*clamp(1.0-in.distance/3200.0,0.3,1.0);
        if (power.x==0 && power.y==0 && settings.y>0) {
            float3 axis=abs(n.y)<0.9 ? float3(0,1,0):float3(1,0,0);
            float3 tangent=normalize(cross(axis,n)), bitangent=cross(n,tangent);
            float occlusion=0;
            // Fixed cosine-weighted hemisphere directions: stable while paused
            // or moving, without temporal history, noise or a denoising pass.
            uint samples=settings.z>0 ? uint(clamp(settings.z,1.0,16.0)):16u;
            for (uint i=0;i<samples;i++) {
                float r=sqrt((float(i)+0.5)/float(samples)), angle=float(i)*2.39996323;
                ray query;
                query.origin=in.world+n*0.15;
                query.direction=tangent*(r*cos(angle))+bitangent*(r*sin(angle))+n*sqrt(1-r*r);
                query.min_distance=0.05;query.max_distance=settings.x;
                float distance=aoHitDistance(query,world,vertices,materials,alpha);
                occlusion+=1.0-smoothstep(0.0,settings.x,distance);
            }
            shade*=1.0-settings.y*(occlusion/float(samples));
        }
        float3 illumination=float3(shade);
        if (power.x==0 && power.y==0)
            for (uint i=0;i<min(lightCount,16u);i++)
                illumination+=directLight(in.world,n,lights[i],world,vertices,materials,alpha);
        return float4(powerColor(emissiveColor(c.rgb,litPalette(c.rgb,shade,illumination-float3(shade)),emission,power),power),1);
    }
    """
}
