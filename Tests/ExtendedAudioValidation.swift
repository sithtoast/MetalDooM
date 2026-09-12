import AVFoundation

private final class Meter {
    private let lock=NSLock();private var value:Float=0
    func add(_ buffer:AVAudioPCMBuffer) {
        var peak:Float=0
        if let data=buffer.floatChannelData { for c in 0..<Int(buffer.format.channelCount) { for i in 0..<Int(buffer.frameLength) { peak=max(peak,abs(data[c][i])) } } }
        lock.lock();value=max(value,peak);lock.unlock()
    }
    var peak:Float { lock.lock();defer{lock.unlock()};return value }
}
@main struct ExtendedAudioValidation {
    static func main() { do { try run() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) } }
    static func run() throws {
        let args=CommandLine.arguments,exe=URL(fileURLWithPath:args[1]),base=URL(fileURLWithPath:args[2]),root=URL(fileURLWithPath:args[3])
        let fixtures=exe.deletingLastPathComponent().appendingPathComponent("fixtures")
        let worker=ExtendedWorker();_=try worker.start(executable:exe,paths:[base,fixtures.appendingPathComponent("render-materials.wad")],map:1,base:0,profile:0)
        let classic=try WAD(previewResources:[base,fixtures.appendingPathComponent("render-materials.wad")],baseIndex:0,profile:0,identity:worker.identity!)
        _=try worker.tick(count:35);let firing=try worker.tick(buttons:1,count:35)
        let pistol=firing.audio.events.filter{$0.operation==1 && $0.name=="DSPISTOL"}
        guard pistol.count==3,pistol.map(\.tic)==[39,53,67] else { throw PortError("Pistol batch timing changed.") }
        worker.cancel()
        func measure(_ sound:SoundPlayer,rounds:Int=12) throws -> (Float,Double,Double) {
            let buffer=AVAudioPCMBuffer(pcmFormat:sound.engine.manualRenderingFormat,frameCapacity:4096)!
            var peak:Float=0,left=0.0,right=0.0
            for _ in 0..<rounds where try sound.engine.renderOffline(4096,to:buffer) == .success {
                for i in 0..<Int(buffer.frameLength) {
                    let l=buffer.floatChannelData![0][i],r=buffer.floatChannelData![1][i]
                    peak=max(peak,max(abs(l),abs(r)));left+=Double(l*l);right+=Double(r*r)
                }
            }
            return (peak,left,right)
        }
        let player=try ExtendedSoundPlayer(resources:classic,offline:true);try player.prepare(firing.audio);try player.sound.setActive(true)
        player.apply(pistol[0]);let pcm=try measure(player.sound)
        guard pcm.0>0.01,pcm.0<=1 else { throw PortError("Invalid native pistol PCM.") }
        for pan:Float in [-1,1] {
            player.sound.stopAll();player.apply(ExtendedSoundEvent(tic:0,channel:0,operation:1,name:"DSPISTOL",volume:1,pan:pan))
            let energy=try measure(player.sound)
            guard pan<0 ? energy.1>energy.2*10:energy.2>energy.1*10 else { throw PortError("Native stereo separation failed.") }
        }
        player.muted=true;_=try measure(player.sound,rounds:2);player.apply(pistol[0])
        guard try measure(player.sound).0<0.00001 else { throw PortError("Muted preview scheduled audio.") }
        player.muted=false
        player.apply(pistol[0]);player.apply(ExtendedSoundEvent(tic:0,channel:pistol[0].channel,operation:0,name:"",volume:0,pan:0))
        _=try measure(player.sound,rounds:2);guard try measure(player.sound).0<0.00001 else { throw PortError("Stopped sound still rendered.") }
        func words(_ values:[UInt32])->Data { Data(values.flatMap{v in (0..<4).map{UInt8(truncatingIfNeeded:v>>(8*$0))}}) }
        var pending=Data("MSA1".utf8);pending.append(words([1,1,1,0,0,1]));pending.append(Data("DSPISTOL".utf8));pending.append(words([127,0]))
        let before=player.sound.scheduledSounds;var completed=false
        try player.play(ExtendedAudio(data:pending)){completed=true};player.stop()
        RunLoop.current.run(until:Date().addingTimeInterval(0.05))
        guard !completed,player.sound.scheduledSounds==before,!player.sound.engine.isRunning else { throw PortError("Cancelled audio callback restarted playback.") }
        print("PASS cancelled playback suppresses pending starts/completion and pauses mixer")
        player.stop();print("PASS exact pistol tics 39/53/67, native PCM, stereo pan, mute and channel stop")
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        for (fixture,weapon,hold) in [("rust-incinerator",5,12),("rust-blade-full",6,85)] {
            let w=ExtendedWorker(),files=paths+[fixtures.appendingPathComponent(fixture+".wad")]
            _=try w.start(executable:exe,paths:files,map:1,base:1)
            let resources=try WAD(previewResources:files,baseIndex:1,profile:1,identity:w.identity!)
            var batches:[ExtendedAudio]=[]
            batches.append(try w.tick(forward:25,count:3).audio)
            batches.append(try w.tick(buttons:UInt8(4 | weapon<<3)).audio)
            batches.append(try w.tick(count:35).audio);batches.append(try w.tick(count:35).audio)
            for _ in 0..<hold { batches.append(try w.tick(buttons:1).audio) };batches.append(try w.tick(count:35).audio)
            let p=try ExtendedSoundPlayer(resources:resources,offline:true)
            for batch in batches { try p.prepare(batch) };try p.sound.setActive(true)
            var heard=Set<String>()
            for e in batches.flatMap(\.events) where e.operation==1 && heard.insert(e.name).inserted {
                p.sound.stopAll();p.apply(e);guard try measure(p.sound).0>0.0001 else { throw PortError("Silent Rust sample: \(e.name)") }
            }
            guard heard.count>=2 else { throw PortError("Missing pickup/firing sound events.") }
            print("PASS \(fixture) native PCM from actual events: \(heard.sorted().joined(separator:", "))")
            p.stop();w.cancel()
        }
        do {
            let w=ExtendedWorker();_=try w.start(executable:exe,paths:paths,map:16,base:1);_=try w.tick(count:4)
            let pressed=try w.tick(buttons:2),moving=try w.tick(count:35)
            let starts=(pressed.audio.events+moving.audio.events).filter{$0.operation==1}
            guard starts.contains(where:{$0.name=="DSSWTCHN"}),starts.count>=2 else { throw PortError("Missing switch/movement sounds.") }
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:w.identity!)
            let p=try ExtendedSoundPlayer(resources:resources,offline:true);try p.prepare(pressed.audio);try p.prepare(moving.audio);try p.sound.setActive(true)
            for e in starts { p.sound.stopAll();p.apply(e);guard try measure(p.sound).0>0.0001 else { throw PortError("Silent switch/mover sample.") } }
            p.stop();w.cancel();print("PASS MAP16 switch/movement native PCM: \(Set(starts.map(\.name)).sorted())")
        }
        // Exercise the actual device render path. This proves native output data,
        // not physical speaker audibility or the user's volume setting.
        let live=try ExtendedSoundPlayer(resources:classic),meter=Meter();try live.prepare(firing.audio)
        live.sound.engine.mainMixerNode.installTap(onBus:0,bufferSize:1024,format:nil){buffer,_ in meter.add(buffer)}
        try live.sound.setActive(true);live.apply(pistol[0]);RunLoop.current.run(until:Date().addingTimeInterval(0.75))
        guard live.sound.engine.isRunning,meter.peak>0.001 else { throw PortError("Native device output tap stayed silent.") }
        live.sound.engine.mainMixerNode.removeTap(onBus:0);live.stop()
        print("PASS native device output tap peak \(meter.peak); physical speaker audibility unverified")
    }
}
