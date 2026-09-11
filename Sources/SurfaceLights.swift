// SPDX-License-Identifier: GPL-2.0-or-later
import simd

/// One-sided point approximations grouped into 128-unit surface patches.
/// Representatives remain on an actual triangle, including concave BSP sectors.
struct SurfaceLightPatch {
    var area:Float=0
    var weighted=SIMD3<Float>.zero
    var centers:[SIMD3<Float>]=[]
    var normal=SIMD3<Float>.zero
    var color=SIMD4<Float>.zero
}
struct SurfaceLightKey: Hashable {
    let material:MaterialKey
    let cell:SIMD3<Int32>
    let plane:SIMD4<Int32>
}
struct SurfaceLightCollector {
    private var patches:[SurfaceLightKey:SurfaceLightPatch]=[:]
    mutating func add(_ triangle:[WorldVertex],material:MaterialKey,color:SIMD4<Float>,normal:SIMD3<Float>) {
        let a=SIMD3(triangle[0].position.x,triangle[0].position.y,triangle[0].position.z)
        let b=SIMD3(triangle[1].position.x,triangle[1].position.y,triangle[1].position.z)
        let c=SIMD3(triangle[2].position.x,triangle[2].position.y,triangle[2].position.z)
        subdivide(a,b,c,material:material,color:color,normal:normal,depth:0)
    }
    private mutating func subdivide(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,material:MaterialKey,color:SIMD4<Float>,normal:SIMD3<Float>,depth:Int) {
        let ab=simd_length_squared(b-a),bc=simd_length_squared(c-b),ca=simd_length_squared(a-c)
        // Large triangles need multiple sources; their centroid alone can be
        // hundreds of units away from the visible edge of a liquid pool.
        if max(ab,max(bc,ca))>128*128 && depth<8 {
            if ab>=bc && ab>=ca {
                let mid=(a+b)*0.5
                subdivide(a,mid,c,material:material,color:color,normal:normal,depth:depth+1)
                subdivide(mid,b,c,material:material,color:color,normal:normal,depth:depth+1)
            } else if bc>=ca {
                let mid=(b+c)*0.5
                subdivide(a,b,mid,material:material,color:color,normal:normal,depth:depth+1)
                subdivide(a,mid,c,material:material,color:color,normal:normal,depth:depth+1)
            } else {
                let mid=(c+a)*0.5
                subdivide(a,b,mid,material:material,color:color,normal:normal,depth:depth+1)
                subdivide(mid,b,c,material:material,color:color,normal:normal,depth:depth+1)
            }
            return
        }
        let area=simd_length(simd_cross(b-a,c-a))*0.5
        guard area>0.001, color.w>0 else { return }
        let center=(a+b+c)/3
        let cell=SIMD3<Int32>(Int32(floor(center.x/128)),Int32(floor(center.y/128)),Int32(floor(center.z/128)))
        let plane=SIMD4<Int32>(Int32((normal.x*1024).rounded()),Int32((normal.y*1024).rounded()),Int32((normal.z*1024).rounded()),Int32(simd_dot(center,normal).rounded()))
        let key=SurfaceLightKey(material:material,cell:cell,plane:plane)
        var patch=patches[key] ?? SurfaceLightPatch()
        patch.area+=area;patch.weighted+=center*area;patch.centers.append(center)
        patch.normal=normal;patch.color=color;patches[key]=patch
    }
    func lights() -> [DynamicLightUniforms] {
        // Dictionary iteration never controls source-budget selection.
        let result=patches.values.map { p -> DynamicLightUniforms in
            let mean=p.weighted/p.area
            let center=p.centers.min { simd_length_squared($0-mean)<simd_length_squared($1-mean) }!
            let intensity=min(2,0.5+p.area/8192)*sqrt(p.color.w)*1.5
            return DynamicLightUniforms(positionRadius:SIMD4(center+p.normal*4,256),
                colorIntensity:SIMD4(p.color.x,p.color.y,p.color.z,intensity),options:SIMD4(1,0,0,0),facing:SIMD4(p.normal,0))
        }
        return result.sorted {
            if $0.positionRadius.x != $1.positionRadius.x { return $0.positionRadius.x<$1.positionRadius.x }
            if $0.positionRadius.y != $1.positionRadius.y { return $0.positionRadius.y<$1.positionRadius.y }
            if $0.positionRadius.z != $1.positionRadius.z { return $0.positionRadius.z<$1.positionRadius.z }
            if $0.facing.x != $1.facing.x { return $0.facing.x<$1.facing.x }
            if $0.facing.y != $1.facing.y { return $0.facing.y<$1.facing.y }
            return $0.facing.z<$1.facing.z
        }
    }
    static func color(material:MaterialKey,pixels:PixelImage) -> SIMD4<Float> {
        let settings=emissionSettings(material)
        guard settings.y>0 else { return .zero }
        func smooth(_ a:Float,_ b:Float,_ x:Float) -> Float {
            let t=min(1,max(0,(x-a)/(b-a)));return t*t*(3-2*t)
        }
        var sum=SIMD3<Float>.zero, coverage:Float=0
        for i in stride(from:0,to:pixels.rgba.count,by:4) where pixels.rgba[i+3]>=128 {
            let color=SIMD3<Float>(Float(pixels.rgba[i]),Float(pixels.rgba[i+1]),Float(pixels.rgba[i+2]))/255
            let bright=max(color.x,max(color.y,color.z)), dark=min(color.x,min(color.y,color.z))
            var mask=smooth(settings.x,min(1,settings.x+0.25),bright)
            if settings.z>0 { mask*=smooth(0.15,0.4,bright-dark) }
            sum+=color*mask;coverage+=mask
        }
        guard coverage>0 else { return .zero }
        return SIMD4(sum/coverage,coverage/Float(pixels.width*pixels.height))
    }
}
