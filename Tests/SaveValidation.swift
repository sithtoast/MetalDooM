// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

@main struct SaveValidation {
    static func main() throws {
        let wad = try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        let wrongWAD = try WAD(url:URL(fileURLWithPath:CommandLine.arguments[2]))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let file = directory.appendingPathComponent("roundtrip.mdsave"), raw = directory.appendingPathComponent("payload")
        MD_TestMonsters(0); precondition(MD_Load(wad.url.path,1,1) != 0)
        func tick(_ n: Int) { for _ in 0..<n { precondition(MD_Tick(0,0,0,0) != 0) } }
        func things() -> [MD_Thing] {
            let count = Int(MD_CopyThings(nil,0,0,0)); var result = [MD_Thing](repeating:MD_Thing(),count:count)
            _ = result.withUnsafeMutableBufferPointer { MD_CopyThings($0.baseAddress,Int32(count),0,0) }; return result
        }
        precondition(MD_TestPlacePlayer(1056,-3616,Float.pi/2) != 0)
        MD_TestTarget(1,128);tick(25)
        for _ in 0..<10 {precondition(MD_CombatTick(0,0,0,0,1,-1) != 0)}
        let enemyHealth = MD_TestHealthForType(1)
        // Remove a real pickup and modify player and enemy state before saving.
        let item = things().first { $0.doomedType == 2014 }!
        precondition(MD_TestPlacePlayer(item.x,item.y,0) != 0); precondition(MD_Tick(25,0,0,0) != 0)
        MD_TestDamagePlayer(17)
        var x: Float=0,y: Float=0,angle: Float=0,side: Int32=0
        precondition(MD_TestSwitch(63,&x,&y,&angle,&side) >= 0)
        precondition(MD_TestPlacePlayer(x,y,angle) != 0);precondition(MD_Tick(0,0,0,1) != 0);tick(5)
        let player = MD_GetPlayer(), inventory = MD_GetHUD(), objects = things()
        let sectors = (0..<MD_SectorCount()).map { MD_GetSector($0) }
        let switchBefore = MD_GetSide(side)
        try SaveStore.write(to:file,wad:wad,map:"E1M1",pitch:0.25)
        let originalFile = try Data(contentsOf:file)
        precondition(MD_Load(wad.url.path,1,2) != 0);tick(50)
        let save = try SaveStore.read(from:file,wad:wad);precondition(save.pitch == 0.25)
        try save.payload.write(to:raw)
        precondition(MD_ReadSave(raw.path) != 0)
        let restored = MD_GetPlayer(), after = MD_GetHUD()
        precondition(MD_GetProgress().map == 1 && player.x == restored.x && player.y == restored.y && player.eyeZ == restored.eyeZ && player.angle == restored.angle && player.tick == restored.tick)
        precondition(inventory.health == after.health && inventory.armor == after.armor && inventory.bullets == after.bullets && inventory.weapons == after.weapons)
        precondition(MD_TestHealthForType(1)==enemyHealth)
        let restoredObjects = things();precondition(restoredObjects.count == objects.count)
        for (a,b) in zip(objects,restoredObjects) { precondition(a.x==b.x && a.y==b.y && a.z==b.z && a.lump==b.lump && a.doomedType==b.doomedType) }
        for i in sectors.indices { let actual=MD_GetSector(Int32(i)); precondition(actual.floor==sectors[i].floor && actual.ceiling==sectors[i].ceiling && actual.light==sectors[i].light) }
        func lower(_ side: MD_Side) -> String { var value=side.lower;return withUnsafePointer(to:&value) { $0.withMemoryRebound(to:CChar.self,capacity:9) {String(cString:$0)} } }
        precondition(lower(MD_GetSide(side))==lower(switchBefore));tick(40);precondition(lower(MD_GetSide(side))=="SW1COMP")
        print("PASS: cross-map restore of position/view/tic, inventory, removed pickup, things, sectors and timed switch reset")
        var rejected=false
        do { _ = try SaveStore.read(from:file,wad:wrongWAD) } catch { rejected=true };precondition(rejected)
        var badPayload=save.payload;badPayload[100] ^= 1
        let bad=SavedGame(format:save.format,version:save.version,wadSHA256:save.wadSHA256,map:save.map,savedAt:save.savedAt,pitch:save.pitch,payload:badPayload,payloadSHA256:save.payloadSHA256)
        try PropertyListEncoder().encode(bad).write(to:file)
        rejected=false;do { _ = try SaveStore.read(from:file,wad:wad) } catch {rejected=true};precondition(rejected)
        try originalFile.prefix(100).write(to:file)
        rejected=false;do { _ = try SaveStore.read(from:file,wad:wad) } catch {rejected=true};precondition(rejected)
        try originalFile.write(to:file)
        MD_TestExit(0);tick(1)
        rejected=false;do {try SaveStore.write(to:file,wad:wad,map:"E1M1",pitch:0)} catch {rejected=true};precondition(rejected)
        let preserved = try Data(contentsOf:file);precondition(preserved==originalFile)
        print("PASS: wrong WAD and damaged/truncated saves rejected; failed save preserves existing file")
        precondition(MD_ReadSave(raw.path) != 0 && MD_GetProgress().phase==0)
        MD_TestDamagePlayer(1000);precondition(MD_GetHUD().health<=0)
        precondition(MD_ReadSave(raw.path) != 0 && MD_GetHUD().health>0)
        print("PASS: load from intermission and after death")
        precondition(MD_Load(wad.url.path,1,1) != 0)
        let beforeInvalid=MD_GetPlayer();try Data(repeating:0,count:512).write(to:raw)
        precondition(MD_ReadSave(raw.path)==0 && MD_GetPlayer().tick==beforeInvalid.tick && MD_GetPlayer().x==beforeInvalid.x)
        precondition(wad.mapTitle("E1M1")=="E1M1: Hangar" && wad.mapTitle("E1M2")=="E1M2: Nuclear Plant")
        print("PASS: bad native header preserves live game; canonical map names")
    }
}
