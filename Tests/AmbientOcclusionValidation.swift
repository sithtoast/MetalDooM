// SPDX-License-Identifier: GPL-2.0-or-later
// Combined with App by test-ambient-occlusion.sh. Real GPU rendering, fixed scene.
setbuf(stdout,nil)
func pumpEvents(_ seconds: Double) {
    let end=Date().addingTimeInterval(seconds)
    while Date()<end {
        if let event=NSApp.nextEvent(matching:.any,until:end,inMode:.default,dequeue:true) { NSApp.sendEvent(event) }
        RunLoop.current.run(until:Date().addingTimeInterval(0.001))
    }
}
let application=NSApplication.shared
application.setActivationPolicy(.regular)
let subject=App()
subject.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
precondition(subject.wad != nil)
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
subject.renderer.onWarning={ fatalError($0) }
subject.renderer.onError={ fatalError("\($0)") }
MD_TestMonsters(0)

func frame() -> [UInt8] {
    autoreleasepool {
        guard let drawable=subject.view.currentDrawable else { fatalError("No drawable") }
        let texture=drawable.texture, width=texture.width, height=texture.height
        subject.view.draw()
        let queue=subject.renderer.queue
        let buffer=subject.renderer.device.makeBuffer(length:width*height*4,options:.storageModeShared)!
        let command=queue.makeCommandBuffer()!, encoder=command.makeBlitCommandEncoder()!
        encoder.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:width*4,destinationBytesPerImage:width*height*4)
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        precondition(command.status == .completed,"Readback failed: \(String(describing:command.error))")
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
precondition(!subject.renderer.ambientOcclusionEnabled)
let classic=try measure(false)
let occluded=try measure(true)
let ao=subject.renderer.ambientOcclusion!
precondition(ao.triangleCount>0 && ao.buildCount==1,"Paused geometry should build once")
let repeated=frame()
precondition(repeated==occluded,"AO should be stable in a paused scene")
let restored=try measure(false)
precondition(restored==classic,"Disabling AO must exactly restore classic pixels")
let hudStart=(800-Int(SpriteRenderer.hudHeight(width:1280)))*1280*4
precondition(classic[hudStart...]==occluded[hudStart...],"AO changed HUD")
let changed=stride(from:0,to:hudStart,by:4).filter { classic[$0] != occluded[$0] || classic[$0+1] != occluded[$0+1] || classic[$0+2] != occluded[$0+2] }.count
precondition(changed>1000,"AO did not visibly affect world surfaces")
for i in stride(from:0,to:hudStart,by:4) { for c in 0..<3 { precondition(occluded[i+c]<=classic[i+c],"AO unexpectedly brightened pixel") } }
try png(classic,"classic");try png(occluded,"ao")
print("PASS: \(changed) world pixels shaded; HUD unchanged; stable paused pixels; disabling AO restores identical classic image")
// Open a real original door and verify the same renderer rebuilds the ray mesh.
if subject.wad!.maps.contains("E1M1") {
    try subject.renderer.setAmbientOcclusion(true)
    var x:Float=0,y:Float=0,angle:Float=0,sector:Int32=0
    precondition(MD_TestDoor(0,&x,&y,&angle,&sector)>=0)
    precondition(MD_TestPlacePlayer(x,y,angle) != 0)
    let closed=MD_GetSector(sector).ceiling
    _ = frame()
    let builds=subject.renderer.ambientOcclusion!.buildCount
    application.activate(ignoringOtherApps:true);subject.window.makeKeyAndOrderFront(nil)
    pumpEvents(0.2)
    precondition(application.isActive && subject.window.isKeyWindow,"Native test window must have focus")
    subject.renderer.paused=false
    subject.view.useQueued=true
    for _ in 0..<25 { RunLoop.current.run(until:Date().addingTimeInterval(0.04)); _ = frame() }
    subject.renderer.paused=true
    precondition(MD_GetSector(sector).ceiling>closed,"Original door did not open")
    precondition(subject.renderer.ambientOcclusion!.buildCount>builds,"Door movement did not update ray geometry")
    let settled=subject.renderer.ambientOcclusion!.buildCount
    for _ in 0..<4 { _ = frame() }
    precondition(subject.renderer.ambientOcclusion!.buildCount==settled,"Paused door rebuilds unnecessarily")
    try png(frame(),"door-ao")
    print("PASS: original door opens, AO mesh rebuilds during motion and stops rebuilding when paused")
}
// Exercise map replacement with an enabled acceleration structure, then shutdown
// while GPU work/resources have existed. One engine WAD stack remains in use.
try subject.renderer.setAmbientOcclusion(true)
_ = frame()
let oldBuilds=subject.renderer.ambientOcclusion!.buildCount
let nextMap=subject.wad!.maps.contains("E1M2") ? "E1M2":"MAP02"
_ = try subject.renderer.load(wad:subject.wad!,map:nextMap)
_ = frame()
precondition(subject.renderer.ambientOcclusion!.buildCount>oldBuilds)
print("PASS: enabled AO rebuilds after map replacement")
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.window.performClose(nil)
RunLoop.current.run(until:Date().addingTimeInterval(0.1))
print("PASS: AO resources survive queued frames and clean shutdown")
