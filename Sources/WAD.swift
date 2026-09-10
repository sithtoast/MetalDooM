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
    let sourceURLs: [URL]
    let sourceData: [Data]
    let engineOrder: [Int32]
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
        sourceURLs=[self.url]; sourceData=[b.data]
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
        engineOrder=found.indices.map(Int32.init)
        maps = found.indices.compactMap { i in
            guard i + 1 < found.count, found[i+1].name == "THINGS" else { return nil }
            return found[i].name
        }
        guard signature == "PWAD" || !maps.isEmpty else { throw PortError("No classic Doom maps found in this WAD.") }
    }
    // One shared directory plan preserves native lump indices without copying
    // game data into a stitched file. Only the directory is reordered.
    init(url: URL, addOns: [URL]) throws {
        if addOns.isEmpty { self=try WAD(url:url);return }
        let base=try WAD(url:url)
        guard base.signature=="IWAD" else { throw PortError("Choose an IWAD as the base game.") }
        guard !base.maps.contains("E1M1") || base.maps.contains("E2M1") else { throw PortError("Add-ons require the registered or Ultimate Doom IWAD.") }
        let extras=try addOns.map { try WAD(url:$0) }
        guard extras.allSatisfy({$0.signature=="PWAD"}) else { throw PortError("Add-ons must be PWAD files; choose only one base IWAD.") }
        self.url=base.url; signature="IWAD"
        sourceURLs=[base.url]+extras.map(\.url);sourceData=base.sourceData+extras.flatMap(\.sourceData)
        guard sourceURLs.count<=33, Set(sourceURLs).count==sourceURLs.count,
              !sourceURLs.contains(where:{$0.path.contains("\n")}) else { throw PortError("Invalid, duplicate or excessive WAD paths.") }
        let all=([base]+extras).flatMap(\.lumps)
        guard all.count<=200_000 else { throw PortError("Too many combined WAD resources.") }
        var general=[Int](), sprite=[String:Int](), flat=[String:Int](), mode=0
        let spriteStart=base.lumps.firstIndex{$0.name=="S_START"}, spriteEnd=base.lumps.firstIndex{$0.name=="S_END"}
        let flatStart=base.lumps.firstIndex{$0.name=="F_START"}, flatEnd=base.lumps.firstIndex{$0.name=="F_END"}
        guard let spriteStart,let spriteEnd,let flatStart,let flatEnd else { throw PortError("Base IWAD is missing sprite or flat namespaces.") }
        var offset=0
        for file in [base]+extras {
            mode=0
            for (local,lump) in file.lumps.enumerated() {
                let i=offset+local, name=lump.name
                if ["S_START","SS_START"].contains(name) { mode=1;continue }
                if ["F_START","FF_START"].contains(name) { mode=2;continue }
                if ["S_END","SS_END","F_END","FF_END"].contains(name) { mode=0;continue }
                if name.range(of:"^[SF][1-9]_(START|END)$",options:.regularExpression) != nil { continue }
                if mode==1 { if lump.bytes.count>0 { sprite[name]=i } }
                else if mode==2 { if lump.bytes.count>0 { flat[name]=i } }
                else if sprite[name] != nil { sprite[name]=i }
                else if flat[name] != nil { flat[name]=i }
                else { general.append(i) }
            }
            guard mode==0 else { throw PortError("Unclosed WAD resource namespace in \(file.url.lastPathComponent).") }
            offset += file.lumps.count
        }
        let order=general+[spriteStart]+sprite.values.sorted()+[spriteEnd,flatStart]+flat.values.sorted()+[flatEnd]
        engineOrder=order.map(Int32.init);let effective=order.map{all[$0]};lumps=effective
        maps=Array(Set(effective.indices.compactMap { i -> String? in
            guard i+1<effective.count,effective[i+1].name=="THINGS" else { return nil };return effective[i].name
        })).sorted()
        if maps.contains("E5M1") {
            guard base.maps.contains("E4M1"),!base.maps.contains("MAP01"),
                  lumps.contains(where:{$0.name=="E5TEXT"}),lumps.contains(where:{$0.name=="SIGILINT"}) else {
                throw PortError("Episode 5 currently supports standard SIGIL with Ultimate Doom.")
            }
        }
        if extras.contains(where:{ ($0.lump("DEHACKED") != nil || $0.lump("UMAPINFO") != nil || $0.lump("MAPINFO") != nil) && !(isSigil && $0.lump("E5TEXT") != nil && $0.lump("SIGILINT") != nil) }) {
            throw PortError("This add-on requires unsupported map metadata or DeHackEd changes. Standard SIGIL v1.23 has a dedicated Episode 5 profile.")
        }
        guard extras.flatMap(\.maps).allSatisfy({base.maps.contains("MAP01") ? $0.hasPrefix("MAP") : $0.hasPrefix("E")}) else {
            throw PortError("The add-on's map format does not match the base game.")
        }
        guard !maps.contains(where:{$0.hasPrefix("E6")}) else { throw PortError("Episode 6 / SIGIL II is not supported yet.") }
    }
    var isSigil: Bool { sourceURLs.count>1 && maps.contains("E5M1") && lump("E5TEXT") != nil }
    var displayFiles: String { sourceURLs.map(\.lastPathComponent).joined(separator:" + ") }
    var sigilStory: String { String(data:lump("E5TEXT")?.data ?? Data(),encoding:.utf8) ?? "" }
    func lump(_ name: String) -> Bytes? { lumps.last { $0.name == name }?.bytes }
    func mapLump(_ map: String, _ name: String) throws -> Bytes {
        guard let marker = lumps.lastIndex(where: { $0.name == map }) else { throw PortError("Map \(map) not found.") }
        let fields=["THINGS","LINEDEFS","SIDEDEFS","VERTEXES","SEGS","SSECTORS","NODES","SECTORS","REJECT","BLOCKMAP"]
        guard let field=fields.firstIndex(of:name) else { throw PortError("Unsupported map lump: \(name)") }
        let index=marker+1+field
        guard index<lumps.count, lumps[index].name==name else {
            throw PortError("\(map) is missing \(name). Supply a complete classic Doom map block.")
        }
        return lumps[index].bytes
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
