import Foundation
import simd

/// Copied worker geometry. Loading this value never loads the extended engine
/// into the app process. The wire format and compatibility limits are documented
/// in docs/EXTENDED_GEOMETRY.md; production worker transport is still separate work.
struct ExtendedGeometry {
    let map: DoomMap
    let tic: Int
    let contentSHA256: String
    let data:Data
    let reusedTopology:Bool
    init(data: Data, previous:ExtendedGeometry?=nil) throws {
        self.data=data
        let bytes=Bytes(data:data)
        try bytes.check(0,120)
        let version=try bytes.i32(4)
        guard (5...6).contains(version),data.prefix(4)==Data("MGE\(version)".utf8) else {
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
        let counts=try (0..<7).map { try bytes.i32(28+$0*4) }, strides=[8,24,version==6 ? 40:36,version==6 ? 152:140,16,12,24]
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
        func sky(_ p:Int)throws->SkyTransfer? {
            let id=try bytes.i32(p)
            if id==0 {guard data[p..<p+28].allSatisfy({$0==0}) else {throw PortError("Invalid empty sky transfer")};return nil}
            let x=try fixed(p+20),y=try fixed(p+24)
            guard (1...1_000_000).contains(id),abs(x)>0,abs(x)<=256,y>0,y<=256 else {throw PortError("Invalid sky transfer scale/ID")}
            return try SkyTransfer(id:id,name:name(p+4),angle:UInt32(unsigned(p+12)),mid:fixed(p+16),scale:SIMD2(x,y))
        }
        func validateSkies(_ sectors:[Sector])throws {
            var bank:[Int:SkyTransfer]=[:]
            for sector in sectors {for sky in [sector.floorSky,sector.ceilingSky].compactMap({$0}) {
                guard bank[sky.id]==nil || bank[sky.id]==sky else {throw PortError("Conflicting sky transfer identity")}
                bank[sky.id]=sky
            }}
        }
        func tint(_ p:Int)throws->Int {
            let value=try bytes.i32(p);guard (0...255).contains(value) else {throw PortError("Invalid tint index")};return value
        }
        func sector(_ p:Int)throws->Sector {
            let fl=try bytes.i32(p+44),cl=try bytes.i32(p+48),wall=try bytes.i32(p+8)
            guard (0...255).contains(fl),(0...255).contains(cl),(0...511).contains(wall) else {throw PortError("Invalid transferred plane light")}
            return try Sector(floor:fixed(p),ceiling:fixed(p+4),light:Float(wall)/255,
                floorTexture:name(p+12),ceilingTexture:name(p+20),floorOffset:SIMD2(fixed(p+28),fixed(p+32)),ceilingOffset:SIMD2(fixed(p+36),fixed(p+40)),
                floorRotation:UInt32(unsigned(p+76)),ceilingRotation:UInt32(unsigned(p+80)),floorSky:sky(p+84),ceilingSky:sky(p+112),
                floorLight:Float(fl)/255,ceilingLight:Float(cl)/255,backFloor:fixed(p+52),backCeiling:fixed(p+56),backCeilingTexture:name(p+60),spriteClip:SIMD2(fixed(p+68),fixed(p+72)),tint:version==6 ? tint(p+140):0,floorTint:version==6 ? tint(p+144):0,ceilingTint:version==6 ? tint(p+148):0)
        }
        var offsets=[120]
        for i in 0..<7 { offsets.append(offsets.last!+counts[i]*strides[i]) }
        if let previous,previous.data.count==data.count {
            func equal(_ offset:Int,_ length:Int)->Bool {
                data.withUnsafeBytes { current in previous.data.withUnsafeBytes { old in
                    memcmp(current.baseAddress!+offset,old.baseAddress!+offset,length)==0
                } }
            }
            // Identity/counts plus all immutable vertex/line/seg/leaf/node bytes
            // must match. Header tic/player fields are intentionally excluded.
            if equal(12,4),equal(28,92),equal(offsets[0],offsets[2]-offsets[0]),
               equal(offsets[4],data.count-offsets[4]) {
                var sides=previous.map.sides,sectors=previous.map.sectors
                for i in sides.indices {
                    let p=offsets[2]+i*strides[2]
                    if !equal(p,strides[2]) { sides[i]=try Side(sector:bytes.i32(p),x:fixed(p+4),y:fixed(p+8),upper:name(p+12),lower:name(p+20),middle:name(p+28),tint:version==6 ? tint(p+36):0) }
                }
                for i in sectors.indices {
                    let p=offsets[3]+i*strides[3]
                    if !equal(p,strides[3]) { sectors[i]=try sector(p) }
                }
                try validateSkies(sectors)
                map=try DoomMap(copying:previous.map,sides:sides,sectors:sectors,start:SIMD2(fixed(16),fixed(20)),angle:Float(unsigned(24))*2 * .pi/4294967296)
                reusedTopology=true;return
            }
        }
        reusedTopology=false
        var cursor=120
        func records(_ kind: Int) -> [Int] {
            let start=cursor; cursor += counts[kind]*strides[kind]
            return (0..<counts[kind]).map { start+$0*strides[kind] }
        }
        let points=try records(0).map { try SIMD2(fixed($0),fixed($0+4)) }
        let lines=try records(1).map { try Line(a:bytes.i32($0),b:bytes.i32($0+4),flags:unsigned($0+8),front:bytes.i32($0+12),back:bytes.i32($0+16),blend:bytes.i32($0+20)) }
        guard lines.allSatisfy({(0...64).contains($0.blend)}) else {throw PortError("Invalid wall blend table ID")}
        let sides=try records(2).map { try Side(sector:bytes.i32($0),x:fixed($0+4),y:fixed($0+8),upper:name($0+12),lower:name($0+20),middle:name($0+28),tint:version==6 ? tint($0+36):0) }
        let sectors=try records(3).map {try sector($0)}
        try validateSkies(sectors)
        let segs=try records(4).map { try Seg(a:bytes.i32($0),b:bytes.i32($0+4),line:bytes.i32($0+8),side:bytes.i32($0+12)) }
        let leaves=try records(5).map { try Leaf(count:bytes.i32($0),first:bytes.i32($0+4),sector:bytes.i32($0+8)) }
        let nodes=try records(6).map { try Node(origin:SIMD2(fixed($0),fixed($0+4)),direction:SIMD2(fixed($0+8),fixed($0+12)),right:unsigned($0+16),left:unsigned($0+20)) }
        map=try DoomMap(name:String(format:"MAP%02d",number),points:points,lines:lines,sides:sides,sectors:sectors,
                        segs:segs,leaves:leaves,nodes:nodes,start:SIMD2(fixed(16),fixed(20)),angle:Float(unsigned(24))*2 * .pi/4294967296)
    }
}
