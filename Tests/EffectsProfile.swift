// SPDX-License-Identifier: GPL-2.0-or-later
// Optional AO_PROFILE=1 branch of the native harness: GPU duration, no pixel readback.
subject.view.drawableSize=CGSize(width:2200,height:1520)
func profileFrame() {
    autoreleasepool {
        subject.view.draw()
        let fence=subject.renderer.queue.makeCommandBuffer()!
        fence.commit();fence.waitUntilCompleted()
        validationRequire(fence.status == .completed,"Profile command failed")
        RunLoop.current.run(until:Date().addingTimeInterval(0.001))
    }
}
func profile(_ label:String,_ preset:EffectsPreset) throws {
    try subject.renderer.applyEffectsPreset(preset,view:subject.view)
    for _ in 0..<8 { profileFrame() }
    gpuTimes=[]
    for _ in 0..<32 { profileFrame() }
    let sorted=gpuTimes.sorted()
    validationRequire(sorted.count==32,"Profile missed frame timing callbacks")
    print(String(format:"PROFILE %@: median %.3f ms, p95 %.3f ms, 2200x1520, %d GPU frames",label,sorted[16],sorted[30],sorted.count))
}
print("PROFILE: fixed camera, paused simulation, API validation \(ProcessInfo.processInfo.environment["MTL_DEBUG_LAYER"] ?? "default"), GPU duration excludes display pacing")
try profile("Classic",EffectsPreset())
try profile("Medium",EffectsPreset.builtins[1])
try profile("Medium HDR",EffectsPreset.builtins[3])
var preset=EffectsPreset.builtins[3];preset.ao=false
try profile("Medium HDR without AO",preset)
preset=EffectsPreset.builtins[3];preset.effects.remove(SceneEffect.softShadows.rawValue)
try profile("Medium HDR without soft shadows",preset)
preset=EffectsPreset.builtins[3];preset.effects.remove(SceneEffect.volumetrics.rawValue)
try profile("Medium HDR without volumetrics",preset)
preset=EffectsPreset.builtins[3];preset.highRayQuality=true
try profile("Medium HDR High",preset)
try profile("Ludicrous",EffectsPreset.builtins[4])
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
}
do { try runAOValidation() } catch { validationFail(String(describing:error)) }
