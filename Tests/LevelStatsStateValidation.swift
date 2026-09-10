// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
@main struct Validation {
    static func main() {
        precondition(LevelStatsText.time(0)=="0:00")
        precondition(LevelStatsText.time(34)=="0:00")
        precondition(LevelStatsText.time(35)=="0:01")
        precondition(LevelStatsText.time(2100)=="1:00")
        precondition(LevelStatsText.time(126000)=="60:00")
        precondition(LevelStatsText.par(-1)=="N/A" && LevelStatsText.par(75)=="1:15")
        var hud=MD_HUD(), notice=SecretNotice()
        hud.secrets=2;hud.levelTics=700;notice.reset(hud)
        precondition(!notice.visible(at:hud.levelTics)) // restored counts are not new discoveries
        hud.secrets=3;notice.update(hud);precondition(notice.visible(at:700))
        notice.update(hud);precondition(notice.visible(at:804) && !notice.visible(at:805))
        hud.levelTics=750;hud.secrets=4;notice.update(hud)
        precondition(notice.visible(at:854) && !notice.visible(at:855))
        hud.secrets=0;hud.levelTics=0;notice.reset(hud)
        precondition(!notice.visible(at:0))
        print("PASS: tic-based time formatting, missing par, secret timeout/refresh, restore and reset suppression")
    }
}
