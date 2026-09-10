// SPDX-License-Identifier: GPL-2.0-or-later
// Combined with App by test-ambient-occlusion.sh. Real GPU rendering, fixed scene.
setbuf(stdout,nil)
func validationFail(_ message: String, file: StaticString = #filePath, line: UInt = #line) -> Never {
    fputs("FAIL: \(message) [\(file):\(line)]\n",stderr)
    exit(EXIT_FAILURE)
}
func validationRequire(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Validation check failed", file: StaticString = #filePath, line: UInt = #line) {
    if !condition() { validationFail(message(),file:file,line:line) }
}
func pumpEvents(_ seconds: Double) {
    let end=Date().addingTimeInterval(seconds)
    while Date()<end {
        if let event=NSApp.nextEvent(matching:.any,until:end,inMode:.default,dequeue:true) { NSApp.sendEvent(event) }
        RunLoop.current.run(until:Date().addingTimeInterval(0.001))
    }
}
func runAOValidation() throws {
let application=NSApplication.shared
application.setActivationPolicy(.regular)
let subject=App()
subject.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
validationRequire(subject.wad != nil)
subject.endAttract();subject.gameMenu?.removeFromSuperview();subject.gameMenu=nil
subject.view.isPaused=true;subject.renderer.paused=true
subject.view.autoResizeDrawable=false
subject.view.drawableSize=CGSize(width:1280,height:800)
subject.window.makeKeyAndOrderFront(nil)
application.activate(ignoringOtherApps:true)
pumpEvents(0.2)
subject.view.drawableSize=CGSize(width:1280,height:800)
let output=URL(fileURLWithPath:ProcessInfo.processInfo.environment["AO_OUTPUT"]!)
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
var gpuTimes:[Double]=[]
subject.renderer.onGPUFrame={ gpuTimes.append($0*1000) }
subject.renderer.onWarning={ validationFail($0) }
subject.renderer.onError={ validationFail("\($0)") }
MD_TestMonsters(0)

func frame() -> [UInt8] {
    autoreleasepool {
        guard let drawable=subject.view.currentDrawable else { validationFail("No drawable") }
        let texture=drawable.texture, width=texture.width, height=texture.height
        subject.view.draw()
        let queue=subject.renderer.queue
        let buffer=subject.renderer.device.makeBuffer(length:width*height*4,options:.storageModeShared)!
        let command=queue.makeCommandBuffer()!, encoder=command.makeBlitCommandEncoder()!
        encoder.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:width*4,destinationBytesPerImage:width*height*4)
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        validationRequire(command.status == .completed,"Readback failed: \(String(describing:command.error))")
        RunLoop.current.run(until:Date().addingTimeInterval(0.001))
        return Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:UInt8.self),count:width*height*4))
    }
}
func png(_ bytes:[UInt8], _ name:String) throws {
    let image=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1280,pixelsHigh:800,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1280*4,bitsPerPixel:32)!
    for i in stride(from:0,to:bytes.count,by:4) {
        image.bitmapData![i]=bytes[i+2];image.bitmapData![i+1]=bytes[i+1];image.bitmapData![i+2]=bytes[i];image.bitmapData![i+3]=255
    }
    try image.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
}
func measure(_ enabled:Bool) throws -> [UInt8] {
    try subject.renderer.setAmbientOcclusion(enabled)
    for _ in 0..<8 { _=frame() }
    gpuTimes=[]
    var result:[UInt8]=[]
    for _ in 0..<32 { result=frame() }
    print("\(enabled ? "AO":"Classic") GPU command mean: \(gpuTimes.reduce(0,+)/Double(gpuTimes.count)) ms at 1280x800; \(gpuTimes.count) samples")
    return result
}
try validateAlphaRays(device:subject.renderer.device,queue:subject.renderer.queue)
validationRequire(!subject.renderer.ambientOcclusionEnabled)
let classic=try measure(false)
let occluded=try measure(true)
let ao=subject.renderer.ambientOcclusion!
validationRequire(ao.triangleCount>0 && ao.buildCount==1,"Paused geometry should build once")
let defaultSettings=subject.renderer.aoSettings
let originalSettingsKey=subject.benchmarkSettings
subject.renderer.setAOSettings(strength:0)
validationRequire(subject.benchmarkSettings != originalSettingsKey)
validationRequire(frame()==classic,"Zero strength must restore classic pixels")
subject.renderer.setAOSettings(strength:1)
let strong=frame()
validationRequire(strong != occluded,"Strength control has no visible effect")
subject.renderer.setAOSettings(strength:defaultSettings.strength,radius:16)
let near=frame()
validationRequire(near != occluded,"Radius control has no visible effect")
subject.renderer.setAOSettings(radius:defaultSettings.radius)
validationRequire(subject.benchmarkSettings==originalSettingsKey)
validationRequire(ao.buildCount==1,"AO controls must not rebuild geometry")
print("PASS: strength/radius change GPU pixels and benchmark identity, zero strength restores classic, controls do not rebuild geometry")
let repeated=frame()
validationRequire(repeated==occluded,"AO should be stable in a paused scene")
let restored=try measure(false)
validationRequire(restored==classic,"Disabling AO must exactly restore classic pixels")
let hudStart=(800-Int(SpriteRenderer.hudHeight(width:1280)))*1280*4
validationRequire(classic[hudStart...]==occluded[hudStart...],"AO changed HUD")
let changed=stride(from:0,to:hudStart,by:4).filter { classic[$0] != occluded[$0] || classic[$0+1] != occluded[$0+1] || classic[$0+2] != occluded[$0+2] }.count
validationRequire(changed>1000,"AO did not visibly affect world surfaces")
for i in stride(from:0,to:hudStart,by:4) { for c in 0..<3 { validationRequire(occluded[i+c]<=classic[i+c],"AO unexpectedly brightened pixel") } }
try png(classic,"classic");try png(occluded,"ao")
print("PASS: \(changed) world pixels shaded; HUD unchanged; stable paused pixels; disabling AO restores identical classic image")
// Opt-in fixture for the original Ultimate Doom E1M1 zigzag room. Its ceiling
// and walls are dark; bright pixels above the HUD reveal sky through mesh gaps.
if ProcessInfo.processInfo.environment["AO_CEILING"] == "1" {
    validationRequire(subject.renderer.validationMapName == "E1M1","AO_CEILING requires original E1M1")
    subject.renderer.setAOSettings(strength:1,radius:96)
    for enabled in [false,true] {
        try subject.renderer.setAmbientOcclusion(enabled)
        for (p,point) in [(Float(2848),Float(-2960)),(3008,-3328),(3008,-3744)].enumerated() {
            for a in 0..<8 {
                subject.renderer.validationCamera(point.0,point.1,17,Float(a)*Float.pi/4,1.05)
                let pixels=frame()
                try png(pixels,"ceiling-\(p)-\(a)-\(enabled ? "ao":"classic")")
                let bright=stride(from:0,to:600*1280*4,by:4).filter {
                    min(pixels[$0],pixels[$0+1],pixels[$0+2])>180
                }.count
                validationRequire(bright==0,"Ceiling sky leak: \(bright) pixels at pose \(p)/\(a), AO \(enabled)")
            }
        }
    }
    validationRequire(MD_TestPlacePlayer(2848,-2960,Float.pi/4) != 0)
    subject.renderer.validationCamera(2848,-2960,17,Float.pi/4,1.05)
    try subject.renderer.saveGame(to:output.appendingPathComponent("ceiling.mdsave"),title:"Zigzag ceiling regression")
    subject.renderer.setAOSettings(strength:defaultSettings.strength,radius:defaultSettings.radius)
    try subject.renderer.validationSynchronizeEngine()
    print("PASS: 24 zigzag ceiling viewpoints have no sky leaks with classic or maximum AO")
}
// Light and AO share the same mesh but remain independently switchable.
try subject.renderer.setAmbientOcclusion(false)
let lightClassic=frame()
let lightSettingsKey=subject.benchmarkSettings
try subject.renderer.setDynamicLight(true)
validationRequire(!subject.renderer.ambientOcclusionEnabled,"Enabling a light must not enable AO")
let lit=frame()
let shared=subject.renderer.ambientOcclusion!
let lightBuilds=shared.buildCount
validationRequire(lit != lightClassic,"Moving light did not illuminate the world")
validationRequire(lit[hudStart...]==lightClassic[hudStart...],"Light changed the HUD")
validationRequire(frame()==lit,"Paused light must remain stationary")
validationRequire(subject.benchmarkSettings != lightSettingsKey)
subject.renderer.setDynamicLightShadows(false)
let unshadowed=frame()
for i in stride(from:0,to:hudStart,by:4) { for c in 0..<3 {
    validationRequire(lit[i+c]<=unshadowed[i+c],"Shadows added illumination")
}}
try png(lit,"light-shadowed");try png(unshadowed,"light-unshadowed")
subject.renderer.setDynamicLightShadows(true)
subject.renderer.validationLightPhase(70)
let moved=frame()
validationRequire(moved != lit,"Light did not move after advancing its game-time phase")
validationRequire(shared.buildCount==lightBuilds,"Light movement/shadow toggle rebuilt world geometry")
try subject.renderer.setAmbientOcclusion(true)
let combined=frame()
validationRequire(subject.renderer.ambientOcclusion === shared,"AO and light must share their ray mesh")
validationRequire(combined != moved,"AO did not combine with the moving light")
try png(combined,"light-ao")
try subject.renderer.setDynamicLight(false)
validationRequire(subject.renderer.ambientOcclusionEnabled && subject.renderer.ambientOcclusion === shared)
try subject.renderer.setAmbientOcclusion(false)
validationRequire(subject.renderer.ambientOcclusion == nil,"Disabling both effects must release ray resources")
validationRequire(frame()==lightClassic,"Disabling light/AO must restore classic pixels")
validationRequire(subject.benchmarkSettings==lightSettingsKey)
try subject.renderer.setDynamicLight(true)
for shadows in [false,true] {
    subject.renderer.setDynamicLightShadows(shadows)
    for _ in 0..<8 { _=frame() };gpuTimes=[]
    for _ in 0..<32 { _=frame() }
    print("Light shadows \(shadows): GPU command mean \(gpuTimes.reduce(0,+)/Double(gpuTimes.count)) ms, 1280x800, \(gpuTimes.count) samples")
}
try subject.renderer.setAmbientOcclusion(true)
for _ in 0..<8 { _=frame() };gpuTimes=[]
for _ in 0..<32 { _=frame() }
print("AO plus shadowed light: GPU command mean \(gpuTimes.reduce(0,+)/Double(gpuTimes.count)) ms, 1280x800, \(gpuTimes.count) samples")
try subject.renderer.setAmbientOcclusion(false)
print("PASS: moving light, paused stability, independent AO/light toggles, shared geometry, HUD preservation and exact classic restoration")

if ProcessInfo.processInfo.environment["AO_CEILING"] == "1" {
    var mostShadowed=0
    for (scene,pose) in [(Float(1056),Float(-3400),Float.pi/2),(288,-3040,-Float.pi/2),(1888,-2480,0)].enumerated() {
        validationRequire(MD_TestPlacePlayer(pose.0,pose.1,pose.2) != 0)
        try subject.renderer.validationSynchronizeEngine()
        for phase:Int32 in [0,70,140,210] {
            subject.renderer.validationLightPhase(phase)
            subject.renderer.setDynamicLightShadows(true);let shadows=frame()
            subject.renderer.setDynamicLightShadows(false);let clear=frame()
            let changed=stride(from:0,to:hudStart,by:4).filter { shadows[$0+2]<clear[$0+2] }.count
            mostShadowed=max(mostShadowed,changed)
            print("Shadow scene \(scene), phase \(phase): \(changed) red-channel pixels occluded")
            try png(shadows,"light-scene-\(scene)-\(phase)-shadows")
            try png(clear,"light-scene-\(scene)-\(phase)-clear")
        }
    }
    validationRequire(mostShadowed>1000,"World geometry did not visibly cast test-light shadows")
    subject.renderer.setDynamicLightShadows(true)
    print("PASS: original world geometry visibly casts shadows")
}

// Open a real original door and verify the same renderer rebuilds the ray mesh.
if subject.wad!.maps.contains("E1M1") {
    try subject.renderer.setAmbientOcclusion(true)
    var x:Float=0,y:Float=0,angle:Float=0,sector:Int32=0
    validationRequire(MD_TestDoor(0,&x,&y,&angle,&sector)>=0)
    validationRequire(MD_TestPlacePlayer(x,y,angle) != 0)
    let closed=MD_GetSector(sector).ceiling
    _ = frame()
    let builds=subject.renderer.ambientOcclusion!.buildCount
    validationRequire(MD_Tick(0,0,0,1) != 0)
    for _ in 0..<25 {
        validationRequire(MD_Tick(0,0,0,0) != 0)
        try subject.renderer.validationSynchronizeEngine()
        _ = frame()
    }
    validationRequire(MD_GetSector(sector).ceiling>closed,"Original door did not open")
    validationRequire(subject.renderer.ambientOcclusion!.buildCount>builds,"Door movement did not update ray geometry")
    let settled=subject.renderer.ambientOcclusion!.buildCount
    for _ in 0..<4 { _ = frame() }
    validationRequire(subject.renderer.ambientOcclusion!.buildCount==settled,"Paused door rebuilds unnecessarily")
    try png(frame(),"door-ao")
    print("PASS: original door opens, AO mesh rebuilds during motion and stops rebuilding when paused")
}
// Save/load retains independently selected effects and restores the game-time orbit.
try subject.renderer.setAmbientOcclusion(true)
try subject.renderer.validationSynchronizeEngine()
let savedTime=MD_GetHUD().levelTics
let lightSave=output.appendingPathComponent("light.mdsave")
try subject.renderer.saveGame(to:lightSave,title:"Moving light validation")
try subject.renderer.loadGame(from:lightSave)
_=frame()
validationRequire(subject.renderer.dynamicLightEnabled && subject.renderer.ambientOcclusionEnabled)
validationRequire(MD_GetHUD().levelTics==savedTime,"Save/load changed the light's game-time phase")
print("PASS: enabled light/AO and game-time orbit survive native save/load")

// Exercise map replacement with an enabled acceleration structure, then shutdown
// while GPU work/resources have existed. One engine WAD stack remains in use.
try subject.renderer.setAmbientOcclusion(true)
_ = frame()
let oldBuilds=subject.renderer.ambientOcclusion!.buildCount
let nextMap=subject.wad!.maps.contains("E1M2") ? "E1M2":"MAP02"
_ = try subject.renderer.load(wad:subject.wad!,map:nextMap)
_ = frame()
validationRequire(subject.renderer.ambientOcclusion!.buildCount>oldBuilds)
print("PASS: enabled AO rebuilds after map replacement")
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
RunLoop.current.run(until:Date().addingTimeInterval(0.1))
print("PASS: AO resources survive queued frames and clean shutdown")

}
do { try runAOValidation() } catch { validationFail(String(describing:error)) }
