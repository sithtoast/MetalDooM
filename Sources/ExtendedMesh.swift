import Foundation

/// One wall chunk per linedef and one flat chunk per sector. Static clipping and
/// edge stitching are cached; neighbors participate in height/texture changes.
/// Only materials touched by replaced chunks are assembled and uploaded again.
final class ExtendedMesh {
    private var map:DoomMap, topology:GeometryTopology
    private let heights:[String:Float]
    private var chunks:[[MaterialKey:[WorldVertex]]]=[]
    private var members:[MaterialKey:Set<Int>]=[:], vertices:[MaterialKey:[WorldVertex]]=[:]
    private var sectorLines:[[Int]], sideLines:[[Int]]
    private(set) var rebuiltChunks=0
    init(map:DoomMap,heights:[String:Float]) throws {
        self.map=map;self.heights=heights;topology=try GeometryTopology(map:map)
        sectorLines=Array(repeating:[],count:map.sectors.count)
        sideLines=Array(repeating:[],count:map.sides.count)
        for (i,line) in map.lines.enumerated() {
            for side in [line.front,line.back] where side>=0 {
                sideLines[side].append(i);sectorLines[map.sides[side].sector].append(i)
            }
        }
        chunks=Array(repeating:[:],count:map.lines.count+map.sectors.count)
    }
    func matches(_ value:DoomMap)->Bool {
        map.name==value.name && map.points==value.points && map.lines==value.lines &&
        map.segs==value.segs && map.leaves==value.leaves && map.nodes==value.nodes &&
        map.sectors.count==value.sectors.count && map.sides.map(\.sector)==value.sides.map(\.sector)
    }
    func update(_ value:DoomMap,initial:Bool=false) throws -> (Geometry,Set<MaterialKey>) {
        var dirty=Set<Int>()
        if initial { dirty=Set(chunks.indices) }
        else {
            for i in value.sectors.indices where map.sectors[i] != value.sectors[i] {
                dirty.insert(map.lines.count+i)
                let old=map.sectors[i],new=value.sectors[i]
                if old.floor != new.floor || old.ceiling != new.ceiling || old.light != new.light ||
                   old.floorTexture != new.floorTexture || old.ceilingTexture != new.ceilingTexture ||
                   old.backFloor != new.backFloor || old.backCeiling != new.backCeiling || old.backCeilingTexture != new.backCeilingTexture || old.ceilingSky?.id != new.ceilingSky?.id {
                    dirty.formUnion(sectorLines[i])
                }
            }
            for i in value.sides.indices where map.sides[i] != value.sides[i] { dirty.formUnion(sideLines[i]) }
        }
        map=value
        var changed=Set<MaterialKey>()
        for i in dirty {
            let part=try Geometry(map:map,textureHeights:heights,topology:topology,
                                  lineIndices:i<map.lines.count ? [i]:[],
                                  sectorIndices:i>=map.lines.count ? [i-map.lines.count]:[])
            var replacement=Dictionary(uniqueKeysWithValues:part.batches.map{($0.material,$0.vertices)})
            if !part.skyVertices.isEmpty { replacement[MaterialKey(name:"F_SKY1",flat:true)]=part.skyVertices }
            for key in chunks[i].keys { members[key]?.remove(i);changed.insert(key) }
            for key in replacement.keys { members[key,default:[]].insert(i);changed.insert(key) }
            chunks[i]=replacement;rebuiltChunks+=1
        }
        for key in changed {
            let ids=(members[key] ?? []).sorted()
            if ids.isEmpty { vertices.removeValue(forKey:key);continue }
            var joined:[WorldVertex]=[]
            joined.reserveCapacity(ids.reduce(0){$0+(chunks[$1][key]?.count ?? 0)})
            for id in ids { joined += chunks[id][key]! }
            vertices[key]=joined
        }
        let skyKey=MaterialKey(name:"F_SKY1",flat:true)
        let batches=vertices.filter{$0.key != skyKey}.map{Batch(material:$0.key,vertices:$0.value)}.sorted {
            (($0.material.flat ? "F":"W")+$0.material.name,$0.material.blend,$0.material.sky) < (($1.material.flat ? "F":"W")+$1.material.name,$1.material.blend,$1.material.sky)
        }
        return (Geometry(batches:batches,skyVertices:vertices[skyKey] ?? []),changed)
    }
}

/// Interpolate sector values before tessellation: door openings may add/remove
/// triangles, so interpolating matching vertex indices would connect wrong edges.
final class ExtendedSurfaceInterpolation {
    private var previous:DoomMap?,current:DoomMap?
    private(set) var moving=false
    private var changed:[Int]=[]
    func accept(_ map:DoomMap) {
        previous=current;current=map;changed=[]
        if let old=previous,old.name==map.name,old.lines==map.lines,old.sectors.count==map.sectors.count {
            changed=map.sectors.indices.filter { i in
                let a=old.sectors[i],b=map.sectors[i]
                return a.floor != b.floor || a.ceiling != b.ceiling || a.backFloor != b.backFloor || a.backCeiling != b.backCeiling || a.spriteClip != b.spriteClip
            }
        } else {previous=nil}
        moving = !changed.isEmpty
    }
    static func interpolate(_ a:Sector,_ b:Sector,_ t:Float)->Sector {
        // Fake-flat region/material changes are discrete. Unbounded clipping
        // transitions must never produce infinity arithmetic or sweep a room.
        guard a.floorTexture==b.floorTexture,a.ceilingTexture==b.ceilingTexture,
              a.backCeilingTexture==b.backCeilingTexture,a.floorSky==b.floorSky,a.ceilingSky==b.ceilingSky,
              a.spriteClip.x.isFinite==b.spriteClip.x.isFinite,a.spriteClip.y.isFinite==b.spriteClip.y.isFinite,
              abs(a.floor-b.floor)<64,abs(a.ceiling-b.ceiling)<64 else {return b}
        func lerp(_ x:Float,_ y:Float)->Float {x==y ? y:x+(y-x)*t}
        var result=b
        result.floor=lerp(a.floor,b.floor);result.ceiling=lerp(a.ceiling,b.ceiling)
        if let x=a.backFloor,let y=b.backFloor {result.backFloor=lerp(x,y)}
        if let x=a.backCeiling,let y=b.backCeiling {result.backCeiling=lerp(x,y)}
        result.spriteClip=SIMD2(lerp(a.spriteClip.x,b.spriteClip.x),lerp(a.spriteClip.y,b.spriteClip.y))
        return result
    }
    func sample(_ fraction:Float)->DoomMap? {
        guard var map=current else {return nil}
        if fraction<1,let previous {for i in changed {map.sectors[i]=Self.interpolate(previous.sectors[i],map.sectors[i],fraction)}}
        return map
    }
}
