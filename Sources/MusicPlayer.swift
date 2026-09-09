// SPDX-License-Identifier: GPL-2.0-or-later
import AVFoundation

// Main-thread owner. AVMIDIPlayer uses macOS's built-in General MIDI sound bank.
final class MusicPlayer {
    private let wad: WAD
    private var player: AVMIDIPlayer?
    private(set) var trackName = ""
    private(set) var loopCount = 0
    private var active = false
    private var started = false
    private var pausedPosition = 0.0
    var enabled = true { didSet { if !enabled { pause() } } }
    var position: Double { player?.currentPosition ?? 0 }
    var duration: Double { player?.duration ?? 0 }
    var isPlaying: Bool { player?.isPlaying ?? false }
    init(wad: WAD, map: String) throws {
        self.wad=wad
        try select(Self.levelTrack(map))
    }
    deinit { player?.stop() }
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
        let next=try AVMIDIPlayer(data:MUS.midi(lump.data),soundBankURL:nil)
        next.prepareToPlay()
        guard next.duration > 0 else { throw PortError("Empty music: \(name).") }
        player?.stop(); player=next; trackName=name; pausedPosition=0; loopCount=0; started=false
        update(active:active)
    }
    private func pause() {
        guard let player, player.isPlaying else { return }
        pausedPosition=player.currentPosition; player.stop(); started=false
    }
    func update(active: Bool) {
        self.active=active
        guard active && enabled else { pause(); return }
        guard let player else { return }
        // The native player can keep running beyond the final MIDI event, so
        // loop at the score duration rather than waiting for isPlaying to clear.
        if player.currentPosition >= player.duration || (started && !player.isPlaying) {
            player.stop(); pausedPosition=0; started=false; loopCount += 1
        }
        guard !player.isPlaying else { return }
        player.currentPosition=pausedPosition
        player.play(nil); started=true
    }
}
