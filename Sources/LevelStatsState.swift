// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

struct SecretNotice {
    private var count: Int32 = 0
    private var until: Int32 = 0
    mutating func reset(_ hud: MD_HUD) { count=hud.secrets; until=0 }
    mutating func update(_ hud: MD_HUD) {
        if hud.secrets > count { until=hud.levelTics+105 }
        count=hud.secrets
    }
    func visible(at tic: Int32) -> Bool { tic < until }
}

enum LevelStatsText {
    static func time(_ tics: Int32) -> String {
        let t=max(0,Int64(tics))
        return String(format:"%lld:%02lld",t/2100,(t/35)%60)
    }
    static func par(_ seconds: Int32) -> String {
        seconds < 0 ? "N/A" : String(format:"%d:%02d",seconds/60,seconds%60)
    }
}

