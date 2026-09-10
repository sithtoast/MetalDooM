// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import AVFoundation
@main struct FinalDoomValidation {
    static func main() throws {
        let wad=try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        let wrong=try WAD(url:URL(fileURLWithPath:CommandLine.arguments[2]))
        let profile=Int(CommandLine.arguments[3])!
        precondition(wad.finalDoom==profile && wad.maps.count==32 && wad.gameName.hasPrefix("Final Doom:"))
        precondition(wad.mapTitle("MAP01")=="MAP01: \(profile==1 ? "System Control":"Congo")")
        precondition(wad.mapTitle(profile==1 ? "MAP25":"MAP06").contains("Baron's"))
        if profile==2 { precondition(wad.mapTitle("MAP19")=="MAP19: NME") }
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:temporary,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:temporary) }
        let renamed=temporary.appendingPathComponent("renamed.wad")
        try wad.sourceData[0].write(to:renamed)
        let renamedWAD=try WAD(url:renamed);precondition(renamedWAD.finalDoom==profile)
        let art=try Art(wad:wad);MD_TestMonsters(1)
        for map in 1...32 {
            let name=String(format:"MAP%02d",map)
            precondition(wad.mapTitle(name) != name)
            let data=try DoomMap(wad:wad,name:name), geometry=try Geometry(map:data,textureHeights:art.textureHeights())
            for material in Set(geometry.batches.map(\.material)) { let image=try art.image(material);precondition(image != nil) }
            let sky=wad.skyName(for:name);precondition(sky==(map<12 ? "SKY1":map<21 ? "SKY2":"SKY3"))
            let skyImage=try art.image(MaterialKey(name:sky,flat:false));precondition(skyImage != nil)
            let music=wad.lump(MusicPlayer.levelTrack(name))!;let sequence=AVAudioSequencer()
            try sequence.load(from:MUS.midi(music.data),options:.smf_ChannelsToTracks)
            precondition(!sequence.tracks.isEmpty)
            precondition(MD_Load(wad.url.path,1,Int32(map)) != 0)
            for _ in 0..<5 { precondition(MD_Tick(0,0,0,0) != 0) }
            var things=[MD_Thing](repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,0,0)))
            things.withUnsafeMutableBufferPointer { _=MD_CopyThings($0.baseAddress,Int32($0.count),0,0) }
            for thing in things { _ = try art.patch(lump:Int(thing.lump)) }
            precondition(MD_Cheat("idfa") != 0)
            let player=MD_GetPlayer(),hud=MD_GetHUD(),saveURL=temporary.appendingPathComponent("save.mdsave")
            try SaveStore.write(to:saveURL,wad:wad,map:name,pitch:0.125)
            let save=try SaveStore.read(from:saveURL,wad:renamedWAD)
            var rejected=false;do { _=try SaveStore.read(from:saveURL,wad:wrong) } catch { rejected=true };precondition(rejected)
            precondition(MD_Load(wad.url.path,1,Int32(map==32 ? 1:map+1)) != 0)
            let raw=temporary.appendingPathComponent("payload");try save.payload.write(to:raw)
            precondition(MD_ReadSave(raw.path) != 0)
            let restored=MD_GetPlayer();precondition(MD_GetProgress().map==map && restored.x==player.x && restored.y==player.y && restored.tick==player.tick && MD_GetHUD().weapons==hud.weapons && MD_GetHUD().shells==hud.shells)
        }
        for name in ["TITLEPIC","CREDIT","BOSSBACK"] { let image=try art.patch(named:name);precondition(image != nil) }
        for name in ["D_DM2TTL","D_DM2INT","D_READ_M","D_EVIL"] {
            let seq=AVAudioSequencer();try seq.load(from:MUS.midi(wad.lump(name)!.data),options:.smf_ChannelsToTracks)
        }
        print("PASS: all 32 Final Doom map geometries/materials, sky ranges, music, sprites, names, cross-map saves and wrong-campaign rejection; renamed IWAD identity")
    }
}
