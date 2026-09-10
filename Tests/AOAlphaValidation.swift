// SPDX-License-Identifier: GPL-2.0-or-later
// Exercise the production ray/alpha routine with analytic geometry and masks.
func validateAlphaRays(device: MTLDevice, queue: MTLCommandQueue) throws {
    let prefix="""
    #include <metal_stdlib>
    using namespace metal;
    struct Out { float4 position [[position]]; float2 uv; float light; float distance; float fullbright; float3 world; };
    vertex Out worldVertex(uint id [[vertex_id]]) { Out o={};o.position=float4(0,0,0,1);return o; }
    float3 powerColor(float3 rgb,float4 power) { return rgb; }
    """
    let kernel="""
    kernel void probe(primitive_acceleration_structure world [[buffer(0)]],
            const device AOVertex *vertices [[buffer(1)]], const device uint4 *materials [[buffer(2)]],
            const device uchar *alpha [[buffer(3)]], device float *distances [[buffer(4)]], uint id [[thread_position_in_grid]]) {
        ray r;r.origin=float3(float(id)+0.5,1.5,2);r.direction=float3(0,0,-1);r.min_distance=0.05;r.max_distance=8;
        distances[id]=aoHitDistance(r,world,vertices,materials,alpha);
    }
    """
    let ao=try AmbientOcclusion(device:device,shader:prefix,format:.bgra8Unorm)
    let library=try device.makeLibrary(source:prefix+AmbientOcclusion.shader+kernel,options:nil)
    let pipeline=try device.makeComputePipelineState(function:library.makeFunction(name:"probe")!)
    func plane(z:Float, uvOffset:Float, opaque:Bool) -> AOGeometry {
        let points:[SIMD2<Float>]=[SIMD2(0,0),SIMD2(4,0),SIMD2(4,4),SIMD2(0,0),SIMD2(4,4),SIMD2(0,4)]
        return AOGeometry(vertices:points.map { AOVertex(position:SIMD4($0.x,$0.y,z,1),uv:SIMD4($0.x+uvOffset,$0.y,0,0)) },opaque:opaque)
    }
    let alpha:[UInt8]=Array(repeating:[UInt8](arrayLiteral:128,127,255,0),count:4).flatMap{$0}
        + Array(repeating:[UInt8](arrayLiteral:0,255,0,255),count:4).flatMap{$0}
    let mask=device.makeBuffer(bytes:alpha,length:alpha.count,options:.storageModeShared)!
    func probe(offset:UInt32=0, uv:Float = -4, wall:Bool=true) throws -> [Float] {
        let command=queue.makeCommandBuffer()!
        var geometry=[plane(z:0,uvOffset:uv,opaque:false)]
        if wall { geometry.append(plane(z:-2,uvOffset:0,opaque:true)) }
        try ao.prepare(geometry:geometry,device:device,command:command)
        var info=[SIMD4<UInt32>(offset,4,4,0)]
        if wall { info.append(SIMD4(0,4,4,6)) }
        try ao.updateMaterials(info,device:device)
        let output=device.makeBuffer(length:16,options:.storageModeShared)!
        let encoder=command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        encoder.setAccelerationStructure(ao.structure!,bufferIndex:0)
        encoder.setBuffer(ao.vertices!,offset:0,index:1);encoder.setBuffer(ao.materials!,offset:0,index:2)
        encoder.setBuffer(mask,offset:0,index:3);encoder.setBuffer(output,offset:0,index:4)
        encoder.dispatchThreads(MTLSize(width:4,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:4,height:1,depth:1))
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        validationRequire(command.status == .completed,"Alpha ray command failed: \(String(describing:command.error))")
        return Array(UnsafeBufferPointer(start:output.contents().assumingMemoryBound(to:Float.self),count:4))
    }
    func expect(_ actual:[Float],_ expected:[Float]) {
        validationRequire(zip(actual,expected).allSatisfy { abs($0-$1)<0.001 },"Alpha ray distances \(actual), expected \(expected)")
    }
    expect(try probe(),[2,4,2,4])
    let built=ao.buildCount
    expect(try probe(offset:16),[4,2,4,2])
    validationRequire(ao.buildCount==built,"Animated alpha mapping rebuilt geometry")
    expect(try probe(uv:-3),[4,2,4,2])
    validationRequire(ao.buildCount==built,"UV-only change rebuilt geometry")
    expect(try probe(wall:false),[2,8,2,8])
    print("PASS: alpha bars hit, holes reveal the wall or open sky, 127/128 cutoff and negative UV wrapping match raster rules; animation/UV updates avoid BVH rebuilds")
}
