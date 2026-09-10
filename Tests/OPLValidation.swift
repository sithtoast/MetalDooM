import AVFoundation
@main struct OPLValidation {
 static func main() throws {
    let defaults=UserDefaults.standard, previous=UserDefaults.standard.object(forKey:"musicBackend")
    defer { if let previous { defaults.set(previous,forKey:"musicBackend") } else { defaults.removeObject(forKey:"musicBackend") } }
    defaults.set("opl",forKey:"musicBackend")
    let wad=try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
    let title=wad.maps.contains("MAP01") ? "D_DM2TTL" : "D_INTRO"
    let player=try MusicPlayer(wad:wad,map:wad.maps.contains("MAP01") ? "MAP01" : "E1M1")
    try player.select(title)
    precondition(player.backend=="opl" && player.duration>3)
    player.update(active:true);RunLoop.current.run(until:Date().addingTimeInterval(0.3))
    precondition(player.isPlaying && player.position>0)
    player.update(active:false);let position=player.position
    RunLoop.current.run(until:Date().addingTimeInterval(0.15));precondition(!player.isPlaying && abs(player.position-position)<0.02)
    player.volume=0;player.update(active:true);precondition(player.isPlaying && player.volume==0)
    player.enabled=false;precondition(!player.isPlaying)
    player.enabled=true;player.volume=0.7;player.update(active:true)
    defaults.set("apple",forKey:"musicBackend");player.update(active:true);precondition(player.backend=="apple" && player.isPlaying && player.trackName==title)
    defaults.set("opl",forKey:"musicBackend");player.update(active:true);precondition(player.backend=="opl" && player.isPlaying && player.trackName==title)
    player.update(active:false)
    // Identical input must produce identical PCM regardless of previously rendered song.
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:dir) }
    let midi=dir.appendingPathComponent("title.mid"), a=dir.appendingPathComponent("a.wav"), b=dir.appendingPathComponent("b.wav")
    try MUS.midi(wad.lump(title)!.data).write(to:midi)
    let bank=wad.lump("GENMIDI")!.data
    func render(_ output:URL)->Int32 { bank.withUnsafeBytes { MD_RenderOPL($0.baseAddress,Int32($0.count),midi.path,output.path) } }
    precondition(render(a)==1 && render(b)==1)
    let data=try Data(contentsOf:a), repeated=try Data(contentsOf:b);precondition(data==repeated)
    let file=try AVAudioFile(forReading:a), buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(min(file.length,44100)))!
    try file.read(into:buffer);let samples=UnsafeBufferPointer(start:buffer.floatChannelData![0],count:Int(buffer.frameLength))
    precondition(samples.map{abs($0)}.max()!>0.001)
    let shortMIDI=Data([77,84,104,100,0,0,0,6,0,0,0,1,0,70,77,84,114,107,0,0,0,15,0,0xc0,0,0,0x90,69,100,14,0x80,69,0,0,255,47,0])
    let looping=try OPLPlayer(wad:wad,midi:shortMIDI)
    looping.player.volume=0;looping.player.play();RunLoop.current.run(until:Date().addingTimeInterval(0.35))
    precondition(looping.player.isPlaying && looping.player.currentTime<looping.player.duration)
    looping.player.stop()
    precondition(MD_RenderOPL(nil,0,midi.path,b.path)==0)
    if CommandLine.arguments.contains("--all") {
        var count=0
        for lump in wad.lumps where lump.name.hasPrefix("D_") {
            let track=try OPLPlayer(wad:wad,midi:MUS.midi(lump.bytes.data))
            precondition(track.player.duration>0);count += 1
        }
        print("PASS: all \(count) WAD music tracks render as OPL PCM")
    }
    print("PASS: OPL title PCM, deterministic repeat, invalid bank, pause/resume, mute, and Apple/OPL track-preserving switch; duration \(player.duration)s")
 }
}
