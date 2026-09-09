// SPDX-License-Identifier: GPL-2.0-or-later
// Single-player timing and map locations from Chocolate Doom's wi_stuff.c.
struct IntermissionSequence {
    private(set) var values = [Int32](repeating: -1, count: 5)
    private(set) var stage = 1
    private(set) var tick = 0
    private(set) var entering = false
    private(set) var advance = false
    private var pause = 35
    private var elapsed = 0.0
    private var enteringTicks = 0
    private let targets: [Int32]
    private let canAdvance: Bool
    init(_ state: MD_Progress = MD_Progress()) {
        func percent(_ value: Int32, _ total: Int32) -> Int32 { Int32(Int64(value)*100/Int64(max(1,total))) }
        targets = [percent(state.kills,state.maxKills),percent(state.items,state.maxItems),percent(state.secrets,state.maxSecrets),state.seconds,state.parSeconds]
        canAdvance = state.phase == 1
    }
    // Sound codes: 0 pistol count, 1 barrel explosion completion, 2 shotgun cock.
    mutating func update(seconds: Double, pressed: Bool) -> [Int32] {
        var sounds: [Int32] = []
        if pressed {
            if stage != 10 { values = targets; stage = 10; sounds.append(1) }
            else if canAdvance {
                if entering { advance = true }
                else { entering = true; enteringTicks = 0; sounds.append(2) }
            }
        }
        elapsed += seconds
        while elapsed >= 1.0/35.0 {
            elapsed -= 1.0/35.0; tick += 1
            if entering {
                enteringTicks += 1
                if enteringTicks >= 4*35 { advance = true }
            } else if stage < 10 {
                if stage % 2 == 1 {
                    pause -= 1
                    if pause == 0 { stage += 1; pause = 35 }
                } else {
                    let indices = stage == 8 ? [3,4] : [stage/2-1]
                    if tick & 3 == 0 { sounds.append(0) }
                    for i in indices { values[i] = min(targets[i],values[i]+(stage == 8 ? 3 : 2)) }
                    if indices.allSatisfy({values[$0] == targets[$0]}) { stage += 1; sounds.append(1) }
                }
            }
        }
        return sounds
    }
    var pointerVisible: Bool { (4*35-enteringTicks) & 31 < 20 }
    static let nodes: [[(Float,Float)]] = [
        [(185,164),(148,143),(69,122),(209,102),(116,89),(166,55),(71,56),(135,29),(71,24)],
        [(254,25),(97,50),(188,64),(128,78),(214,92),(133,130),(208,136),(148,140),(235,158)],
        [(156,168),(48,154),(174,95),(265,75),(130,48),(279,23),(198,48),(140,25),(281,136)]
    ]
    static func completedNodes(_ state: MD_Progress) -> [Int] {
        guard state.commercial == 0, (1...3).contains(state.episode) else { return [] }
        let last = state.map == 9 ? Int(state.nextMap)-2 : Int(state.map)-1
        var nodes = last >= 0 ? Array(0...min(7,last)) : []
        if state.didSecret != 0 || state.map == 9 { nodes.append(8) }
        return nodes
    }
}
