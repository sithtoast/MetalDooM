import Foundation
import simd

@main struct Validation {
    static func main() throws {
        let fixtureURL = URL(fileURLWithPath:CommandLine.arguments[1])
        let fixture = try WAD(url:fixtureURL)
        let room = try DoomMap(wad:fixture,name:"MAP01")
        guard room.sector(at:.zero) == 0,
              try Geometry(map:room).triangleCount == 12 else { throw PortError("Fixture geometry regression.") }
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
        for path in CommandLine.arguments.dropFirst(2) {
            let wad = try WAD(url:URL(fileURLWithPath:path)), art = try Art(wad:wad)
            var checked = Set<MaterialKey>()
            for name in wad.maps {
                let map = try DoomMap(wad:wad,name:name), geometry = try Geometry(map:map)
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
                print("PASS: \(name), \(map.sectors.count) sectors, \(geometry.triangleCount) triangles")
            }
            print("PASS: \(wad.maps.count) maps, \(checked.count) decoded materials from \(path)")
        }
    }
}
