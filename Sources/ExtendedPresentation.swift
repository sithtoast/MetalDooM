import Foundation

struct ExtendedSprite {
    let name:String, x:Float, y:Float, z:Float, floorZ:Float, light:Float
    let flags:Int, editor:Int, state:Int
    var previous:SIMD4<Float>?=nil
    func position(fraction:Float)->SIMD4<Float> {
        let current=SIMD4(x,y,z,floorZ)
        guard fraction<1,let previous else {return current}
        return previous+(current-previous)*fraction
    }
    var blendTable:Int {flags>>8 != 0 ? flags>>8:flags&16 != 0 ? 2:flags&8 != 0 ? 1:0}
}
struct ExtendedPresentation {
    let tic:Int, readyWeapon:Int, ammo:Int
    let snapCamera:Bool
    let actors:[ExtendedSprite], weapons:[ExtendedSprite]
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,32)
        guard data.prefix(4)==Data("MSP5".utf8),try b.i32(4)==5,(0...1).contains(try b.i32(28)) else { throw PortError("Invalid sprite snapshot header.") }
        snapCamera=try b.i32(28)==1
        tic=try b.i32(8);let count=try b.i32(12),weaponCount=try b.i32(16)
        readyWeapon=try b.i32(20);ammo=try b.i32(24)
        guard tic>=0,(0...1_000_000).contains(count),(0...2).contains(weaponCount),(0...8).contains(readyWeapon),ammo>=(-1),
              data.count==32+count*56+weaponCount*24 else { throw PortError("Invalid sprite snapshot counts or state.") }
        func record(_ offset:Int,weapon:Bool) throws -> ExtendedSprite {
            let raw=data[offset..<offset+8],text=raw.prefix{$0 != 0}
            guard !text.isEmpty,text.allSatisfy({(33...126).contains($0)}),raw.dropFirst(text.count).allSatisfy({$0==0}) else { throw PortError("Invalid sprite resource name.") }
            let light=try b.i32(offset+(weapon ? 16:24)),flags=try b.i32(offset+(weapon ? 20:28))
            guard (0...255).contains(light),flags>=0,flags & ~(weapon ? 0xff1f:0xff3f)==0,flags & 16==0 || flags & 8 != 0,flags & 4==0 || flags & 24==0,
                  flags>>8==0 || (3...64).contains(flags>>8) && flags & 24==8 else { throw PortError("Invalid sprite presentation flags/light (\(flags)/\(light)).") }
            func fixed(_ p:Int) throws -> Float { Float(try b.i32(p))/65536 }
            return try ExtendedSprite(name:String(decoding:text,as:UTF8.self),x:fixed(offset+8),y:fixed(offset+12),
                z:weapon ? 0:fixed(offset+16),floorZ:weapon ? 0:fixed(offset+20),light:Float(light)/255,
                flags:flags,editor:weapon ? 0:b.i32(offset+32),state:weapon ? 0:b.i32(offset+36),
                previous:weapon || flags&32==0 ? nil:SIMD4(fixed(offset+40),fixed(offset+44),fixed(offset+48),fixed(offset+52)))
        }
        actors=try (0..<count).map{try record(32+$0*56,weapon:false)}
        weapons=try (0..<weaponCount).map{try record(32+count*56+$0*24,weapon:true)}
    }
}

/// Presentation-only, at most one tic behind. Never extrapolate or modify the
/// worker state. Callers opt in for continuous play and snap on pause/restore.
struct ExtendedInterpolation {
    struct Frame {
        let tic:Int,map:Int,playing:Bool,snap:Bool
        let position:SIMD3<Float>,angle:Float,weapon:Int,weapons:[ExtendedSprite]
    }
    struct Sample {let position:SIMD3<Float>,angle:Float,weapons:[SIMD2<Float>],fraction:Float}
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
        guard active,let old=previous else {return Sample(position:frame.position,angle:frame.angle,weapons:xy,fraction:1)}
        let blend=Float(max(0,min(1,(now-received)*35)))
        if blend==1 {return Sample(position:frame.position,angle:frame.angle,weapons:xy,fraction:1)}
        let turn=atan2(sin(frame.angle-old.angle),cos(frame.angle-old.angle))
        // Frame/slot changes and patched coordinate jumps are discrete. Keep
        // weapon and flash together rather than blending unrelated artwork.
        let same=old.weapon==frame.weapon && old.weapons.count==frame.weapons.count &&
            zip(old.weapons,frame.weapons).allSatisfy { a,b in
                a.name==b.name && a.flags==b.flags && abs(a.x-b.x)<=32 && abs(a.y-b.y)<=32
            }
        let weapons=same ? zip(old.weapons,xy).map { a,b in SIMD2(a.x,a.y)+(b-SIMD2(a.x,a.y))*blend }:xy
        return Sample(position:old.position+(frame.position-old.position)*blend,angle:old.angle+turn*blend,weapons:weapons,fraction:blend)
    }
}

/// Palette-index tables refreshed per level, indexed background * 256 + foreground.
struct ExtendedBlendTables {
    static let maxByteCount=24+256*768+256*256+64*65536
    let palettes:[UInt8], colormaps:[UInt8], tables:[[UInt8]]
    var palette:[UInt8] {Array(palettes.prefix(768))}
    var normal:[UInt8] {tables[0]}
    var additive:[UInt8] {tables[1]}
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,24)
        let count=try b.i32(12),colors=try b.i32(8),maps=try b.i32(16)
        guard (2...64).contains(count),(768...256*768).contains(colors),colors%768==0,
              (256...256*256).contains(maps),maps%256==0,data.count==24+colors+maps+count*65536,
              data.prefix(4)==Data("MBL3".utf8),try b.i32(4)==3,try b.i32(20)==0 else {throw PortError("Invalid blend/color snapshot.")}
        palettes=Array(data[24..<24+colors]);colormaps=Array(data[24+colors..<24+colors+maps])
        let start=24+colors+maps
        tables=(0..<count).map {Array(data[(start+$0*65536)..<(start+($0+1)*65536)])}
    }
    func validate(_ presentation:ExtendedPresentation,palette:Int=0,fixed:Int=0,walls:[Int]=[]) throws {
        guard palette<palettes.count/768,fixed<colormaps.count/256,
              (presentation.actors+presentation.weapons).allSatisfy({$0.blendTable<=tables.count}),walls.allSatisfy({$0<=tables.count}) else {throw PortError("Missing blend table, palette or colormap.")}
    }
    func rgba(index:Int)->[UInt8] {
        let palette=self.palette
        return tables[index].flatMap { entry in
            let p=Int(entry)*3;return [palette[p],palette[p+1],palette[p+2],255]
        }
    }
}
