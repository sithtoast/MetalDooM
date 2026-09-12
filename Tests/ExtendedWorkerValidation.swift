import Foundation

@main struct ExtendedWorkerValidation {
    static func main() {
        do { try run() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) }
    }
    static func run() throws {
        let args=CommandLine.arguments, executable=URL(fileURLWithPath:args[1]), base=URL(fileURLWithPath:args[2]), root=URL(fileURLWithPath:args[3])
        do {
            let worker=ExtendedWorker()
            let first=try worker.start(executable:executable,paths:[base],map:1,base:0,profile:0)
            guard first.tic==0, first.health==100, first.geometry != nil else { throw PortError("Invalid initial worker view.") }
            let map=first.geometry!.map, sector=first.geometry!.map.sectors[first.geometry!.map.sector(at:first.geometry!.map.start)]
            guard first.eyeZ == min(sector.floor+41,sector.ceiling-4), map.name=="MAP01" else { throw PortError("Incorrect initial view height.") }
            let moved=try worker.tick(forward:25,count:35)
            guard moved.tic==35, abs(moved.x-first.x)+abs(moved.y-first.y)>1 else { throw PortError("Remote movement failed.") }
            let copied=try worker.geometry()
            guard copied.tic==35, copied.geometry?.tic==35 else { throw PortError("Remote geometry tic mismatch.") }
            worker.cancel()
            var rejected=false
            do { _=try worker.geometry() } catch { rejected=true }
            guard rejected else { throw PortError("Cancelled worker accepted a command.") }
            print("PASS framed worker startup, movement, geometry identity/tics and cancellation")
        }
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        for map in 1...16 {
            let worker=ExtendedWorker()
            let first=try worker.start(executable:executable,paths:paths,map:map,base:1)
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            var rejected=false
            do { _=try WAD(previewResources:paths,baseIndex:0,profile:1,identity:worker.identity!) } catch { rejected=true }
            guard rejected, resources.signature=="PWAD" else { throw PortError("Resource identity mismatch accepted.") }
            let builder=try ExtendedSceneBuilder(resources:resources)
            let scene=try builder.prepare(first)
            guard scene.geometry.triangleCount>0 else { throw PortError("Invalid scene.") }
            guard !first.presentation.actors.isEmpty, first.presentation.weapons.count==1,
                  scene.spritePatches.count>1 else { throw PortError("Missing initial actor/weapon presentation.") }
            let active=try worker.tick(count:35)
            _=try builder.prepare(active)
            print("PASS sprite frames MAP\(map): \(active.presentation.actors.count) actors, \(active.presentation.weapons.count) weapon layers at tic 35")
            print("PASS Rust MAP\(map): \(scene.geometry.triangleCount) textured triangles, \(scene.images.count) materials, sky \(first.sky), eyeZ \(first.eyeZ)")
            worker.cancel()
        }
        let fixtures=executable.deletingLastPathComponent().appendingPathComponent("fixtures")
        do {
            let worker=ExtendedWorker()
            let state=try worker.start(executable:executable,paths:[base,fixtures.appendingPathComponent("render-rotations.wad")],map:1,base:0,profile:0)
            let names=["POSSA5","POSSA4A6","POSSA3A7","POSSA2A8","POSSA1","POSSA2A8","POSSA3A7","POSSA4A6"]
            let flips=[0,1,1,1,0,0,0,0]
            guard state.presentation.actors.count==8 else { throw PortError("Player/helper incorrectly included in sprite list.") }
            for (index,sprite) in state.presentation.actors.enumerated() {
                guard sprite.name==names[index],sprite.flags&1==flips[index] else { throw PortError("Incorrect directional sprite/flip at \(index): \(sprite.name).") }
            }
            worker.cancel();print("PASS eight camera-relative rotations and mirrored pairs")
        }
        do {
            let worker=ExtendedWorker(),files=[base,fixtures.appendingPathComponent("render-materials.wad")]
            let first=try worker.start(executable:executable,paths:files,map:1,base:0,profile:0)
            let resources=try WAD(previewResources:files,baseIndex:0,profile:0,identity:worker.identity!)
            let builder=try ExtendedSceneBuilder(resources:resources)
            _=try builder.prepare(first)
            let floor=MaterialKey(name:"NUKAGE1",flat:true),wall=MaterialKey(name:"FIREBLU1",flat:false)
            var floorFrames=Set<String>(),wallFrames=Set<String>(),last=first
            for tic in 1...65 {
                last=try worker.tick()
                guard last.geometry==nil else { throw PortError("Static world was retransmitted at tic \(tic).") }
                let scene=try builder.prepare(last)
                let f=last.materials.translations[floor] ?? floor,w=last.materials.translations[wall] ?? wall
                guard f.name=="NUKAGE\(((tic-1)/8)%3+1)",w.name=="FIREBLU\(((tic-1)/8)%2+1)",
                      scene.images[f] != nil,scene.images[w] != nil else { throw PortError("Engine animation phase/resource mismatch at tic \(tic).") }
                floorFrames.insert(f.name);wallFrames.insert(w.name)
            }
            let decodes=builder.imageDecodes,sprites=builder.spriteDecodes
            _=try builder.prepare(last)
            guard builder.meshBuilds==1,builder.imageDecodes==decodes,builder.spriteDecodes==sprites,
                  floorFrames.count==3,wallFrames.count==2 else { throw PortError("Static scene/resource reuse failed.") }
            print("PASS 65 exact animation phases, 3 flat/2 wall frames, one mesh build, stable decode caches")
            worker.cancel()
        }
        do {
            let worker=ExtendedWorker()
            let first=try worker.start(executable:executable,paths:paths,map:16,base:1)
            let builder=try ExtendedSceneBuilder(resources:WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!))
            let initial=try builder.prepare(first)
            // Spawn initializes usedown; release it before testing a new press.
            _=try builder.prepare(worker.tick(count:4))
            let pressed=try worker.tick(buttons:2)
            let opened=try worker.tick(count:35)
            guard pressed.geometry != nil,opened.geometry != nil else { throw PortError("Moving geometry was omitted.") }
            _=try builder.prepare(pressed);let final=try builder.prepare(opened)
            guard final.copiedGeometry.map.sectors.map({[$0.floor,$0.ceiling]}) != initial.copiedGeometry.map.sectors.map({[$0.floor,$0.ceiling]}),builder.meshBuilds==4 else { throw PortError("Moving geometry was not rebuilt.") }
            print("PASS MAP16 switch/moving sector invalidates cached geometry")
            worker.cancel()
        }
        for (fixture,weapon,hold) in [("rust-incinerator",5,12),("rust-blade-full",6,85)] {
            let worker=ExtendedWorker(), files=paths+[fixtures.appendingPathComponent(fixture+".wad")]
            _=try worker.start(executable:executable,paths:files,map:1,base:1)
            let resources=try WAD(previewResources:files,baseIndex:1,profile:1,identity:worker.identity!)
            let art=try Art(wad:resources)
            _=try worker.tick(forward:25,count:3)
            _=try worker.tick(buttons:UInt8(4 | (weapon<<3)))
            _=try worker.tick(count:35);let ready=try worker.tick(count:35)
            guard ready.presentation.readyWeapon==weapon else { throw PortError("Fixture weapon not ready.") }
            var names=Set<String>(), weaponNames=Set<String>(), maxActors=0, flash=false, last=ready
            for tic in 0..<hold+35 {
                last=try worker.tick(buttons:tic<hold ? 1:0)
                maxActors=max(maxActors,last.presentation.actors.count)
                flash=flash || last.presentation.weapons.count==2
                for sprite in last.presentation.actors+last.presentation.weapons where names.insert(sprite.name).inserted {
                    guard let index=resources.spriteLumpIndex(sprite.name) else { throw PortError("Missing firing sprite: \(sprite.name)") }
                    _=try art.patch(lump:index)
                }
                weaponNames.formUnion(last.presentation.weapons.map(\.name))
            }
            guard last.presentation.ammo<ready.presentation.ammo, maxActors>0, weaponNames.count>1 else { throw PortError("Weapon/projectile presentation did not advance.") }
            print("PASS \(fixture) firing: \(names.count) decoded sprite frames, \(maxActors) visible actors, flash=\(flash), ammo \(ready.presentation.ammo)->\(last.presentation.ammo)")
            worker.cancel()
        }
        do {
            let original=try Data(contentsOf:executable.deletingLastPathComponent().appendingPathComponent("initial-presentation.msp"))
            _=try ExtendedPresentation(data:original)
            func mutate(_ offset:Int,_ value:UInt32)->Data {
                var data=original
                for i in 0..<4 { data[offset+i]=UInt8(truncatingIfNeeded:value>>(8*i)) }
                return data
            }
            let invalid=[Data(original.prefix(31)),Data(original.dropLast()),original+Data([0]),
                mutate(4,2),mutate(12,UInt32.max),mutate(16,3),mutate(28,1),mutate(32,0),mutate(32+28,16)]
            for data in invalid {
                var rejected=false
                do { _=try ExtendedPresentation(data:data) } catch { rejected=true }
                guard rejected else { throw PortError("Malformed sprite snapshot accepted.") }
            }
            print("PASS \(invalid.count) malformed sprite snapshot boundaries")
        }
        do {
            func words(_ values:[UInt32])->Data { Data(values.flatMap { v in (0..<4).map{UInt8(truncatingIfNeeded:v>>(8*$0))} }) }
            let record=Data("FIREBLU1FIREBLU2".utf8)+words([0])
            let valid=Data("MMT1".utf8)+words([1,0,1])+record
            _=try ExtendedMaterials(data:valid)
            func mutate(_ offset:Int,_ value:UInt32)->Data {
                var d=valid;d.replaceSubrange(offset..<offset+4,with:words([value]));return d
            }
            var invalid:[Data]=[Data(valid.prefix(15)),Data(valid.dropLast()),valid+Data([0]),mutate(4,2),
                mutate(8,UInt32.max),mutate(12,65537),mutate(16,0),mutate(32,2)]
            var duplicate=Data("MMT1".utf8);duplicate.append(words([1,0,2]));duplicate.append(record);duplicate.append(record)
            var identity=Data("MMT1".utf8);identity.append(words([1,0,1]));identity.append(Data("FIREBLU1FIREBLU1".utf8));identity.append(words([0]))
            invalid.append(duplicate);invalid.append(identity)
            for packet in invalid {
                var rejected=false;do { _=try ExtendedMaterials(data:packet) } catch { rejected=true }
                guard rejected else { throw PortError("Malformed material snapshot accepted.") }
            }
            var view=try Data(contentsOf:executable.deletingLastPathComponent().appendingPathComponent("initial-view.mvw"))
            let b=Bytes(data:view),offset=48+(try b.i32(36))+(try b.i32(40))+8
            view.replaceSubrange(offset..<offset+4,with:words([1]))
            var rejected=false;do { _=try ExtendedView(data:view) } catch { rejected=true }
            guard rejected else { throw PortError("Mismatched material tic accepted.") }
            print("PASS 10 malformed material boundaries and material/view tic mismatch")
        }
        for mode in ["stall","oversize","sequence","truncated"] {
            let worker=ExtendedWorker(timeout:0.2), start=ProcessInfo.processInfo.systemUptime
            var rejected=false
            do { _=try worker.start(executable:executable.deletingLastPathComponent().appendingPathComponent("fake-"+mode),paths:[base],map:1,base:0) } catch { rejected=true }
            guard rejected, ProcessInfo.processInfo.systemUptime-start<2 else { throw PortError("Unbounded or accepted bad reply: \(mode)") }
            print("PASS client rejects \(mode) reply within deadline")
        }
    }
}
