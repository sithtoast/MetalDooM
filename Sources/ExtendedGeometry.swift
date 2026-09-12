import Foundation
import simd

/// Copied worker geometry. Loading this value never loads the extended engine
/// into the app process. The wire format and compatibility limits are documented
/// in docs/EXTENDED_GEOMETRY.md; production worker transport is still separate work.
struct ExtendedGeometry {
    let map: DoomMap
    let tic: Int
    let contentSHA256: String
    init(data: Data) throws {
        let bytes=Bytes(data:data)
        try bytes.check(0,120)
        guard data.prefix(4) == Data("MGE1".utf8), try bytes.i32(4) == 1 else {
            throw PortError("Unsupported worker geometry format.")
        }
        tic=try bytes.i32(8)
        let number=try bytes.i32(12)
        guard tic >= 0, (1...32).contains(number) else { throw PortError("Invalid geometry identity.") }
        let hash=data[56..<120]
        guard hash.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw PortError("Invalid geometry content fingerprint.")
        }
        contentSHA256=String(decoding:hash,as:UTF8.self)
        let counts=try (0..<7).map { try bytes.i32(28+$0*4) }, strides=[8,20,36,28,16,12,24]
        var expected=120
        for (count,stride) in zip(counts,strides) {
            guard (0...1_000_000).contains(count) else { throw PortError("Excessive geometry count.") }
            expected += count*stride
        }
        guard data.count == expected else { throw PortError("Truncated or trailing worker geometry.") }
        func fixed(_ offset: Int) throws -> Float { Float(try bytes.i32(offset))/65536 }
        func unsigned(_ offset: Int) throws -> Int { Int(UInt32(bitPattern:Int32(try bytes.i32(offset)))) }
        func name(_ offset: Int) throws -> String {
            let raw=data[offset..<offset+8]
            let visible=raw.prefix { $0 != 0 }
            guard !visible.isEmpty, visible.allSatisfy({ (33...126).contains($0) }),
                  raw.dropFirst(visible.count).allSatisfy({$0 == 0}) else { throw PortError("Invalid geometry material name.") }
            return String(decoding:visible,as:UTF8.self).uppercased()
        }
        var cursor=120
        func records(_ kind: Int) -> [Int] {
            let start=cursor; cursor += counts[kind]*strides[kind]
            return (0..<counts[kind]).map { start+$0*strides[kind] }
        }
        let points=try records(0).map { try SIMD2(fixed($0),fixed($0+4)) }
        let lines=try records(1).map { try Line(a:bytes.i32($0),b:bytes.i32($0+4),flags:unsigned($0+8),front:bytes.i32($0+12),back:bytes.i32($0+16)) }
        let sides=try records(2).map { try Side(sector:bytes.i32($0),x:fixed($0+4),y:fixed($0+8),upper:name($0+12),lower:name($0+20),middle:name($0+28)) }
        let sectors=try records(3).map { try Sector(floor:fixed($0),ceiling:fixed($0+4),light:Float(bytes.i32($0+8)).clamped(0,255)/255,floorTexture:name($0+12),ceilingTexture:name($0+20)) }
        let segs=try records(4).map { try Seg(a:bytes.i32($0),b:bytes.i32($0+4),line:bytes.i32($0+8),side:bytes.i32($0+12)) }
        let leaves=try records(5).map { try Leaf(count:bytes.i32($0),first:bytes.i32($0+4),sector:bytes.i32($0+8)) }
        let nodes=try records(6).map { try Node(origin:SIMD2(fixed($0),fixed($0+4)),direction:SIMD2(fixed($0+8),fixed($0+12)),right:unsigned($0+16),left:unsigned($0+20)) }
        map=try DoomMap(name:String(format:"MAP%02d",number),points:points,lines:lines,sides:sides,sectors:sectors,
                        segs:segs,leaves:leaves,nodes:nodes,start:SIMD2(fixed(16),fixed(20)),angle:Float(unsigned(24))*2 * .pi/4294967296)
    }
}
