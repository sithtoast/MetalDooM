import Foundation

@main struct ExtendedLifecycleValidation {
    static func check(_ ok:Bool,_ message:String) throws {if !ok {throw PortError(message)}}
    static func main() {do {try run()} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}}
    static func run() throws {
        let exe=URL(fileURLWithPath:CommandLine.arguments[1]),base=URL(fileURLWithPath:CommandLine.arguments[2]),root=URL(fileURLWithPath:CommandLine.arguments[3])
        let fixtures=exe.deletingLastPathComponent().appendingPathComponent("fixtures")
        let rust=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        let normal=[2,3,4,5,6,7,0,9,10,11,12,13,14,0,3,11]
        let routes=normal.enumerated().map{($0.offset+1,false,$0.element)}+[(2,true,15),(10,true,16)]
        for (map,secret,next) in routes {
            let worker=ExtendedWorker();defer{worker.close()}
            let paths=rust+[fixtures.appendingPathComponent(secret ? "lifecycle-secret.wad":"lifecycle-normal.wad")]
            let initial=try worker.start(executable:exe,paths:paths,map:map,base:1)
            try check(initial.ui.playing && initial.ui.map==map,"Wrong initial map/phase")
            let picked=try worker.tick(side:24,count:3)
            try check(picked.ui.health==200 && picked.ui.armor==100 && picked.ui.keys==1 && picked.ui.weapons&4 != 0,"Missing real inventory pickups: health \(picked.ui.health), armor \(picked.ui.armor), keys \(picked.ui.keys), weapons \(picked.ui.weapons)")
            let finished=try worker.tick(buttons:2,count:35)
            try check(finished.ui.phase==(next==0 ? 3:2) && finished.ui.nextMap==next && finished.ui.secretExit==secret,"Wrong campaign route/ending MAP\(map)")
            try check(finished.tic<38 && finished.ui.keys==0 && finished.ui.items>0,"Batch did not stop at exit or clear keys/copy stats")
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            let builder=try ExtendedSceneBuilder(resources:resources)
            _=try builder.prepare(initial);_=try builder.prepare(finished)
            if next>0 {
                let advanced=try worker.advance(restart:false)
                try check(advanced.tic==0 && advanced.ui.playing && advanced.ui.map==next && advanced.geometry?.map.name==String(format:"MAP%02d",next),"Continue did not load tic-zero target")
                try check(advanced.ui.health==200 && advanced.ui.armor==100 && advanced.ui.keys==0 && advanced.ui.weapons&4 != 0 && advanced.ui.ammo==finished.ui.ammo,"Continue lost inventory")
                try check(advanced.ui.kills==0 && advanced.ui.items==0 && advanced.ui.secrets==0,"New level retained counters")
                _=try ExtendedScene(view:advanced,resources:resources)
            }
            let restart=try worker.advance(restart:true)
            try check(restart.tic==0 && restart.ui.playing && restart.ui.health==100 && restart.ui.armor==0 && restart.ui.keys==0 && restart.ui.weapons==3 && restart.ui.ammo==[50,0,0,0],"Restart did not reset world/inventory")
            let again=try worker.advance(restart:true)
            try check(again.geometry?.data==restart.geometry?.data && again.ui.map==restart.ui.map,"Repeated restart changed initial world")
            print("PASS MAP\(map) \(secret ? "secret":"normal") → \(next==0 ? "episode end":String(next)), real pickups, batch boundary, carryover and repeated fresh restart")
        }
        let dead=ExtendedWorker();defer{dead.close()}
        _=try dead.start(executable:exe,paths:[base,fixtures.appendingPathComponent("lifecycle-death.wad")],map:1,base:0,profile:0)
        var state=try dead.tick(count:35)
        while state.ui.playing && state.tic<350 {state=try dead.tick(count:35)}
        try check(state.ui.phase==1 && state.health<=0,"Hazard did not report death")
        let restored=try dead.advance(restart:true)
        try check(restored.ui.playing && restored.health==100 && restored.tic==0,"Death restart failed")
        print("PASS actual damaging-floor death at tic\(state.tic), batch stops, same-session restart at health100/tic0")
        for action in [false] {
            let bad=ExtendedWorker();defer{bad.close()}
            _=try bad.start(executable:exe,paths:[base],map:1,base:0,profile:0)
            var rejected=false;do{_=try bad.advance(restart:action)}catch{rejected=true}
            try check(rejected,"Continue during play accepted")
        }
        print("PASS invalid lifecycle action rejects")
    }
}
