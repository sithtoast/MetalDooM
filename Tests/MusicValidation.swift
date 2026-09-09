// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

@main struct MusicValidation {
    static func main() throws {
        setbuf(stdout,nil)
        let wad=try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        let commercial=wad.maps.contains("MAP01")
        let first=commercial ? "D_RUNNIN":"D_E1M1", second=commercial ? "D_STALKS":"D_E1M2"
        let inter=commercial ? "D_DM2INT":"D_INTER"
        var count=0
        for lump in wad.lumps where lump.name.hasPrefix("D_") {
            let midi=try MUS.midi(lump.bytes.data)
            let repeated=try MUS.midi(lump.bytes.data); precondition(midi==repeated)
            let player=try AVMIDIPlayer(data:midi,soundBankURL:nil)
            precondition(player.duration > 0)
            count += 1
        }
        print("PASS: converted and loaded all \(count) WAD music tracks into Apple's MIDI player")
        let original=wad.lump(first)!.data
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
        let player=try MusicPlayer(wad:wad,map:commercial ? "MAP01":"E1M1")
        func advance(_ seconds: Double) { RunLoop.current.run(until:Date().addingTimeInterval(seconds)) }
        player.update(active:true); advance(0.3)
        precondition(player.isPlaying && player.position>0)
        player.update(active:false); let paused=player.position; advance(0.2)
        precondition(!player.isPlaying && abs(player.position-paused)<0.02)
        player.update(active:true); advance(0.2); precondition(player.position>paused)
        player.enabled=false; advance(0.1); precondition(!player.isPlaying)
        player.enabled=true; player.update(active:true); precondition(player.isPlaying)
        try player.select(inter); precondition(player.trackName==inter && player.isPlaying)
        try player.select(second); precondition(player.trackName==second && player.isPlaying)
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
        let pitchPlayer=player
        pitchPlayer.volume=1
        let instrument=pitchPlayer.engine.attachedNodes.compactMap{$0 as? AVAudioUnitMIDIInstrument}.first!
        var samples=[Float](); var sampleRate=44100.0
        pitchPlayer.engine.mainMixerNode.installTap(onBus:0,bufferSize:1024,format:nil) { buffer,_ in
            guard let channel=buffer.floatChannelData?[0] else { return }
            lock.lock(); sampleRate=buffer.format.sampleRate
            samples.append(contentsOf:UnsafeBufferPointer(start:channel,count:Int(buffer.frameLength)))
            lock.unlock()
        }
        func frequency() throws -> Double {
            try pitchPlayer.engine.start()
            instrument.sendController(7,withValue:100,onChannel:0)
            instrument.sendController(11,withValue:127,onChannel:0)
            instrument.sendProgramChange(73,onChannel:0)
            instrument.startNote(69,withVelocity:100,onChannel:0); advance(0.4)
            lock.lock(); samples.removeAll(); lock.unlock(); advance(0.4)
            lock.lock(); let captured=samples, rate=sampleRate; lock.unlock()
            precondition(captured.count>4096)
            // Autocorrelation around the expected A4 period avoids counting harmonics.
            precondition(captured.map{abs($0)}.max()!>0.0001)
            let low=Int(rate/550), high=Int(rate/380)
            var best=low, correlation = -Double.infinity
            for lag in low...high {
                var product=0.0, power=0.0
                for i in 0..<(captured.count-high) {
                    product += Double(captured[i]*captured[i+lag])
                    power += Double(captured[i+lag]*captured[i+lag])
                }
                let value=product/sqrt(max(power,1e-20))
                if value>correlation { correlation=value; best=lag }
            }
            instrument.stopNote(69,onChannel:0)
            return rate/Double(best)
        }
        instrument.sendPitchBend(8192,onChannel:0)
        let baseline=try frequency()
        instrument.sendPitchBend(16320,onChannel:0)
        let raised=try frequency()
        try pitchPlayer.select(second); pitchPlayer.update(active:false)
        let restored=try frequency()
        precondition(abs(baseline-440)<6 && raised>baseline*1.08 && abs(restored-baseline)<5,
                     "MIDI pitch reset: baseline \(baseline), bent \(raised), restored \(restored)")
        pitchPlayer.engine.mainMixerNode.removeTap(onBus:0); pitchPlayer.update(active:false)
        print("PASS: measured A4 pitch before/after bent track: \(baseline) / \(raised) / \(restored) Hz")
        print("PASS: malformed scores, percussion/pitch/controllers, E4/Doom II routing, native playback, pause/resume, mute, track changes and natural looping")
    }
}
