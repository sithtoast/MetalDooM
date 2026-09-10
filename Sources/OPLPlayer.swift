// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

// Render the upstream global OPL sequencer on the main thread, then play its
// PCM through Core Audio. Title and level players never share mutable chip state.
final class OPLPlayer {
    let player: AVAudioPlayer
    private let directory: URL
    init(wad: WAD, midi: Data) throws {
        guard let bank=wad.lump("GENMIDI") else { throw PortError("Classic OPL requires the WAD's GENMIDI instrument bank.") }
        directory=FileManager.default.temporaryDirectory.appendingPathComponent("MetalDooM-OPL-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        do {
            let input=directory.appendingPathComponent("score.mid"), output=directory.appendingPathComponent("music.wav")
            try midi.write(to:input)
            let ok=bank.data.withUnsafeBytes { MD_RenderOPL($0.baseAddress,Int32($0.count),input.path,output.path) }
            guard ok != 0 else { throw PortError("Classic OPL could not render this score (invalid data or longer than ten minutes). Try Apple MIDI.") }
            player=try AVAudioPlayer(contentsOf:output);player.numberOfLoops = -1;player.prepareToPlay()
        } catch { try? FileManager.default.removeItem(at:directory);throw error }
    }
    deinit { player.stop();try? FileManager.default.removeItem(at:directory) }
}
