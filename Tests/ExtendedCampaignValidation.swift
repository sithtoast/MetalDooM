import AppKit
@main struct CampaignValidation {
    static func check(_ value:Bool,_ text:String) throws {if !value {throw PortError(text)}}
    static func main() {do {try run()} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}}
    static func run() throws {
        let exe=URL(fileURLWithPath:CommandLine.arguments[1]),root=URL(fileURLWithPath:CommandLine.arguments[2]),out=URL(fileURLWithPath:CommandLine.arguments[3])
        let normal=[2,3,4,5,6,7,0,9,10,11,12,13,14,0,3,11]
        let routes=normal.enumerated().map{($0.offset+1,false,$0.element)}+[(2,true,15),(10,true,16)]
        for (map,secret,next) in routes {
            let worker=ExtendedWorker();defer{worker.close()}
            let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}+[exe.deletingLastPathComponent().appendingPathComponent("fixtures/lifecycle-\(secret ? "secret":"normal").wad")]
            _=try worker.start(executable:exe,paths:paths,map:map,base:1)
            _=try worker.tick(count:3);let state=try worker.tick(buttons:2)
            let raw=try worker.campaign(),metadata=try ExtendedCampaign(data:raw,ui:state.ui)
            try check(metadata.map==map && metadata.nextMap==next && metadata.visited==[map],"Incorrect selected metadata/visited map")
            let again=try worker.campaign();try check(raw==again,"Repeated metadata changed")
            let wad=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            if map==14 {
                let original=try JSONSerialization.jsonObject(with:wad.lump(metadata.exitAnim)!.data) as! [String:Any]
                for mode in 0..<7 {
                    var bad=original,data=bad["data"] as! [String:Any]
                    var layers=data["layers"] as! [[String:Any]],anims=layers[1]["anims"] as! [[String:Any]],frames=anims[0]["frames"] as! [[String:Any]]
                    switch mode {
                    case 0:bad["version"]="2.0.0"
                    case 1:frames[0]["duration"] = -1
                    case 2:frames[0]["type"]=8
                    case 3:frames[0]["image"]="TOOLONGNAME"
                    case 4:anims[0]["conditions"]=[["condition":9,"param":0]]
                    case 5:anims[0]["x"]=Int.min
                    default:frames=[]
                    }
                    anims[0]["frames"]=frames;layers[1]["anims"]=anims;data["layers"]=layers;bad["data"]=data
                    var rejected=false
                    do { _=try ExtendedInterlevel(data:JSONSerialization.data(withJSONObject:bad)) } catch {rejected=true}
                    try check(rejected,"Accepted malformed interlevel \(mode)")
                }
                let castOriginal=try JSONSerialization.jsonObject(with:wad.lump(metadata.endFinale)!.data) as! [String:Any]
                for mode in 0..<6 {
                    var bad=castOriginal,data=bad["data"] as! [String:Any],cast=data["castrollcall"] as! [String:Any],actors=cast["castanims"] as! [[String:Any]],frames=actors[0]["aliveframes"] as! [[String:Any]]
                    switch mode {
                    case 0:data["type"]=1
                    case 1:data["donextmap"]=true
                    case 2:frames[0]["duration"] = -1
                    case 3:frames[0]["translation"]="TRANMAP"
                    case 4:actors[0]["alertsound"]=4096
                    default:frames=[]
                    }
                    actors[0]["aliveframes"]=frames;cast["castanims"]=actors;data["castrollcall"]=cast;bad["data"]=data
                    var rejected=false
                    do {_=try ExtendedFinale(data:JSONSerialization.data(withJSONObject:bad),metadata:metadata)} catch {rejected=true}
                    try check(rejected,"Accepted malformed finale \(mode)")
                }
                print("PASS 13 malformed interlevel/finale schema, frame, condition, sound and coordinate cases")
            }
            let sequence=try ExtendedCampaignSequence(metadata:metadata,ui:state.ui,wad:wad)
            let view=try ExtendedCampaignView(sequence:sequence,wad:wad);view.frame=NSRect(x:0,y:0,width:960,height:720)
            func screenshot(_ name:String) throws {
                let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:960,pixelsHigh:720,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:3840,bitsPerPixel:32)!
                NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:NSGraphicsContext(bitmapImageRep:rep)!.cgContext,flipped:true)
                let t=NSAffineTransform();t.translateX(by:0,yBy:720);t.scaleX(by:1,yBy:-1);t.concat();view.draw(view.bounds)
                NSGraphicsContext.restoreGraphicsState()
                try rep.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(name+".png"))
                let pixels=UnsafeBufferPointer(start:rep.bitmapData!,count:960*720*4)
                try check(Set(pixels).count>8,"Artwork readback is empty")
            }
            try check(sequence.exit.music=="D_DM2INT" && sequence.exit.animations(map:map,entering:false,visited:Set(metadata.visited)).isEmpty,"Exit conditions/music incorrect")
            if map==1 {try screenshot("statistics")}
            for _ in 0..<10000 {sequence.tick()}
            try check(sequence.statistics.stage==10 && sequence.stage == .statistics,"Statistics do not finish/wait")
            sequence.press()
            if next>0 {
                try check(sequence.stage == .entering,"Missing entering screen")
                let arrows=sequence.entry!.animations(map:next,entering:true,visited:Set(metadata.visited))
                try check(arrows.count==2 && arrows.contains{$0.frames.first?.image=="XWISPLAT"},"Visited/target markers incorrect")
                let arrow=arrows.first{$0.frames.count==2}!
                try check(arrow.frame(tic:0)==arrow.frames[0].image && arrow.frame(tic:22)==arrow.frames[0].image && arrow.frame(tic:23)=="TNT1A0" && arrow.frame(tic:33)=="TNT1A0" && arrow.frame(tic:34)==arrow.frames[0].image,"Arrow 23/11 tic timing incorrect")
                if secret {try screenshot("entering-secret-\(map)")}
                for _ in 0..<139 {sequence.tick()};try check(sequence.stage == .entering,"Entering ends early")
                sequence.tick();try check(sequence.stage == .complete,"Entering does not advance at 4 seconds")
                let fresh=try worker.advance(restart:false);try check(fresh.ui.map==next && fresh.tic==0,"Presentation affected engine route")
            } else {
                try check(sequence.stage == .story && sequence.music.0=="D_SHORES","Episode story/music missing")
                sequence.press();try check(sequence.visibleCharacters==metadata.story.count,"Story cannot be accelerated")
                try screenshot("story-\(map)");sequence.press()
                if map==7 {try check(sequence.stage == .art,"Episode1 credits missing");try screenshot("credits")}
                else {
                    try check(sequence.stage == .cast && sequence.music.0=="D_DEJAVU" && !sequence.music.1,"Custom cast music/loop wrong")
                    for index in 0..<7 {
                        try check(sequence.castIndex==index && !sequence.dead,"Cast order wrong")
                        try screenshot("cast-\(index)")
                        let durations=sequence.actor.aliveframes.map(\.tics)
                        for _ in 0..<durations.reduce(0,+) {sequence.tick()}
                        try check(sequence.frameIndex==0 && sequence.castIndex==index,"Alive cast doesn't loop")
                        sequence.press();try check(sequence.dead,"Fire didn't trigger death")
                        let deathTics=sequence.actor.deathframes.map(\.tics).reduce(0,+)
                        for _ in 0..<deathTics {sequence.tick()}
                    }
                    try check(sequence.castIndex==0 && !sequence.dead,"Cast does not restart after hero")
                }
            }
            // Untrusted boundary data must remain tied to the last copied UI.
            var json=try JSONSerialization.jsonObject(with:raw) as! [String:Any]
            for (key,value) in [("version",2),("map",99),("tic",state.tic+1),("nextMap",99),("parTics",-1)] {
                var bad=json;bad[key]=value;var rejected=false
                do{_=try ExtendedCampaign(data:JSONSerialization.data(withJSONObject:bad),ui:state.ui)}catch{rejected=true}
                try check(rejected,"Accepted malformed campaign \(key)")
            }
            json["visited"]=[map,map];var rejected=false
            do{_=try ExtendedCampaign(data:JSONSerialization.data(withJSONObject:json),ui:state.ui)}catch{rejected=true}
            try check(rejected,"Accepted duplicate visited map")
            print("PASS MAP\(map) \(secret ? "secret":"normal"): copied metadata, decoded artwork, music, statistics, markers/story/cast and malformed bounds")
        }
    }
}
