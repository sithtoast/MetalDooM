// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

@main struct AudioValidation {
    static func main() throws {
        let wad = try WAD(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        let sound = try SoundPlayer(wad:wad,offline:true)
        guard MD_Load(wad.url.path,1,1) != 0 else { throw PortError(String(cString:MD_LastError())) }
        try sound.setActive(true); sound.drain()
        for _ in 0..<25 { precondition(MD_CombatTick(0,0,0,0,0,-1) != 0) }; sound.drain()
        for _ in 0..<10 { precondition(MD_CombatTick(0,0,0,0,1,-1) != 0) }; sound.drain()
        precondition(sound.scheduledSounds > 0,"No sound was scheduled")
        let buffer = AVAudioPCMBuffer(pcmFormat:sound.engine.manualRenderingFormat,frameCapacity:4096)!
        var peak: Float = 0
        for _ in 0..<12 {
            let status = try sound.engine.renderOffline(4096,to:buffer)
            if status == .success {
                for channel in 0..<Int(buffer.format.channelCount) {
                    for i in 0..<Int(buffer.frameLength) { peak = max(peak,abs(buffer.floatChannelData![channel][i])) }
                }
            }
        }
        precondition(peak > 0.01 && peak <= 1,"Invalid rendered peak: \(peak)")
        try sound.setActive(false); precondition(!sound.engine.isRunning)
        try sound.setActive(true); precondition(sound.engine.isRunning)
        let mono = AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
        let invalid = Bytes(data:Data([3,0,0,0,64,0,0,0]))
        var rejected = false
        do { _ = try SoundPlayer.decode(invalid,format:mono) } catch { rejected = true }
        precondition(rejected)
        print("PASS: native AVAudioEngine rendered original pistol audio (peak \(peak)), pause/resume, malformed DMX rejection")
    }
}
