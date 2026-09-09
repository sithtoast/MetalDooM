// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

@main struct MusicValidation {
    static func main() throws {
        let wad=try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        var count=0
        for lump in wad.lumps where lump.name.hasPrefix("D_") {
            let midi=try MUS.midi(lump.bytes.data)
            let repeated=try MUS.midi(lump.bytes.data); precondition(midi==repeated)
            let player=try AVMIDIPlayer(data:midi,soundBankURL:nil)
            precondition(player.duration > 0)
            count += 1
        }
        print("PASS: converted and loaded all \(count) WAD music tracks into Apple's MIDI player")
        let original=wad.lump("D_E1M1")!.data
        for damaged in [Data(),Data(original.prefix(15)),Data(original.dropLast())] {
            var rejected=false; do { _ = try MUS.midi(damaged) } catch { rejected=true }
            precondition(rejected)
        }
        // One note, channel 15 percussion, explicit velocity, pitch and controller.
        let events: [UInt8]=[0x9f,0xa3,100,14,0x2f,128,0x4f,3,80,0x8f,35,14,0x60]
        var mus=Data([77,85,83,26,UInt8(events.count),0,16,0,1,0,0,0,0,0,0,0]); mus.append(contentsOf:events)
        let midi=try MUS.midi(mus)
        precondition(midi.range(of:Data([0x99,35,100])) != nil)
        precondition(midi.range(of:Data([0xe9,0,64])) != nil)
        precondition(midi.range(of:Data([0xb9,7,80])) != nil)
        let passthrough=try MUS.midi(midi); precondition(passthrough==midi)
        let aliases=["E3M4","E3M2","E3M3","E1M5","E2M7","E2M4","E2M6","E2M5","E1M9"]
        for i in 1...9 { precondition(MusicPlayer.levelTrack("E4M\(i)")=="D_"+aliases[i-1]) }
        precondition(MusicPlayer.levelTrack("MAP01")=="D_RUNNIN" && MusicPlayer.levelTrack("MAP32")=="D_ULTIMA")
        let player=try MusicPlayer(wad:wad,map:"E1M1")
        func advance(_ seconds: Double) { RunLoop.current.run(until:Date().addingTimeInterval(seconds)) }
        player.update(active:true); advance(0.3)
        precondition(player.isPlaying && player.position>0)
        player.update(active:false); let paused=player.position; advance(0.2)
        precondition(!player.isPlaying && abs(player.position-paused)<0.02)
        player.update(active:true); advance(0.2); precondition(player.position>paused)
        player.enabled=false; advance(0.1); precondition(!player.isPlaying)
        player.enabled=true; player.update(active:true); precondition(player.isPlaying)
        try player.select("D_INTER"); precondition(player.trackName=="D_INTER" && player.isPlaying)
        try player.select("D_E1M2"); precondition(player.trackName=="D_E1M2" && player.isPlaying)
        let lock=NSLock(); var peak: Float=0
        player.engine.mainMixerNode.installTap(onBus:0,bufferSize:1024,format:nil) { buffer,_ in
            var value: Float=0
            if let channels=buffer.floatChannelData {
                for channel in 0..<Int(buffer.format.channelCount) {
                    for i in 0..<Int(buffer.frameLength) { value=max(value,abs(channels[channel][i])) }
                }
            }
            lock.lock(); peak=max(peak,value); lock.unlock()
        }
        player.volume=1; advance(0.5)
        lock.lock(); let audible=peak; lock.unlock(); precondition(audible>0.0001)
        player.volume=0; advance(0.2); lock.lock(); peak=0; lock.unlock(); advance(0.3)
        lock.lock(); let silent=peak; lock.unlock(); precondition(silent<0.000001)
        player.engine.mainMixerNode.removeTap(onBus:0); player.update(active:false)
        print("PASS: actual native synth mixer output is nonzero at full volume and silent at zero")
        // Tiny synthetic WAD tests natural end looping without waiting for a song.
        var file=Data("IWAD".utf8)
        func le(_ n: Int) -> Data { Data([UInt8(n&255),UInt8((n>>8)&255),UInt8((n>>16)&255),UInt8((n>>24)&255)]) }
        file.append(le(3)); file.append(le(12+mus.count)); file.append(mus)
        for (name,size) in [("D_E1M1",mus.count),("E1M1",0),("THINGS",0)] {
            file.append(le(12)); file.append(le(size)); var nameBytes=Data(name.utf8)
            nameBytes.append(Data(repeating:0,count:8-nameBytes.count)); file.append(nameBytes)
        }
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wad")
        try file.write(to:url); defer { try? FileManager.default.removeItem(at:url) }
        let short=try MusicPlayer(wad:WAD(url:url),map:"E1M1")
        short.update(active:true)
        for _ in 0..<100 {
            advance(0.1); short.update(active:true)
            if short.loopCount > 0 { break }
        }
        precondition(short.isPlaying && short.loopCount==1)
        short.update(active:false)
        print("PASS: malformed scores, percussion/pitch/controllers, E4/Doom II routing, native playback, pause/resume, mute, track changes and natural looping")
    }
}
