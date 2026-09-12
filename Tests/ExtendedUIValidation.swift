import AVFoundation

private final class MusicMeter {
    private let lock=NSLock();private var value:Float=0
    func add(_ buffer:AVAudioPCMBuffer) {
        var peak:Float=0
        if let data=buffer.floatChannelData { for c in 0..<Int(buffer.format.channelCount) { for i in 0..<Int(buffer.frameLength) { peak=max(peak,abs(data[c][i])) } } }
        lock.lock();value=max(value,peak);lock.unlock()
    }
    var peak:Float { lock.lock();defer{lock.unlock()};return value }
}
@main struct ExtendedUIValidation {
    static func require(_ value:Bool,_ message:String) throws { if !value { throw PortError(message) } }
    static func main() { do { try run() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) } }
    static func run() throws {
        let args=CommandLine.arguments,exe=URL(fileURLWithPath:args[1]),base=URL(fileURLWithPath:args[2]),root=URL(fileURLWithPath:args[3])
        let files=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        for map in 1...16 {
            let w=ExtendedWorker();defer{w.close()}
            let state=try w.start(executable:exe,paths:files,map:map,base:1)
            let resources=try WAD(previewResources:files,baseIndex:1,profile:1,identity:w.identity!)
            let text=String(decoding:resources.lump("UMAPINFO")!.data,as:UTF8.self)
            func capture(_ pattern:String,_ input:String) throws -> String? {
                let regex=try NSRegularExpression(pattern:pattern,options:[.caseInsensitive,.dotMatchesLineSeparators])
                guard let match=regex.firstMatch(in:input,range:NSRange(input.startIndex...,in:input)),let range=Range(match.range(at:1),in:input) else { return nil };return String(input[range])
            }
            let block=try capture(String(format:"\\bmap\\s+MAP%02d\\s*\\{([^}]*)\\}",map),text)
            let expected=try block.flatMap{try capture("\\bmusic\\s*=\\s*\"([^\"]+)\"",$0)} ?? MusicPlayer.levelTrack(String(format:"MAP%02d",map))
            try require(state.ui.music==expected.uppercased(),"UMAPINFO music selection mismatch")
            let midi=try MUS.midi(resources.lump(state.ui.music)!.data),player=try AVMIDIPlayer(data:midi,soundBankURL:nil)
            try require(player.duration>0 && state.ui.health==100 && state.ui.armor==0 && state.ui.readyAmmo==50 && state.ui.keys==0,"Bad initial HUD/music")
            let later=try w.tick(count:35)
            try require(later.ui.musicGeneration==state.ui.musicGeneration && later.ui.music==state.ui.music,"Unchanged level restarted music")
            print("PASS MAP\(map) authoritative track \(state.ui.music), MIDI \(Int(player.duration))s, initial HUD and stable music generation")
        }
        let fixture=exe.deletingLastPathComponent().appendingPathComponent("fixtures/ui-pickups.wad")
        let w=ExtendedWorker();defer{w.close()}
        let first=try w.start(executable:exe,paths:[base,fixture],map:1,base:0,profile:0)
        let resources=try WAD(previewResources:[base,fixture],baseIndex:0,profile:0,identity:w.identity!)
        let pickup=try w.tick(forward:25,count:3)
        try require(pickup.ui.armor==100 && pickup.ui.keys&3==3,"HUD missed armor/keys")
        let previous=UserDefaults.standard.string(forKey:"musicBackend")
        let player=try MusicPlayer(wad:resources,map:"MAP01",track:first.ui.music,backend:"apple")
        try require(player.trackName=="D_UITEST" && !player.isPlaying && player.backend=="apple","Preview music did not prepare paused")
        let meter=MusicMeter()
        player.engine.mainMixerNode.installTap(onBus:0,bufferSize:1024,format:nil){buffer,_ in meter.add(buffer)}
        func run(_ seconds:Double) { let end=Date().addingTimeInterval(seconds);while Date()<end { player.update(active:true);RunLoop.current.run(until:Date().addingTimeInterval(0.01)) } }
        player.looping=false;run(0.8)
        try require(!player.isPlaying && player.loopCount==0 && meter.peak>0.0001,"Nonlooping music/PCM failed")
        player.looping=true;run(0.2)
        try require(player.isPlaying && player.loopCount==1,"Looping music failed to restart")
        player.update(active:false);let paused=player.position
        RunLoop.current.run(until:Date().addingTimeInterval(0.1))
        try require(!player.isPlaying && abs(player.position-paused)<0.01,"Paused score advanced")
        run(0.1);try require(player.isPlaying && player.position>paused,"Music failed to resume")
        player.enabled=false;let muted=player.position;run(0.1)
        try require(!player.isPlaying && abs(player.position-muted)<0.01,"Disabled music advanced")
        player.enabled=true;run(0.1);player.update(active:false)
        player.engine.mainMixerNode.removeTap(onBus:0)
        try require(UserDefaults.standard.string(forKey:"musicBackend")==previous,"Preview changed classic backend preference")
        print("PASS native music PCM peak \(meter.peak), nonloop/loop, pause/resume, independent enable and unchanged classic preference; physical audibility unverified")
        let initial=try Data(contentsOf:exe.deletingLastPathComponent().appendingPathComponent("initial-view.mvw"))
        let raw=Data(initial.suffix(144))
        var cases=[Data(raw.dropLast()),raw+Data([0])]
        for (offset,value) in [(4,4),(8,-1),(16,-1),(20,9),(24,51),(28,64),(32,512),(36,-1),(52,-1),(76,2),(80,0),(84,4),(88,1),(92,4),(96,0),(100,1),(104,-1),(128,1),(132,2),(136,256),(140,256)] {
            var bad=raw;for i in 0..<4 { bad[offset+i]=UInt8(truncatingIfNeeded:UInt32(bitPattern:Int32(value))>>(i*8)) };cases.append(bad)
        }
        var bad=raw;bad[68]=0;cases.append(bad)
        for data in cases { var rejected=false;do{_=try ExtendedUI(data:data)}catch{rejected=true};try require(rejected,"Malformed HUD/music accepted") }
        var mismatch=initial;mismatch[mismatch.count-144+8]=1
        var rejected=false;do{_=try ExtendedView(data:mismatch)}catch{rejected=true};try require(rejected,"Mismatched HUD tic accepted")
        print("PASS \(cases.count) malformed MUI3 packets and HUD/view tic mismatch")
    }
}
