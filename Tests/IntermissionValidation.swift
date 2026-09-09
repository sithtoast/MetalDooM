// SPDX-License-Identifier: GPL-2.0-or-later
@main struct IntermissionValidation {
    static func main() {
        var state = MD_Progress(); state.phase=1; state.episode=1; state.map=1; state.nextMap=2
        state.kills=3; state.maxKills=4; state.items=1; state.maxItems=2
        state.secrets=0; state.maxSecrets=0; state.seconds=65; state.parSeconds=30
        var sequence = IntermissionSequence(state)
        for _ in 0..<34 { precondition(sequence.update(seconds:1.0/35,pressed:false).isEmpty) }
        precondition(sequence.values == [-1,-1,-1,-1,-1])
        _ = sequence.update(seconds:1.0/35,pressed:false)
        precondition(sequence.stage == 2)
        _ = sequence.update(seconds:1.0/35,pressed:false)
        precondition(sequence.values == [1,-1,-1,-1,-1])
        var sounds: [Int32] = []
        for _ in 0..<1000 { sounds += sequence.update(seconds:1.0/35,pressed:false) }
        precondition(sequence.stage==10 && sequence.values == [75,50,0,65,30])
        precondition(sounds.contains(0) && sounds.filter{$0==1}.count==4)
        precondition(!sequence.entering && !sequence.advance)
        precondition(sequence.update(seconds:0,pressed:true)==[2] && sequence.entering)
        precondition(sequence.pointerVisible)
        for _ in 0..<139 { _ = sequence.update(seconds:1.0/35,pressed:false) }
        precondition(!sequence.advance)
        _ = sequence.update(seconds:1.0/35,pressed:false); precondition(sequence.advance)
        sequence = IntermissionSequence(state)
        precondition(sequence.update(seconds:0,pressed:true)==[1])
        precondition(sequence.values == [75,50,0,65,30] && !sequence.entering)
        _ = sequence.update(seconds:0,pressed:true); precondition(sequence.entering && !sequence.advance)
        _ = sequence.update(seconds:0,pressed:true); precondition(sequence.advance)
        state.phase=2; sequence=IntermissionSequence(state)
        for _ in 0..<3 { _ = sequence.update(seconds:0,pressed:true) }
        precondition(sequence.stage==10 && !sequence.advance && !sequence.entering)
        state.phase=1; precondition(IntermissionSequence.completedNodes(state)==[0])
        state.map=9; state.nextMap=4; state.didSecret=1
        precondition(IntermissionSequence.completedNodes(state)==[0,1,2,8])
        state.episode=4; precondition(IntermissionSequence.completedNodes(state).isEmpty)
        state.episode=1; state.commercial=1; precondition(IntermissionSequence.completedNodes(state).isEmpty)
        print("PASS: original counter timing, sounds, zero totals, skip/advance, automatic destination transition, episode end and secret markers")
    }
}
