import AVFoundation

/// Main-queue playback of a completed manual simulation batch. The UI waits for
/// the batch's event timeline before accepting another command. PCM tails finish
/// naturally while the simulation is stopped; no timers advance gameplay.
final class ExtendedSoundPlayer {
    let sound:SoundPlayer
    var muted=false { didSet { if muted { sound.stopAll() } } }
    private let resources:WAD
    private var generation=0, lastTic=0
    private var indices:[String:Int]=[:]
    init(resources:WAD,offline:Bool=false) throws {
        self.resources=resources
        sound=try SoundPlayer(wad:resources,offline:offline,onlyLumps:[],voiceCount:32)
    }
    func prepare(_ audio:ExtendedAudio) throws {
        for e in audio.events where e.operation==1 && indices[e.name]==nil {
            guard let index=resources.lumps.lastIndex(where:{$0.name==e.name}) else { throw PortError("Missing preview sound: \(e.name)") }
            indices[e.name]=index
        }
        try sound.prepare(lumps:Set(indices.values),wad:resources)
    }
    /// Shared event application also used by the native offline mixer check.
    func apply(_ event:ExtendedSoundEvent) {
        guard !muted else { return }
        switch event.operation {
        case 0: sound.play(MD_SoundEvent(channel:Int32(event.channel),lump:-1,volume:0,pan:0))
        case 1: sound.play(MD_SoundEvent(channel:Int32(event.channel),lump:Int32(indices[event.name]!),volume:event.volume,pan:event.pan))
        default: sound.update(channel:event.channel,volume:event.volume,pan:event.pan)
        }
    }
    func play(_ audio:ExtendedAudio,completion:@escaping ()->Void) throws {
        guard audio.tic>=lastTic,audio.events.allSatisfy({$0.tic>=lastTic}) else { throw PortError("Stale preview sound events.") }
        try prepare(audio)
        let start=lastTic;lastTic=audio.tic
        guard !audio.events.isEmpty else { completion();return }
        try sound.setActive(true)
        let token=generation,now=DispatchTime.now()
        for e in audio.events {
            DispatchQueue.main.asyncAfter(deadline:now+Double(e.tic-start)/35) { [weak self] in
                guard let self,self.generation==token else { return };self.apply(e)
            }
        }
        DispatchQueue.main.asyncAfter(deadline:now+Double(audio.tic-start)/35) { [weak self] in
            guard let self,self.generation==token else { return };completion()
        }
    }
    func stop() { generation+=1;sound.stopAll();try? sound.setActive(false) }
}
