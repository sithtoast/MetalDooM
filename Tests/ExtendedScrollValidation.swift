import Foundation
import simd

@main struct ExtendedScrollValidation {
    static func check(_ ok:Bool,_ message:String) throws {if !ok {throw PortError(message)}}
    static func main() {do {try run()} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}}
    static func run() throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1]),exe=URL(fileURLWithPath:CommandLine.arguments[2])
        for kind in ["floor","ceiling","both","reverse","carry"] {
            let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}+[exe.deletingLastPathComponent().appendingPathComponent("fixtures/scroll-\(kind).wad")]
            let worker=ExtendedWorker();defer{worker.close()}
            let first=try worker.start(executable:exe,paths:paths,map:1,base:1)
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            let heights=try Art(wad:resources).textureHeights(),base=first.geometry!.map
            let mesh=try ExtendedMesh(map:base,heights:heights)
            _=try mesh.update(base,initial:true)
            let initialChunks=mesh.rebuiltChunks
            var state=first
            for tic in 1...7 {
                state=try worker.tick()
                guard let copied=state.geometry else {throw PortError("Scrolling state omitted geometry")}
                let sector=copied.map.sectors[0],reverse:Float=kind=="reverse" ? -1:1
                let floor=kind=="ceiling" ? SIMD2<Float>.zero:SIMD2(0,Float(tic)*16*reverse)
                let ceiling=["ceiling","both","reverse"].contains(kind) ? SIMD2(-Float(tic)*16*reverse,0):.zero
                try check(sector.floorOffset==floor && sector.ceilingOffset==ceiling,"Wrong engine direction/speed: \(kind) tic\(tic)")
                try check(copied.reusedTopology,"Scroller invalidated immutable wire topology")
                let decoded=try ExtendedGeometry(data:copied.data)
                try check(decoded.map.sectors==copied.map.sectors,"Cached offset decode differs")
                let (geometry,changed)=try mesh.update(copied.map)
                try check(mesh.rebuiltChunks==initialChunks+tic && changed.allSatisfy(\.flat),"Scroller rebuilt walls")
                for batch in geometry.batches where batch.material.flat {
                    let shift=batch.material.name==sector.floorTexture ? floor:ceiling
                    for vertex in batch.vertices {
                        try check(vertex.uvLight.x==vertex.position.x+shift.x.truncatingRemainder(dividingBy:64) && vertex.uvLight.y==vertex.position.z+shift.y.truncatingRemainder(dividingBy:64),"Wrong plane UV sign or period")
                    }
                }
                if kind != "carry" {try check(state.x==first.x && state.y==first.y,"Texture-only scroll moved player")}
            }
            if kind=="carry" {try check(state.y != first.y,"Conveyor stopped carrying player")}
            let unchanged=try mesh.update(worker.geometry().geometry!.map)
            try check(unchanged.1.isEmpty,"Paused copy rebuilt materials")
            let saved=try worker.save(),restored=ExtendedWorker();defer{restored.close()}
            _=try restored.start(executable:exe,paths:paths,map:1,base:1)
            let loaded=try restored.restore(saved)
            try check(loaded.geometry!.map.sectors==state.geometry!.map.sectors,"Load lost scroll phase")
            for _ in 0..<8 {
                let a=try worker.tick(),b=try restored.tick()
                try check(a.geometry!.data==b.geometry!.data,"Restored scroller diverged")
            }
            let reset=try worker.advance(restart:true)
            try check(reset.geometry!.map.sectors[0].floorOffset == .zero && reset.geometry!.map.sectors[0].ceilingOffset == .zero,"Restart retained offsets")
            // The version bump must reject old packets, even with cached topology.
            var old=first.geometry!.data;old[3]=49;old[4]=1
            var rejected=false;do{_=try ExtendedGeometry(data:old,previous:first.geometry)}catch{rejected=true}
            try check(rejected,"Old MGE1 accepted")
            print("PASS \(kind): engine scroll direction/speed, periodic UVs, flat-only cache updates, pause/copy, save continuation and restart")
        }
        // Fractional and negative offsets are independent of engine tick speed.
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        let worker=ExtendedWorker();defer{worker.close()}
        let initial=try worker.start(executable:exe,paths:paths,map:1,base:1)
        var map=initial.geometry!.map
        for i in map.sectors.indices {map.sectors[i].floorOffset=SIMD2(64.25,-128.5);map.sectors[i].ceilingOffset=SIMD2(-64.75,256.125)}
        let geometry=try Geometry(map:map)
        for batch in geometry.batches where batch.material.flat {
            for v in batch.vertices {
                let u=v.uvLight.x-v.position.x,w=v.uvLight.y-v.position.z
                try check((u==0.25 && w == -0.5)||(u == -0.75 && w==0.125),"Fractional offset lost")
            }
        }
        print("PASS fractional signed offsets and multi-period wrapping")
    }
}
