import Foundation
import CryptoKit
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
    private var previewSpriteLumps: [String:Int]? = nil
    private var previewFlatLumps: [String:Bytes]? = nil
    // Detect from the base IWAD resources, before any add-on can override them.
    // These campaign-specific patch sets also identify renamed original IWADs.
    let isKEXEdition: Bool
    var displayName: String { gameName + (isKEXEdition ? " (KEX Edition)" : "") }
    // Identify the supported official rerelease profiles from the base file.
    // GAMECONF is inspected for identity only; its load/options directives are
    // never executed. PWAD metadata cannot relabel the base IWAD.
    private static func kexProfile(_ lumps: [Lump], signature: String, finalDoom: Int) -> Bool {
        guard signature == "IWAD",
              let metadata=lumps.last(where:{$0.name == "GAMECONF"})?.bytes.data,
              metadata.count <= 65536,
              let json=(try? JSONSerialization.jsonObject(with:metadata)) as? [String:Any],
              json["type"] as? String == "gameconf",
              let data=json["data"] as? [String:Any] else { return false }
        let names=Set(lumps.map(\.name))
        let title: String, mode: String
        if finalDoom == 1 { title="TNT: Evilution";mode="commercial" }
        else if finalDoom == 2 { title="The Plutonia Experiment";mode="commercial" }
        else if names.contains("MAP01") && names.contains("DMENUPIC") { title="Doom II";mode="commercial" }
        else if names.contains("E1M1") && names.contains("E4M1") { title="Doom";mode="retail" }
        else { return false }
        return data["title"] as? String == title && data["mode"] as? String == mode
    }
    let campaign: KEXCampaign?
    let finalDoom: Int // 0: other, 1: TNT, 2: Plutonia
    private static func finalDoomProfile(_ names: Set<String>) -> Int {
        guard names.contains("MAP01") else { return 0 }
        if Set(["REDTNT2", "BLUTNT", "BTNTCRAT"]).isSubset(of:names) { return 1 }
        if Set(["CAMO1", "CAMO4", "MC5"]).isSubset(of:names) { return 2 }
        return 0
    }
    var gameName: String {
        if let campaign { return campaign.title }
        if finalDoom == 1 { return "Final Doom: TNT: Evilution" }
        if finalDoom == 2 { return "Final Doom: The Plutonia Experiment" }
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
        campaign=nil
        finalDoom=Self.finalDoomProfile(Set(found.map(\.name)))
        isKEXEdition=Self.kexProfile(found,signature:signature,finalDoom:finalDoom)
        lumps = found
        engineOrder=found.indices.map(Int32.init)
        maps = found.indices.compactMap { i in
            guard i + 1 < found.count, found[i+1].name == "THINGS" else { return nil }
            return found[i].name
        }
        guard signature == "PWAD" || !maps.isEmpty else { throw PortError("No classic Doom maps found in this WAD.") }
    }
    // Diagnostic resources only. The worker owns map decoding and simulation;
    // normal gameplay refuses this PWAD-labelled resource view.
    init(previewResources paths: [URL], baseIndex: Int, profile: Int, identity: String) throws {
        guard (1...32).contains(paths.count), paths.indices.contains(baseIndex), (0...2).contains(profile) else { throw PortError("Invalid preview resource plan.") }
        let files=try paths.map { try WAD(url:$0) }
        var material=Data([77,69,83,69,83,83,50,0,UInt8(baseIndex),UInt8(profile),UInt8(paths.count),0,0,0,0,0])
        for file in files { material.append(contentsOf:SHA256.hash(data:file.sourceData[0])) }
        guard SHA256.hash(data:material).map({String(format:"%02x",$0)}).joined() == identity else { throw PortError("Preview resources differ from the worker session.") }
        url=files[baseIndex].url;signature="PWAD";sourceURLs=files.map(\.url);sourceData=files.flatMap(\.sourceData)
        lumps=files.flatMap(\.lumps);engineOrder=[];maps=[];campaign=nil;finalDoom=0;isKEXEdition=false
        var flats:[String:Bytes]=[:], spriteNames:[String:Int]=[:], offset=0
        for file in files {
            var inFlats=false, inSprites=false
            for (index,lump) in file.lumps.enumerated() {
                if ["S_START","SS_START"].contains(lump.name) { inSprites=true;continue }
                if ["S_END","SS_END"].contains(lump.name) { inSprites=false;continue }
                if inSprites && lump.bytes.count>0 { spriteNames[lump.name]=offset+index }
                if ["F_START","FF_START"].contains(lump.name) { inFlats=true;continue }
                if ["F_END","FF_END"].contains(lump.name) { inFlats=false;continue }
                if inFlats && lump.bytes.count>0 { flats[lump.name]=lump.bytes }
            }
            guard !inFlats, !inSprites else { throw PortError("Unclosed preview resource namespace.") }
            offset += file.lumps.count
        }
        previewFlatLumps=flats;previewSpriteLumps=spriteNames

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
        let profiles=extras.compactMap(KEXCampaign.identify)
        campaign=profiles.first
        if let campaign {
            guard extras.count==1 else { throw PortError("Load this dedicated KEX campaign by itself with its base IWAD.") }
            guard campaign.id==3 ? base.maps.contains("E4M1") && !base.maps.contains("MAP01") : base.maps.contains("MAP01") && base.finalDoom==0 else {
                throw PortError(campaign.id==3 ? "SIGIL II requires Ultimate Doom.":"This campaign requires Doom II.")
            }
        }
        finalDoom=base.finalDoom
        isKEXEdition=base.isKEXEdition
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
        maps=campaign?.maps ?? Array(Set(effective.indices.compactMap { i -> String? in
            guard i+1<effective.count,effective[i+1].name=="THINGS" else { return nil };return effective[i].name
        })).sorted()
        if maps.contains("E5M1") {
            guard base.maps.contains("E4M1"),!base.maps.contains("MAP01"),
                  lumps.contains(where:{$0.name=="E5TEXT"}),lumps.contains(where:{$0.name=="SIGILINT"}) else {
                throw PortError("Episode 5 currently supports standard SIGIL with Ultimate Doom.")
            }
        }
        if campaign == nil && extras.contains(where:{ ($0.lump("DEHACKED") != nil || $0.lump("UMAPINFO") != nil || $0.lump("MAPINFO") != nil || $0.lump("ANIMATED") != nil || $0.lump("SWITCHES") != nil) && !(isSigil && $0.lump("E5TEXT") != nil && $0.lump("SIGILINT") != nil) }) {
            throw PortError("This add-on requires unsupported map metadata or DeHackEd changes. Legacy of Rust needs ID24 engine support. Only validated editions of SIGIL, SIGIL II, No Rest for the Living and Master Levels have dedicated profiles.")
        }
        guard extras.flatMap(\.maps).allSatisfy({base.maps.contains("MAP01") ? $0.hasPrefix("MAP") : $0.hasPrefix("E")}) else {
            throw PortError("The add-on's map format does not match the base game.")
        }
        guard campaign?.id==3 || !maps.contains(where:{$0.hasPrefix("E6")}) else { throw PortError("This SIGIL II edition has not been validated. Use the supported bundled rerelease file.") }
    }
    func skyName(for map: String) -> String {
        if let sky=campaign?.value("skytexture",map:map) { return sky }
        if isSigil && map.hasPrefix("E5") { return "SKY5" }
        if map.hasPrefix("E2") { return "SKY2" }
        if map.hasPrefix("E3") { return "SKY3" }
        if map.hasPrefix("E4") { return "SKY4" }
        if map.hasPrefix("MAP"), let number=Int(map.dropFirst(3)) {
            return number > 20 ? "SKY3" : number > 11 ? "SKY2" : "SKY1"
        }
        return "SKY1"
    }
    var isSigil: Bool { sourceURLs.count>1 && maps.contains("E5M1") && lump("E5TEXT") != nil }
    var displayFiles: String { sourceURLs.map(\.lastPathComponent).joined(separator:" + ") }
    var sigilStory: String { String(data:lump("E5TEXT")?.data ?? Data(),encoding:.utf8) ?? "" }
    func spriteLumpIndex(_ name:String) -> Int? { previewSpriteLumps?[name] }
    func flatLump(_ name: String) -> Bytes? { previewFlatLumps.map { $0[name] } ?? lump(name) }
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

struct SkyTransfer:Hashable {
    let id:Int,name:String,angle:UInt32,mid:Float,scale:SIMD2<Float>
}
struct Sector: Equatable {
    var floor: Float, ceiling: Float
    let light: Float
    let floorTexture: String, ceilingTexture: String
    var floorOffset: SIMD2<Float> = .zero, ceilingOffset: SIMD2<Float> = .zero
    var floorRotation:UInt32=0,ceilingRotation:UInt32=0
    var floorSky:SkyTransfer?=nil,ceilingSky:SkyTransfer?=nil
    var floorLight:Float?=nil,ceilingLight:Float?=nil
    var backFloor:Float?=nil,backCeiling:Float?=nil,backCeilingTexture:String?=nil
    var spriteClip:SIMD2<Float> = SIMD2(-Float.infinity,Float.infinity)
    var tint:Int=0,floorTint:Int=0,ceilingTint:Int=0
    var backView:Sector {Sector(floor:backFloor ?? floor,ceiling:backCeiling ?? ceiling,light:light,floorTexture:floorTexture,ceilingTexture:backCeilingTexture ?? ceilingTexture)}
}
struct Side: Equatable {
    let sector: Int, x: Float, y: Float
    let upper: String, lower: String, middle: String
    var tint:Int=0
}
struct Line: Equatable { let a: Int, b: Int, flags: Int, front: Int, back: Int; var blend:Int=0 }
struct Seg: Equatable { let a: Int, b: Int, line: Int, side: Int }
struct Leaf: Equatable { let count: Int, first: Int; var sector: Int? = nil }
struct Node: Equatable {
    static let leafBit = 0x80000000
    static func classicChild(_ child: Int) -> Int { child & 0x8000 != 0 ? leafBit | (child & 0x7fff) : child }
    let origin: SIMD2<Float>, direction: SIMD2<Float>; let right: Int, left: Int }

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
            Line(a: try l.u16(p), b: try l.u16(p+2), flags: try l.u16(p+4), front: try l.u16(p+10), back: try l.u16(p+12) == 65535 ? -1 : l.u16(p+12))
        }
        let g = try wad.mapLump(name, "SEGS")
        segs = try g.records(12).map { Seg(a: try g.u16($0), b: try g.u16($0+2), line: try g.u16($0+6), side: try g.u16($0+8)) }
        let f = try wad.mapLump(name, "SSECTORS")
        leaves = try f.records(4).map { Leaf(count: try f.u16($0), first: try f.u16($0+2)) }
        let n = try wad.mapLump(name, "NODES")
        nodes = try n.records(28).map { p in
            Node(origin: SIMD2(Float(try n.i16(p)),Float(try n.i16(p+2))),
                 direction: SIMD2(Float(try n.i16(p+4)),Float(try n.i16(p+6))), right: try Node.classicChild(n.u16(p+24)), left: try Node.classicChild(n.u16(p+26)))
        }
        let t = try wad.mapLump(name, "THINGS")
        guard let spawn = try t.records(10).first(where: { try t.u16($0+6) == 1 }) else { throw PortError("No player-one start in \(name).") }
        start = SIMD2(Float(try t.i16(spawn)), Float(try t.i16(spawn+2)))
        angle = Float(try t.i16(spawn+4)) * .pi / 180
        try validate()
    }
    init(name: String, points: [SIMD2<Float>], lines: [Line], sides: [Side], sectors: [Sector],
         segs: [Seg], leaves: [Leaf], nodes: [Node], start: SIMD2<Float>, angle: Float) throws {
        self.name=name; self.points=points; self.lines=lines; self.sides=sides; self.sectors=sectors
        self.segs=segs; self.leaves=leaves; self.nodes=nodes; self.start=start; self.angle=angle
        try validate()
    }
    /// Reuse already validated static geometry after an exact wire-byte match.
    init(copying map:DoomMap,sides:[Side],sectors:[Sector],start:SIMD2<Float>,angle:Float) throws {
        guard sides.count==map.sides.count,sectors.count==map.sectors.count,
              sides.allSatisfy({sectors.indices.contains($0.sector)}) else { throw PortError("Invalid dynamic map references.") }
        name=map.name;points=map.points;lines=map.lines;segs=map.segs;leaves=map.leaves;nodes=map.nodes
        self.sides=sides;self.sectors=sectors;self.start=start;self.angle=angle
    }
    func validate() throws {
        guard !points.isEmpty, !sectors.isEmpty, !leaves.isEmpty else { throw PortError("Empty map geometry.") }
        for side in sides { guard sectors.indices.contains(side.sector) else { throw PortError("Invalid sidedef sector.") } }
        for line in lines {
            guard points.indices.contains(line.a), points.indices.contains(line.b), sides.indices.contains(line.front),
                  line.back == -1 || sides.indices.contains(line.back) else { throw PortError("Invalid linedef reference.") }
        }
        for seg in segs {
            guard points.indices.contains(seg.a), points.indices.contains(seg.b), lines.indices.contains(seg.line), (0...1).contains(seg.side) else {
                throw PortError("Invalid seg reference.")
            }
            let side = seg.side == 0 ? lines[seg.line].front : lines[seg.line].back
            guard sides.indices.contains(side) else { throw PortError("Seg references a missing side.") }
        }
        for leaf in leaves {
            if let sector = leaf.sector, !sectors.indices.contains(sector) { throw PortError("Invalid subsector sector.") }
            guard leaf.count > 0, leaf.first >= 0, leaf.first <= segs.count, leaf.count <= segs.count - leaf.first else { throw PortError("Invalid subsector range.") }
        }
        for (index, node) in nodes.enumerated() {
            guard simd_length_squared(node.direction) > 0 else { throw PortError("Degenerate BSP partition.") }
            for child in [node.right, node.left] {
                guard child & Node.leafBit != 0 ? leaves.indices.contains(child & ~Node.leafBit) : (child >= 0 && child < index) else {
                    throw PortError("Invalid or cyclic BSP tree.")
                }
            }
        }
    }
    func leafSector(_ index: Int) -> Int {
        if let sector = leaves[index].sector { return sector }
        let seg = segs[leaves[index].first], line = lines[seg.line]
        return sides[seg.side == 0 ? line.front : line.back].sector
    }
    var transferredSkies:[Int:SkyTransfer] {
        var result:[Int:SkyTransfer]=[:]
        for sector in sectors {for sky in [sector.floorSky,sector.ceilingSky].compactMap({$0}) {result[sky.id]=sky}}
        return result
    }
    func sector(at point: SIMD2<Float>) -> Int {
        guard !nodes.isEmpty else { return leafSector(0) }
        var index = nodes.count - 1
        while index & Node.leafBit == 0 {
            let node = nodes[index]
            index = cross(node.direction, point - node.origin) <= 0 ? node.right : node.left
        }
        return leafSector(index & ~Node.leafBit)
    }

}
func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { a.x*b.y-a.y*b.x }
extension Float { func clamped(_ low: Float, _ high: Float) -> Float { min(high, max(low, self)) } }

/// Dedicated, byte-identified rerelease profiles. This is deliberately not a general
/// UMAPINFO/DeHackEd interpreter: an edited or different edition must be assessed again.
struct KEXCampaign {
    let id: Int32
    let title: String
    let maps: [String]
    let metadata: [String:String]
    var endingMap: Int { id==1 ? 8:id==2 ? 20:8 }
    var endingName: String { id==3 ? "E6M8":String(format:"MAP%02d",endingMap) }
    func value(_ key:String, map:String) -> String? {
        guard let block=metadata[map], let regex=try? NSRegularExpression(pattern:"(?im)^\\s*"+NSRegularExpression.escapedPattern(for:key)+"\\s*=\\s*\"([^\"]*)\""),
              let match=regex.firstMatch(in:block,range:NSRange(block.startIndex...,in:block)),let range=Range(match.range(at:1),in:block) else { return nil }
        return String(block[range])
    }
    var story: String {
        guard let block=metadata[endingName], let start=block.range(of:"(?im)^\\s*intertext\\s*=",options:.regularExpression) else { return "" }
        let tail=String(block[start.upperBound...])
        let pattern="^\\s*\"[^\"]*\"(?:\\s*,\\s*\"[^\"]*\")*"
        guard let range=tail.range(of:pattern,options:.regularExpression) else { return "" }
        return String(tail[range]).components(separatedBy:"\"").enumerated().filter{$0.offset%2==1}.map(\.element).joined(separator:"\n")
    }
    static func identify(_ wad:WAD) -> KEXCampaign? {
        guard wad.signature=="PWAD" else { return nil }
        let hash=SHA256.hash(data:wad.sourceData[0]).map{String(format:"%02x",$0)}.joined()
        let id:Int32,title:String
        switch hash {
        case "e2eb4bd5b0e8252fa1198b2c34b5da7602015e2fe5d702a91209bc11d1fbb9f8": id=1;title="No Rest for the Living"
        case "3e42d71e316a3e3e53d47860509998d63a0758eafd846171c77f218b0043eaef": id=2;title="Master Levels for Doom II"
        case "ab75c9352d1ae8fedb581014ec47eb09c28933a6a66e367424dff8ee2810e825": id=3;title="SIGIL II"
        default:return nil
        }
        let text=String(decoding:wad.lump("UMAPINFO")!.data,as:UTF8.self)
        let regex=try! NSRegularExpression(pattern:"(?is)map\\s+(MAP[0-9]+|E[0-9]M[0-9])\\s*\\{([^}]*)\\}")
        var metadata:[String:String]=[:]
        for match in regex.matches(in:text,range:NSRange(text.startIndex...,in:text)) {
            metadata[String(text[Range(match.range(at:1),in:text)!]).uppercased()]=String(text[Range(match.range(at:2),in:text)!])
        }
        return KEXCampaign(id:id,title:title,maps:wad.maps.sorted(),metadata:metadata)
    }
}
