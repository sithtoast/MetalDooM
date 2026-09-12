import Foundation
import simd

// Frozen build-137 mesh algorithm: independent parity oracle for topology caching.
struct ReferenceGeometry {
    let batches: [Batch]
    let triangleCount: Int
    let skyVertices: [WorldVertex]
    init(map: DoomMap, textureHeights: [String:Float] = [:]) throws {
        var groups: [MaterialKey: [WorldVertex]] = [:]
        func vertex(_ p: SIMD2<Float>, _ height: Float, _ u: Float, _ v: Float, _ light: Float) -> WorldVertex {
            WorldVertex(position: SIMD4(p.x, height, -p.y, 1), uvLight: SIMD4(u,v,light,0))
        }
        func wall(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ bottom: Float, _ top: Float,
                  _ side: Side, _ texture: String, _ light: Float, _ anchor: Float,blend:Int=0) {
            guard top > bottom, texture != "-", !texture.isEmpty else { return }
            let length = simd_length(b-a), u = side.x
            let one = vertex(a,bottom,u,anchor-bottom+side.y,light)
            let two = vertex(b,bottom,u+length,anchor-bottom+side.y,light)
            let three = vertex(b,top,u+length,anchor-top+side.y,light)
            let four = vertex(a,top,u,anchor-top+side.y,light)
            // w marks directional walls; the fragment shader rejects the far side.
            var vertices = [one,two,three,one,three,four]
            for i in vertices.indices { vertices[i].uvLight.w = 1 }
            groups[MaterialKey(name:texture,flat:texture == "F_SKY1",blend:blend), default:[]] += vertices
        }
        for line in map.lines {
            for isBack in [false,true] {
                let sideIndex = isBack ? line.back : line.front
                guard sideIndex != -1 else { continue }
                let side = map.sides[sideIndex], sector = map.sectors[side.sector]
                let a = map.points[isBack ? line.b : line.a], b = map.points[isBack ? line.a : line.b]
                let otherIndex = isBack ? line.front : line.back
                let shade: Float = abs(a.y-b.y) < 0.01 ? 0.88 : 1
                let light = max(0.12,sector.light*shade)
                let bottomPegged = line.flags & 16 != 0, topPegged = line.flags & 8 != 0
                func height(_ name: String) -> Float { textureHeights[name] ?? 128 }
                if otherIndex == -1 {
                    wall(a,b,sector.floor,sector.ceiling,side,side.middle,light,
                         bottomPegged ? sector.floor+height(side.middle) : sector.ceiling)
                    if sector.ceilingTexture == "F_SKY1" {
                        wall(a,b,sector.ceiling,32768,side,"F_SKY1",1,0)
                    }
                } else {
                    let other = map.sectors[map.sides[otherIndex].sector]
                    if !(sector.ceilingTexture == "F_SKY1" && other.ceilingTexture == "F_SKY1") {
                        wall(a,b,max(sector.floor,other.ceiling),sector.ceiling,side,side.upper,light,
                             topPegged ? sector.ceiling : other.ceiling+height(side.upper))
                    } else {
                        wall(a,b,other.ceiling,sector.ceiling,side,"F_SKY1",1,0)
                    }
                    wall(a,b,sector.floor,min(sector.ceiling,other.floor),side,side.lower,light,
                         bottomPegged ? (sector.ceilingTexture == "F_SKY1" && other.ceilingTexture == "F_SKY1" ? other.ceiling : sector.ceiling) : other.floor)
                    // Middle patches appear once within the shared opening; transparent
                    // texels reveal the opposite sector rather than repeating vertically.
                    let openingBottom = max(sector.floor,other.floor), openingTop = min(sector.ceiling,other.ceiling)
                    let anchor = bottomPegged ? openingBottom+height(side.middle) : openingTop
                    wall(a,b,max(openingBottom,anchor+side.y-height(side.middle)),
                         min(openingTop,anchor+side.y),side,side.middle,light,anchor,blend:line.blend)
                }
            }
        }
        var minimum = map.points[0], maximum = minimum
        for p in map.points { minimum = simd_min(minimum,p); maximum = simd_max(maximum,p) }
        // Keep clipping intersections precise until the final GPU vertex upload.
        let bounds = [minimum,SIMD2(maximum.x,minimum.y),maximum,SIMD2(minimum.x,maximum.y)].map { SIMD2<Double>($0) }
        func clipped(_ polygon: [SIMD2<Double>], _ node: Node, _ right: Bool) -> [SIMD2<Double>] {
            guard !polygon.isEmpty else { return [] }
            let origin = SIMD2<Double>(node.origin), direction = SIMD2<Double>(node.direction)
            func distance(_ point: SIMD2<Double>) -> Double {
                let delta = point-origin
                return (direction.x*delta.y-direction.y*delta.x) * (right ? -1 : 1)
            }
            var result: [SIMD2<Double>] = []
            var a = polygon.last!
            var da = distance(a)
            for b in polygon {
                let db = distance(b)
                if (da >= 0) != (db >= 0) { result.append(a+(b-a)*(da/(da-db))) }
                if db >= 0 { result.append(b) }
                a = b; da = db
            }
            return result
        }
        var pending: [(Int,[SIMD2<Double>])] = [(map.nodes.isEmpty ? Node.leafBit : map.nodes.count-1,bounds)]
        var flats: [(polygon:[SIMD2<Double>],sector:Sector)] = []
        var visits = 0
        while let (index,polygon) = pending.popLast() {
            visits += 1
            guard visits < 1_000_000 else { throw PortError("Excessive BSP complexity.") }
            guard polygon.count >= 3 else { continue }
            if index & Node.leafBit == 0 {
                let node = map.nodes[index]
                pending.append((node.right,clipped(polygon,node,true)))
                pending.append((node.left,clipped(polygon,node,false)))
            } else {
                let leaf = map.leaves[index & ~Node.leafBit]
                var polygon = polygon
                // BSP partitions alone do not include every outer room edge.
                // Clip against the original directed linedef, not its seg endpoints:
                // node builders round split vertices to integer coordinates. Using
                // those shortened segs as planes cuts slivers out of adjacent flats
                // (visible as sky leaks in E1M1's zigzag room) and misaligns walls.
                for seg in map.segs[leaf.first..<leaf.first+leaf.count] {
                    let line = map.lines[seg.line]
                    let a = map.points[seg.side == 0 ? line.a : line.b]
                    let b = map.points[seg.side == 0 ? line.b : line.a]
                    if simd_length_squared(b-a) > 0 {
                        polygon = clipped(polygon,Node(origin:a,direction:b-a,right:0,left:0),true)
                    }
                }
                guard polygon.count >= 3 else { continue }
                let sector = map.sectors[map.leafSector(index & ~Node.leafBit)]
                flats.append((polygon,sector))
            }
        }
        // Adjacent leaves can have different numbers of vertices along the same
        // edge. Split both sides at every shared point so rasterization does not
        // leave single-pixel cracks at those T-junctions.
        let points = Array(Set(flats.flatMap { $0.polygon }))
        let sorted = [points.sorted { $0.x < $1.x },points.sorted { $0.y < $1.y }]
        func lowerBound(_ values:[SIMD2<Double>],_ axis:Int,_ value:Double) -> Int {
            var low=0,high=values.count
            while low<high {
                let mid=(low+high)/2
                if values[mid][axis]<value { low=mid+1 } else { high=mid }
            }
            return low
        }
        func edgePoints(_ a:SIMD2<Double>,_ b:SIMD2<Double>) -> [(Double,SIMD2<Double>)] {
            let delta=b-a,length=simd_length_squared(b-a)
            guard length>1e-14 else { return [] }
            let ranges=(0..<2).map { axis in
                lowerBound(sorted[axis],axis,min(a[axis],b[axis])-1e-7)..<lowerBound(sorted[axis],axis,max(a[axis],b[axis])+1e-7)
            }
            let axis=ranges[0].count<ranges[1].count ? 0:1
            var interior:[(Double,SIMD2<Double>)]=[]
            for point in sorted[axis][ranges[axis]] {
                let t=simd_dot(point-a,delta)/length
                if t>1e-8 && t<1-1e-8 && simd_length_squared(point-(a+delta*t))<1e-14 {
                    interior.append((t,point))
                }
            }
            var result:[(Double,SIMD2<Double>)]=[]
            var previous=SIMD2<Float>(a)
            for entry in interior.sorted(by: { $0.0<$1.0 }) {
                let point=SIMD2<Float>(entry.1)
                if point != previous && point != SIMD2<Float>(b) { result.append(entry);previous=point }
            }
            return result
        }
        // Give wall tops/bottoms the same edge vertices as the neighboring flats.
        // Interpolate attributes along each original triangle to retain pegging,
        // texture coordinates and directional-wall flags.
        for key in Array(groups.keys) {
            let original=groups[key]!
            var stitched:[WorldVertex]=[]
            for i in stride(from:0,to:original.count,by:3) {
                let triangle=Array(original[i..<i+3])
                var boundary:[WorldVertex]=[]
                for edge in 0..<3 {
                    let a=triangle[edge],b=triangle[(edge+1)%3]
                    boundary.append(a)
                    guard a.position.y==b.position.y else { continue }
                    let from=SIMD2(Double(a.position.x),Double(-a.position.z))
                    let to=SIMD2(Double(b.position.x),Double(-b.position.z))
                    for (t,point) in edgePoints(from,to) {
                        boundary.append(WorldVertex(position:SIMD4(Float(point.x),a.position.y,Float(-point.y),1),
                                                    uvLight:a.uvLight+(b.uvLight-a.uvLight)*Float(t)))
                    }
                }
                if boundary.count==3 { stitched += triangle;continue }
                let center=WorldVertex(position:triangle.reduce(SIMD4<Float>.zero) { $0+$1.position }/3,
                                       uvLight:triangle.reduce(SIMD4<Float>.zero) { $0+$1.uvLight }/3)
                for j in boundary.indices { stitched += [center,boundary[j],boundary[(j+1)%boundary.count]] }
            }
            groups[key]=stitched
        }
        for flat in flats {
            let sector=flat.sector
            var polygon:[SIMD2<Double>]=[]
            var split=false
            for i in flat.polygon.indices {
                let a=flat.polygon[i],b=flat.polygon[(i+1)%flat.polygon.count]
                guard simd_length_squared(b-a)>1e-14 else { continue }
                polygon.append(a)
                let interior=edgePoints(a,b)
                polygon += interior.map { $0.1 }
                split = split || !interior.isEmpty
            }
            guard polygon.count>=3 else { continue }
            // A center fan preserves collinear boundary vertices, unlike a fan
            // anchored at a corner on an edge that has just been subdivided.
            let center=polygon.reduce(SIMD2<Double>.zero,+)/Double(polygon.count)
            let triangles: [[SIMD2<Double>]] = split
                ? polygon.indices.map { [center,polygon[$0],polygon[($0+1)%polygon.count]] }
                : (1..<polygon.count-1).map { [polygon[0],polygon[$0],polygon[$0+1]] }
            for ceiling in [false,true] {
                let name = ceiling ? sector.ceilingTexture : sector.floorTexture
                let height = ceiling ? sector.ceiling : sector.floor
                for points in triangles {
                    let triangle = points.map { p in
                        vertex(SIMD2<Float>(p),height,Float(p.x)+(ceiling ? sector.ceilingOffset.x:sector.floorOffset.x).truncatingRemainder(dividingBy:64),Float(-p.y)+(ceiling ? sector.ceilingOffset.y:sector.floorOffset.y).truncatingRemainder(dividingBy:64),max(0.12,sector.light))
                    }
                    groups[MaterialKey(name:name,flat:true),default:[]] += triangle
                }
            }
        }
        skyVertices = groups.removeValue(forKey:MaterialKey(name:"F_SKY1",flat:true)) ?? []
        batches = groups.map { Batch(material:$0.key,vertices:$0.value) }.sorted {
            ($0.material.flat ? "F" : "W")+$0.material.name < ($1.material.flat ? "F" : "W")+$1.material.name
        }
        triangleCount = batches.reduce(0) { $0+$1.vertices.count/3 }
    }
}
