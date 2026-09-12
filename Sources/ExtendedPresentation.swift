import Foundation

struct ExtendedSprite {
    let name:String, x:Float, y:Float, z:Float, floorZ:Float, light:Float
    let flags:Int, editor:Int, state:Int
}
struct ExtendedPresentation {
    let tic:Int, readyWeapon:Int, ammo:Int
    let actors:[ExtendedSprite], weapons:[ExtendedSprite]
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,32)
        guard data.prefix(4)==Data("MSP1".utf8),try b.i32(4)==1,try b.i32(28)==0 else { throw PortError("Invalid sprite snapshot header.") }
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
