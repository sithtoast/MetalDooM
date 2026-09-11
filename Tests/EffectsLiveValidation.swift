// SPDX-License-Identifier: GPL-2.0-or-later
// AO_LIVE=1: exercise MTKView's automatic draw loop, never call view.draw().
subject.window.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps:true)
subject.view.isPaused=false
for index in [0,1,0,3,0,1,0] {
    try subject.renderer.applyEffectsPreset(EffectsPreset.builtins[index],view:subject.view)
    let before=subject.renderer.renderedFrames
    pumpEvents(1)
    let count=subject.renderer.renderedFrames-before
    validationRequire(count>5,"Automatic drawing stalled after \(EffectsPreset.names[index]): \(count) frames")
    print("PASS: automatic \(EffectsPreset.names[index]) drawing: \(count) frames after transition")
}
subject.view.isPaused=true
try subject.renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
validationRequire(subject.view.isPaused,"Preset reset manual-draw mode")
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
}
do { try runAOValidation() } catch { validationFail(String(describing:error)) }
