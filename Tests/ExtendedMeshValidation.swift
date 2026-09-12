import Foundation

@main struct ExtendedMeshValidation {
    // The frozen algorithm builds a Set then sorts by a single axis. Its
    // equivalent T-junction choices can differ by ~1e-15 near zero between runs.
    // Normalize only sub-micro-unit zero coordinates for the byte comparison.
    static func canonical(_ input:[WorldVertex])->[WorldVertex] {
        input.map { v in
            var v=v
            for i in 0..<4 { if abs(v.position[i])<0.000001 { v.position[i]=0 };if abs(v.uvLight[i])<0.000001 { v.uvLight[i]=0 } }
            return v
        }
    }
    static func require(_ valid:Bool,_ message:String) throws { if !valid { throw PortError(message) } }
    static func triangles(_ vertices:[WorldVertex])->[Data:Int] {
        var result:[Data:Int]=[:]
        canonical(vertices).withUnsafeBytes { raw in
            for i in stride(from:0,to:raw.count,by:3*MemoryLayout<WorldVertex>.stride) {
                result[Data(raw[i..<i+3*MemoryLayout<WorldVertex>.stride]),default:0]+=1
            }
        }
        return result
    }
    static func compare(_ geometry:Geometry,_ map:DoomMap,_ heights:[String:Float]) throws {
        let reference=try ReferenceGeometry(map:map,textureHeights:heights)
        try require(geometry.batches.map(\.material)==reference.batches.map(\.material),"Material identity mismatch")
        for (a,b) in zip(geometry.batches,reference.batches) {
            let actual=triangles(a.vertices),expected=triangles(b.vertices)
            if actual != expected {
                print("Mismatch \(map.name) \(a.material): vertices \(a.vertices.count)/\(b.vertices.count), differing triangles \(actual.filter{expected[$0.key] != $0.value}.count)")
                for record in actual.keys.filter({expected[$0] != actual[$0]}).prefix(1) { print("actual",record.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}) }
                for record in expected.keys.filter({expected[$0] != actual[$0]}).prefix(1) { print("expected",record.withUnsafeBytes{Array($0.bindMemory(to:Float.self))}) }
                throw PortError("Triangle bytes differ: \(a.material)")
            }
        }
        try require(triangles(geometry.skyVertices)==triangles(reference.skyVertices),"Sky triangle bytes differ")
    }
    static func main() { do { try run() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) } }
    static func run() throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1]),exe=URL(fileURLWithPath:CommandLine.arguments[2])
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        for number in [1,13,16] {
            let worker=ExtendedWorker();defer{worker.close()}
            let first=try worker.start(executable:exe,paths:paths,map:number,base:1)
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            let heights=try Art(wad:resources).textureHeights(),builder=try ExtendedSceneBuilder(resources:resources)
            let initial=try builder.prepare(first);try compare(initial.geometry,initial.copiedGeometry.map,heights)
            var final=initial,previous=initial.copiedGeometry
            for tic in 1...140 {
                let state=try worker.tick(buttons:tic==36 ? 2:tic>70 ? 1:0)
                final=try builder.prepare(state)
                if let copied=state.geometry {
                    try require(copied.reusedTopology,"Unchanged wire topology was decoded again")
                    if [1,36,40,71,140].contains(tic) {
                        let full=try ExtendedGeometry(data:copied.data)
                        try require(full.map.sides==copied.map.sides && full.map.sectors==copied.map.sectors && full.map.start==copied.map.start && full.map.angle==copied.map.angle,"Cached dynamic decode disagrees with full decode")
                        try compare(final.geometry,full.map,heights)
                    }
                    previous=copied
                }
            }
            try require(builder.meshBuilds==1,"Dynamic changes rebuilt BSP topology")
            let forced=try builder.prepare(worker.geometry())
            try require(forced.changedMaterials.isEmpty,"Unchanged forced snapshot triggered uploads")
            print("PASS MAP\(number): exact old-algorithm triangle/UV/light/sky multisets at 6 snapshots; one topology build over 140 tics")
            if number==16 {
                // Exercise height/pegging, light clamps, UV offsets, texture/sky
                // additions/removal, and restore against the independent oracle.
                let base=initial.copiedGeometry.map,cache=try ExtendedMesh(map:base,heights:heights)
                _=try cache.update(base,initial:true)
                var changed=base
                let old=changed.sectors[0]
                changed.sectors[0]=Sector(floor:old.floor-16,ceiling:old.ceiling+32,light:0.01,floorTexture:"F_SKY1",ceilingTexture:old.floorTexture)
                let side=changed.sides[0]
                changed.sides[0]=Side(sector:side.sector,x:side.x+13.5,y:side.y-7,upper:"STARTAN3",lower:"STARTAN3",middle:"-")
                try compare(cache.update(changed).0,changed,heights)
                try compare(cache.update(base).0,base,heights)
                try require(try cache.update(base).1.isEmpty,"Restored unchanged mesh uploaded")
                // Cached decoder must reject bad dynamic references/names and
                // fall back to validation when immutable wire geometry changes.
                let bytes=Bytes(data:previous.data),sides=120+(try bytes.i32(28))*8+(try bytes.i32(32))*20
                var bad=previous.data
                for i in 0..<4 { bad[sides+i]=255 }
                var rejected=false
                do { _=try ExtendedGeometry(data:bad,previous:previous) } catch { rejected=true }
                try require(rejected,"Cached invalid side reference accepted")
                bad=previous.data;bad[sides+12]=0
                rejected=false;do { _=try ExtendedGeometry(data:bad,previous:previous) } catch { rejected=true }
                try require(rejected,"Cached invalid material accepted")
                var moved=previous.data;moved[120] ^= 1
                let updated=try ExtendedGeometry(data:moved,previous:previous)
                try require(!updated.reusedTopology && !cache.matches(updated.map),"Static topology mutation reused old cache")
                let rebuilt=try ExtendedMesh(map:updated.map,heights:heights)
                try compare(rebuilt.update(updated.map,initial:true).0,updated.map,heights)
                print("PASS synthetic floor/ceiling/light/offset/texture/sky changes and restoration; cached malformed data rejected; topology mutation rebuilds")
            }
        }
    }
}
