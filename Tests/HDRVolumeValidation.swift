// SPDX-License-Identifier: GPL-2.0-or-later
// Part of the native GPU harness. SDR tests above retain their byte-exact contract.
do {
let renderer=subject.renderer!
try validateWorldSampling(device:renderer.device,queue:renderer.queue)
try renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
_ = try renderer.load(wad:subject.wad!,map:subject.wad!.maps.contains("E1M1") ? "E1M1":"MAP01")
MD_TestMonsters(0);MD_TestLightSource(0)
try renderer.validationSynchronizeEngine()
for _ in 0..<3 { _=frame() }
let classic=frame()
try renderer.setSceneEffect(.textureFiltering,enabled:true)
let filtered=frame()
validationRequire(filtered != classic,"World filtering did not change the scene")
validationRequire(filtered[hudStart...]==classic[hudStart...],"Filtering changed HUD pixels")
validationRequire(frame()==filtered,"Filtering is unstable while paused")
try png(filtered,"polish-filtered-world")
try renderer.setSceneEffect(.textureFiltering,enabled:false)
validationRequire(frame()==classic,"Filtering failed exact Classic restoration")
try renderer.applyEffectsPreset(EffectsPreset.builtins[1],view:subject.view)
for _ in 0..<3 { _=frame() }
try png(frame(),"polish-enhanced")
try renderer.applyEffectsPreset(EffectsPreset.builtins[2],view:subject.view)
for _ in 0..<3 { _=frame() }
try png(frame(),"polish-atmospheric")
try renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
for _ in 0..<3 { _=frame() }
try renderer.setSceneEffect(.volumetrics,enabled:true)
validationRequire(frame()==classic,"Volumetrics invented a light source")
try renderer.setDynamicLight(true)
try renderer.setSceneEffect(.volumetrics,enabled:false)
let lightOnly=frame()
try renderer.setSceneEffect(.volumetrics,enabled:true)
let fog=frame()
let qualityMesh=renderer.ambientOcclusion!,qualityBuilds=renderer.ambientOcclusion!.buildCount
renderer.setHighRayQuality(true)
let highFog=frame()
validationRequire(frame()==highFog,"High ray quality is unstable")
validationRequire(highFog[hudStart...]==fog[hudStart...],"Ray quality changed HUD")
validationRequire(qualityMesh.buildCount==qualityBuilds,"Ray quality rebuilt world geometry")
renderer.setHighRayQuality(false)
validationRequire(frame()==fog,"Balanced quality did not restore exact pixels")
validationRequire(fog != lightOnly,"Volumetric light is invisible")
validationRequire(fog[hudStart...]==lightOnly[hudStart...],"Fog affected HUD")
validationRequire(frame()==fog,"Paused fog flickers")
renderer.setFogDensity(0)
validationRequire(frame()==lightOnly,"Zero density is not an exact bypass")
renderer.setFogDensity(0.003)
validationRequire(frame()==fog,"Fog density restoration failed")
try png(fog,"volumetric-test-light")
try renderer.setSceneEffect(.volumetrics,enabled:false)
validationRequire(frame()==lightOnly,"Fog toggle does not restore scene")
try renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
for _ in 0..<3 { _=frame() }
validationRequire(frame()==classic,"Classic preset failed exact restoration")
validationRequire(!NSWindow.allowsAutomaticWindowTabbing && subject.window.tabbingMode == .disallowed,"Automatic window tabs still enabled")

func hdrFrame() -> [Float] {
    autoreleasepool {
        guard let drawable=subject.view.currentDrawable else { validationFail("No HDR drawable") }
        let texture=drawable.texture,w=texture.width,h=texture.height
        validationRequire(texture.pixelFormat == .rgba16Float,"HDR drawable is not floating point")
        subject.view.draw()
        let buffer=renderer.device.makeBuffer(length:w*h*8,options:.storageModeShared)!
        let command=renderer.queue.makeCommandBuffer()!,copy=command.makeBlitCommandEncoder()!
        copy.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:w,height:h,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:w*8,destinationBytesPerImage:w*h*8)
        copy.endEncoding();command.commit();command.waitUntilCompleted()
        validationRequire(command.status == .completed,"HDR readback failed")
        RunLoop.current.run(until:Date().addingTimeInterval(0.001))
        let values=buffer.contents().assumingMemoryBound(to:Float16.self)
        return (0..<w*h*4).map { Float(values[$0]) }
    }
}

// An opaque partition must block scattering even when the viewing ray is clear.
// This exercises the production march and resolve, not a duplicate shadow equation.
do {
    let ao=try AmbientOcclusion(device:renderer.device,shader:renderer.validationWorldShader,format:.rgba16Float)
    let volume=try VolumetricLighting(device:renderer.device,shader:renderer.validationWorldShader,format:.rgba16Float)
    let points:[SIMD3<Float>]=[SIMD3(0,-100,-100),SIMD3(0,100,-100),SIMD3(0,100,100),SIMD3(0,-100,-100),SIMD3(0,100,100),SIMD3(0,-100,100)]
    let mesh=AOGeometry(vertices:points.map { AOVertex(position:SIMD4($0,1),uv:.zero) },opaque:true)
    let alpha=renderer.device.makeBuffer(length:1,options:.storageModeShared)!
    alpha.contents().storeBytes(of:UInt8(255),as:UInt8.self)
    let depthDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:16,height:16,mipmapped:false)
    depthDescriptor.storageMode = .private;depthDescriptor.usage = [.renderTarget,.shaderRead]
    let depth=renderer.device.makeTexture(descriptor:depthDescriptor)!
    let targetDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:16,height:16,mipmapped:false)
    targetDescriptor.storageMode = .shared;targetDescriptor.usage = [.renderTarget,.shaderRead]
    let target=renderer.device.makeTexture(descriptor:targetDescriptor)!
    var inverse=matrix_identity_float4x4
    inverse.columns.0.x=0.1;inverse.columns.1.y=0.1;inverse.columns.2.z=20;inverse.columns.3.x = -1
    func scattering(_ shadows:Bool) throws -> Float {
        let command=renderer.queue.makeCommandBuffer()!
        try ao.prepare(geometry:[mesh],device:renderer.device,command:command)
        try ao.updateMaterials([SIMD4(0,1,1,0)],device:renderer.device)
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=target;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .store;pass.depthAttachment.clearDepth=0.5
        command.makeRenderCommandEncoder(descriptor:pass)!.endEncoding()
        let light=DynamicLightUniforms(positionRadius:SIMD4(5,0,5,30),colorIntensity:SIMD4(1,0.4,0.1,5),options:SIMD4(shadows ? 1:0,0,0,0))
        try volume.prepare(command:command,depth:depth,worldHeight:16,inverse:inverse,eye:SIMD3(-1,0,0),lights:[light],ao:ao,alpha:alpha,density:0.01)
        pass.colorAttachments[0].loadAction = .load;pass.depthAttachment.loadAction = .load
        let encoder=command.makeRenderCommandEncoder(descriptor:pass)!
        volume.draw(encoder:encoder);encoder.endEncoding();command.commit();command.waitUntilCompleted()
        validationRequire(command.status == .completed,"Volumetric partition probe failed")
        var pixels=[Float16](repeating:0,count:16*16*4)
        target.getBytes(&pixels,bytesPerRow:16*8,from:MTLRegionMake2D(0,0,16,16),mipmapLevel:0)
        return stride(from:0,to:pixels.count,by:4).map { Float(pixels[$0]) }.reduce(0,+)
    }
    let open=try scattering(false),blocked=try scattering(true)
    validationRequire(open>1 && blocked==0,"Volumetric scattering leaked through an opaque partition: \(open) vs \(blocked)")
    print("PASS: production volumetric rays are fully blocked by an opaque partition; shadow bypass restores scattering")
}

// Exercise display mapping independently of changing macOS display headroom.
let outputMapper=try HDROutput(device:renderer.device)
let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:8,height:1,mipmapped:false)
d.storageMode = .shared;d.usage = [.shaderRead,.renderTarget]
let source=renderer.device.makeTexture(descriptor:d)!,target=renderer.device.makeTexture(descriptor:d)!
let inputs:[Float]=[0,0.02,0.25,0.5,0.75,1,1.01,4]
var pixels=inputs.flatMap { [Float16($0),Float16($0),Float16($0),Float16(1)] }
pixels.withUnsafeBytes { source.replace(region:MTLRegionMake2D(0,0,8,1),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:64) }
for headroom:Float in [1,2,4,8] {
    let command=renderer.queue.makeCommandBuffer()!
    outputMapper.present(command:command,source:source,target:target,headroom:headroom,peak:8)
    command.commit();command.waitUntilCompleted()
    validationRequire(command.status == .completed,"EDR mapping command failed")
    target.getBytes(&pixels,bytesPerRow:64,from:MTLRegionMake2D(0,0,8,1),mipmapLevel:0)
    let values=(0..<8).map { Float(pixels[$0*4]) }
    validationRequire(values.allSatisfy { $0.isFinite && $0>=0 && $0<=headroom },"EDR exceeded live headroom")
    validationRequire(abs(values[3]-0.21404)<0.001 && values[5]==1,"SDR transfer or standard white changed")
    validationRequire(zip(values,values.dropFirst()).allSatisfy { $0 <= $1 },"EDR mapping not monotonic")
    if headroom>1 {
        validationRequire(values[6]>1 && values[7]>values[6],"HDR highlights clipped to SDR")
        validationRequire(values[6]<1.03,"HDR peak amplifies fine highlight contrast")
    }
}
print("PASS: linear EDR transfer, unclipped highlights, monotonic shoulder and 1x/2x/4x/8x headroom limits")

let legacyData=Data("{\"effects\":[],\"ao\":false,\"testLight\":false,\"testShadows\":true,\"hdr\":false,\"strength\":0.5,\"radius\":48,\"density\":0.003,\"peak\":4}".utf8)
let legacyPreset=try JSONDecoder().decode(EffectsPreset.self,from:legacyData)
validationRequire(legacyPreset.highRayQuality==nil && legacyPreset.lightGain==nil && legacyPreset.bloomStrength==nil && legacyPreset.hdrSpriteBoost==nil,"Legacy custom presets failed to decode")
let savedCustom=UserDefaults.standard.data(forKey:"customEffectsPreset.v1")
defer {
    if let savedCustom { UserDefaults.standard.set(savedCustom,forKey:"customEffectsPreset.v1") }
    else { UserDefaults.standard.removeObject(forKey:"customEffectsPreset.v1") }
}
try renderer.applyEffectsPreset(EffectsPreset.builtins[3],view:subject.view)
validationRequire(subject.effectsPresetName=="Medium HDR")
validationRequire((subject.view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent == true)
for _ in 0..<3 { _=hdrFrame() }
let hdr=hdrFrame()
validationRequire(hdr.allSatisfy { $0.isFinite && $0>=0 },"Nonfinite HDR pixels")
let headroom=Float(subject.window.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1)
let maximum=hdr.max()!
validationRequire(maximum<=max(1,min(headroom,renderer.hdrPeak))+0.01,"Frame exceeds requested/display peak")
validationRequire(hdr[hudStart...].allSatisfy { $0<=1 },"HUD exceeds standard white")
for i in stride(from:hudStart,to:hdr.count,by:4) {
    for channel in 0..<3 {
        let value=Float(classic[i+2-channel])/255
        let linear=value<=0.04045 ? value/12.92:pow((value+0.055)/1.055,2.4)
        validationRequire(abs(hdr[i+channel]-linear)<0.002,"HDR altered HUD colors")
    }
}
print("HDR live display: current headroom \(headroom)x, potential \(subject.window.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1)x; drawable maximum \(maximum)")
// Native key-equivalent dispatch exercises the actual menu shortcut, not only the action.
guard let appMenu=NSApp.mainMenu,
      let shortcutMenu=appMenu.items.compactMap(\.submenu).first(where: { $0.title=="View" }),
      let shortcutItem=shortcutMenu.items.first(where: { $0.action == #selector(App.toggleClassicMedium) }) else {
    validationFail("Missing native preset shortcut menu")
}
validationRequire(shortcutItem.keyEquivalent=="e" && shortcutItem.keyEquivalentModifierMask==[.command,.shift],"Wrong preset shortcut")
let shortcut=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.command,.shift],timestamp:0,
    windowNumber:subject.window.windowNumber,context:nil,characters:"E",charactersIgnoringModifiers:"e",isARepeat:false,keyCode:14)!
let untouchedCustom=UserDefaults.standard.data(forKey:"customEffectsPreset.v1")
let shortcutScale=subject.view.renderScale,shortcutFPS=subject.view.preferredFramesPerSecond
for expected in ["Classic","Medium","Classic","Medium"] {
    validationRequire(appMenu.performKeyEquivalent(with:shortcut),"Preset shortcut was not handled")
    validationRequire(subject.effectsPresetName==expected && renderer.pickupMessage=="Effects: \(expected)","Shortcut or preset notice failed")
    validationRequire(subject.view.renderScale==shortcutScale && subject.view.preferredFramesPerSecond==shortcutFPS,"Shortcut changed graphics settings")
    for _ in 0..<3 { _=frame() }
}
subject.view.useQueued=false
subject.view.keyDown(with:shortcut)
validationRequire(!subject.view.useQueued && !subject.view.keys.contains(14),"Command shortcut leaked into gameplay Use")
subject.benchmark=BenchmarkRun(context:"preset shortcut",settings:subject.benchmarkSettings)
validationRequire(!subject.validateMenuItem(shortcutItem),"Preset shortcut enabled during benchmark")
subject.toggleClassicMedium()
validationRequire(subject.effectsPresetName=="Medium","Shortcut action bypassed benchmark lock")
subject.benchmark=nil
validationRequire(UserDefaults.standard.data(forKey:"customEffectsPreset.v1")==untouchedCustom,"Shortcut overwrote saved custom preset")
print("PASS: Classic/Medium native key equivalent, repeated switching, notice, graphics/custom preservation, gameplay input isolation and benchmark lock")
// Navigate the actual pause menu. Highlighting explains a preset without applying it.
subject.openGameMenu()
func menuButtons(_ view:NSView) -> [NSButton] {
    view.subviews.flatMap { child in (child as? NSButton).map { [$0] } ?? menuButtons(child) }
}
func menuCanvas(_ view:NSView) -> ClassicMenuCanvas? {
    if let canvas=view as? ClassicMenuCanvas { return canvas }
    return view.subviews.compactMap(menuCanvas).first
}
func pressMenuButton(_ title:String) {
    guard let menu=subject.gameMenu, let button=menuButtons(menu).first(where: { $0.title==title }) else { validationFail("Missing in-game row: \(title)") }
    button.performClick(nil)
}
pressMenuButton("Options");pressMenuButton("Effects")
guard let gameMenu=subject.gameMenu, let effectsCanvas=menuCanvas(gameMenu) else { validationFail("Missing in-game effects canvas") }
validationRequire(gameMenu.page=="Effects" && effectsCanvas.items.dropLast().map(\.title)==EffectsPreset.names,"In-game names or route differ")
func effectsKey(_ code:UInt16) -> NSEvent {
    NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:subject.window.windowNumber,
        context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:code)!
}
validationRequire(effectsCanvas.selected==1,"Active preset not initially selected")
_ = gameMenu.handleKey(effectsKey(125))
validationRequire(subject.effectsPresetName=="Medium" && effectsCanvas.selected==2,"Highlight applied preset early")
validationRequire(effectsCanvas.labels.contains(where: { $0.0==EffectsPreset.descriptions[2][0] }),"Description did not follow keyboard selection")
validationRequire(menuButtons(gameMenu).first(where: { $0.title=="High" })?.accessibilityHelp()==EffectsPreset.descriptions[2].joined(separator:" "),"Missing accessible preset explanation")
_ = gameMenu.handleKey(effectsKey(36))
validationRequire(subject.effectsPresetName=="High" && effectsCanvas.items[2].value?()=="ACTIVE","Enter did not apply High")
pressMenuButton("Medium HDR")
validationRequire(subject.effectsPresetName=="Medium HDR" && renderer.hdrEnabled && renderer.paused,"In-game HDR switch failed or unpaused game")
subject.benchmark=BenchmarkRun(context:"in-game presets",settings:subject.benchmarkSettings)
pressMenuButton("Classic")
validationRequire(subject.effectsPresetName=="Medium HDR" && effectsCanvas.labels.contains(where: { $0.0=="Wait for the benchmark to finish." }),"In-game preset bypassed benchmark lock or hid reason")
subject.benchmark=nil
pressMenuButton("Classic")
validationRequire(subject.effectsPresetName=="Classic" && !renderer.hdrEnabled,"In-game Classic did not leave HDR")
validationRequire(subject.view.renderScale==shortcutScale && subject.view.preferredFramesPerSecond==shortcutFPS && UserDefaults.standard.data(forKey:"customEffectsPreset.v1")==untouchedCustom,"In-game presets changed graphics or saved custom")
renderer.setLightGain(2);effectsCanvas.onRefresh?()
validationRequire(effectsCanvas.labels.contains(where: { $0.0=="CURRENT: Custom" }),"Manual override left stale in-game status")
pressMenuButton("Classic")
_ = gameMenu.handleKey(effectsKey(53))
validationRequire(gameMenu.page=="Options","Effects Escape did not return to Options")
subject.closeGameMenu();renderer.paused=true
for _ in 0..<3 { _=frame() }
print("PASS: in-game effects route, names, highlight descriptions/accessibility, explicit keyboard/mouse apply, paused HDR/SDR switching, benchmark lock, graphics/custom preservation and Back")

// Exercise the real menu routing: Ludicrous must not steal Saved Custom's tag.
let effectsMenu=NSMenu(title:"Validation graphics");subject.addGraphicsMenus(to:effectsMenu)
let presetsMenu=effectsMenu.items.first { $0.title=="Effects Presets" }!.submenu!
let ludicrousItem=presetsMenu.items.first { $0.title=="Ludicrous" }!
let customItem=presetsMenu.items.first { $0.title=="Apply Saved Custom" }!
validationRequire(ludicrousItem.tag != customItem.tag,"Ludicrous collides with Saved Custom")
subject.selectEffectsPreset(ludicrousItem)
validationRequire(subject.effectsPresetName=="Ludicrous" && renderer.highRayQuality,"Ludicrous preset not applied")
validationRequire(renderer.aoSettings.strength==0.5 && renderer.aoSettings.radius==48 && renderer.fogDensity==0.003 && renderer.hdrPeak==8,"Ludicrous budgets not restored")
validationRequire(renderer.lightGain==2 && renderer.bloomStrength==0.3 && renderer.hdrSpriteBoost,"Ludicrous intensities not applied")
for _ in 0..<3 { _=hdrFrame() }
let ludicrous=hdrFrame()
validationRequire(ludicrous.allSatisfy { $0.isFinite && $0>=0 && $0<=8.01 },"Ludicrous exceeds display headroom")
validationRequire(ludicrous[hudStart...]==hdr[hudStart...],"Ludicrous changed HUD")
// Live display headroom can change between frames; hold the output ceiling
// at standard white for deterministic pixel comparisons below.
renderer.setHDRPeak(1)
for _ in 0..<3 { _=hdrFrame() }
let steadyLudicrous=hdrFrame()
validationRequire(hdrFrame()==steadyLudicrous,"Paused Ludicrous is unstable")
// Isolate each restored control in a deterministic lit scene.
try renderer.setDynamicLight(true)
renderer.setLightGain(1)
let mild=hdrFrame(),baseLights=renderer.validationSelectedLights
renderer.setLightGain(2)
let strong=hdrFrame(),strongLights=renderer.validationSelectedLights
validationRequire(mild != strong && mild[hudStart...]==strong[hudStart...],"Added light strength has no world-only effect")
validationRequire(zip(baseLights,strongLights).allSatisfy { $1.colorIntensity.w == $0.colorIntensity.w*2 },"Light gain did not scale all sources")
renderer.setBloomStrength(0)
let noBloom=hdrFrame()
renderer.setBloomStrength(0.3)
validationRequire(hdrFrame() != noBloom,"Restored bloom strength is ineffective")
MD_TestLightSource(1);try renderer.validationSynchronizeEngine()
renderer.setHDRSpriteBoost(false)
let noBoost=hdrFrame()
renderer.setHDRSpriteBoost(true)
let boost=hdrFrame()
validationRequire(boost != noBoost && boost[hudStart...]==noBoost[hudStart...],"HDR sprite boost has no world-only effect")
renderer.setLightGain(.nan);renderer.setBloomStrength(.infinity)
validationRequire(renderer.lightGain==1 && renderer.bloomStrength==0.12,"Invalid strengths escaped sanitization")
try renderer.applyEffectsPreset(EffectsPreset.builtins[3],view:subject.view)
validationRequire(subject.effectsPresetName=="Medium HDR" && !renderer.hdrSpriteBoost && renderer.lightGain==1 && renderer.bloomStrength==0.12,"Medium HDR did not reset Ludicrous intensities")
renderer.setLightGain(2);renderer.setBloomStrength(0.3);renderer.setHDRSpriteBoost(true)
renderer.setHDRPeak(8);renderer.setFogDensity(0.006)
validationRequire(subject.effectsPresetName=="Custom","Manual adjustments leave stale preset checkmark")
renderer.setHighRayQuality(true)
subject.saveEffectsPreset()
let custom=EffectsPreset(renderer:renderer)
validationRequire(subject.savedEffectsPreset==custom,"Custom preset persistence failed")
try renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
subject.selectEffectsPreset(customItem)
validationRequire(EffectsPreset(renderer:renderer)==custom,"Custom preset restore failed")
for _ in 0..<3 { _=hdrFrame() }
let old=subject.view.drawableSize
subject.view.drawableSize=CGSize(width:641,height:403)
for _ in 0..<3 { _=hdrFrame() }
validationRequire(hdrFrame().count==641*403*4,"HDR resize failed")
subject.view.drawableSize=old
for _ in 0..<3 { _=hdrFrame() }
let save=output.appendingPathComponent("hdr-volume.mdsave")
try renderer.saveGame(to:save,title:"HDR volume validation")
try renderer.loadGame(from:save)
validationRequire(EffectsPreset(renderer:renderer)==custom,"HDR settings lost on save/load")
_=hdrFrame()
for _ in 0..<2 {
    try renderer.setHDR(false,view:subject.view)
    for _ in 0..<3 { _=frame() }
    try renderer.setHDR(true,view:subject.view)
    for _ in 0..<3 { _=hdrFrame() }
}
try renderer.applyEffectsPreset(EffectsPreset(),view:subject.view)
for _ in 0..<3 { _=frame() }
validationRequire(subject.view.colorPixelFormat == .bgra8Unorm && !renderer.hdrEnabled)
validationRequire((subject.view.layer as? CAMetalLayer)?.wantsExtendedDynamicRangeContent == false)
do {
    let defaults=UserDefaults.standard,scale=subject.view.renderScale,fps=subject.view.preferredFramesPerSecond,size=subject.view.drawableSize
    let savedScale=defaults.object(forKey:"renderScale"),savedFPS=defaults.object(forKey:"frameLimit")
    defer {
        subject.view.renderScale=scale;subject.view.preferredFramesPerSecond=fps;subject.view.drawableSize=size
        if let savedScale { defaults.set(savedScale,forKey:"renderScale") } else { defaults.removeObject(forKey:"renderScale") }
        if let savedFPS { defaults.set(savedFPS,forKey:"frameLimit") } else { defaults.removeObject(forKey:"frameLimit") }
    }
    for i in App.graphicsPresets.indices {
        let item=NSMenuItem(title:"Graphics",action:#selector(App.selectGraphicsPreset(_:)),keyEquivalent:"");item.tag=i
        subject.selectGraphicsPreset(item)
        let (expectedScale,expectedFPS)=App.graphicsPresets[i]
        validationRequire(subject.view.renderScale==expectedScale && subject.view.preferredFramesPerSecond==expectedFPS,"Graphics preset was not applied")
        validationRequire(defaults.double(forKey:"renderScale")==Double(expectedScale) && defaults.integer(forKey:"frameLimit")==expectedFPS,"Graphics preset was not remembered")
        validationRequire(subject.validateMenuItem(item) && item.state == .on,"Graphics preset checkmark is stale")
        validationRequire(subject.effectsPresetName=="Classic","Graphics preset changed effects")
    }
}
for _ in 0..<3 { _=frame() }
let visibleSize=subject.view.drawableSize
subject.view.isPaused=false;subject.window.miniaturize(nil);pumpEvents(0.1)
let hiddenFrames=renderer.renderedFrames
for _ in 0..<5 { renderer.draw(in:subject.view) }
validationRequire(renderer.renderedFrames==hiddenFrames,"Minimized window still submits GPU frames")
subject.view.isPaused=true;subject.window.deminiaturize(nil);subject.window.makeKeyAndOrderFront(nil)
pumpEvents(0.1);subject.view.drawableSize=visibleSize
for _ in 0..<3 { _=frame() }
print("PASS: Ludicrous menu routing, restored intensity pixels, HUD/EDR bounds, legacy and custom intensity restoration")
print("PASS: ray quality stability/restoration/HUD/mesh reuse, legacy custom presets, and minimized-window GPU suppression")
print("PASS: volumetric sources/density/toggles/HUD/pause, Medium HDR/custom presets, live EDR output, resize, save/load, repeated HDR/SDR switching, graphics preset persistence/checkmarks, and disabled window tabs")
}
