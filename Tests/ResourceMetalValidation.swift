// SPDX-License-Identifier: GPL-2.0-or-later
// Uses the private preview fixture from make_resource_fixture.py.
validationRequire(subject.renderer.validationHasTexture("STARTAN2"))
validationRequire(subject.renderer.validationHasTexture("STARTAN3"),"Non-SW switch counterpart was not preloaded")
// Preview has only FIREWALA sidedefs, so STARTAN3 cannot come from map geometry.
let testMap=try DoomMap(wad:subject.wad!,name:"E1M1")
validationRequire(!testMap.sides.contains { [$0.upper,$0.middle,$0.lower].contains("STARTAN3") })
subject.renderer.validationHUDVisible=false
try subject.renderer.validationSynchronizeEngine()
let before=frame()
validationRequire(frame()==before,"Paused resource animation changed")
for _ in 0..<4 { validationRequire(MD_Tick(0,0,0,0) != 0) }
try subject.renderer.validationSynchronizeEngine()
let after=frame()
let changed=zip(before,after).filter { $0 != $1 }.count
validationRequire(changed>1000,"Packed 4-tic floor animation did not change GPU pixels")
let save=output.appendingPathComponent("resource-phase.mdsave")
try subject.renderer.saveGame(to:save)
for _ in 0..<16 { validationRequire(MD_Tick(0,0,0,0) != 0) }
try subject.renderer.loadGame(from:save)
let restored=frame()
validationRequire(restored==after,"Resource save/load did not restore identical GPU pixels")
try png(before,"resources-before");try png(after,"resources-after")
print("PASS: non-SW switch counterpart preload, stable pause, \(changed) changed GPU bytes after 4 tics, exact saved animation pixels")
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
}
do { try runAOValidation() } catch { validationFail(String(describing:error)) }
