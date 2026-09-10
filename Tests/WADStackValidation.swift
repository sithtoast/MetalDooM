// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

@main struct WADStackValidation {
    static func main() throws {
        let base=URL(fileURLWithPath:CommandLine.arguments[1]), addon=URL(fileURLWithPath:CommandLine.arguments[2])
        let wad=try WAD(url:base,addOns:[addon]), original=try WAD(url:base)
        precondition(wad.isSigil && wad.maps.count==45 && wad.maps.contains("E1M1"))
        precondition(wad.lump("TITLEPIC")?.data != original.lump("TITLEPIC")?.data)
        precondition(wad.lump("E5TEXT") != nil && wad.mapTitle("E5M1").contains("Baphomet"))
        func configure(_ wad:WAD)->Int32 {
            wad.sourceURLs.map(\.path).joined(separator:"\n").withCString { paths in
                wad.engineOrder.withUnsafeBufferPointer { MD_ConfigureWADStack(paths,$0.baseAddress,Int32($0.count)) }
            }
        }
        precondition(configure(wad) != 0)
        MD_TestMonsters(0)
        let art=try Art(wad:wad)
        for map in 1...9 {
            let name="E5M\(map)", data=try DoomMap(wad:wad,name:name)
            let geometry=try Geometry(map:data,textureHeights:art.textureHeights())
            for material in Set(geometry.batches.map(\.material)) { let image=try art.image(material);precondition(image != nil) }
            let sky=try art.image(MaterialKey(name:"SKY5",flat:false));precondition(sky != nil)
            precondition(MD_Load(base.path,5,Int32(map)) != 0)
            precondition(MD_GetProgress().episode==5 && MD_GetProgress().map==map)
            var things=[MD_Thing](repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,0,0)))
            things.withUnsafeMutableBufferPointer { _=MD_CopyThings($0.baseAddress,Int32($0.count),0,0) }
            for thing in things { precondition(wad.lumps.indices.contains(Int(thing.lump)));_ = try art.patch(lump:Int(thing.lump)) }
            precondition(MD_Cheat("idfa") != 0)
            let before=MD_GetHUD()
            MD_TestExit(0);precondition(MD_Tick(0,0,0,0) != 0)
            if map==8 { precondition(MD_GetProgress().phase==2) }
            else {
                precondition(MD_GetProgress().nextMap==(map==9 ? 7:map+1))
                precondition(MD_Continue() != 0 && MD_GetHUD().weapons==before.weapons)
            }
        }
        precondition(MD_Load(base.path,5,6) != 0)
        MD_TestExit(1);precondition(MD_Tick(0,0,0,0) != 0)
        precondition(MD_GetProgress().nextMap==9 && MD_Continue() != 0 && MD_GetProgress().map==9)
        let save=SaveStore.temporaryURL();defer { try? FileManager.default.removeItem(at:save) }
        try SaveStore.write(to:save,wad:wad,map:"E5M9",pitch:0)
        let saved=try SaveStore.read(from:save,wad:wad)
        let native=SaveStore.temporaryURL();defer { try? FileManager.default.removeItem(at:native) }
        try saved.payload.write(to:native)
        precondition(MD_Load(base.path,1,1) != 0 && MD_ReadSave(native.path) != 0 && MD_GetProgress().episode==5)
        do { _ = try SaveStore.read(from:save,wad:original);fatalError("Base-only save mismatch accepted") } catch is PortError {}
        precondition(configure(wad) != 0)
        precondition(configure(original)==0)
        print("PASS: ordered SIGIL overlay, all nine maps/materials/sprite indices, secret route, ending, inventory and E5 save restoration")
        // Independent overlays test precedence and save identity, including order.
        func patch(_ value:UInt8)->URL {
            let url=SaveStore.temporaryURL().appendingPathExtension("wad")
            var data=Data("PWAD".utf8)
            func le(_ n:Int)->Data { Data([UInt8(n&255),UInt8(n>>8&255),UInt8(n>>16&255),UInt8(n>>24&255)]) }
            data.append(le(1));data.append(le(13));data.append(value)
            data.append(le(12));data.append(le(1));data.append(Data("OVERRIDE".utf8))
            try! data.write(to:url);return url
        }
        let a=patch(1),b=patch(2);defer { try? FileManager.default.removeItem(at:a);try? FileManager.default.removeItem(at:b) }
        let ab=try WAD(url:base,addOns:[a,b]),ba=try WAD(url:base,addOns:[b,a])
        precondition(ab.lump("OVERRIDE")?.data==Data([2]) && ba.lump("OVERRIDE")?.data==Data([1]))
        let digestAB=try SaveStore.wadDigest(ab),digestBA=try SaveStore.wadDigest(ba);precondition(digestAB != digestBA)
        print("PASS: later PWAD wins and save identity distinguishes identical files in reversed load order")
        func writePatch(_ entries:[Lump])->URL {
            let url=SaveStore.temporaryURL().appendingPathExtension("wad")
            func le(_ n:Int)->Data { Data([UInt8(n&255),UInt8(n>>8&255),UInt8(n>>16&255),UInt8(n>>24&255)]) }
            var body=Data(),directory=Data()
            for entry in entries {
                directory.append(le(12+body.count));directory.append(le(entry.bytes.count))
                var name=Data(entry.name.utf8);name.append(Data(repeating:0,count:8-name.count));directory.append(name)
                body.append(entry.bytes.data)
            }
            var data=Data("PWAD".utf8);data.append(le(entries.count));data.append(le(12+body.count));data.append(body);data.append(directory)
            try! data.write(to:url);return url
        }
        let start=original.lumps.firstIndex{$0.name=="S_START"}!,flatStart=original.lumps.firstIndex{$0.name=="F_START"}!
        let sprite=original.lumps[(start+1)...].first{$0.bytes.count>0}!,flat=original.lumps[(flatStart+1)...].first{$0.bytes.count>0}!
        let override=writePatch([sprite,flat]);defer { try? FileManager.default.removeItem(at:override) }
        let replaced=try WAD(url:base,addOns:[override])
        precondition(replaced.lumps.filter{$0.name==sprite.name}.count==1 && replaced.lumps.filter{$0.name==flat.name}.count==1)
        let spriteIndex=replaced.lumps.firstIndex{$0.name==sprite.name}!
        precondition(spriteIndex>replaced.lumps.firstIndex{$0.name=="S_START"}! && spriteIndex<replaced.lumps.firstIndex{$0.name=="S_END"}!)
        let broken=writePatch([Lump(name:"E1M1",bytes:Bytes(data:Data())),Lump(name:"THINGS",bytes:Bytes(data:Data()))])
        defer { try? FileManager.default.removeItem(at:broken) }
        let incomplete=try WAD(url:base,addOns:[broken])
        do { _=try DoomMap(wad:incomplete,name:"E1M1");fatalError("Incomplete replacement map accepted") } catch is PortError {}
        print("PASS: exact-name sprite/flat replacements stay inside merged namespaces; partial maps cannot borrow another map's lumps")
    }
}
