import Foundation
import simd

struct PortError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct Bytes {
    let data: Data
    var count: Int { data.count }
    func check(_ offset: Int, _ length: Int) throws {
        guard offset >= 0, length >= 0, offset <= count, length <= count - offset else {
            throw PortError("Truncated or invalid WAD data (offset \(offset), length \(length)).")
        }
    }
    func u16(_ p: Int) throws -> Int {
        try check(p, 2)
        return Int(data[p]) | Int(data[p + 1]) << 8
    }
    func i16(_ p: Int) throws -> Int { Int(Int16(bitPattern: UInt16(try u16(p)))) }
    func i32(_ p: Int) throws -> Int {
        try check(p, 4)
        let n = UInt32(data[p]) | UInt32(data[p+1]) << 8 | UInt32(data[p+2]) << 16 | UInt32(data[p+3]) << 24
        return Int(Int32(bitPattern: n))
    }
    func name(_ p: Int, _ length: Int = 8) throws -> String {
        try check(p, length)
        return String(decoding: data[p..<p+length].prefix { $0 != 0 }, as: UTF8.self).uppercased()
    }
    func records(_ stride: Int) throws -> [Int] {
        guard count % stride == 0 else { throw PortError("Invalid map record size; only classic Doom maps are supported.") }
        return Array(Swift.stride(from: 0, to: count, by: stride))
    }
}

struct Lump { let name: String; let bytes: Bytes }
struct WAD {
    let url: URL
    let signature: String
    let lumps: [Lump]
    let maps: [String]
    // Match the engine's map-based game detection; filenames may be renamed.
    var gameName: String {
        if maps.contains("MAP01") { return "Doom II" }
        if maps.contains("E4M1") { return "The Ultimate Doom" }
        if maps.contains("E2M1") { return "Doom" }
        if maps.contains("E1M1") { return "Doom (Shareware)" }
        return "Doom"
    }
    init(url: URL) throws {
        self.url = url.standardizedFileURL
        let b = Bytes(data: try Data(contentsOf: url))
        signature = try b.name(0, 4)
        guard signature == "IWAD" || signature == "PWAD" else { throw PortError("This is not an IWAD or PWAD file.") }
        let count = try b.i32(4), directory = try b.i32(8)
        guard count > 0, count <= 200_000 else { throw PortError("Invalid WAD lump count.") }
        try b.check(directory, count * 16)
        var found: [Lump] = []
        for i in 0..<count {
            let entry = directory + i * 16
            let offset = try b.i32(entry), size = try b.i32(entry + 4)
            try b.check(offset, size)
            found.append(Lump(name: try b.name(entry + 8), bytes: Bytes(data: b.data.subdata(in: offset..<offset+size))))
        }
        lumps = found
        maps = found.indices.compactMap { i in
            guard i + 1 < found.count, found[i+1].name == "THINGS" else { return nil }
            return found[i].name
        }
        guard !maps.isEmpty else { throw PortError("No classic Doom maps found in this WAD.") }
    }
    func lump(_ name: String) -> Bytes? { lumps.last { $0.name == name }?.bytes }
    func mapLump(_ map: String, _ name: String) throws -> Bytes {
        guard let marker = lumps.lastIndex(where: { $0.name == map }) else { throw PortError("Map \(map) not found.") }
        let next = min(marker + 12, lumps.count)
        guard let item = lumps[(marker+1)..<next].first(where: { $0.name == name }) else {
            throw PortError("\(map) is missing \(name). Only classic Doom map data is supported.")
        }
        return item.bytes
    }
}

struct Sector {
    let floor: Float, ceiling: Float, light: Float
    let floorTexture: String, ceilingTexture: String
}
struct Side {
    let sector: Int, x: Float, y: Float
    let upper: String, lower: String, middle: String
}
struct Line { let a: Int, b: Int, flags: Int, front: Int, back: Int }
struct Seg { let a: Int, b: Int, line: Int, side: Int }
struct Leaf { let count: Int, first: Int }
struct Node { let origin: SIMD2<Float>, direction: SIMD2<Float>; let right: Int, left: Int }

struct DoomMap {
    let name: String
    let points: [SIMD2<Float>], lines: [Line]
    var sides: [Side]
    var sectors: [Sector]
    let segs: [Seg], leaves: [Leaf], nodes: [Node]
    let start: SIMD2<Float>, angle: Float
    init(wad: WAD, name: String) throws {
        self.name = name
        let v = try wad.mapLump(name, "VERTEXES")
        points = try v.records(4).map { SIMD2(Float(try v.i16($0)), Float(try v.i16($0+2))) }
        let s = try wad.mapLump(name, "SECTORS")
        sectors = try s.records(26).map { p in
            Sector(floor: Float(try s.i16(p)), ceiling: Float(try s.i16(p+2)), light: Float(try s.i16(p+20)).clamped(0,255)/255,
                   floorTexture: try s.name(p+4), ceilingTexture: try s.name(p+12))
        }
        let d = try wad.mapLump(name, "SIDEDEFS")
        sides = try d.records(30).map { p in
            Side(sector: try d.u16(p+28), x: Float(try d.i16(p)), y: Float(try d.i16(p+2)),
                 upper: try d.name(p+4), lower: try d.name(p+12), middle: try d.name(p+20))
        }
        let l = try wad.mapLump(name, "LINEDEFS")
        lines = try l.records(14).map { p in
            Line(a: try l.u16(p), b: try l.u16(p+2), flags: try l.u16(p+4), front: try l.u16(p+10), back: try l.u16(p+12))
        }
        let g = try wad.mapLump(name, "SEGS")
        segs = try g.records(12).map { Seg(a: try g.u16($0), b: try g.u16($0+2), line: try g.u16($0+6), side: try g.u16($0+8)) }
        let f = try wad.mapLump(name, "SSECTORS")
        leaves = try f.records(4).map { Leaf(count: try f.u16($0), first: try f.u16($0+2)) }
        let n = try wad.mapLump(name, "NODES")
        nodes = try n.records(28).map { p in
            Node(origin: SIMD2(Float(try n.i16(p)),Float(try n.i16(p+2))),
                 direction: SIMD2(Float(try n.i16(p+4)),Float(try n.i16(p+6))), right: try n.u16(p+24), left: try n.u16(p+26))
        }
        let t = try wad.mapLump(name, "THINGS")
        guard let spawn = try t.records(10).first(where: { try t.u16($0+6) == 1 }) else { throw PortError("No player-one start in \(name).") }
        start = SIMD2(Float(try t.i16(spawn)), Float(try t.i16(spawn+2)))
        angle = Float(try t.i16(spawn+4)) * .pi / 180
        guard !points.isEmpty, !sectors.isEmpty, !leaves.isEmpty else { throw PortError("Empty map geometry.") }
        for side in sides { guard sectors.indices.contains(side.sector) else { throw PortError("Invalid sidedef sector.") } }
        for line in lines {
            guard points.indices.contains(line.a), points.indices.contains(line.b), sides.indices.contains(line.front),
                  line.back == 65535 || sides.indices.contains(line.back) else { throw PortError("Invalid linedef reference.") }
        }
        for seg in segs {
            guard points.indices.contains(seg.a), points.indices.contains(seg.b), lines.indices.contains(seg.line), (0...1).contains(seg.side) else {
                throw PortError("Invalid seg reference.")
            }
            let side = seg.side == 0 ? lines[seg.line].front : lines[seg.line].back
            guard sides.indices.contains(side) else { throw PortError("Seg references a missing side.") }
        }
        for leaf in leaves {
            guard leaf.count > 0, leaf.first <= segs.count, leaf.count <= segs.count - leaf.first else { throw PortError("Invalid subsector range.") }
        }
        for (index, node) in nodes.enumerated() {
            guard simd_length_squared(node.direction) > 0 else { throw PortError("Degenerate BSP partition.") }
            for child in [node.right, node.left] {
                guard child & 0x8000 != 0 ? leaves.indices.contains(child & 0x7fff) : child < index else {
                    throw PortError("Invalid or cyclic classic BSP tree.")
                }
            }
        }
    }
    func leafSector(_ index: Int) -> Int {
        let seg = segs[leaves[index].first], line = lines[seg.line]
        return sides[seg.side == 0 ? line.front : line.back].sector
    }
    func sector(at point: SIMD2<Float>) -> Int {
        guard !nodes.isEmpty else { return leafSector(0) }
        var index = nodes.count - 1
        while index & 0x8000 == 0 {
            let node = nodes[index]
            index = cross(node.direction, point - node.origin) <= 0 ? node.right : node.left
        }
        return leafSector(index & 0x7fff)
    }

}
func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { a.x*b.y-a.y*b.x }
extension Float { func clamped(_ low: Float, _ high: Float) -> Float { min(high, max(low, self)) } }
