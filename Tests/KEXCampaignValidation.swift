// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
@main struct KEXCampaignValidation {
    static func main() {
        do { try run() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) }
    }
    static func run() throws {
        let base=URL(fileURLWithPath:CommandLine.arguments[1]),addon=URL(fileURLWithPath:CommandLine.arguments[2])
        let wad=try WAD(url:base,addOns:[addon]),profile=wad.campaign!
        func check(_ ok:Bool,_ message:String) throws { if !ok { throw PortError(message+": "+String(cString:MD_LastError())) } }
        try check(MD_ConfigureCampaign(profile.id,profile.story) != 0,"profile configuration")
        let configured=wad.sourceURLs.map(\.path).joined(separator:"\n").withCString { paths in wad.engineOrder.withUnsafeBufferPointer { MD_ConfigureWADStack(paths,$0.baseAddress,Int32($0.count)) } }
        try check(configured != 0,"stack configuration")
        try check(wad.maps.count==(profile.id==2 ? 21:9),"campaign map filter")
        try check(!profile.story.isEmpty,"ending story metadata")
        let art=try Art(wad:wad),episode:Int32=profile.id==3 ? 6:1
        for name in wad.maps {
            let number=Int32(profile.id==3 ? String(name.suffix(1)):String(name.suffix(2)))!
            let data=try DoomMap(wad:wad,name:name),geometry=try Geometry(map:data,textureHeights:art.textureHeights())
            for material in Set(geometry.batches.map(\.material)) { try check(try art.image(material) != nil,"\(name) material \(material)") }
            try check(try art.image(MaterialKey(name:wad.skyName(for:name),flat:false)) != nil,"sky")
            try check(profile.value("music",map:name).flatMap(wad.lump) != nil,"music metadata")
            _=try MUS.midi(wad.lump(profile.value("music",map:name)!)!.data)
            try check(wad.mapTitle(name) != name,"map title")
            try check(MD_Load(base.path,episode,number) != 0,"\(name) engine load")
            let hud=MD_GetHUD()
            try check(hud.parSeconds==(profile.id==2 ? 0:hud.parSeconds) && (profile.id==2 || hud.parSeconds>0),"par")
            var things=[MD_Thing](repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,0,0)))
            things.withUnsafeMutableBufferPointer{_=MD_CopyThings($0.baseAddress,Int32($0.count),0,0)}
            for thing in things { _=try art.patch(lump:Int(thing.lump)) }
            let save=SaveStore.temporaryURL();defer{try? FileManager.default.removeItem(at:save)}
            try SaveStore.write(to:save,wad:wad,map:name,pitch:0)
            let saved=try SaveStore.read(from:save,wad:wad),native=SaveStore.temporaryURL();defer{try? FileManager.default.removeItem(at:native)}
            try saved.payload.write(to:native)
            try check(MD_ReadSave(native.path) != 0 && MD_GetProgress().map==number && MD_GetProgress().episode==episode,"save round trip")
            try check(MD_Cheat("idfa") != 0,"inventory")
            let inventory=MD_GetHUD().weapons
            MD_TestExit(0);try check(MD_Tick(0,0,0,0) != 0,"normal exit")
            if number==profile.endingMap {
                if profile.id==3 { try check(MD_GetProgress().phase==2,"SIGIL II finale") }
                else { try check(MD_BeginStory() != 0 && String(cString:MD_StoryText())==profile.story,"campaign story");try check(MD_StartCast() != 0,"cast ending") }
            } else {
                let next=number == (profile.id==2 ? 21:9) ? (profile.id==1 ? 5:profile.id==2 ? 19:4):number+1
                try check(MD_GetProgress().nextMap==next,"\(name) route")
                try check(MD_BeginStory()==0,"no inherited story")
                try check(MD_Continue() != 0 && MD_GetHUD().weapons==inventory,"inventory continuation")
            }
            print("PASS \(name): geometry, textures, sprites, metadata, save, progression")
        }
        // IDs from the pinned engine info.h: mancubus=8, spider=19, arachnotron=20.
        if profile.id==3 {
            try check(MD_Load(base.path,6,8) != 0,"SIGIL II boss map")
            var animated=[MD_Material](repeating:MD_Material(),count:Int(MD_CopyAnimatedMaterials(nil,0)))
            animated.withUnsafeMutableBufferPointer{_=MD_CopyAnimatedMaterials($0.baseAddress,Int32($0.count))}
            let flame=animated.first { var m=$0;return withUnsafePointer(to:&m.name) { $0.withMemoryRebound(to:CChar.self,capacity:9){String(cString:$0)=="FLMWAL01"} } }!
            let before=MD_TranslatedMaterial(flame.index,0)
            for _ in 0..<8 { try check(MD_Tick(0,0,0,0) != 0,"animation ticks") }
            try check(MD_TranslatedMaterial(flame.index,0) != before,"SIGIL II flame animation")
            MD_TestTarget(19,256)
            try check(MD_TestTargetHealth()==9000,"SIGIL II spider health patch")
            try check(MD_Cheat("iddqd") != 0,"god mode")
            _=MD_TestDamageType(19,100000,10000)
            for _ in 0..<200 { try check(MD_Tick(0,0,0,0) != 0,"boss death ticks") }
            try check(MD_GetProgress().phase==0,"SIGIL II must not exit on spider death")
        } else {
            for map:Int32 in profile.id==2 ? [7,19,20]:[7] {
                try check(MD_Load(base.path,1,map) != 0,"boss action map")
                try check(MD_Cheat("iddqd") != 0,"god mode")
                for (type,tag,direction):(Int32,Int32,Float) in [(8,666,-1),(20,667,1)] {
                    let sectors=(0..<MD_SectorCount()).filter{MD_TestSectorTag($0)==tag}
                    let before=sectors.map{MD_GetSector($0).floor}
                    // Kill through original death states, preserving the last-boss test.
                    let killed=MD_TestDamageType(type,100000,10000)
                    for _ in 0..<350 { try check(MD_Tick(0,0,0,0) != 0,"boss ticks") }
                    let moved=zip(sectors,before).contains{(MD_GetSector($0.0).floor-$0.1)*direction>0}
                    if map==7 { try check(!moved,"disabled MAP07 boss action") }
                    else if type==8 || map==20 { try check(killed>0 && (sectors.isEmpty || moved),"MAP\(map) tag \(tag) boss action") }
                }
            }
        }
        print("PASS: campaign boss actions and health")
        let source:Int32=profile.id==1 ? 4:profile.id==2 ? 18:3
        try check(MD_Load(base.path,episode,source) != 0,"secret source")
        MD_TestExit(1);try check(MD_Tick(0,0,0,0) != 0,"secret exit")
        try check(MD_GetProgress().nextMap==(profile.id==2 ? 21:9) && MD_Continue() != 0,"secret route")
        var rejected=false
        do { _=try WAD(url:base,addOns:[addon,addon]) } catch is PortError { rejected=true }
        try check(rejected,"duplicate campaign rejection")
        try check(MD_Load(base.path,1,32)==0,"base campaign maps must be excluded")
        let edited=SaveStore.temporaryURL().appendingPathExtension("wad");defer{try? FileManager.default.removeItem(at:edited)}
        var editedData=try Data(contentsOf:addon);editedData.append(0);try editedData.write(to:edited)
        rejected=false
        do { _=try WAD(url:base,addOns:[edited]) } catch is PortError { rejected=true }
        try check(rejected,"unvalidated campaign edition rejected")
        print("PASS: \(profile.title), all \(wad.maps.count) maps and secret route; no full playthrough claim")
    }
}
