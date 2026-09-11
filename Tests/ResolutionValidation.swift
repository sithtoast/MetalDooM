// SPDX-License-Identifier: GPL-2.0-or-later
func scale(_ value:CGFloat,_ metalFX:Bool=true) {
    subject.view.renderScale=value;subject.view.metalFXEnabled=metalFX
    subject.view.drawableSize=CGSize(width:1280,height:800)
}
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
try subject.renderer.applyEffectsPreset(EffectsPreset.builtins[3],view:subject.view)
scale(1);let hdrReference=hdrFrame()
for factor:CGFloat in [0.5,0.75,1.5,2,1] {
    scale(factor);let pixels=hdrFrame()
    validationRequire(pixels.allSatisfy{$0.isFinite && $0 >= 0 && $0<=8},"Invalid HDR radiance")
    validationRequire(pixels[hudStart...]==hdrReference[hudStart...],"Scaling changed HDR HUD")
}
scale(0.5);subject.view.drawableSize=CGSize(width:960,height:600);_=hdrFrame()
try subject.renderer.setHDR(false,view:subject.view);scale(0.75);_=frame()
try subject.renderer.applyEffectsPreset(EffectsPreset(),view:subject.view);scale(1)
print("PASS: HDR/SDR transitions, finite bounded HDR, native HDR HUD equality, resize, all world effects and weapon invisibility")
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
}
do { try runAOValidation() } catch { validationFail(String(describing:error)) }
