import Foundation
@main struct ControlSectorValidation {
 static func main() throws {
  let exe=URL(fileURLWithPath:CommandLine.arguments[1]),base=URL(fileURLWithPath:CommandLine.arguments[2])
  for mode in ["normal","underwater","above","sky-below","sky-above","floorlight","ceilinglight"] {
   let paths=[base,exe.deletingLastPathComponent().appendingPathComponent("fixtures/control-\(mode).wad")]
   let worker=ExtendedWorker();defer{worker.close()}
   let initial=try worker.start(executable:exe,paths:paths,map:1,base:0,profile:0)
   let sector=initial.geometry!.map.sectors[0]
   func check(_ value:Bool)throws {guard value else {throw PortError("Control sector \(mode): \(sector)")}}
   try check(initial.eyeZ==41)
   switch mode {
   case "normal":try check(sector.floor==16 && sector.ceiling==96 && sector.floorTexture=="FLOOR0_1" && sector.light==Float(192)/255)
   case "underwater":try check(sector.floor==0 && sector.ceiling==64-1/Float(65536) && sector.floorTexture=="NUKAGE1" && sector.ceilingTexture=="CEIL3_5" && sector.backCeilingTexture=="CEIL1_1" && sector.light==Float(64)/255)
   case "above":try check(sector.floor==32+1/Float(65536) && sector.ceiling==128 && sector.floorTexture=="NUKAGE1" && sector.ceilingTexture=="CEIL3_5")
   case "sky-below":try check(sector.floor==64 && sector.ceiling==64-1/Float(65536) && sector.ceilingTexture=="NUKAGE1")
   case "sky-above":try check(sector.floor==32+1/Float(65536) && sector.ceiling==32 && sector.floorTexture=="CEIL3_5")
   case "floorlight":try check(sector.floorLight==Float(64)/255 && sector.ceilingLight==Float(192)/255 && sector.light==Float(192)/255)
   default:try check(sector.floorLight==Float(192)/255 && sector.ceilingLight==Float(64)/255 && sector.light==Float(192)/255)
   }
   if mode=="floorlight" || mode=="ceilinglight" {
    try check(initial.presentation.actors.first?.light==Float(128)/255)
   }
   let saved=try worker.save();_=try worker.geometry();try check(try worker.save()==saved)
   let fresh=ExtendedWorker();defer{fresh.close()}
   _=try fresh.start(executable:exe,paths:paths,map:1,base:0,profile:0)
   let restored=try fresh.restore(saved)
   try check(restored.geometry!.map.sectors==initial.geometry!.map.sectors)
   for _ in 0..<35 {
    let a=try worker.tick(forward:25),b=try fresh.tick(forward:25)
    try check(a.geometry?.map.sectors==b.geometry?.map.sectors && a.eyeZ==b.eyeZ)
    if mode=="underwater" {try check(a.x<0 && a.eyeZ<64)}
   }
   let raw=initial.geometry!.data,bytes=Bytes(data:raw)
   let p=120+(try bytes.i32(28))*8+(try bytes.i32(32))*24+(try bytes.i32(36))*36
   for field in [44,48] {
    var bad=raw;bad[p+field]=0;bad[p+field+1]=1
    for previous in [nil,initial.geometry] {
     var rejected=false;do {_=try ExtendedGeometry(data:bad,previous:previous)}catch{rejected=true}
     try check(rejected)
    }
   }
   if mode=="floorlight" {
    var changed=raw;changed[p+44]=96
    let update=try ExtendedGeometry(data:changed,previous:initial.geometry)
    let resources=try WAD(previewResources:paths,baseIndex:0,profile:0,identity:worker.identity!)
    let heights=try Art(wad:resources).textureHeights()
    let mesh=try ExtendedMesh(map:initial.geometry!.map,heights:heights)
    _=try mesh.update(initial.geometry!.map,initial:true);let before=mesh.rebuiltChunks
    let (actual,materials)=try mesh.update(update.map)
    try check(update.reusedTopology && mesh.rebuiltChunks==before+1 && materials.allSatisfy(\.flat))
    let expected=try Geometry(map:update.map,textureHeights:heights)
    func samples(_ g:Geometry)->[String] {g.batches.flatMap{b in b.vertices.map{"\(b.material):\($0.position):\($0.uvLight)"}}.sorted()}
    try check(samples(actual)==samples(expected))
   }
   print("PASS \(mode) real special, resolved planes/lights, physical eye height, immutable copy, save/continuation and malformed cached lights")
  }
 }
}
