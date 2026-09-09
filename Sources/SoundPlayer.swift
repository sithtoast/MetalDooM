// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

// Original DMX unsigned PCM converted once to a common native mixer format.
final class SoundPlayer {
    let engine = AVAudioEngine()
    private let voices = (0..<16).map { _ in AVAudioPlayerNode() }
    private var buffers: [Int:AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
    var volume: Float { get { engine.mainMixerNode.outputVolume } set { engine.mainMixerNode.outputVolume=max(0,min(1,newValue)) } }
    private(set) var scheduledSounds = 0
    init(wad: WAD, offline: Bool = false, onlyLumps: Set<String>? = nil) throws {
        for (index,lump) in wad.lumps.enumerated() where lump.name.hasPrefix("DS") && (onlyLumps == nil || onlyLumps!.contains(lump.name)) {
            if let buffer = try Self.decode(lump.bytes,format:format) { buffers[index] = buffer }
        }
        for voice in voices { engine.attach(voice); engine.connect(voice,to:engine.mainMixerNode,format:format) }
        engine.mainMixerNode.outputVolume = 0.7
        if offline {
            try engine.enableManualRenderingMode(.offline,format:AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!,maximumFrameCount:4096)
        }
        engine.prepare()
    }
    deinit { engine.stop() }
    static func decode(_ bytes: Bytes, format: AVAudioFormat) throws -> AVAudioPCMBuffer? {
        guard bytes.count >= 8 else { return nil }
        guard try bytes.u16(0) == 3 else { return nil } // PC speaker lumps are unsupported.
        let rate = try bytes.u16(2), count = try bytes.i32(4)
        guard rate > 0, count > 48, count <= bytes.count-8 else { throw PortError("Invalid DMX sound sample.") }
        // DMX ignores the 16 padding samples at either end.
        let samples = count-32, ratio = Double(rate)/format.sampleRate
        let frames = Int(Double(samples)/ratio)
        guard frames > 0, frames <= 10_000_000,
              let buffer = AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(frames)),
              let output = buffer.floatChannelData?[0] else { throw PortError("Cannot allocate sound buffer.") }
        buffer.frameLength = AVAudioFrameCount(frames)
        for i in 0..<frames {
            let position = Double(i)*ratio, a = min(Int(position),samples-1), b = min(a+1,samples-1)
            let mix = Float(position-Double(a))
            let first = Float(bytes.data[24+a])-128, second = Float(bytes.data[24+b])-128
            output[i] = (first+(second-first)*mix)/128
        }
        return buffer
    }
    func setActive(_ active: Bool) throws {
        if active { if !engine.isRunning { try engine.start() } }
        else if engine.isRunning { engine.pause() }
    }
    func drain() {
        var event = MD_SoundEvent()
        while MD_PopSound(&event) != 0 { play(event) }
    }
    func play(_ event: MD_SoundEvent) {
        guard voices.indices.contains(Int(event.channel)) else { return }
        let voice = voices[Int(event.channel)]
        voice.stop()
        guard event.lump >= 0, let buffer = buffers[Int(event.lump)] else { return }
        voice.volume = event.volume; voice.pan = event.pan
        voice.scheduleBuffer(buffer,at:nil,options:[]); voice.play(); scheduledSounds += 1
    }
}
