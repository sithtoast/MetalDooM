import Foundation

struct ExtendedUI {
    let tic:Int,health:Int,armor:Int,weapon:Int,readyAmmo:Int,keys:UInt32,weapons:UInt32
    let ammo:[Int],maxAmmo:[Int],music:String,looping:Bool,musicGeneration:Int,ammoType:Int
    let phase:Int,map:Int,nextMap:Int,kills:Int,totalKills:Int,items:Int,totalItems:Int,secrets:Int,totalSecrets:Int,levelTics:Int,secretExit:Bool
    let palette:Int,fixedMap:Int
    var playing:Bool { phase==0 }
    init(data:Data) throws {
        let b=Bytes(data:data)
        guard data.count==144,data.prefix(4)==Data("MUI3".utf8),try b.i32(4)==3,try b.i32(88)==0 else { throw PortError("Invalid UI snapshot header/length") }
        tic=try b.i32(8);health=try b.i32(12);armor=try b.i32(16);weapon=try b.i32(20);readyAmmo=try b.i32(24)
        let cards=try b.i32(28),owned=try b.i32(32),flags=try b.i32(76)
        musicGeneration=try b.i32(80);ammoType=try b.i32(84)
        ammo=try (0..<4).map{try b.i32(36+$0*4)};maxAmmo=try (0..<4).map{try b.i32(52+$0*4)}
        let raw=data[68..<76],name=raw.prefix{$0 != 0}
        guard tic>=0,armor>=0,(0...8).contains(weapon),readyAmmo>=(-1),(0...63).contains(cards),(0...511).contains(owned),
              ammo.allSatisfy({$0>=0}),maxAmmo.allSatisfy({$0>=0}),(-1...3).contains(ammoType),
              readyAmmo == (ammoType<0 ? -1:ammo[ammoType]),(0...1).contains(flags),musicGeneration>0,
              !name.isEmpty,name.allSatisfy({(33...126).contains($0)}),raw.dropFirst(name.count).allSatisfy({$0==0}) else { throw PortError("Invalid HUD/music snapshot values") }
        phase=try b.i32(92);map=try b.i32(96);nextMap=try b.i32(100)
        kills=try b.i32(104);totalKills=try b.i32(108);items=try b.i32(112);totalItems=try b.i32(116)
        secrets=try b.i32(120);totalSecrets=try b.i32(124);levelTics=try b.i32(128)
        palette=try b.i32(136);fixedMap=try b.i32(140)
        let exit=try b.i32(132);secretExit=exit==1
        guard (0...3).contains(phase),(1...32).contains(map),phase==2 ? (1...32).contains(nextMap):nextMap==0,
              [kills,totalKills,items,totalItems,secrets,totalSecrets,levelTics].allSatisfy({$0>=0}),levelTics==tic,
              (0...1).contains(exit),phase>=2 || exit==0,(0...255).contains(palette),(0...255).contains(fixedMap),
              phase != 0 || health>0,phase != 1 || health<=0 else {throw PortError("Invalid level lifecycle snapshot")}
        keys=UInt32(cards);weapons=UInt32(owned);looping=flags==1;music=String(decoding:name,as:UTF8.self)
    }
    var rustWeaponName:String { ["FIST","PISTOL","SHOTGUN","CHAINGUN","ROCKET LAUNCHER","INCINERATOR","CALAMITY BLADE","CHAINSAW","SUPER SHOTGUN"][weapon] }
    var rustAmmoName:String { ammoType<0 ? "": ["BULLETS","SHELLS","FUEL","ROCKETS"][ammoType] }
}
