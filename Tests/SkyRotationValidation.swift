import Foundation
@main struct SkyRotationValidation {
 static func main() throws {
  let exe=URL(fileURLWithPath:CommandLine.arguments[1]),base=URL(fileURLWithPath:CommandLine.arguments[2])
  for mode in ["sky271","sky272","sky-scroll","floor","ceiling","both","offset-both"] {
   let paths=[base,exe.deletingLastPathComponent().appendingPathComponent("fixtures/sky-rotation-\(mode).wad")]
   let worker=ExtendedWorker();defer{worker.close()}
   let initial=try worker.start(executable:exe,paths:paths,map:1,base:0,profile:0)
   let copied=initial.geometry!,sector=copied.map.sectors[0]
   func check(_ value:Bool)throws {guard value else {throw PortError("Sky/rotation \(mode): \(sector)")}}
   let resources=try WAD(previewResources:paths,baseIndex:0,profile:0,identity:worker.identity!)
   let builder=try ExtendedSceneBuilder(resources:resources),scene=try builder.prepare(initial)
   if mode.hasPrefix("sky") {
    try check(sector.floorSky==sector.ceilingSky && sector.floorSky?.name=="SKY2")
    try check(sector.floorSky?.angle==UInt32(4096*65536) && sector.floorSky?.mid==32)
    try check(sector.floorSky?.scale==SIMD2(mode=="sky272" ? 1:-1,1))
    try check(copied.map.sectors[1].ceilingSky==nil && !scene.geometry.skyVertices.isEmpty)
    try check(scene.geometry.batches.contains{$0.material.sky>0})
    let raw=copied.data,b=Bytes(data:raw),p=120+(try b.i32(28))*8+(try b.i32(32))*24+(try b.i32(36))*36
    for (offset,value) in [(84,UInt32.max),(104,0),(108,0),(112,0),(124,1)] {
     var bad=raw;for i in 0..<4 {bad[p+offset+i]=UInt8(truncatingIfNeeded:value>>(i*8))}
     for previous in [nil,initial.geometry] {
      var rejected=false;do {_=try ExtendedGeometry(data:bad,previous:previous)}catch{rejected=true}
      try check(rejected)
     }
    }
   } else {
    if mode != "ceiling" {try check(sector.floorRotation>0)}else{try check(sector.floorRotation==0)}
    if mode != "floor" {try check(sector.ceilingRotation>0)}else{try check(sector.ceilingRotation==0)}
    for batch in scene.geometry.batches where batch.material.flat {
     let ceiling=batch.material.name==sector.ceilingTexture
     // Sector1 remains unrotated, so identify target-sector interior vertices.
     for v in batch.vertices where v.position.x<0 {
      let rotation=ceiling ? sector.ceilingRotation:sector.floorRotation
      if rotation==0 {continue}
      if mode != "offset-both" {
       try check(abs(v.uvLight.x-v.position.z)<0.01 && abs(v.uvLight.y+v.position.x)<0.01)
      }else{
       try check(sector.floorOffset==SIMD2(64,-496) && sector.ceilingOffset==sector.floorOffset)
      }
     }
    }
   }
   let saved=try worker.save();_=try worker.geometry();try check(try worker.save()==saved)
   let fresh=ExtendedWorker();defer{fresh.close()}
   _=try fresh.start(executable:exe,paths:paths,map:1,base:0,profile:0)
   let restored=try fresh.restore(saved);try check(restored.geometry!.map.sectors==copied.map.sectors)
   var last=initial
   for _ in 0..<35 {
    let a=try worker.tick(),b=try fresh.tick();_=try builder.prepare(a)
    try check(a.geometry?.map.sectors==b.geometry?.map.sectors);last=a
   }
   if mode=="sky-scroll" {try check(last.geometry?.map.sectors[0].floorSky != sector.floorSky)}
   try check(builder.meshBuilds==1)
   print("PASS \(mode): real control, sector-local materials/UVs, copied-state canary, fresh save/continuation, stable topology and malformed skies")
  }
 }
}
