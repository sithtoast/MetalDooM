import Foundation

@main struct ExtendedInterpolationValidation {
    static func check(_ ok:Bool,_ message:String) throws {if !ok {throw PortError(message)}}
    static func sprite(_ x:Float,_ y:Float,_ name:String="PISGA0")->ExtendedSprite {
        .init(name:name,x:x,y:y,z:0,floorZ:0,light:1,flags:0,editor:0,state:0)
    }
    static func run() throws {
        typealias Frame=ExtendedInterpolation.Frame
        let first=Frame(tic:1,map:1,playing:true,snap:false,position:SIMD3(0,0,41),angle:Float.pi*359/180,weapon:1,weapons:[sprite(1,32),sprite(1,32,"PISFA0")])
        let next=Frame(tic:2,map:1,playing:true,snap:false,position:SIMD3(8,4,43),angle:Float.pi/180,weapon:1,weapons:[sprite(5,36),sprite(5,36,"PISFA0")])
        var tween=ExtendedInterpolation();tween.setActive(true);tween.accept(first,now:0);tween.accept(next,now:1.0/35)
        let half=tween.sample(now:1.5/35)!
        try check(half.position==SIMD3(4,2,42) && half.weapons==[SIMD2(3,34),SIMD2(3,34)],"Wrong midpoint or flash alignment")
        try check(abs(sin(half.angle))<0.00001 && cos(half.angle)>0.9999,"Yaw took long path through wrap")
        try check(tween.sample(now:2.0/35)!.position==next.position && tween.sample(now:100)!.position==next.position && tween.sample(now:100)!.angle==next.angle,"Extrapolated past current state")
        tween.setActive(false);try check(tween.sample(now:1.5/35)!.position==next.position,"Pause did not snap")
        tween.setActive(true);try check(tween.sample(now:1.5/35)!.position==next.position,"Resume reused stale history")
        for mode in ["teleport","map","tic","dead","late","distance","weapon","frame","jump"] {
            tween=ExtendedInterpolation();tween.setActive(true);tween.accept(first,now:0)
            let frame=Frame(tic:mode=="tic" ? 4:2,map:mode=="map" ? 2:1,playing:mode != "dead",snap:mode=="teleport",
                position:mode=="distance" ? SIMD3(100,0,41):next.position,angle:next.angle,weapon:mode=="weapon" ? 2:1,
                weapons:[sprite(mode=="jump" ? 100:5,36,mode=="frame" ? "PISGB0":"PISGA0"),sprite(5,36,"PISFA0")])
            let time=mode=="late" ? 1:1.0/35;tween.accept(frame,now:time)
            let sample=tween.sample(now:time)!
            if ["weapon","frame","jump"].contains(mode) {try check(sample.weapons[0]==SIMD2(frame.weapons[0].x,36),"Weapon discontinuity blended")}
            else {try check(sample.position==frame.position && sample.weapons[0]==SIMD2(frame.weapons[0].x,36),"Discontinuity blended: \(mode)")}
        }
        var actor=sprite(8,4);actor.previous=SIMD4(0,0,-2,-2)
        try check(actor.position(fraction:0.5)==SIMD4(4,2,-1,-1),"Actor/feet did not share midpoint")
        actor.previous=nil;try check(actor.position(fraction:0)==SIMD4(8,4,0,0),"Spawn/teleport interpolated")
        let a=Sector(floor:0,ceiling:64,light:1,floorTexture:"A",ceilingTexture:"B",backFloor:0,backCeiling:64,spriteClip:SIMD2(0,64))
        var b=a;b.floor=4;b.ceiling=60;b.backFloor=4;b.backCeiling=60;b.spriteClip=SIMD2(4,60)
        let middle=ExtendedSurfaceInterpolation.interpolate(a,b,0.5)
        try check(middle.floor==2 && middle.ceiling==62 && middle.backFloor==2 && middle.backCeiling==62 && middle.spriteClip==SIMD2(2,62),"Plane/wall/clip midpoint mismatch")
        b.spriteClip=SIMD2(-Float.infinity,60)
        try check(ExtendedSurfaceInterpolation.interpolate(a,b,0.5)==b,"Fake-flat region transition interpolated")
        b=a;b.floor=100;try check(ExtendedSurfaceInterpolation.interpolate(a,b,0.5)==b,"Instant surface displacement interpolated")
        let unbounded=Sector(floor:0,ceiling:64,light:1,floorTexture:"A",ceilingTexture:"B")
        try check(ExtendedSurfaceInterpolation.interpolate(unbounded,unbounded,0.5)==unbounded,"Unbounded clip produced NaN")
        print("PASS actor/feet midpoint, spawn snap, front/back planes and clip alignment, fake-flat/jump snaps and unbounded clips")
        print("PASS interpolation midpoint, shortest yaw, weapon/flash alignment, clamping, pause/resume and nine discontinuity cases")
        let root=URL(fileURLWithPath:CommandLine.arguments[1]),exe=URL(fileURLWithPath:CommandLine.arguments[2])
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        let fixture=exe.deletingLastPathComponent().appendingPathComponent("fixtures/interpolation-teleport.wad")
        let worker=ExtendedWorker();defer{worker.close()}
        var state=try worker.start(executable:exe,paths:paths+[fixture],map:1,base:1)
        var teleported=false
        for _ in 0..<35 {
            let old=state;state=try worker.tick(forward:25)
            if state.presentation.snapCamera {
                try check(abs(state.angle-Float.pi/2)<0.01 && abs(state.x+16)<0.01,"Wrong teleport destination")
                try check(abs(state.x-old.x)<64 && abs(state.y-old.y)<64,"Fixture did not exercise short teleport")
                teleported=true;break
            }
        }
        try check(teleported,"Actual teleport failed to signal camera discontinuity")
        print("PASS actual short walk-over teleport signals snap in MSP5")
        let walk=ExtendedWorker();defer{walk.close()}
        _=try walk.start(executable:exe,paths:paths,map:1,base:1)
        _=try walk.tick(count:35)
        var positions=Set<String>(),eyes=Set<Float>()
        for _ in 0..<16 {
            state=try walk.tick(forward:25)
            positions.insert("\(state.presentation.weapons.first!.x),\(state.presentation.weapons.first!.y)");eyes.insert(state.eyeZ)
        }
        try check(positions.count>4 && eyes.count>4,"Existing engine view/weapon bob absent")
        let saved=try walk.save(),load=ExtendedWorker();defer{load.close()}
        _=try load.start(executable:exe,paths:paths,map:1,base:1);let restored=try load.restore(saved)
        try check(restored.eyeZ==state.eyeZ && restored.presentation.weapons.first!.x==state.presentation.weapons.first!.x,"Bob phase not restored")
        for _ in 0..<35 {
            let a=try walk.tick(forward:25),b=try load.tick(forward:25)
            try check(a.eyeZ==b.eyeZ && a.presentation.weapons.first?.x==b.presentation.weapons.first?.x && a.presentation.weapons.first?.y==b.presentation.weapons.first?.y,"Bob diverged after restore")
        }
        print("PASS real walking view/weapon bob and exact restored phase/future tics")
    }
    static func main() {do {try run()}catch{fputs("FAIL: \(error)\n",stderr);exit(1)}}
}
