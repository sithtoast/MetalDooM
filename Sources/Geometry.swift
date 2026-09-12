import Foundation
import simd

struct PixelImage { let width: Int, height: Int; let rgba: [UInt8] }
struct PatchImage { let image: PixelImage; let left: Int, top: Int; var paletteIndices:[UInt8]? = nil }
struct MaterialKey: Hashable { let name: String; let flat: Bool }
struct WorldVertex {
    var position: SIMD4<Float>
    var uvLight: SIMD4<Float>
}
struct Batch { let material: MaterialKey; let vertices: [WorldVertex] }

final class Art {
    let wad: WAD
    let palette: Bytes?
    let patchNames: [String]
    var definitions: [String: Bytes] = [:]
    init(wad: WAD) throws {
        self.wad = wad
        palette = wad.lump("PLAYPAL")
        if let palette { try palette.check(0, 768) }
        if let names = wad.lump("PNAMES") {
            let count = try names.i32(0)
            guard count >= 0, count <= 100_000 else { throw PortError("Invalid patch-name count.") }
            try names.check(4, count * 8)
            patchNames = try (0..<count).map { try names.name(4+$0*8) }
        } else { patchNames = [] }
        for name in ["TEXTURE1", "TEXTURE2"] {
            guard let textures = wad.lump(name) else { continue }
            let count = try textures.i32(0)
            guard count >= 0, count <= 100_000 else { throw PortError("Invalid texture count.") }
            try textures.check(4, count*4)
            for i in 0..<count {
                let offset = try textures.i32(4+i*4)
                try textures.check(offset, 22)
                let patches = try textures.u16(offset+20)
                try textures.check(offset, 22 + patches*10)
                definitions[try textures.name(offset)] = Bytes(data: textures.data.subdata(in: offset..<offset+22+patches*10))
            }
        }
    }
    func color(_ index: UInt8) -> [UInt8] {
        guard let palette else { return [index,index,index,255] }
        let p = Int(index)*3
        return [palette.data[p],palette.data[p+1],palette.data[p+2],255]
    }
    func patch(named name: String) throws -> PatchImage? {
        guard let bytes = wad.lump(name) else { return nil }
        return try decodePatch(bytes)
    }
    func patch(lump: Int) throws -> PatchImage {
        guard wad.lumps.indices.contains(lump) else { throw PortError("Invalid sprite lump index.") }
        return try decodePatch(wad.lumps[lump].bytes)
    }
    func decodePatch(_ bytes: Bytes) throws -> PatchImage {
        let width = try bytes.u16(0), height = try bytes.u16(2)
        let left = try bytes.i16(4), top = try bytes.i16(6)
        guard width > 0, height > 0, width <= 4096, height <= 4096, width*height <= 4_194_304 else {
            throw PortError("Unsupported sprite/HUD patch dimensions.")
        }
        try bytes.check(8,width*4)
        var pixels = [UInt8](repeating:0,count:width*height*4)
        var indices=[UInt8](repeating:0,count:width*height)
        for column in 0..<width {
            var cursor = try bytes.i32(8+column*4), previousTop = -1
            guard cursor >= 8+width*4 else { throw PortError("Patch column overlaps its directory.") }
            while true {
                try bytes.check(cursor,1)
                let delta = Int(bytes.data[cursor]); if delta == 255 { break }
                try bytes.check(cursor,3)
                let length = Int(bytes.data[cursor+1])
                try bytes.check(cursor,length+4)
                let row = delta <= previousTop ? previousTop+delta : delta
                previousTop = row
                for pixel in 0..<length where row+pixel < height {
                    let offset = ((row+pixel)*width+column)*4
                    indices[offset/4]=bytes.data[cursor+3+pixel]
                    pixels.replaceSubrange(offset..<offset+4,with:color(bytes.data[cursor+3+pixel]))
                }
                cursor += length+4
            }
        }
        return PatchImage(image:PixelImage(width:width,height:height,rgba:pixels),left:left,top:top,paletteIndices:indices)
    }
    func image(_ key: MaterialKey) throws -> PixelImage? {
        if key.flat {
            guard let flat = wad.flatLump(key.name), flat.count == 4096 else { return nil }
            return PixelImage(width: 64, height: 64, rgba: flat.data.flatMap { color($0) })
        }
        guard let texture = definitions[key.name] else { return nil }
        let width = try texture.u16(12), height = try texture.u16(14)
        guard width > 0, height > 0, width <= 4096, height <= 4096, width*height <= 4_194_304 else { throw PortError("Unsupported texture dimensions.") }
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        let count = try texture.u16(20)
        for i in 0..<count {
            let p = 22+i*10, xOrigin = try texture.i16(p), yOrigin = try texture.i16(p+2), patchIndex = try texture.u16(p+4)
            guard patchNames.indices.contains(patchIndex), let patch = wad.lump(patchNames[patchIndex]) else { continue }
            let columns = try patch.u16(0)
            try patch.check(8, columns*4)
            for x in 0..<columns {
                let outputX = xOrigin+x
                guard outputX >= 0, outputX < width else { continue }
                var cursor = try patch.i32(8+x*4)
                var previousTop = -1
                while true {
                    try patch.check(cursor, 1)
                    let topDelta = Int(patch.data[cursor])
                    if topDelta == 255 { break }
                    try patch.check(cursor, 3)
                    let length = Int(patch.data[cursor+1])
                    try patch.check(cursor, length+4)
                    let top = topDelta <= previousTop ? previousTop + topDelta : topDelta
                    previousTop = top
                    for y in 0..<length {
                        let outputY = yOrigin+top+y
                        guard outputY >= 0, outputY < height else { continue }
                        let c = color(patch.data[cursor+3+y]), offset = (outputY*width+outputX)*4
                        pixels.replaceSubrange(offset..<offset+4, with: c)
                    }
                    cursor += length+4
                }
            }
        }
        return PixelImage(width: width, height: height, rgba: pixels)
    }
    func textureHeights() throws -> [String:Float] {
        try definitions.mapValues { Float(try $0.u16(14)) }
    }
    static let fallback: PixelImage = {
        var pixels: [UInt8] = []
        for y in 0..<64 { for x in 0..<64 {
            let line = y % 16 == 0 || (x + ((y/16)%2)*16)%32 == 0
            let c: UInt8 = line ? 45 : 115
            pixels += [c, c, c, 255]
        } }
        return PixelImage(width:64, height:64, rgba:pixels)
    }()
}

/// Static BSP clipping, T-junctions and stitched flat triangles for one map.
/// Mutable edge memoization is confined to the owning scene-builder queue.
final class GeometryTopology {
    private var sorted:[[SIMD2<Double>]]=[]
    private var edges:[SIMD4<Double>:[(Double,SIMD2<Double>)]]=[:]
    private(set) var flatGroups:[(Int,[[SIMD2<Double>]])]=[]
    private(set) var trianglesBySector:[[[SIMD2<Double>]]]
    init(map:DoomMap) throws {
        trianglesBySector=Array(repeating:[],count:map.sectors.count)
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
        var flats: [(polygon:[SIMD2<Double>],sector:Int)] = []
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
                let sector = map.leafSector(index & ~Node.leafBit)
                flats.append((polygon,sector))
            }
        }
        // Adjacent leaves can have different numbers of vertices along the same
        // edge. Split both sides at every shared point so rasterization does not
        // leave single-pixel cracks at those T-junctions.
        let points = Array(Set(flats.flatMap { $0.polygon }))
        // Tie breaks keep nearly coincident T-junction choices stable across
        // randomized Set iteration and repeated topology builds.
        sorted = [points.sorted { $0.x == $1.x ? $0.y < $1.y:$0.x < $1.x },
                  points.sorted { $0.y == $1.y ? $0.x < $1.x:$0.y < $1.y }]
        for flat in flats {
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
            trianglesBySector[flat.sector] += triangles
            flatGroups.append((flat.sector,triangles))
        }
    }
    private func lowerBound(_ values:[SIMD2<Double>],_ axis:Int,_ value:Double) -> Int {
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
            for entry in interior.sorted(by: { $0.0 == $1.0 ? ($0.1.x == $1.1.x ? $0.1.y < $1.1.y:$0.1.x < $1.1.x):$0.0<$1.0 }) {
                let point=SIMD2<Float>(entry.1)
                if point != previous && point != SIMD2<Float>(b) { result.append(entry);previous=point }
            }
            return result
        }
    func wallEdgePoints(_ a:SIMD2<Double>,_ b:SIMD2<Double>)->[(Double,SIMD2<Double>)] {
        let key=SIMD4(a.x,a.y,b.x,b.y)
        if let result=edges[key] { return result }
        let result=edgePoints(a,b);edges[key]=result;return result
    }
}

struct Geometry {
    let batches: [Batch]
    let triangleCount: Int
    let skyVertices: [WorldVertex]
    init(batches:[Batch],skyVertices:[WorldVertex]) {
        self.batches=batches;self.skyVertices=skyVertices
        triangleCount=batches.reduce(0){$0+$1.vertices.count/3}
    }
    init(map: DoomMap, textureHeights: [String:Float] = [:], topology:GeometryTopology?=nil,
         lineIndices:[Int]?=nil,sectorIndices:[Int]?=nil) throws {
        let topology=try topology ?? GeometryTopology(map:map)
        var groups: [MaterialKey: [WorldVertex]] = [:]
        func vertex(_ p: SIMD2<Float>, _ height: Float, _ u: Float, _ v: Float, _ light: Float) -> WorldVertex {
            WorldVertex(position: SIMD4(p.x, height, -p.y, 1), uvLight: SIMD4(u,v,light,0))
        }
        func wall(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ bottom: Float, _ top: Float,
                  _ side: Side, _ texture: String, _ light: Float, _ anchor: Float) {
            guard top > bottom, texture != "-", !texture.isEmpty else { return }
            let length = simd_length(b-a), u = side.x
            let one = vertex(a,bottom,u,anchor-bottom+side.y,light)
            let two = vertex(b,bottom,u+length,anchor-bottom+side.y,light)
            let three = vertex(b,top,u+length,anchor-top+side.y,light)
            let four = vertex(a,top,u,anchor-top+side.y,light)
            // w marks directional walls; the fragment shader rejects the far side.
            var vertices = [one,two,three,one,three,four]
            for i in vertices.indices { vertices[i].uvLight.w = 1 }
            groups[MaterialKey(name:texture,flat:texture == "F_SKY1"), default:[]] += vertices
        }
        for index in lineIndices ?? Array(map.lines.indices) {
            let line=map.lines[index]
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
                         min(openingTop,anchor+side.y),side,side.middle,light,anchor)
                }
            }
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
                    for (t,point) in topology.wallEdgePoints(from,to) {
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
        let surfaces=sectorIndices.map { $0.map { ($0,topology.trianglesBySector[$0]) } } ?? topology.flatGroups
        for (index,triangles) in surfaces {
            let sector=map.sectors[index]
            for ceiling in [false,true] {
                let name = ceiling ? sector.ceilingTexture : sector.floorTexture
                let height = ceiling ? sector.ceiling : sector.floor
                // Woof plane coordinates are world X + xoffs, -world Y + yoffs.
                // Reduce the offset to one 64-texel period before adding it to
                // world coordinates, retaining precision during long sessions.
                let shift = ceiling ? sector.ceilingOffset : sector.floorOffset
                let u = shift.x.truncatingRemainder(dividingBy:64)
                let v = shift.y.truncatingRemainder(dividingBy:64)
                for points in triangles {
                    let triangle = points.map { p in
                        vertex(SIMD2<Float>(p),height,Float(p.x)+u,Float(-p.y)+v,max(0.12,sector.light))
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
