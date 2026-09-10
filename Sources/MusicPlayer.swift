// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

// Main-thread sequencer with Apple's DLS synth and an independent volume mixer.
final class MusicPlayer {
    private let wad: WAD
    let engine=AVAudioEngine()
    private let synth=AVAudioUnitMIDIInstrument(audioComponentDescription:AudioComponentDescription(
        componentType:kAudioUnitType_MusicDevice,componentSubType:kAudioUnitSubType_DLSSynth,
        componentManufacturer:kAudioUnitManufacturer_Apple,componentFlags:0,componentFlagsMask:0))
    static var onError: ((Error) -> Void)?
    private var previousOPLPosition: Double = 0
    static var preferredBackend: String {
        UserDefaults.standard.string(forKey:"musicBackend") == "apple" ? "apple" : "opl"
    }
    private(set) var backend = ""
    private var opl: OPLPlayer?
    private var sequencer: AVAudioSequencer?
    private(set) var trackName = ""
    private(set) var loopCount = 0
    private var active = false
    var enabled = true { didSet { if !enabled { pause() } } }
    var volume: Float { get { engine.mainMixerNode.outputVolume } set { engine.mainMixerNode.outputVolume=max(0,min(1,newValue));opl?.player.volume=engine.mainMixerNode.outputVolume } }
    var position: Double { opl?.player.currentTime ?? sequencer?.currentPositionInSeconds ?? 0 }
    var duration: Double { opl?.player.duration ?? sequencer?.tracks.map(\.lengthInSeconds).max() ?? 0 }
    var isPlaying: Bool { opl?.player.isPlaying ?? sequencer?.isPlaying ?? false }
    init(wad: WAD, map: String) throws {
        self.wad=wad
        engine.attach(synth); engine.connect(synth,to:engine.mainMixerNode,format:nil)
        engine.mainMixerNode.outputVolume=0.7
        engine.prepare()
        try select(Self.levelTrack(map))
    }
    deinit { sequencer?.stop(); engine.stop() }
    static func levelTrack(_ map: String) -> String {
        if map.hasPrefix("MAP"), let number=Int(map.dropFirst(3)), (1...32).contains(number) {
            let tracks=["RUNNIN","STALKS","COUNTD","BETWEE","DOOM","THE_DA","SHAWN","DDTBLU","IN_CIT","DEAD", "STLKS2","THEDA2","DOOM2","DDTBL2","RUNNI2","DEAD2","STLKS3","ROMERO","SHAWN2","MESSAG","COUNT2","DDTBL3","AMPIE","THEDA3","ADRIAN","MESSG2","ROMER2","TENSE","SHAWN3","OPENIN","EVIL","ULTIMA"]
            return "D_"+tracks[number-1]
        }
        if map.hasPrefix("E4M"), let number=Int(map.suffix(1)), (1...9).contains(number) {
            return "D_"+["E3M4","E3M2","E3M3","E1M5","E2M7","E2M4","E2M6","E2M5","E1M9"][number-1]
        }
        return "D_"+map
    }
    static func endTrack(_ state: MD_Progress) -> String {
        if state.phase == 2 { return state.commercial != 0 ? "D_READ_M" : "D_VICTOR" }
        return state.commercial != 0 ? "D_DM2INT" : "D_INTER"
    }
    func select(_ name: String) throws {
        guard let lump=wad.lump(name) else { throw PortError("Missing music: \(name).") }
        let midi=try MUS.midi(lump.data)
        if Self.preferredBackend == "opl" {
            let next=try OPLPlayer(wad:wad,midi:midi)
            pause();sequencer=nil;opl=next;backend="opl";trackName=name;loopCount=0;previousOPLPosition=0
            next.player.volume=volume
            update(active:active);return
        }
        let next=AVAudioSequencer(audioEngine:engine)
        try next.load(from:midi,options:.smf_ChannelsToTracks)
        for track in next.tracks { track.destinationAudioUnit=synth }
        guard next.tracks.contains(where:{$0.lengthInSeconds>0}) else { throw PortError("Empty music: \(name).") }
        pause(); opl=nil; backend="apple"; resetSynth(); sequencer=next; trackName=name; loopCount=0
        try engine.start()
        next.prepareToPlay()
        update(active:active)
    }
    // MUS scores need not initialize every channel. Never inherit a previous
    // song's bend, sustain or expression (including on loops).
    private func resetSynth() {
        for channel in UInt8(0)...UInt8(15) {
            synth.sendController(120, withValue:0, onChannel:channel)
            synth.sendController(121, withValue:0, onChannel:channel)
            synth.sendPitchBend(8192, onChannel:channel)
        }
    }
    private func pause() {
        opl?.player.pause();sequencer?.stop(); engine.pause()
    }
    func update(active: Bool) {
        self.active=active
        if backend != Self.preferredBackend, !trackName.isEmpty {
            do { try select(trackName) } catch {
                UserDefaults.standard.set(backend,forKey:"musicBackend")
                DispatchQueue.main.async { Self.onError?(error) }
            }
        }
        if let opl {
            if opl.player.currentTime < previousOPLPosition { loopCount += 1 }
            previousOPLPosition=opl.player.currentTime
            if active && enabled { if !opl.player.isPlaying { opl.player.play() } }
            else { opl.player.pause() }
            return
        }
        guard active && enabled else { if engine.isRunning { pause() }; return }
        guard let sequencer else { return }
        do {
            if !engine.isRunning { try engine.start() }
            if position >= duration {
                sequencer.stop(); resetSynth(); sequencer.currentPositionInSeconds=0; loopCount += 1
            }
            if !sequencer.isPlaying { try sequencer.start() }
        } catch {
            pause()
            // Device failures must not terminate the gameplay simulation.
            fputs("Music playback: \(error)\n",stderr)
        }
    }
}
