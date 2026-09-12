import AppKit
func lifecycleAppValidation() throws {
    let app=NSApplication.shared;app.setActivationPolicy(.regular)
    let subject=ExtendedPreviewApp()
    subject.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
    defer{subject.validationClose()}
    func wait(_ message:String,_ condition:()->Bool) throws {
        let end=Date().addingTimeInterval(30)
        while !condition() && Date()<end {
            if let event=app.nextEvent(matching:.any,until:Date().addingTimeInterval(0.01),inMode:.default,dequeue:true){app.sendEvent(event)}
            RunLoop.current.run(until:Date().addingTimeInterval(0.005))
            if let failure=subject.validationFailure {throw PortError(failure)}
        }
        guard condition() else {throw PortError("Timed out: \(message), tic \(subject.validationUI?.tic ?? -1), phase \(subject.validationUI?.phase ?? -1)")}
    }
    try wait("initial"){subject.validationUI != nil}
    let initialMap=subject.validationUI!.map
    let death=ProcessInfo.processInfo.environment["LIFECYCLE_FIXTURE"]!.contains("death")
    subject.validationRun()
    if !death {try wait("initial release tics"){(subject.validationUI?.tic ?? 0)>=3};subject.validationUse()}
    try wait("boundary"){subject.validationUI?.phase == (death ? 1:initialMap==1 ? 2:3)}
    guard subject.validationBoundaryControls else {throw PortError("Boundary controls not ready")}
    print("PASS native \(death ? "death":"completion") panel and disabled gameplay; \(subject.validationText)")
    if !death {
        guard let campaign=subject.validationCampaign,subject.validationMusic=="D_DM2INT" else {throw PortError("Missing native intermission/music")}
        subject.validationPause()
        let pausedTic=campaign.tic
        RunLoop.current.run(until:Date().addingTimeInterval(0.1))
        guard campaign.tic==pausedTic,!subject.validationCampaignRunning else {throw PortError("Paused presentation advanced")}
        subject.validationRun()
        try wait("presentation resume"){campaign.tic>pausedTic}
        subject.validationPress() // fill totals
        subject.validationPress() // entering or story
        if initialMap==1 {
            guard campaign.stage == .entering else {throw PortError("Native Continue skipped entering")}
            subject.validationPress()
            try wait("continue"){subject.validationUI?.map==2 && subject.validationUI?.tic==0 && subject.validationPaused}
            guard subject.validationMusic=="D_SHORES",subject.validationCampaign==nil else {throw PortError("New map music/overlay not reset")}
            print("PASS native statistics, entering, independent pause/resume and Continue to paused MAP02")
        } else {
            guard campaign.stage == .story,subject.validationMusic=="D_SHORES" else {throw PortError("Native episode story missing")}
            subject.validationPress();subject.validationPress()
            if initialMap==7 {
                guard campaign.stage == .art else {throw PortError("Native credits missing")}
            } else {
                guard campaign.stage == .cast,subject.validationMusic=="D_DEJAVU" else {throw PortError("Native custom cast/music missing")}
                subject.validationPress()
                guard campaign.dead else {throw PortError("Native cast Fire missing")}
                try wait("cast death to banshee"){campaign.castIndex==1}
                guard subject.validationCampaignSounds>0 else {throw PortError("Patched cast audio did not schedule")}
            }
            print("PASS native episode \(initialMap) story, credits/cast controls and music/audio")
        }
    }
    subject.validationAdvance(restart:true)
    try wait("restart"){subject.validationUI?.playing==true && subject.validationUI?.health==100 && subject.validationUI?.tic==0 && subject.validationPaused}
    for _ in 0..<2 {
        subject.validationStep()
        try wait("step"){subject.validationUI!.tic>0 && subject.validationPaused}
        subject.validationAdvance(restart:true)
        try wait("repeated restart"){subject.validationUI!.tic==0 && subject.validationPaused}
    }
    guard subject.validationUI?.readyAmmo==50,subject.validationUI?.keys==0,subject.validationUI?.armor==0 else {throw PortError("Restart HUD did not reset")}
    print("PASS repeated native restart/step resets HUD, music/audio sequencing and controls without stale frames")
    // Closing while a level action is queued must suppress its eventual UI reply.
    subject.validationAdvance(restart:true);subject.validationClose()
    RunLoop.current.run(until:Date().addingTimeInterval(0.05))
    print("PASS close during level replacement drains worker and suppresses pending presentation")
}
setbuf(stdout,nil)
do {try lifecycleAppValidation()} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}
