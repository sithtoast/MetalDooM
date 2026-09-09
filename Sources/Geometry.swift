import Foundation
import simd

struct PixelImage { let width: Int, height: Int; let rgba: [UInt8] }
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
    func image(_ key: MaterialKey) throws -> PixelImage? {
        if key.flat {
            guard let flat = wad.lump(key.name), flat.count == 4096 else { return nil }
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

struct Geometry {
    let batches: [Batch]
    let triangleCount: Int
    init(map: DoomMap) throws {
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
            groups[MaterialKey(name:texture,flat:false), default:[]] += [one,two,three,one,three,four]
        }
        for line in map.lines {
            for isBack in [false,true] {
                let sideIndex = isBack ? line.back : line.front
                guard sideIndex != 65535 else { continue }
                let side = map.sides[sideIndex], sector = map.sectors[side.sector]
                let a = map.points[isBack ? line.b : line.a], b = map.points[isBack ? line.a : line.b]
                let otherIndex = isBack ? line.front : line.back
                let shade: Float = abs(a.y-b.y) < 0.01 ? 0.88 : 1
                let light = max(0.12,sector.light*shade)
                if otherIndex == 65535 {
                    wall(a,b,sector.floor,sector.ceiling,side,side.middle,light,sector.ceiling)
                } else {
                    let other = map.sectors[map.sides[otherIndex].sector]
                    if !(sector.ceilingTexture == "F_SKY1" && other.ceilingTexture == "F_SKY1") {
                        wall(a,b,max(sector.floor,other.ceiling),sector.ceiling,side,side.upper,light,sector.ceiling)
                    }
                    wall(a,b,sector.floor,min(sector.ceiling,other.floor),side,side.lower,light,other.floor)
                    // Masked middle textures require sided draw ranges and pegging; deferred.
                }
            }
        }
        var minimum = map.points[0], maximum = minimum
        for p in map.points { minimum = simd_min(minimum,p); maximum = simd_max(maximum,p) }
        let bounds = [minimum,SIMD2(maximum.x,minimum.y),maximum,SIMD2(minimum.x,maximum.y)]
        func clipped(_ polygon: [SIMD2<Float>], _ node: Node, _ right: Bool) -> [SIMD2<Float>] {
            guard !polygon.isEmpty else { return [] }
            var result: [SIMD2<Float>] = []
            var a = polygon.last!
            var da = cross(node.direction,a-node.origin) * (right ? -1 : 1)
            for b in polygon {
                let db = cross(node.direction,b-node.origin) * (right ? -1 : 1)
                if (da >= 0) != (db >= 0) { result.append(a+(b-a)*(da/(da-db))) }
                if db >= 0 { result.append(b) }
                a = b; da = db
            }
            return result
        }
        var pending: [(Int,[SIMD2<Float>])] = [(map.nodes.isEmpty ? 0x8000 : map.nodes.count-1,bounds)]
        var visits = 0
        while let (index,polygon) = pending.popLast() {
            visits += 1
            guard visits < 1_000_000 else { throw PortError("Excessive BSP complexity.") }
            guard polygon.count >= 3 else { continue }
            if index & 0x8000 == 0 {
                let node = map.nodes[index]
                pending.append((node.right,clipped(polygon,node,true)))
                pending.append((node.left,clipped(polygon,node,false)))
            } else {
                let sector = map.sectors[map.leafSector(index & 0x7fff)]
                for ceiling in [false,true] {
                    let name = ceiling ? sector.ceilingTexture : sector.floorTexture
                    if name == "F_SKY1" { continue }
                    let height = ceiling ? sector.ceiling : sector.floor
                    for i in 1..<polygon.count-1 {
                        let triangle = [polygon[0],polygon[i],polygon[i+1]].map { p in
                            vertex(p,height,p.x,-p.y,max(0.12,sector.light))
                        }
                        groups[MaterialKey(name:name,flat:true),default:[]] += triangle
                    }
                }
            }
        }
        batches = groups.map { Batch(material:$0.key,vertices:$0.value) }.sorted {
            ($0.material.flat ? "F" : "W")+$0.material.name < ($1.material.flat ? "F" : "W")+$1.material.name
        }
        triangleCount = batches.reduce(0) { $0+$1.vertices.count/3 }
    }
}
