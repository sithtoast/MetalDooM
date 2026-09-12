import Foundation

struct ExtendedSprite {
    let name:String, x:Float, y:Float, z:Float, floorZ:Float, light:Float
    let flags:Int, editor:Int, state:Int
}
struct ExtendedPresentation {
    let tic:Int, readyWeapon:Int, ammo:Int
    let snapCamera:Bool
    let actors:[ExtendedSprite], weapons:[ExtendedSprite]
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,32)
        guard data.prefix(4)==Data("MSP2".utf8),try b.i32(4)==2,(0...1).contains(try b.i32(28)) else { throw PortError("Invalid sprite snapshot header.") }
        snapCamera=try b.i32(28)==1
        tic=try b.i32(8);let count=try b.i32(12),weaponCount=try b.i32(16)
        readyWeapon=try b.i32(20);ammo=try b.i32(24)
        guard tic>=0,(0...1_000_000).contains(count),(0...2).contains(weaponCount),(0...8).contains(readyWeapon),ammo>=(-1),
              data.count==32+count*40+weaponCount*24 else { throw PortError("Invalid sprite snapshot counts or state.") }
        func record(_ offset:Int,weapon:Bool) throws -> ExtendedSprite {
            let raw=data[offset..<offset+8],text=raw.prefix{$0 != 0}
            guard !text.isEmpty,text.allSatisfy({(33...126).contains($0)}),raw.dropFirst(text.count).allSatisfy({$0==0}) else { throw PortError("Invalid sprite resource name.") }
            let light=try b.i32(offset+(weapon ? 16:24)),flags=try b.i32(offset+(weapon ? 20:28))
            guard (0...255).contains(light),flags>=0,flags & ~(weapon ? 7:15)==0 else { throw PortError("Invalid sprite presentation flags/light (\(flags)/\(light)).") }
            func fixed(_ p:Int) throws -> Float { Float(try b.i32(p))/65536 }
            return try ExtendedSprite(name:String(decoding:text,as:UTF8.self),x:fixed(offset+8),y:fixed(offset+12),
                z:weapon ? 0:fixed(offset+16),floorZ:weapon ? 0:fixed(offset+20),light:Float(light)/255,
                flags:flags,editor:weapon ? 0:b.i32(offset+32),state:weapon ? 0:b.i32(offset+36))
        }
        actors=try (0..<count).map{try record(32+$0*40,weapon:false)}
        weapons=try (0..<weaponCount).map{try record(32+count*40+$0*24,weapon:true)}
    }
}

/// Presentation-only, at most one tic behind. Never extrapolate or modify the
/// worker state. Callers opt in for continuous play and snap on pause/restore.
struct ExtendedInterpolation {
    struct Frame {
        let tic:Int,map:Int,playing:Bool,snap:Bool
        let position:SIMD3<Float>,angle:Float,weapon:Int,weapons:[ExtendedSprite]
    }
    struct Sample {let position:SIMD3<Float>,angle:Float,weapons:[SIMD2<Float>]}
    private var current:Frame?,previous:Frame?,received=0.0
    private(set) var active=false
    mutating func setActive(_ enabled:Bool) {
        if active != enabled {previous=nil}
        active=enabled
    }
    mutating func accept(_ frame:Frame,now:Double) {
        let old=current
        previous=nil
        if active,let old,frame.playing,old.playing,!frame.snap,
           frame.map==old.map,frame.tic==old.tic+1,now>=received,now-received<=2.0/35.0 {
            let delta=frame.position-old.position
            // Engine teleport flag covers even short teleports. Large unmarked
            // corrections also snap instead of drawing a path through geometry.
            if abs(delta.x)<64 && abs(delta.y)<64 && abs(delta.z)<32 {previous=old}
        }
        current=frame;received=now
    }
    func sample(now:Double)->Sample? {
        guard let frame=current else {return nil}
        let xy=frame.weapons.map{SIMD2($0.x,$0.y)}
        guard active,let old=previous else {return Sample(position:frame.position,angle:frame.angle,weapons:xy)}
        let blend=Float(max(0,min(1,(now-received)*35)))
        if blend==1 {return Sample(position:frame.position,angle:frame.angle,weapons:xy)}
        let turn=atan2(sin(frame.angle-old.angle),cos(frame.angle-old.angle))
        // Frame/slot changes and patched coordinate jumps are discrete. Keep
        // weapon and flash together rather than blending unrelated artwork.
        let same=old.weapon==frame.weapon && old.weapons.count==frame.weapons.count &&
            zip(old.weapons,frame.weapons).allSatisfy { a,b in
                a.name==b.name && a.flags==b.flags && abs(a.x-b.x)<=32 && abs(a.y-b.y)<=32
            }
        let weapons=same ? zip(old.weapons,xy).map { a,b in SIMD2(a.x,a.y)+(b-SIMD2(a.x,a.y))*blend }:xy
        return Sample(position:old.position+(frame.position-old.position)*blend,angle:old.angle+turn*blend,weapons:weapons)
    }
}
