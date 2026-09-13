// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

// Main-thread sequencer with Apple's DLS synth and an independent volume mixer.
final class MusicPlayer {
    private let wad: WAD
    private let backendOverride:String?
    private var selectedBackend:String { backendOverride ?? Self.preferredBackend }
    var looping=true { didSet { recorded?.numberOfLoops=looping ? -1:0; opl?.player.numberOfLoops=looping ? -1:0 } }
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
    private final class RecordedCompletion:NSObject,AVAudioPlayerDelegate {
        weak var current:AVAudioPlayer?
        var finished=false
        func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool) {if player === current {finished=true}}
    }
    private let recordedCompletion=RecordedCompletion()
    private var recorded:AVAudioPlayer?
    private(set) var resolvedTrackName=""
    var preferRecorded=false
    private var opl: OPLPlayer?
    private var sequencer: AVAudioSequencer?
    private(set) var trackName = ""
    private(set) var loopCount = 0
    private var active = false
    var enabled = true { didSet { if !enabled { pause() } } }
    var volume: Float { get { engine.mainMixerNode.outputVolume } set { engine.mainMixerNode.outputVolume=max(0,min(1,newValue));opl?.player.volume=engine.mainMixerNode.outputVolume;recorded?.volume=engine.mainMixerNode.outputVolume } }
    var position: Double { recorded?.currentTime ?? opl?.player.currentTime ?? sequencer?.currentPositionInSeconds ?? 0 }
    var duration: Double { recorded?.duration ?? opl?.player.duration ?? sequencer?.tracks.map(\.lengthInSeconds).max() ?? 0 }
    var isPlaying: Bool { recorded?.isPlaying ?? opl?.player.isPlaying ?? sequencer?.isPlaying ?? false }
    init(wad: WAD, map: String,track:String?=nil,backend:String?=nil,preferRecorded:Bool=false) throws {
        self.wad=wad;backendOverride=backend;self.preferRecorded=preferRecorded
        engine.attach(synth); engine.connect(synth,to:engine.mainMixerNode,format:nil)
        engine.mainMixerNode.outputVolume=0.7
        engine.prepare()
        try select(track ?? wad.campaign?.value("music",map:map) ?? Self.levelTrack(map))
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
        // WAD names are case-insensitive, including engine-selected Doom II tracks.
        let name=name.uppercased()
        guard let lump=wad.lump(name) else { throw PortError("Missing music: \(name).") }
        let alternate=preferRecorded ? Self.recordedTrack(name,wad:wad):nil
        if let alternate,let audio=wad.lump(alternate) {
            let wave=try Self.decodeVorbis(audio.data),next=try AVAudioPlayer(data:wave,fileTypeHint:AVFileType.wav.rawValue)
            pause();recordedCompletion.finished=false;recordedCompletion.current=next;next.delegate=recordedCompletion;recorded=next;opl=nil;sequencer=nil;backend="recorded";trackName=name;resolvedTrackName=alternate;loopCount=0;previousOPLPosition=0
            next.numberOfLoops=looping ? -1:0;next.volume=volume;next.prepareToPlay();update(active:active);return
        }
        let midi=try MUS.midi(lump.data)
        resolvedTrackName=name
        if selectedBackend == "opl" {
            let next=try OPLPlayer(wad:wad,midi:midi)
            pause();recorded=nil;sequencer=nil;opl=next;backend="opl";trackName=name;loopCount=0;previousOPLPosition=0
            next.player.numberOfLoops=looping ? -1:0
            next.player.volume=volume
            update(active:active);return
        }
        let next=AVAudioSequencer(audioEngine:engine)
        try next.load(from:midi,options:.smf_ChannelsToTracks)
        for track in next.tracks { track.destinationAudioUnit=synth }
        guard next.tracks.contains(where:{$0.lengthInSeconds>0}) else { throw PortError("Empty music: \(name).") }
        pause(); recorded=nil;opl=nil; backend="apple"; resetSynth(); sequencer=next; trackName=name; loopCount=0
        try engine.start()
        next.prepareToPlay()
        update(active:active)
    }
    static func recordedTrack(_ name:String,wad:WAD)->String? {
        let name=name.uppercased();guard name.hasPrefix("D_") else {return nil}
        let direct="H_"+name.dropFirst(2)
        if wad.lump(direct)?.data.prefix(4)==Data("OggS".utf8) {return direct}
        // Rerelease repeats several original tracks under map-specific aliases.
        // Match their effective MIDI content, respecting add-on overrides.
        guard let source=wad.lump(name)?.data else {return nil}
        for candidate in Set(wad.lumps.map(\.name)).sorted() where candidate.hasPrefix("H_") {
            if wad.lump("D_"+candidate.dropFirst(2))?.data==source,
               wad.lump(candidate)?.data.prefix(4)==Data("OggS".utf8) {return candidate}
        }
        return nil
    }
    static func decodeVorbis(_ data:Data)throws->Data {
        guard data.count<=64*1024*1024 else {throw PortError("Recorded music is too large")}
        var pcm:UnsafeMutablePointer<Int16>?,channels:Int32=0,rate:Int32=0
        let frames=data.withUnsafeBytes {MD_DecodeVorbis($0.bindMemory(to:UInt8.self).baseAddress,Int32(data.count),&pcm,&channels,&rate)}
        guard frames>0,let pcm else {throw PortError("Invalid or unsupported Ogg Vorbis music")}
        defer {MD_FreeVorbis(pcm)}
        let size=Int(frames)*Int(channels)*2
        var wave=Data("RIFF".utf8)
        func word(_ x:UInt32){var v=x.littleEndian;withUnsafeBytes(of:&v){wave.append(contentsOf:$0)}}
        func short(_ x:UInt16){var v=x.littleEndian;withUnsafeBytes(of:&v){wave.append(contentsOf:$0)}}
        word(UInt32(size+36));wave.append(Data("WAVEfmt ".utf8));word(16);short(1);short(UInt16(channels));word(UInt32(rate))
        word(UInt32(rate*channels*2));short(UInt16(channels*2));short(16);wave.append(Data("data".utf8));word(UInt32(size))
        wave.append(UnsafeBufferPointer(start:UnsafeRawPointer(pcm).assumingMemoryBound(to:UInt8.self),count:size));return wave
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
        recorded?.pause();opl?.player.pause();sequencer?.stop(); engine.pause()
    }
    func update(active: Bool) {
        self.active=active
        if backend != "recorded",backend != selectedBackend, !trackName.isEmpty {
            do { try select(trackName) } catch {
                if backendOverride == nil { UserDefaults.standard.set(backend,forKey:"musicBackend") }
                DispatchQueue.main.async { Self.onError?(error) }
            }
        }
        if let recorded {
            if looping && recorded.currentTime<previousOPLPosition {loopCount+=1};previousOPLPosition=recorded.currentTime
            if active && enabled && !recordedCompletion.finished {if !recorded.isPlaying {recorded.play()}} else {recorded.pause()}
            return
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
                if !looping { pause();return }
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
