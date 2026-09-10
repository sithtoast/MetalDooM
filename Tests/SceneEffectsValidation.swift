// SPDX-License-Identifier: GPL-2.0-or-later
// Inserted inside the existing real-GPU harness. Test actors use the original engine.
do {
try subject.renderer.setAmbientOcclusion(false)
try subject.renderer.setDynamicLight(false)
_ = try subject.renderer.load(wad:subject.wad!,map:subject.wad!.maps.contains("E1M1") ? "E1M1":"MAP01")
MD_TestMonsters(0)
MD_TestLightSource(0);MD_TestLightSource(1);MD_TestLightSource(2)
try subject.renderer.validationSynchronizeEngine()
_=frame()
let effectsKey=subject.benchmarkSettings
var snapshots=Array(repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,MD_GetPlayer().x,MD_GetPlayer().y)))
_ = MD_CopyThings(&snapshots,Int32(snapshots.count),MD_GetPlayer().x,MD_GetPlayer().y)
validationRequire(Set(snapshots.map(\.lightKind)).isSuperset(of:[1,4,6]),"Engine light source classification")
let fixtureHUD=MD_GetHUD(), fixtureEye=SIMD3(MD_GetPlayer().x,MD_GetPlayer().eyeZ,-MD_GetPlayer().y)
let sources=DynamicLightUniforms.gameplay(things:snapshots,hud:fixtureHUD,eye:fixtureEye,effects:[.torches,.projectiles])
validationRequire(sources.count>=3 && sources.count<=16)
validationRequire(DynamicLightUniforms.gameplay(things:snapshots,hud:fixtureHUD,eye:fixtureEye,effects:[]).isEmpty)
validationRequire(DynamicLightUniforms.gameplay(things:Array(repeating:snapshots.first { $0.lightKind==1 }!,count:100),hud:fixtureHUD,eye:fixtureEye,effects:[.torches]).count==16)
for effect in [SceneEffect.torches,.projectiles,.emissive,.bloom] {
    // MAP01 starts outdoors, away from any supported emitter material.
    // Inspect the original LITE5 doorway from inside its sector for emission.
    if effect == .emissive && subject.renderer.validationMapName=="MAP01" {
        subject.renderer.validationCamera(800,504,137,0,0)
    }
    let effectBaseline=frame()
    try subject.renderer.setSceneEffect(effect,enabled:true)
    let lit=frame()
    validationRequire(lit != effectBaseline,"\(effect.title) has no visible effect")
    validationRequire(lit[hudStart...]==effectBaseline[hudStart...],"\(effect.title) touched HUD")
    validationRequire(frame()==lit,"\(effect.title) unstable while paused")
    validationRequire(subject.benchmarkSettings != effectsKey)
    try png(lit,"effect-\(effect.rawValue)")
    try subject.renderer.setSceneEffect(effect,enabled:false)
    validationRequire(frame()==effectBaseline,"\(effect.title) failed exact restoration")
    try subject.renderer.validationSynchronizeEngine()
}
// Fire through authoritative game tics and sample while the pistol flash is active.
var flashed=false
for _ in 0..<40 {
    _=MD_CombatTick(0,0,0,0,1,-1)
    if MD_GetHUD().weaponFlash != 0 { flashed=true;break }
}
validationRequire(flashed,"Engine pistol did not enter flash state")
try subject.renderer.validationSynchronizeEngine()
let flashOff=frame()
try subject.renderer.setSceneEffect(.muzzleFlash,enabled:true)
let flashOn=frame()
validationRequire(flashOn != flashOff && flashOn[hudStart...]==flashOff[hudStart...],"Muzzle illumination/HUD isolation")
try png(flashOn,"effect-muzzle")
for _ in 0..<30 { _=MD_CombatTick(0,0,0,0,0,-1) }
try subject.renderer.validationSynchronizeEngine()
validationRequire(MD_GetHUD().weaponFlash==0)
let expired=frame()
try subject.renderer.setSceneEffect(.muzzleFlash,enabled:false)
validationRequire(frame()==expired,"Muzzle light outlived engine flash")
for effect in SceneEffect.allCases { try subject.renderer.setSceneEffect(effect,enabled:true) }
try subject.renderer.setAmbientOcclusion(true)
try subject.renderer.setDynamicLight(true)
let combined=frame(), shared=subject.renderer.ambientOcclusion!, builds=subject.renderer.ambientOcclusion!.buildCount
try png(combined,"effects-combined")
try subject.renderer.setSceneEffect(.shadows,enabled:false)
let unshadowed=frame()
for i in stride(from:0,to:hudStart,by:4) { for c in 0..<3 { validationRequire(combined[i+c]<=unshadowed[i+c],"Gameplay shadow brightened scene") } }
try subject.renderer.setSceneEffect(.shadows,enabled:true)
validationRequire(subject.renderer.ambientOcclusion === shared && shared.buildCount==builds,"Effect switches rebuilt geometry")
// Resolution changes exercise odd dimensions and texture replacement, then return.
subject.view.drawableSize=CGSize(width:641,height:403)
for _ in 0..<3 { _=frame() }
subject.view.drawableSize=CGSize(width:1280,height:800)
for _ in 0..<3 { _=frame() }
let resizedBack=frame()
if resizedBack != combined {
    print("Resize mismatch: \(resizedBack.count) bytes vs \(combined.count), view \(subject.view.drawableSize)")
    if resizedBack.count==combined.count { try png(resizedBack,"effects-resize-mismatch") }
}
validationRequire(resizedBack==combined,"Bloom failed resize round trip")
let effectsSave=output.appendingPathComponent("effects.mdsave")
try subject.renderer.saveGame(to:effectsSave,title:"All effects validation")
try subject.renderer.loadGame(from:effectsSave)
_=frame()
validationRequire(subject.renderer.sceneEffects.count==SceneEffect.allCases.count,"Save/load lost effect choices")
for effect in SceneEffect.allCases {
    let item=NSMenuItem(title:effect.title,action:#selector(App.toggleSceneEffect(_:)),keyEquivalent:"")
    item.tag=effect.rawValue
    validationRequire(subject.validateMenuItem(item) && item.state == .on,"Effect menu check state")
    subject.benchmark=BenchmarkRun(context:"effects",settings:subject.benchmarkSettings)
    validationRequire(!subject.validateMenuItem(item),"Effect mutable during benchmark")
    subject.benchmark=nil
}
// Fixed colormaps must override every added shading/postprocess effect.
for cheat in ["idbeholdv","idbeholdl"] {
    validationRequire(MD_Cheat(cheat) != 0)
    _=MD_Tick(0,0,0,0);try subject.renderer.validationSynchronizeEngine()
    validationRequire(MD_GetHUD().fixedColorMap != 0)
    let powered=frame()
    for effect in SceneEffect.allCases { try subject.renderer.setSceneEffect(effect,enabled:false) }
    try subject.renderer.setAmbientOcclusion(false);try subject.renderer.setDynamicLight(false)
    validationRequire(frame()==powered,"Added effects changed fixed-colormap powerup")
    for effect in SceneEffect.allCases { try subject.renderer.setSceneEffect(effect,enabled:true) }
    try subject.renderer.setAmbientOcclusion(true);try subject.renderer.setDynamicLight(true)
    validationRequire(MD_Cheat(cheat) != 0)
    _=MD_Tick(0,0,0,0);try subject.renderer.validationSynchronizeEngine()
}
validationRequire(MD_Cheat("idbeholdi") != 0)
_=MD_Tick(0,0,0,0);try subject.renderer.validationSynchronizeEngine()
let invisible=frame()
validationRequire(frame()==invisible,"Fuzz/bloom unstable while paused")
try subject.renderer.setSceneEffect(.bloom,enabled:false)
validationRequire(frame()[hudStart...]==invisible[hudStart...],"Fuzz/bloom changed HUD")
try subject.renderer.setSceneEffect(.bloom,enabled:true)
validationRequire(MD_Cheat("idbeholdi") != 0)
_=MD_Tick(0,0,0,0);try subject.renderer.validationSynchronizeEngine()
print("PASS: invulnerability/light amplification override effects; invisibility and bloom render together")
for _ in 0..<8 { _=frame() }
gpuTimes=[]
for _ in 0..<32 { _=frame() }
print("All effects GPU command mean: \(gpuTimes.reduce(0,+)/Double(gpuTimes.count)) ms at 1280x800; \(gpuTimes.count) samples")
// Keep all effects on for the following map transition and shutdown checks.
print("PASS: independent torch/projectile/emissive/bloom GPU changes, real pistol flash/expiry, pause, HUD isolation, exact restoration, light budget, shared mesh, resize, save/load and benchmark lock")

}
