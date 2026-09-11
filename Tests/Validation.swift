import Foundation
import simd

@main struct Validation {
    static func main() throws {
        let fixtureURL = URL(fileURLWithPath:CommandLine.arguments[1])
        let fixture = try WAD(url:fixtureURL)
        let room = try DoomMap(wad:fixture,name:"MAP01")
        guard room.sector(at:.zero) == 0,
              try Geometry(map:room).triangleCount == 12 else { throw PortError("Fixture geometry regression.") }
        let bounded = try Geometry(map:room)
        for batch in bounded.batches where batch.material.flat {
            for vertex in batch.vertices {
                guard abs(vertex.position.x) <= 128.001, abs(vertex.position.z) <= 128.001 else {
                    throw PortError("Subsector plane escaped its seg boundaries toward the unused far vertex.")
                }
            }
        }
        print("PASS: floor/ceiling polygons respect room edges despite expanded map bounds")
        let splitRoom = try DoomMap(wad:fixture,name:"MAP02")
        let splitGeometry = try Geometry(map:splitRoom)
        for height: Float in [0,128] {
            var area: Float = 0
            for batch in splitGeometry.batches where batch.material.flat {
                for i in stride(from:0,to:batch.vertices.count,by:3) {
                    let vertices = batch.vertices[i..<i+3].map { $0.position }
                    guard vertices.allSatisfy({ $0.y == height }) else { continue }
                    let p = vertices.map { SIMD2($0.x,-$0.z) }
                    area += abs(cross(p[1]-p[0],p[2]-p[0]))/2
                    guard p.allSatisfy({ $0.x >= 0 && $0.x <= 128 && $0.y >= 0 && $0.y <= 128+$0.x/128 }) else {
                        throw PortError("Split flat escaped original wall boundaries.")
                    }
                }
            }
            guard abs(area-16448) < 0.01 else { throw PortError("Rounded BSP segs left a gap in floor/ceiling: area \(area), expected 16448.") }
        }
        print("PASS: rounded BSP split vertices preserve complete floor/ceiling coverage")
        let original = try Data(contentsOf:fixtureURL)
        let invalidURL = fixtureURL.deletingLastPathComponent().appendingPathComponent("invalid.wad")
        defer { try? FileManager.default.removeItem(at:invalidURL) }
        var malformed = [Data(),Data(original.prefix(11)),Data(original.prefix(original.count-1))]
        var badSignature = original; badSignature[0] = 0; malformed.append(badSignature)
        var badDirectory = original; for i in 8..<12 { badDirectory[i] = 255 }; malformed.append(badDirectory)
        for data in malformed {
            try data.write(to:invalidURL)
            do { _ = try WAD(url:invalidURL); throw PortError("Malformed WAD was accepted.") }
            catch let error as PortError where error.description == "Malformed WAD was accepted." { throw error }
            catch {}
        }
        print("PASS: test-room geometry, sector lookup, and five malformed WAD cases")
        let fixtureArt = try Art(wad:fixture)
        // Two sparse columns, signed origin, and transparent gaps.
        let patchData = Data([2,0,4,0,254,255,3,0,16,0,0,0,23,0,0,0,
                              1,2,0,10,20,0,255,0,1,0,30,0,255])
        let patch = try fixtureArt.decodePatch(Bytes(data:patchData))
        guard patch.left == -2, patch.top == 3, patch.image.width == 2, patch.image.height == 4,
              patch.image.rgba[3] == 0, patch.image.rgba[7] == 255,
              patch.image.rgba[4] == 30, patch.image.rgba[8] == 10,
              patch.image.rgba[16] == 20, patch.image.rgba[31] == 0 else {
            throw PortError("Sparse patch pixels, transparency, or offsets are incorrect.")
        }
        var badColumn = patchData; badColumn[8] = 0
        for invalid in [Data(patchData.prefix(patchData.count-1)),badColumn,Data(patchData.prefix(7))] {
            var rejected = false
            do { _ = try fixtureArt.decodePatch(Bytes(data:invalid)) } catch { rejected = true }
            guard rejected else { throw PortError("Malformed sprite patch was accepted.") }
        }
        print("PASS: sprite patch transparency, signed offsets, and malformed column rejection")
        for path in CommandLine.arguments.dropFirst(2) {
            let wad = try WAD(url:URL(fileURLWithPath:path)), art = try Art(wad:wad)
            var checked = Set<MaterialKey>()
            for name in wad.maps {
                let map = try DoomMap(wad:wad,name:name), geometry = try Geometry(map:map,textureHeights:art.textureHeights())
                guard geometry.triangleCount > 0 else { throw PortError("Empty geometry in \(name).") }
                for batch in geometry.batches {
                    for vertex in batch.vertices {
                        guard (0..<4).allSatisfy({ vertex.position[$0].isFinite && vertex.uvLight[$0].isFinite }) else { throw PortError("Non-finite geometry in \(name).") }
                    }
                    if checked.insert(batch.material).inserted {
                        guard let image = try art.image(batch.material), image.rgba.count == image.width*image.height*4 else {
                            throw PortError("Missing or invalid texture \(batch.material.name) in \(name).")
                        }
                    }
                }
                if name == "E1M1" {
                    for texture in ["BRNBIGL","BRNBIGC","BRNBIGR"] {
                        guard let batch = geometry.batches.first(where: { $0.material.name == texture }), !batch.vertices.isEmpty else {
                            throw PortError("Missing exit middle texture: \(texture)")
                        }
                        for v in batch.vertices {
                            guard v.position.y >= -24, v.position.y <= 104, v.uvLight.y >= 0, v.uvLight.y <= 128 else {
                                throw PortError("Exit panel was repeated outside its opening.")
                            }
                        }
                    }
                    guard !geometry.skyVertices.isEmpty,
                          geometry.skyVertices.contains(where: { $0.uvLight.w == 1 }),
                          geometry.skyVertices.contains(where: { $0.uvLight.w == 0 }) else {
                        throw PortError("Sky planes or boundary curtains are missing.")
                    }
                    print("PASS: E1M1 exit panels, bounded middle UVs, sky planes and boundary curtains")
                }
                print("PASS: \(name), \(map.sectors.count) sectors, \(geometry.triangleCount) triangles")
            }
            print("PASS: \(wad.maps.count) maps, \(checked.count) decoded materials from \(path)")
            var inSprites = false, spriteCount = 0
            for (index,lump) in wad.lumps.enumerated() {
                if lump.name == "S_START" || lump.name == "SS_START" { inSprites = true; continue }
                if lump.name == "S_END" || lump.name == "SS_END" { inSprites = false; continue }
                if inSprites && lump.bytes.count > 0 { _ = try art.patch(lump:index); spriteCount += 1 }
            }
            for name in ["STBAR","STARMS","STTPRCNT","STFDEAD0"]
                + (0...9).flatMap({ ["STTNUM\($0)","STYSNUM\($0)"] })
                + (0...5).map({ "STKEYS\($0)" }) {
                guard try art.patch(named:name) != nil else { throw PortError("Missing HUD patch \(name).") }
            }
            print("PASS: \(spriteCount) sprite patches and HUD artwork decoded")
        }
    }
}
