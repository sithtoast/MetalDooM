import Foundation

@main struct ExtendedPlaybackValidation {
    static func main() { do { try run() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) } }
    static func check(_ value:Bool,_ message:String) throws { if !value { throw PortError(message) } }
    static func run() throws {
        var clock=ExtendedPlaybackClock()
        clock.start(now:0)
        try check(!clock.claim(now:0),"Clock advanced before its first deadline")
        try check(clock.claim(now:1),"Late clock failed to advance")
        try check(!clock.claim(now:10),"Clock allowed concurrent requests")
        clock.finish()
        try check(clock.claim(now:10),"Clock failed after slow request")
        clock.finish()
        try check(!clock.claim(now:10),"Clock accumulated catch-up debt")
        clock.pause();try check(!clock.busy && !clock.claim(now:20),"Paused clock advanced")
        clock.start(now:20,steps:35)
        for i in 0..<35 {
            try check(clock.claim(now:clock.deadline),"Missing manual tic \(i)")
            try check(clock.inFlight,"Manual request was not tracked")
            clock.finish()
        }
        try check(!clock.busy && !clock.claim(now:40),"Manual batch exceeded its tic count")
        clock.start(now:40);_=clock.claim(now:41);clock.pause()
        try check(clock.busy && !clock.running && !clock.claim(now:42),"Pause lost pending request")
        clock.finish();try check(!clock.busy,"Paused request never settled")
        clock.start(now:50);try check(!clock.claim(now:50),"Resume inherited time debt")
        clock.pause()
        print("PASS pacing: deadlines, slow work, one in-flight request, exact manual length, pause/resume")

        let args=CommandLine.arguments,exe=URL(fileURLWithPath:args[1]),root=URL(fileURLWithPath:args[2])
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        for map in [1,13,16] {
            let worker=ExtendedWorker();defer{worker.close()}
            let first=try worker.start(executable:exe,paths:paths,map:map,base:1)
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            let builder=try ExtendedSceneBuilder(resources:resources);_=try builder.prepare(first)
            var elapsed:[Double]=[],startTics:[Int]=[],last=first,changes=0
            for tic in 1...140 {
                let start=ProcessInfo.processInfo.systemUptime
                let state=try worker.tick(buttons:tic==36 ? 2:tic>70 ? 1:0)
                let scene=try builder.prepare(state)
                elapsed.append((ProcessInfo.processInfo.systemUptime-start)*1000)
                try check(scene.view.tic==tic && state.audio.tic==tic && state.audio.events.allSatisfy{$0.tic>=tic-1 && $0.tic<=tic},"Scene/audio tic disagreement")
                startTics += state.audio.events.filter{$0.operation==1 && $0.name=="DSPISTOL"}.map(\.tic)
                if scene.geometryChanged { changes+=1 };last=state
            }
            try check(last.tic==140 && last.presentation.ammo<50 && !startTics.isEmpty,"Continuous fire failed")
            if map==16 { try check(changes>0,"Moving world never updated") }
            let sorted=elapsed.sorted(),mean=elapsed.reduce(0,+)/Double(elapsed.count)
            print(String(format:"PASS MAP%02d: 140 consecutive scene/audio tics, %d geometry updates, %d topology builds; worker + CPU preparation mean %.2f ms, p95 %.2f ms, max %.2f ms",map,changes,builder.meshBuilds,mean,sorted[Int(Double(sorted.count-1)*0.95)],sorted.last!))
        }
    }
}
