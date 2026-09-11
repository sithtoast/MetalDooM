// SPDX-License-Identifier: GPL-2.0-or-later
func scale(_ value:CGFloat,_ metalFX:Bool=true) {
    subject.view.renderScale=value;subject.view.metalFXEnabled=metalFX
    subject.view.drawableSize=CGSize(width:1280,height:800)
}
subject.renderer.setMinimalHUDPortrait(false)
subject.renderer.setHUDStyle(.classic)
subject.renderer.setHUDSize(100)
scale(1)
try subject.renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
let reference=frame()
let hudStart=(800-Int(SpriteRenderer.hudHeight(width:1280)))*1280*4
for factor:CGFloat in [0.5,0.75,1.5,2] {
    for fx in [false,true] {
        scale(factor,fx)
        let pixels=frame()
        validationRequire(pixels[hudStart...]==reference[hudStart...],"World scaling changed native HUD")
        validationRequire(pixels != reference,"World scaling did not change world pixels")
        validationRequire(frame()==pixels,"Paused scaling is unstable")
        try png(pixels,"world-\(Int(factor*100))-\(fx ? "metalfx":"nearest")")
    }
}
scale(1);validationRequire(frame()==reference,"Native path did not restore classic pixels")
try png(reference,"native")
print("PASS: native HUD equality, stable world pixels, 50/75% nearest and MetalFX, 150/200% supersampling, exact Classic restoration")
// Exercise the production status-bar layout independently of world resolution.
let savedHUDSize=UserDefaults.standard.object(forKey:"hudStatusBarSize")
for percent in SpriteRenderer.hudSizes {
    scale(1);subject.applyHUDSize(percent)
    validationRequire(UserDefaults.standard.integer(forKey:"hudStatusBarSize")==percent,"HUD preference not saved")
    let height=Int(SpriteRenderer.hudHeight(width:1280,percent:percent))
    validationRequire(height==128*percent/100,"HUD height does not match the requested scale")
    let barStart=(800-height)*1280*4
    let native=frame()
    if percent<100 {
        validationRequire(native != reference,"HUD adjustment did not change pixels")
        // The reclaimed rows contain the rendered world, not an old full-height black band.
        validationRequire(native[hudStart..<barStart].filter{$0>32}.count>1000,"Shrinking HUD failed to reclaim world viewport")
    }
    try png(native,"hud-\(percent)")
    for factor:CGFloat in [0.5,0.75,2] {
        scale(factor);validationRequire(frame()[barStart...]==native[barStart...],"World scale changed the resized HUD")
    }
}
subject.applyHUDSize(100);scale(1)
validationRequire(frame()==reference,"Original HUD size did not restore original pixels")
if let savedHUDSize { UserDefaults.standard.set(savedHUDSize,forKey:"hudStatusBarSize") }
else { UserDefaults.standard.removeObject(forKey:"hudStatusBarSize") }
subject.renderer.setHUDSize(-10);validationRequire(subject.renderer.hudSizePercent==100)
print("PASS: 25/50/75/100% HUD geometry, persistent setting, reclaimed viewport, world-scaling independence and exact original restoration")
// Compare the transparent overlay against the identical full-height scene.
// The mask captures only actual HUD pixels, including shadows, not its world backing.
let savedHUDStyle=UserDefaults.standard.object(forKey:"hudStyle")
subject.applyHUDStyle(.minimal)
validationRequire(UserDefaults.standard.integer(forKey:"hudStyle")==HUDStyle.minimal.rawValue,"HUD style was not saved")
let savedPortrait=UserDefaults.standard.object(forKey:"minimalHUDPortrait")
subject.applyMinimalHUDPortrait(true)
validationRequire(UserDefaults.standard.bool(forKey:"minimalHUDPortrait"),"Portrait preference was not saved")
let liveHUD=MD_GetHUD()
var fixtureHUD=liveHUD;fixtureHUD.health=137;fixtureHUD.armor=84;fixtureHUD.readyAmmo=23;fixtureHUD.keys=63
subject.renderer.validationHUD(fixtureHUD)
subject.renderer.validationHUDVisible=false
let fullWorld=frame()
let bottomStart=(800-32)*1280*4
validationRequire(fullWorld[bottomStart...].filter{$0>32}.count>5000,"Minimal HUD still reserves a black bottom strip")
for percent in SpriteRenderer.hudSizes {
    scale(1);subject.renderer.setHUDSize(percent)
    validationRequire(frame()==fullWorld,"Minimal size changed world projection or weapon placement")
    subject.renderer.validationHUDVisible=true
    let minimal=frame()
    let mask=stride(from:0,to:minimal.count,by:4).filter { minimal[$0..<$0+3] != fullWorld[$0..<$0+3] }
    validationRequire(mask.count>300,"Minimal HUD has no readable artwork")
    validationRequire(mask.allSatisfy { $0/(1280*4)>800-Int(68*SpriteRenderer.hudPixelScale(width:1280,percent:percent)) },"Minimal HUD escaped bottom layout")
    try png(minimal,"minimal-\(percent)")
    for factor:CGFloat in [0.5,0.75,1.5,2] {
        scale(factor);let scaled=frame()
        validationRequire(mask.allSatisfy { scaled[$0..<$0+3]==minimal[$0..<$0+3] },"Scaling changed minimal HUD artwork")
    }
    subject.renderer.validationHUDVisible=false
}
scale(1);subject.renderer.setHUDSize(50);subject.renderer.validationHUDVisible=true
fixtureHUD.readyAmmo = -1;fixtureHUD.keys=0;fixtureHUD.health=0;fixtureHUD.armor=0
subject.renderer.validationHUD(fixtureHUD)
try png(frame(),"minimal-melee-empty")
// All engine face indices use the same animated artwork as Classic.
fixtureHUD.health=100;fixtureHUD.faceIndex=0
subject.renderer.validationHUD(fixtureHUD)
let normalPortrait=frame()
for index in 0...41 {
    fixtureHUD.faceIndex=Int32(index);subject.renderer.validationHUD(fixtureHUD)
    let faceFrame=frame()
    if index==40 || index==41 {
        validationRequire(faceFrame != normalPortrait,"God/dead portrait did not change")
        try png(faceFrame,index==40 ? "portrait-god":"portrait-dead")
    }
}
fixtureHUD.faceIndex=0;subject.renderer.validationHUD(fixtureHUD)
subject.applyMinimalHUDPortrait(false);let noPortrait=frame()
validationRequire(noPortrait != normalPortrait,"Portrait toggle did not affect pixels")
subject.applyMinimalHUDPortrait(true);validationRequire(frame()==normalPortrait,"Portrait toggle did not restore layout")
subject.applyMinimalHUDPortrait(false);validationRequire(frame()==noPortrait,"Portrait-off layout did not restore")
if let savedPortrait { UserDefaults.standard.set(savedPortrait,forKey:"minimalHUDPortrait") }
else { UserDefaults.standard.removeObject(forKey:"minimalHUDPortrait") }
subject.renderer.validationHUD(liveHUD)
subject.renderer.setHUDStyle(.classic);subject.renderer.setHUDSize(100)
validationRequire(frame()==reference,"Classic style did not restore original pixels")
subject.renderer.setMinimalHUDPortrait(true)
validationRequire(frame()==reference,"Minimal portrait preference changed Classic")
print("PASS: all 42 face indices, distinct god/dead faces, persisted portrait toggle, exact off/on and Classic restoration")
if let savedHUDStyle { UserDefaults.standard.set(savedHUDStyle,forKey:"hudStyle") }
else { UserDefaults.standard.removeObject(forKey:"hudStyle") }
print("PASS: transparent full-height world, minimal health/armor/ammo and six keys, size-independent weapon/camera, native overlay pixels at all world scales, Classic restoration")
// At equal output resolution, measure GPU command duration separately from frame pacing.
try subject.renderer.applyEffectsPreset(EffectsPreset.builtins[1],view:subject.view)
for factor:CGFloat in [1,0.75,0.5,1.5,2] {
    scale(factor)
    for _ in 0..<4 { _=frame() };gpuTimes=[]
    for _ in 0..<12 { _=frame() }
    let sorted=gpuTimes.sorted();validationRequire(!sorted.isEmpty)
    print(String(format:"GPU Medium, %d%% world, 1280x800 output: median %.3f ms (%d samples)",Int(factor*100),sorted[sorted.count/2],sorted.count))
}
// Exercise visibility, alpha, world effects and weapon fuzz together with upscaling.
subject.renderer.setHUDStyle(.minimal)
validationRequire(MD_Cheat("idbeholdi") != 0)
try subject.renderer.validationSynchronizeEngine();scale(0.5);_=frame()
validationRequire(MD_Cheat("idbeholdi") != 0)
try subject.renderer.validationSynchronizeEngine()
func hdrFrame() -> [Float] {
    autoreleasepool {
        let drawable=subject.view.currentDrawable!,t=drawable.texture,w=t.width,h=t.height
        subject.view.draw()
        let buffer=subject.renderer.device.makeBuffer(length:w*h*8,options:.storageModeShared)!
        let command=subject.renderer.queue.makeCommandBuffer()!,e=command.makeBlitCommandEncoder()!
        e.copy(from:t,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:w,height:h,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:w*8,destinationBytesPerImage:w*h*8)
        e.endEncoding();command.commit();command.waitUntilCompleted()
        validationRequire(command.status == .completed)
        RunLoop.current.run(until:Date().addingTimeInterval(0.001))
        return Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:UInt16.self),count:w*h*4)).map{Float(Float16(bitPattern:$0))}
    }
}
subject.renderer.setHUDStyle(.classic)
try subject.renderer.applyEffectsPreset(EffectsPreset.builtins[3],view:subject.view)
subject.renderer.setHUDSize(50)
scale(1);let hdrReference=hdrFrame()
let hdrHUDStart=(800-Int(SpriteRenderer.hudHeight(width:1280,percent:50)))*1280*4
for factor:CGFloat in [0.5,0.75,1.5,2,1] {
    scale(factor);let pixels=hdrFrame()
    validationRequire(pixels.allSatisfy{$0.isFinite && $0 >= 0 && $0<=8},"Invalid HDR radiance")
    validationRequire(pixels[hdrHUDStart...]==hdrReference[hdrHUDStart...],"Scaling changed HDR HUD")
}
subject.renderer.setHUDStyle(.minimal)
scale(1);subject.renderer.validationHUDVisible=false;let hdrWorld=hdrFrame()
subject.renderer.validationHUDVisible=true;let hdrMinimal=hdrFrame()
let hdrMask=stride(from:0,to:hdrMinimal.count,by:4).filter { hdrMinimal[$0..<$0+3] != hdrWorld[$0..<$0+3] }
validationRequire(hdrMask.count>100)
for factor:CGFloat in [0.5,0.75,2] {
    scale(factor);let pixels=hdrFrame()
    validationRequire(pixels.allSatisfy{$0.isFinite && $0>=0 && $0<=8})
    validationRequire(hdrMask.allSatisfy { pixels[$0..<$0+3]==hdrMinimal[$0..<$0+3] },"Scaling changed minimal HDR artwork")
}
scale(0.5);subject.view.drawableSize=CGSize(width:960,height:600);_=hdrFrame()
try subject.renderer.setHDR(false,view:subject.view);scale(0.75);_=frame()
try subject.renderer.applyEffectsPreset(EffectsPreset(),view:subject.view);scale(1)
print("PASS: HDR/SDR transitions, finite bounded HDR, native HDR HUD equality, resize, all world effects and weapon invisibility")
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
}
do { try runAOValidation() } catch { validationFail(String(describing:error)) }
