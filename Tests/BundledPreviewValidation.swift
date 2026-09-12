import Foundation

@main struct BundledPreviewValidation {
    static func check(_ value:Bool,_ message:String)throws {if !value {throw PortError(message)}}
    static func main() {
        setbuf(stdout,nil)
        do {try run()}catch{fputs("FAIL: \(error)\n",stderr);exit(1)}
    }
    static func run()throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1]),exe=URL(fileURLWithPath:CommandLine.arguments[2])
        for args in [["--bundled-preview",root.path,"--content","iddm1"],
                     ["--rust-preview",root.path,"--map","MAP17"],
                     ["--bundled-preview",root.path,"--content","music","--map","MAP33"],
                     ["--bundled-preview",root.path,"--content","doom2","--track","D_IBEGIN"],
                     ["--bundled-preview",root.path,"--content","music","--track","../bad"],
                     ["--bundled-preview",root.path,"--content","music","--map","1","--map","2"]] {
            var rejected=false;do{_=try BundledPreviewPlan.arguments(args)}catch{rejected=true}
            try check(rejected,"Invalid bundled CLI plan accepted")
        }
        let legacy=try BundledPreviewPlan.arguments(["--rust-preview",root.path]).0
        try check(legacy.base==1 && legacy.profile==1 && legacy.paths.map(\.lastPathComponent)==["id24res.wad","doom2.wad","id1.wad"],"Legacy launch order changed")
        print("PASS legacy launch and invalid/multiplayer/duplicate/track/map options")
        var identities=Set<String>()
        for kind in BundledPreviewPlan.Content.allCases {
            for extras in [false,true] {
                let plan=try BundledPreviewPlan(root:root,content:kind,extras:extras)
                var savedResources:WAD?
                var rendered=0,actorFrames=Set<String>()
                for map in 1...plan.mapLimit {
                    let worker=ExtendedWorker();defer{worker.close()}
                    var view=try worker.start(executable:exe,paths:plan.paths,map:map,base:plan.base,profile:plan.profile)
                    if map==1 {
                        try check(identities.insert(worker.identity!).inserted,"Resource profile/order identity reused")
                        savedResources=try WAD(previewResources:plan.paths,baseIndex:plan.base,profile:plan.profile,identity:worker.identity!)
                    }
                    let resources=savedResources!,builder=try ExtendedSceneBuilder(resources:resources)
                    let initial=try builder.prepare(view)
                    try check(initial.copiedGeometry.map.name==String(format:"MAP%02d",map),"Wrong campaign map")
                    view=try worker.tick(count:35)
                    let scene=try builder.prepare(view);rendered+=scene.geometry.triangleCount
                    actorFrames.formUnion(view.presentation.actors.map(\.name));actorFrames.formUnion(view.presentation.weapons.map(\.name))
                    try check(scene.geometry.triangleCount>0 && view.ui.map==map,"Empty map/presentation")
                    if map==plan.mapLimit || map==1 {
                        let payload=try worker.save(),engine=try ExtendedSave.engineIdentity(executable:exe)
                        let saved=try ExtendedSave(payload:payload,engine:engine)
                        try check(saved.map==map,"Save envelope rejected late campaign map")
                        let copy=ExtendedWorker();defer{copy.close()}
                        _=try copy.start(executable:exe,paths:plan.paths,map:map,base:plan.base,profile:plan.profile)
                        let restored=try copy.restore(saved.payload)
                        try check(restored.tic==view.tic && restored.presentation.actors.count==view.presentation.actors.count,"Component restore mismatch")
                        for _ in 0..<8 {
                            let a=try worker.tick(forward:10),b=try copy.tick(forward:10)
                            try check(a.x==b.x && a.y==b.y && a.ui.health==b.ui.health && a.presentation.actors.map(\.state)==b.presentation.actors.map(\.state),"Component future state diverged")
                        }
                    }
                }
                let resources=savedResources!,art=try Art(wad:resources)
                if kind == .textures || kind == .resources || kind == .weapons {
                    let heights=try art.textureHeights()
                    for name in heights.keys {_=try art.image(MaterialKey(name:name,flat:false))}
                    print("PASS \(kind.rawValue)/extras=\(extras): all \(heights.count) texture definitions decode")
                }
                if extras {
                    let blank=resources.spriteLumpIndex("TNT1A0")!
                    let image=try art.patch(lump:blank).image
                    try check(stride(from:3,to:image.rgba.count,by:4).allSatisfy{image.rgba[$0]==0},"extras blank actor is visible")
                }
                if kind == .music {
                    let source=try WAD(url:root.appendingPathComponent("id1-mus.wad"))
                    var count=0
                    for lump in source.lumps where lump.name.hasPrefix("D_") {
                        let midi=try MUS.midi(resources.lump(lump.name)!.data)
                        try check(midi.prefix(4)==Data("MThd".utf8),"Music lump failed decoding");count+=1
                    }
                    try check(count==17 && plan.track=="D_IBEGIN","Music preview mapping mismatch")
                    print("PASS all 17 music-pack MIDI tracks and explicit D_IBEGIN audition default")
                }
                print("PASS \(kind.rawValue)/extras=\(extras): \(plan.mapLimit) maps at spawn/tic35, \(rendered) triangles, \(actorFrames.count) sprite frames, first/last map save/future state")
            }
        }
        for extras in [false,true] {
            let plan=try BundledPreviewPlan(root:root,content:.weapons,extras:extras)
            for (fixture,weapon,hold) in [("rust-incinerator",5,12),("rust-blade-full",6,85)] {
                let paths=plan.paths+[exe.deletingLastPathComponent().appendingPathComponent("fixtures/\(fixture).wad")]
                let worker=ExtendedWorker();defer{worker.close()}
                _=try worker.start(executable:exe,paths:paths,map:1,base:plan.base,profile:plan.profile)
                let resources=try WAD(previewResources:paths,baseIndex:plan.base,profile:plan.profile,identity:worker.identity!)
                let art=try Art(wad:resources)
                _=try worker.tick(forward:25,count:3)
                _=try worker.tick(buttons:UInt8(4 | (weapon<<3)))
                _=try worker.tick(count:35);let ready=try worker.tick(count:35)
                try check(ready.presentation.readyWeapon==weapon,"Component weapon pickup failed")
                var names=Set<String>(),weapons=Set<String>(),maxActors=0,last=ready
                for tic in 0..<hold+35 {
                    last=try worker.tick(buttons:tic<hold ? 1:0)
                    maxActors=max(maxActors,last.presentation.actors.count)
                    for sprite in last.presentation.actors+last.presentation.weapons where names.insert(sprite.name).inserted {
                        guard let index=resources.spriteLumpIndex(sprite.name) else {throw PortError("Missing component firing sprite: \(sprite.name)")}
                        _=try art.patch(lump:index)
                    }
                    weapons.formUnion(last.presentation.weapons.map(\.name))
                }
                try check(last.presentation.ammo<ready.presentation.ammo && maxActors>0 && weapons.count>1,"Component weapon firing did not advance")
                print("PASS component \(fixture)/extras=\(extras): pickup, fire, \(names.count) decoded frames, ammo \(ready.presentation.ammo)->\(last.presentation.ammo)")
            }
        }
    }
}
