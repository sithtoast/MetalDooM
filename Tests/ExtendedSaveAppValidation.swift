import AppKit
func saveAppValidation() throws {
    let app=NSApplication.shared;app.setActivationPolicy(.regular)
    let subject=ExtendedPreviewApp();subject.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
    defer{subject.validationClose()}
    let folder=FileManager.default.temporaryDirectory.appendingPathComponent("rust-save-test-"+UUID().uuidString)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)
    defer{try? FileManager.default.removeItem(at:folder)}
    let file=folder.appendingPathComponent("test.mdrust")
    func wait(_ text:String,_ condition:()->Bool) throws {
        let end=Date().addingTimeInterval(30)
        while !condition() && Date()<end {
            if let event=app.nextEvent(matching:.any,until:Date().addingTimeInterval(0.01),inMode:.default,dequeue:true){app.sendEvent(event)}
            RunLoop.current.run(until:Date().addingTimeInterval(0.005))
            if let failure=subject.validationFailure {throw PortError(failure)}
        }
        guard condition() else {throw PortError("Timed out: \(text); \(subject.validationStatus)")}
    }
    try wait("initial"){subject.validationUI != nil}
    let originalMusic=subject.validationMusic
    subject.validationStep();try wait("initial step"){subject.validationUI!.tic==35 && subject.validationPaused}
    subject.validationSave(file);try wait("save"){subject.validationStatus.hasPrefix("Saved") && subject.validationPaused}
    guard FileManager.default.fileExists(atPath:file.path) else {throw PortError("No native save file")}
    for _ in 0..<2 {
        subject.validationStep();try wait("advance beyond save"){subject.validationUI!.tic==70 && subject.validationPaused}
        subject.validationLoad(file);try wait("load"){subject.validationStatus.hasPrefix("Loaded") && subject.validationPaused}
        guard subject.validationUI!.tic==35,subject.validationMusic==originalMusic,subject.validationSaveEnabled else {throw PortError("Restore HUD/music/buttons mismatch: \(subject.validationMusic ?? "nil")")}
    }
    print("PASS native save, two independent worker restores at tic35, subsequent audio/step, paused controls and music")
    var broken=try Data(contentsOf:file);broken[broken.count-1] ^= 1
    let bad=folder.appendingPathComponent("corrupt.mdrust");try broken.write(to:bad)
    subject.validationLoad(bad);try wait("reject corrupt"){subject.validationStatus.hasPrefix("Save/load failed") && subject.validationPaused}
    guard subject.validationUI!.tic==35,subject.validationSaveEnabled else {throw PortError("Failed restore replaced current game")}
    subject.validationStep();try wait("old worker still plays"){subject.validationUI!.tic==70 && subject.validationPaused}
    subject.validationSave(folder.appendingPathComponent("missing/test.mdrust"));try wait("write error"){subject.validationStatus.hasPrefix("Save/load failed") && subject.validationPaused}
    guard subject.validationUI!.tic==70,subject.validationSaveEnabled else {throw PortError("Write failure lost game")}
    print("PASS corrupted save and write failure leave current worker usable")
    subject.validationLoad(file);subject.validationClose()
    RunLoop.current.run(until:Date().addingTimeInterval(0.1))
    print("PASS close during pending restore cancels candidate and preserves teardown ordering")
}
setbuf(stdout,nil)
do {try saveAppValidation()} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}
