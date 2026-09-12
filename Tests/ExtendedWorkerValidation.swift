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
            let worker=ExtendedWorker();defer{worker.close()}
            let initial=try worker.start(executable:executable,paths:[base,fixtures.appendingPathComponent("blend-actors.wad")],map:1,base:0,profile:0)
            guard initial.presentation.actors.map({$0.flags & 30})==[8,26,4],let tables=initial.blendTables else {throw PortError("Incorrect normal/additive/shadow modes")}
            for bg in 0..<256 {for fg in 0..<256 {guard tables.normal[bg*256+fg]==UInt8((bg+2*fg)/3) else {throw PortError("TRANMAP bytes changed")}}}
            guard tables.normal != tables.additive else {throw PortError("Additive table missing")}
            let repeated=try worker.geometry()
            guard repeated.tic==0,repeated.blendTables?.additive==tables.additive else {throw PortError("Blend copy changed simulation or tables")}
            func words(_ values:[UInt32])->Data {Data(values.flatMap {v in (0..<4).map{UInt8(truncatingIfNeeded:v>>(8*$0))}})}
            let packet=Data("MBL3".utf8)+words([3,UInt32(tables.palettes.count),2,UInt32(tables.colormaps.count),0])+Data(tables.palettes+tables.colormaps+tables.normal+tables.additive)
            _=try ExtendedBlendTables(data:packet)
            var cases=[Data(packet.prefix(15)),Data(packet.dropLast()),packet+Data([0])]
            for (offset,value) in [(0,UInt32(0)),(4,1),(8,767),(12,65),(8,256*768+768),(16,255),(16,257),(16,256*256+256),(20,1)] {
                var d=packet;d.replaceSubrange(offset..<offset+4,with:words([value]));cases.append(d)
            }
            for invalid in cases {
                var rejected=false;do {_=try ExtendedBlendTables(data:invalid)}catch {rejected=true}
                guard rejected else {throw PortError("Malformed blend packet accepted")}
            }
            for (palette,fixed,walls) in [(tables.palettes.count/768,0,[Int]()),(0,tables.colormaps.count/256,[]),(0,0,[3])] {
                var rejected=false
                do {try tables.validate(initial.presentation,palette:palette,fixed:fixed,walls:walls)} catch {rejected=true}
                guard rejected else {throw PortError("Missing wall/color resource accepted")}
            }
            print("PASS exact TRANMAP bytes, separate additive table, actor selection, stable copied state and 12 malformed blend packets")
        }
        do {
            let customPaths=[base,fixtures.appendingPathComponent("blend-custom.wad")]
            let worker=ExtendedWorker();defer{worker.close()}
            let initial=try worker.start(executable:executable,paths:customPaths,map:1,base:0,profile:0)
            guard let tables=initial.blendTables,tables.tables.count==4,
                  initial.presentation.actors.map(\.blendTable)==[3,3,0,3] else {throw PortError("Custom table IDs/precedence/deduplication failed")}
            for bg in 0..<256 {for fg in 0..<256 {
                guard tables.tables[2][bg*256+fg]==UInt8((2*bg+fg)/3),tables.tables[3][bg*256+fg]==UInt8(255-fg) else {throw PortError("Custom blend table bytes changed")}
            }}
            let switched=try worker.tick(count:2)
            guard switched.presentation.actors.map(\.blendTable)==[4,3,0,3],switched.blendTables?.tables==tables.tables else {throw PortError("Delayed custom state changed table identity")}
            let save=try worker.save(),restoredWorker=ExtendedWorker();defer{restoredWorker.close()}
            _=try restoredWorker.start(executable:executable,paths:customPaths,map:1,base:0,profile:0)
            let restored=try restoredWorker.restore(save)
            guard restored.presentation.actors.map(\.blendTable)==[4,3,0,3],restored.blendTables?.tables==tables.tables else {throw PortError("Custom table save/restore failed")}
            for _ in 0..<8 {
                let expected=try worker.tick(),actual=try restoredWorker.tick()
                guard expected.presentation.actors.map(\.blendTable)==actual.presentation.actors.map(\.blendTable),expected.presentation.actors.map(\.state)==actual.presentation.actors.map(\.state) else {throw PortError("Custom table continuation failed")}
            }
            let restarted=try worker.advance(restart:true)
            guard restarted.presentation.actors.map(\.blendTable)==[3,3,0,3],restarted.blendTables?.tables==tables.tables else {throw PortError("Custom table restart failed")}
            // A structurally valid sprite ID must also exist in this session bank.
            let raw=try Data(contentsOf:executable.deletingLastPathComponent().appendingPathComponent("initial-presentation.msp"))
            for flags:UInt32 in [8|(1<<8),8|(2<<8),8|(65<<8),3<<8,24|(3<<8),1<<16] {
                var data=raw;for i in 0..<4 {data[60+i]=UInt8(truncatingIfNeeded:flags>>(i*8))}
                var rejected=false;do {_=try ExtendedPresentation(data:data)}catch{rejected=true}
                guard rejected else {throw PortError("Invalid custom sprite flags accepted")}
            }
            var absent=raw;let flags:UInt32=8|(5<<8)
            for i in 0..<4 {absent[60+i]=UInt8(truncatingIfNeeded:flags>>(i*8))}
            var rejected=false;do {try tables.validate(ExtendedPresentation(data:absent))}catch{rejected=true}
            guard rejected else {throw PortError("Absent custom table reference accepted")}
            print("PASS custom table bytes, shared stable IDs, state/fullbright/opaque/fuzz precedence, delayed state, fresh restore/continuation, restart and invalid IDs")
        }
        do {
            let worker=ExtendedWorker();defer{worker.close()}
            let state=try worker.start(executable:executable,paths:[base,fixtures.appendingPathComponent("blend-custom-max.wad")],map:1,base:0,profile:0)
            guard state.blendTables?.tables.count==64,state.presentation.actors.map(\.blendTable)==[64] else {throw PortError("Maximum valid blend bank failed")}
            print("PASS maximum 64-table bank and highest actor table ID")
        }
        for mode in ["default","custom","tagged"] {
            let paths=[base,fixtures.appendingPathComponent("wall-"+mode+".wad")]
            let worker=ExtendedWorker();defer{worker.close()}
            let initial=try worker.start(executable:executable,paths:paths,map:1,base:0,profile:0)
            let id=mode=="default" ? 1:3
            guard initial.geometry!.map.lines[6].blend==id,initial.blendTables!.tables.count==(id==1 ? 2:3) else {throw PortError("Wall blend assignment failed")}
            let resources=try WAD(previewResources:paths,baseIndex:0,profile:0,identity:worker.identity!)
            let scene=try ExtendedScene(view:initial,resources:resources)
            guard scene.geometry.batches.contains(where:{$0.material.blend==id && $0.vertices.count>0}),
                  scene.images.filter({$0.key.blend>0}).values.allSatisfy({$0.paletteIndices != nil}) else {throw PortError("Missing indexed transparent wall geometry")}
            let saved=try worker.save(),fresh=ExtendedWorker();defer{fresh.close()}
            _=try fresh.start(executable:executable,paths:paths,map:1,base:0,profile:0)
            let restored=try fresh.restore(saved),restart=try worker.advance(restart:true)
            guard restored.geometry!.map.lines[6].blend==id,restart.geometry!.map.lines[6].blend==id,
                  restored.blendTables!.tables==initial.blendTables!.tables else {throw PortError("Wall table save/restart failed")}
            print("PASS \(mode) wall table, indexed geometry, restore and refreshed restart bank")
        }
        for mode in ["bonus","berserk","suit","invulnerable","light","damage"] {
            let paths=[base,fixtures.appendingPathComponent("palette-"+mode+".wad")]
            let worker=ExtendedWorker();defer{worker.close()}
            let initial=try worker.start(executable:executable,paths:paths,map:1,base:0,profile:0)
            guard initial.ui.palette==0,initial.ui.fixedMap==0 else {throw PortError("Spawn palette is not neutral")}
            var state=initial,seen=false
            for tic in 0..<35 {
                state=try worker.tick(forward:tic<2 ? 25:0)
                if state.ui.palette>0 {seen=true}
            }
            switch mode {
            case "bonus":guard seen,state.ui.palette==0 else {throw PortError("Bonus palette/fade failed")}
            case "berserk":guard state.ui.palette==3 else {throw PortError("Berserk palette failed")}
            case "suit":guard state.ui.palette==13 else {throw PortError("Radiation palette failed")}
            case "invulnerable":guard state.ui.fixedMap==32 else {throw PortError("Invulnerability colormap failed")}
            case "light":guard state.ui.fixedMap==1 else {throw PortError("Light amplification colormap failed")}
            default:guard state.ui.palette>0,state.ui.health<100 else {throw PortError("Damage palette failed")}
            }
            let saved=try worker.save(),fresh=ExtendedWorker();defer{fresh.close()}
            _=try fresh.start(executable:executable,paths:paths,map:1,base:0,profile:0)
            let loaded=try fresh.restore(saved)
            guard loaded.ui.palette==state.ui.palette,loaded.ui.fixedMap==state.ui.fixedMap else {throw PortError("Restored color phase changed")}
            for _ in 0..<35 {
                let a=try worker.tick(),b=try fresh.tick()
                guard a.ui.palette==b.ui.palette,a.ui.fixedMap==b.ui.fixedMap else {throw PortError("Restored palette continuation diverged")}
            }
            print("PASS \(mode) palette/colormap selection, fade and saved continuation")
        }
        for name in ["blend-bad-table","blend-custom-short","blend-custom-long","blend-custom-limit"] {
            let worker=ExtendedWorker();defer{worker.close()}
            var rejected=false
            do {_=try worker.start(executable:executable,paths:[base,fixtures.appendingPathComponent(name+".wad")],map:1,base:0,profile:0)}catch {rejected=true}
            guard rejected else {throw PortError("Unsupported blend data accepted: \(name)")}
            print("PASS rejected \(name)")
        }

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
            guard final.copiedGeometry.map.sectors.map({[$0.floor,$0.ceiling]}) != initial.copiedGeometry.map.sectors.map({[$0.floor,$0.ceiling]}),builder.meshBuilds==1 else { throw PortError("Moving geometry did not reuse static topology.") }
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
                mutate(4,6),mutate(12,UInt32.max),mutate(16,3),mutate(28,2),mutate(32,0),mutate(32+28,16),mutate(32+28,64),mutate(32+28,12)]
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
            let b=Bytes(data:view),offset=56+(try b.i32(36))+(try b.i32(40))+8
            view.replaceSubrange(offset..<offset+4,with:words([1]))
            var rejected=false;do { _=try ExtendedView(data:view) } catch { rejected=true }
            guard rejected else { throw PortError("Mismatched material tic accepted.") }
            print("PASS 10 malformed material boundaries and material/view tic mismatch")
        }
        do {
            let worker=ExtendedWorker()
            _=try worker.start(executable:executable,paths:[base,fixtures.appendingPathComponent("audio-spatial.wad")],map:1,base:0,profile:0)
            let frame=try worker.tick(count:2)
            let starts=frame.audio.events.filter{$0.operation==1}
            guard starts.count==2,Set(starts.map(\.channel)).count==2,
                  starts.allSatisfy({$0.name=="DSPISTOL" && $0.volume==1}),
                  starts.contains(where:{$0.pan < -0.7}),starts.contains(where:{$0.pan > 0.7}),
                  try worker.geometry().audio.events.isEmpty else { throw PortError("Spatial sound or drain boundary failed.") }
            worker.cancel();print("PASS independent left/right pistol channels, full nearby volume, no replay on geometry request")
        }
        do {
            func words(_ values:[UInt32])->Data { Data(values.flatMap{v in (0..<4).map{UInt8(truncatingIfNeeded:v>>(8*$0))}}) }
            let header=Data("MSA1".utf8)+words([1,10,1])
            let event=words([5,0,1])+Data("DSPISTOL".utf8)+words([127,0])
            let valid=header+event;_=try ExtendedAudio(data:valid)
            func mutate(_ p:Int,_ v:UInt32)->Data { var d=valid;d.replaceSubrange(p..<p+4,with:words([v]));return d }
            var invalid:[Data]=[Data(valid.prefix(15)),Data(valid.dropLast()),valid+Data([0]),mutate(4,2),mutate(12,4097),mutate(16,11),mutate(20,32),mutate(24,3),mutate(28,0),mutate(36,128),mutate(40,129),mutate(24,0)]
            var unordered=Data("MSA1".utf8);unordered.append(words([1,10,2]));unordered.append(event);unordered.append(words([4,0,1]));unordered.append(Data("DSPISTOL".utf8));unordered.append(words([127,0]));invalid.append(unordered)
            for d in invalid { var rejected=false;do{_=try ExtendedAudio(data:d)}catch{rejected=true};guard rejected else{throw PortError("Malformed audio event accepted.")} }
            print("PASS 13 malformed audio packet/order boundaries")
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
