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
        state.commercial=0; state.episode=1; sequence=IntermissionSequence(state)
        precondition(sequence.animations(state).isEmpty)
        for _ in 0..<12 { _ = sequence.update(seconds:1.0/35,pressed:false) }
        let frames=sequence.animations(state).map(\.name)
        precondition(frames.count==10)
        for _ in 0..<11 { _ = sequence.update(seconds:1.0/35,pressed:false) }
        precondition(sequence.animations(state).map(\.name) != frames)
        state.episode=2; state.nextMap=9
        precondition(sequence.animations(state).map(\.name)==["WIA10400"])
        _ = sequence.update(seconds:0,pressed:true); _ = sequence.update(seconds:0,pressed:true)
        precondition(sequence.animations(state).last?.name=="WIA10700")
        for _ in 0..<25 { _ = sequence.update(seconds:1.0/35,pressed:false) }
        precondition(sequence.animations(state).last?.name=="WIA10702")
        state.episode=4; precondition(sequence.animations(state).isEmpty)
        for episode: Int32 in 1...4 {
            var finale=FinaleSequence(episode:episode,textLength:20)
            for _ in 0..<13 { _ = finale.update(seconds:1.0/35,pressed:false) }
            precondition(finale.visibleCharacters==1 && !finale.art)
            _ = finale.update(seconds:0,pressed:true)
            precondition(finale.visibleCharacters==20 && !finale.art)
            precondition(finale.update(seconds:0,pressed:true)==(episode==3 ? [3] : []))
            precondition(finale.art && finale.tick==0 && finale.scroll==320)
            var effects: [Int32]=[]
            for _ in 0..<1220 { effects += finale.update(seconds:1.0/35,pressed:false) }
            precondition(finale.art && finale.scroll==0 && finale.endFrame==6)
            precondition(effects==(episode==3 ? Array(repeating:0,count:6) : []))
            _ = finale.update(seconds:0,pressed:true); precondition(finale.art && finale.tick==1220)
        }
        state.phase=1;state.commercial=1
        var commercial=IntermissionSequence(state)
        _=commercial.update(seconds:0,pressed:true);_=commercial.update(seconds:0,pressed:true)
        _=commercial.update(seconds:9.0/35,pressed:false);precondition(!commercial.advance)
        _=commercial.update(seconds:1.01/35,pressed:false);precondition(commercial.advance)
        var story=FinaleSequence(textLength:20,commercial:true)
        _=story.update(seconds:60,pressed:false);precondition(!story.art)
        _=story.update(seconds:0,pressed:true);precondition(story.art)
        var automatic=FinaleSequence(episode:1,textLength:20)
        for _ in 0..<310 { _ = automatic.update(seconds:1.0/35,pressed:false) }
        precondition(!automatic.art)
        _ = automatic.update(seconds:1.0/35,pressed:false); precondition(automatic.art)
        print("PASS: episode animation frames, secret-map overlay, finale text/skip/auto timing, bunny scroll and six ending shots")
        print("PASS: original counter timing, sounds, zero totals, skip/advance, automatic destination transition, episode end and secret markers")
    }
}
