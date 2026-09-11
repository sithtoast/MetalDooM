// SPDX-License-Identifier: GPL-2.0-or-later
// Runs in the native GPU harness after existing effects checks.
do {
for effect in SceneEffect.allCases { try subject.renderer.setSceneEffect(effect,enabled:false) }
try subject.renderer.setAmbientOcclusion(false);try subject.renderer.setDynamicLight(false)
_ = try subject.renderer.load(wad:subject.wad!,map:subject.wad!.maps.contains("E1M1") ? "E1M1":"MAP01")
MD_TestMonsters(0);MD_TestLightSource(0);MD_TestTarget(11,144)
try subject.renderer.validationSynchronizeEngine()
let baseline=frame(), key=subject.benchmarkSettings
try subject.renderer.setSceneEffect(.spriteLighting,enabled:true)
validationRequire(frame()==baseline,"Sprite lighting created light without a source")
try subject.renderer.setDynamicLight(true)
try subject.renderer.setSceneEffect(.spriteLighting,enabled:false)
let worldOnly=frame()
try subject.renderer.setSceneEffect(.spriteLighting,enabled:true)
let litSprites=frame()
validationRequire(litSprites != worldOnly,"Monster did not receive dynamic light")
validationRequire(litSprites[hudStart...]==worldOnly[hudStart...],"Sprite lighting changed HUD")
validationRequire(frame()==litSprites,"Sprite lighting unstable while paused")
try png(litSprites,"advanced-sprite-lighting")
try subject.renderer.setSceneEffect(.spriteLighting,enabled:false)
validationRequire(frame()==worldOnly,"Sprite toggle failed exact restoration")
try subject.renderer.setDynamicLight(false)
validationRequire(frame()==baseline)

// Surface lighting is independent of the self-emissive material switch.
if subject.renderer.validationMapName=="MAP01" { subject.renderer.validationCamera(800,504,137,0,0) }
else { subject.renderer.validationCamera(2848,-2960,17,-Float.pi/2,0.2) }
let surfaceOff=frame()
try subject.renderer.setSceneEffect(.surfaceLighting,enabled:true)
let surfaceOn=frame()
validationRequire(!subject.renderer.validationSurfaceLights.isEmpty,"No emissive patches extracted")
validationRequire(!subject.renderer.sceneEffects.contains(.emissive))
let surfacePixels=stride(from:0,to:hudStart,by:4).filter { surfaceOn[$0] != surfaceOff[$0] || surfaceOn[$0+1] != surfaceOff[$0+1] || surfaceOn[$0+2] != surfaceOff[$0+2] }.count
print("Surface lighting: \(surfacePixels) world pixels changed")
if surfacePixels<=100 {
    print("Selected emitters: \(subject.renderer.validationSelectedLights)")
    try png(surfaceOn,"advanced-surface-debug")
}
validationRequire(surfacePixels>100,"Emissive patches did not visibly light neighboring surfaces")
validationRequire(surfaceOn[hudStart...]==surfaceOff[hudStart...],"Surface lighting changed HUD")
validationRequire(frame()==surfaceOn,"Surface light selection unstable")
let mesh=subject.renderer.ambientOcclusion!, builds=subject.renderer.ambientOcclusion!.buildCount
try subject.renderer.setSceneEffect(.softShadows,enabled:true)
let soft=frame()
validationRequire(frame()==soft,"Soft shadows unstable while paused")
validationRequire(mesh.buildCount==builds,"Soft shadows rebuilt geometry")
try png(surfaceOn,"advanced-surface-lighting")
try png(soft,"advanced-soft-shadows")
try subject.renderer.setSceneEffect(.softShadows,enabled:false)
validationRequire(frame()==surfaceOn,"Soft shadow toggle failed exact restoration")
try subject.renderer.setSceneEffect(.surfaceLighting,enabled:false)
validationRequire(frame()==surfaceOff,"Surface light toggle failed exact restoration")
try subject.renderer.validationSynchronizeEngine()

let particlesOff=frame()
try subject.renderer.setSceneEffect(.particles,enabled:true)
let particlesOn=frame()
validationRequire(particlesOn != particlesOff,"Torch embers invisible")
validationRequire(particlesOn[hudStart...]==particlesOff[hudStart...],"Particles changed HUD")
validationRequire(frame()==particlesOn,"Particles unstable while paused")
let time=MD_GetHUD().levelTics
subject.renderer.validationLightPhase(time+9)
validationRequire(frame() != particlesOn,"Particles did not advance with game time")
subject.renderer.validationLightPhase(time)
validationRequire(frame()==particlesOn,"Particle game-time restoration failed")
try png(particlesOn,"advanced-particles")
try subject.renderer.setSceneEffect(.particles,enabled:false)
validationRequire(frame()==particlesOff && subject.benchmarkSettings==key,"Independent effect settings failed restoration")
var things=Array(repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,0,0)))
_=MD_CopyThings(&things,Int32(things.count),0,0)
let torch=things.first { $0.lightKind==1 }!
let eye=SIMD3<Float>(torch.x,torch.lightZ,-torch.y)
validationRequire(ParticleRenderer.generate(things:Array(repeating:torch,count:1000),eye:eye,tics:0).count==128,"Particle budget exceeded")
validationRequire(ParticleRenderer.generate(things:[],eye:eye,tics:0).isEmpty,"Particles linger without sources")

// Real weapon fire must supply projectile velocity for trailing sparks.
validationRequire(MD_Cheat("idfa") != 0)
_=MD_CombatTick(0,0,0,0,0,4)
for _ in 0..<50 { _=MD_CombatTick(0,0,0,0,0,-1) }
validationRequire(MD_GetHUD().readyWeapon==4,"Rocket weapon selection failed")
var rocket:MD_Thing?
for _ in 0..<30 {
    _=MD_CombatTick(0,0,0,0,1,-1)
    var snapshot=Array(repeating:MD_Thing(),count:Int(MD_CopyThings(nil,0,0,0)))
    _=MD_CopyThings(&snapshot,Int32(snapshot.count),0,0)
    rocket=snapshot.first { $0.lightKind==6 && abs($0.velocityX)+abs($0.velocityY)>0 }
    if rocket != nil { break }
}
validationRequire(rocket != nil,"Real projectile velocity missing from engine snapshot")
let shot=rocket!, origin=SIMD3<Float>(shot.x,shot.lightZ,-shot.y)
let velocity=SIMD3<Float>(shot.velocityX,shot.velocityZ,-shot.velocityY)
let trail=ParticleRenderer.generate(things:[shot],eye:origin,tics:MD_GetHUD().levelTics)
validationRequire(trail.contains { p in
    let point=SIMD3(p.positionSize.x,p.positionSize.y,p.positionSize.z)
    return simd_dot(origin-point,velocity)>20
},"Particles did not trail behind the moving projectile")
try subject.renderer.validationSynchronizeEngine()
try subject.renderer.setSceneEffect(.particles,enabled:true)
try png(frame(),"advanced-projectile-trails")
print("PASS: real rocket firing supplies moving projectile trails")

for effect in SceneEffect.allCases { try subject.renderer.setSceneEffect(effect,enabled:true) }
try subject.renderer.setAmbientOcclusion(true);try subject.renderer.setDynamicLight(true)
_=frame()
let save=output.appendingPathComponent("advanced-effects.mdsave")
try subject.renderer.saveGame(to:save,title:"Advanced effects validation")
try subject.renderer.loadGame(from:save)
let afterLoad=frame()
validationRequire(subject.renderer.sceneEffects.count==SceneEffect.allCases.count)
validationRequire(frame()==afterLoad,"Advanced effects unstable after save/load")
try png(afterLoad,"advanced-combined")
print("PASS: sprite light reception, independent one-sided surface lights, soft-shadow toggles, embers/time/budget, HUD isolation, exact restoration and combined save/load")
}
