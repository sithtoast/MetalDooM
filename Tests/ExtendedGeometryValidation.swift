import Foundation
import simd

@main struct ExtendedGeometryValidation {
    // The frozen algorithm builds a Set then sorts by a single axis. Its
    // equivalent T-junction choices can differ by ~1e-15 near zero between runs.
    // Normalize only sub-micro-unit zero coordinates for the byte comparison.
    static func canonical(_ input:[WorldVertex])->[WorldVertex] {
        input.map { v in
            var v=v
            for i in 0..<4 { if abs(v.position[i])<0.000001 { v.position[i]=0 };if abs(v.uvLight[i])<0.000001 { v.uvLight[i]=0 } }
            return v
        }
    }
    static func parity(_ map:DoomMap) throws {
        let actual=try Geometry(map:map),reference=try ReferenceGeometry(map:map)
        guard actual.batches.map(\.material)==reference.batches.map(\.material) else { throw PortError("Reference materials differ") }
        for (a,b) in zip(actual.batches,reference.batches) {
            guard canonical(a.vertices).withUnsafeBytes({Data($0)})==canonical(b.vertices).withUnsafeBytes({Data($0)}) else { throw PortError("Classic/reference vertices differ in \(map.name) material \(a.material): first \(zip(canonical(a.vertices),canonical(b.vertices)).first{ $0.position != $1.position || $0.uvLight != $1.uvLight }.map{String(describing:$0)} ?? "none")") }
        }
        guard canonical(actual.skyVertices).withUnsafeBytes({Data($0)})==canonical(reference.skyVertices).withUnsafeBytes({Data($0)}) else { throw PortError("Reference sky differs") }
    }
    static func main() throws {
        let original=try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        let directory=URL(fileURLWithPath:CommandLine.arguments[2])
        for number in 1...32 {
            let name=String(format:"MAP%02d",number)
            let classic=try DoomMap(wad:original,name:name)
            try parity(classic)
            let copied=try ExtendedGeometry(data:Data(contentsOf:directory.appendingPathComponent("classic-\(name).mge"))).map
            guard classic.points.count == copied.points.count, classic.nodes.count == copied.nodes.count,
                  classic.lines.count == copied.lines.count, classic.segs.count == copied.segs.count,
                  classic.leaves.count == copied.leaves.count else { throw PortError("Classic geometry mismatch in \(name).") }
            for i in classic.lines.indices {
                let a=classic.lines[i],b=copied.lines[i]
                guard a.a == b.a, a.b == b.b, classic.points[a.a] == copied.points[b.a], classic.points[a.b] == copied.points[b.b] else { throw PortError("Linedef geometry mismatch.") }
            }
            for i in classic.nodes.indices {
                let a=classic.nodes[i],b=copied.nodes[i]
                guard a.origin == b.origin, a.direction == b.direction, a.right == b.right, a.left == b.left else { throw PortError("BSP mismatch.") }
            }
            for i in classic.leaves.indices {
                guard classic.leafSector(i) == copied.leafSector(i) else { throw PortError("Subsector sector mismatch.") }
            }
            guard try Geometry(map:classic).triangleCount == Geometry(map:copied).triangleCount else { throw PortError("Classic mesh mismatch.") }
            print("PASS \(name) classic and worker BSP, sectors and triangle counts agree")
        }
        for number in 1...16 {
            let name=String(format:"MAP%02d",number)
            let data=try Data(contentsOf:directory.appendingPathComponent("rust-\(name).mge"))
            let snapshot=try ExtendedGeometry(data:data), map=snapshot.map
            try parity(map)
            let geometry=try Geometry(map:map)
            guard geometry.triangleCount > 0, snapshot.tic == 0 else { throw PortError("Empty Rust geometry.") }
            for batch in geometry.batches {
                guard batch.vertices.count % 3 == 0 else { throw PortError("Incomplete triangles.") }
                for v in batch.vertices {
                    guard (0..<4).allSatisfy({v.position[$0].isFinite && v.uvLight[$0].isFinite}) else { throw PortError("Non-finite Rust geometry.") }
                }
            }
            for i in map.leaves.indices {
                let leaf=map.leaves[i],seg=map.segs[leaf.first],line=map.lines[seg.line]
                guard map.leafSector(i) == map.sides[seg.side == 0 ? line.front:line.back].sector else { throw PortError("Worker subsector mismatch.") }
            }
            print("PASS Rust \(name): \(map.points.count) vertices, \(map.nodes.count) nodes, \(map.leaves.count) leaves, \(geometry.triangleCount) triangles")
            if number == 13 {
                guard map.nodes.count > 32768, map.segs.contains(where:{$0.a >= 32768 || $0.b >= 32768}) else { throw PortError("MAP13 did not exercise extended references.") }
                var cases=[Data(data.prefix(119)),Data(data.dropLast()),data+Data([0])]
                func mutate(_ offset:Int,_ value:UInt32) -> Data {
                    var copy=data
                    for i in 0..<4 { copy[offset+i]=UInt8(truncatingIfNeeded:value >> (8*i)) }
                    return copy
                }
                cases += [mutate(4,5),mutate(28,UInt32.max),mutate(28,1_000_001),mutate(12,99)]
                let bytes=Bytes(data:data),counts=try (0..<7).map{try bytes.i32(28+$0*4)},strides=[8,24,36,76,16,12,24]
                let offsets=(0..<7).map { k in 120+(0..<k).reduce(0){$0+counts[$1]*strides[$1]} }
                cases += [mutate(offsets[1],UInt32.max),mutate(offsets[2],UInt32.max),mutate(offsets[4]+12,2),
                          mutate(offsets[5]+4,UInt32.max),mutate(offsets[5]+8,UInt32.max),
                          mutate(offsets[6]+16,UInt32(counts[6])),mutate(offsets[6]+20,UInt32.max)]
                for bad in cases {
                    var rejected=false
                    do { _=try ExtendedGeometry(data:bad) } catch { rejected=true }
                    var cachedRejected=false
                    do { _=try ExtendedGeometry(data:bad,previous:snapshot) } catch { cachedRejected=true }
                    guard cachedRejected else { throw PortError("Cached malformed geometry accepted.") }
                    guard rejected else { throw PortError("Malformed copied geometry accepted.") }
                }
                print("PASS \(cases.count) malformed snapshot boundaries")
            }
        }
    }
}
