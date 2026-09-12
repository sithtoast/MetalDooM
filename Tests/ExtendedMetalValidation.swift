import AppKit
import MetalKit

func runMeshMetalValidation() throws {
    let application=NSApplication.shared;application.setActivationPolicy(.regular)
    let root=URL(fileURLWithPath:CommandLine.arguments[1]),exe=URL(fileURLWithPath:CommandLine.arguments[2])
    let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
    func surface(_ x:CGFloat) throws -> (NSWindow,GameView,Renderer) {
        let window=NSWindow(contentRect:NSRect(x:x,y:100,width:640,height:400),styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false
        let view=GameView(frame:NSRect(x:0,y:0,width:640,height:400),device:MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float
        view.isPaused=true;view.framebufferOnly=false;view.inputBlocked=true
        let renderer=try Renderer(view:view);view.delegate=renderer
        renderer.onError={error in fputs("FAIL renderer: \(error)\n",stderr);exit(1)}
        window.contentView=view;window.orderFront(nil)
        view.layoutSubtreeIfNeeded();view.updateResolution()
        return (window,view,renderer)
    }
    func frame(_ view:GameView,_ renderer:Renderer) throws -> Data {
        try autoreleasepool {
            view.layoutSubtreeIfNeeded()
            view.updateResolution()
            view.releaseDrawables()
            guard let drawable=view.currentDrawable else { throw PortError("No validation drawable") }
            let texture=drawable.texture,w=texture.width,h=texture.height
            guard w==Int(view.drawableSize.width),h==Int(view.drawableSize.height) else {throw PortError("Unexpected drawable dimensions \(w)x\(h)")}
            view.draw()
            let buffer=renderer.device.makeBuffer(length:w*h*4,options:.storageModeShared)!
            let command=renderer.queue.makeCommandBuffer()!,encoder=command.makeBlitCommandEncoder()!
            encoder.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:w,height:h,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:w*4,destinationBytesPerImage:w*h*4)
            encoder.endEncoding();command.commit();command.waitUntilCompleted()
            guard command.status == .completed else { throw PortError("GPU readback failed") }
            RunLoop.current.run(until:Date().addingTimeInterval(0.001))
            return Data(bytes:buffer.contents(),count:w*h*4)
        }
    }
    do {
        let blendPaths=paths+[exe.deletingLastPathComponent().appendingPathComponent("fixtures/blend-empty.wad")]
        let worker=ExtendedWorker();defer{worker.close()}
        let initial=try worker.start(executable:exe,paths:blendPaths,map:1,base:1)
        let resources=try WAD(previewResources:blendPaths,baseIndex:1,profile:1,identity:worker.identity!)
        let builder=try ExtendedSceneBuilder(resources:resources)
        let (window,view,renderer)=try surface(0);defer{view.delegate=nil;window.close()}
        try renderer.loadExtendedPreview(builder.prepare(initial));renderer.validationHUDVisible=false
        func words(_ values:[UInt32])->Data {Data(values.flatMap {v in (0..<4).map{UInt8(truncatingIfNeeded:v>>(8*$0))}})}
        let palette=(0..<256).flatMap{[UInt8($0),UInt8($0),UInt8($0)]}
        let normal=(0..<256).flatMap{bg in (0..<256).map{fg in UInt8((bg+2*fg)/3)}}
        let additive=(0..<256).flatMap{bg in (0..<256).map{fg in UInt8(min(255,bg+fg))}}
        let custom=(0..<256).flatMap{bg in (0..<256).map{fg in UInt8((2*bg+fg)/3)}}
        let palettes=palette+(0..<256).flatMap{[UInt8($0),0,0]}
        let maps=Array(UInt8(0)...UInt8(255))+Array(UInt8(0)...UInt8(255))+Array((UInt8(0)...UInt8(255)).reversed())
        let tables=try ExtendedBlendTables(data:Data("MBL3".utf8)+words([3,UInt32(palettes.count),3,UInt32(maps.count),0])+Data(palettes+maps+normal+additive+custom))
        var images:[Int:PatchImage]=[:]
        // Distinct RGB control colors avoid invisible mask pixels where opaque
        // art equals the background; fullbright blending must use source indices.
        for color in [100,200,220] {
            var pixels=[UInt8](repeating:0,count:32*64*4)
            for y in 0..<64 {for x in 0..<32 where !(14..<18).contains(x) || !(28..<36).contains(y) {
                let p=(y*32+x)*4;pixels[p]=UInt8(color);pixels[p+1]=0;pixels[p+2]=255;pixels[p+3]=255
            }}
            images[color]=PatchImage(image:PixelImage(width:32,height:64,rgba:pixels),left:16,top:64,paletteIndices:[UInt8](repeating:UInt8(color),count:32*64))
        }
        func actor(_ x:Float,_ color:Int)->MD_Thing {
            var value=MD_Thing();value.x=x;value.lump=Int32(color);value.light=1;value.fullbright=1;return value
        }
        let near=actor(0,100),far=actor(64,200),occluder=actor(-32,220)
        try renderer.validationActors(resources:resources,things:[],images:images,blend:[],tables:tables,reset:true)
        func draw(_ actors:[MD_Thing],_ modes:[Int]) throws -> Data {
            try renderer.validationActors(resources:resources,things:actors,images:images,blend:modes,tables:tables)
            return try frame(view,renderer)
        }
        let background=try draw([],[]),nearOpaque=try draw([near],[0]),farOpaque=try draw([far],[0])
        let nearMask=stride(from:0,to:background.count,by:4).map{nearOpaque[$0..<$0+4] != background[$0..<$0+4]}
        let farMask=stride(from:0,to:background.count,by:4).map{farOpaque[$0..<$0+4] != background[$0..<$0+4]}
        let overlap=zip(nearMask,farMask).filter{$0 && $1}.count
        guard overlap>500 else {throw PortError("Translucency fixture has no overlap")}
        func expected(_ mode:Int)->Data {
            var output=background
            for i in nearMask.indices where nearMask[i] || farMask[i] {
                let p=i*4
                var color=(Int(background[p])+Int(background[p+1])+Int(background[p+2])+1)/3
                for (visible,fg) in [(farMask[i],200),(nearMask[i],100)] where visible {
                    color=mode==1 ? (color+2*fg)/3:mode==2 ? min(255,color+fg):(2*color+fg)/3
                }
                output[p]=UInt8(color);output[p+1]=UInt8(color);output[p+2]=UInt8(color);output[p+3]=255
            }
            return output
        }
        for mode in [1,2,3] {
            let actual=try draw([near,far],[mode,mode]),reverse=try draw([far,near],[mode,mode])
            guard actual==reverse else {throw PortError("Translucency depends on actor enumeration order")}
            let oracle=expected(mode)
            guard actual==oracle else {
                let mismatches=zip(actual,oracle).filter{$0 != $1}.count
                let examples=stride(from:0,to:actual.count,by:4).filter{actual[$0..<$0+4] != oracle[$0..<$0+4]}.prefix(5).map{p in "pixel \(p/4): actual=\(Array(actual[p..<p+4])) expected=\(Array(oracle[p..<p+4])) bg=\(Array(background[p..<p+4])) masks=\(nearMask[p/4])/\(farMask[p/4])"}
                throw PortError("Blend mode \(mode) differs from palette oracle in \(mismatches) bytes: \(examples)")
            }
        }
        var shaded=near;shaded.fullbright=0;shaded.light=0.4
        let shadedOpaque=try draw([shaded],[0]),shadedBlend=try draw([shaded],[1])
        var shadedOracle=background
        for p in stride(from:0,to:background.count,by:4) where shadedOpaque[p..<p+4] != background[p..<p+4] {
            let bg=(Int(background[p])+Int(background[p+1])+Int(background[p+2])+1)/3
            let fg=(Int(shadedOpaque[p])+Int(shadedOpaque[p+1])+Int(shadedOpaque[p+2])+1)/3
            let color=UInt8((bg+2*fg)/3)
            shadedOracle[p]=color;shadedOracle[p+1]=color;shadedOracle[p+2]=color;shadedOracle[p+3]=255
        }
        guard shadedBlend==shadedOracle else {throw PortError("Shaded translucent foreground differs from palette oracle")}
        let opaque=try draw([occluder],[0]),behind=try draw([near,occluder,far],[1,0,2])
        var occluded=0
        for p in stride(from:0,to:opaque.count,by:4) where opaque[p..<(p+4)] != background[p..<(p+4)] {
            guard opaque[p..<(p+4)]==behind[p..<(p+4)] else {throw PortError("Translucency draws through opaque actors")};occluded+=1
        }
        guard occluded>500 else {throw PortError("No opaque actor occlusion tested")}
        let outside=actor(512,100)
        guard try draw([outside],[1])==background else {throw PortError("Translucency draws through room walls")}
        var shadow=near;shadow.shadow=1
        guard try draw([shadow],[2])==draw([shadow],[0]) else {throw PortError("Fuzz did not take precedence over translucency")}
        print("PASS native fullbright/shaded normal/additive/custom lookup pixels, \(overlap) overlapping pixels sorted both orders, cutouts, \(occluded) opaque actor pixels, wall occlusion and fuzz precedence")
        renderer.validationColors(tables)
        let neutral=try draw([],[])
        renderer.validationColors(palette:1)
        let flashed=try draw([],[])
        var flashOracle=neutral
        for p in stride(from:0,to:neutral.count,by:4) {
            let index=UInt8((Int(neutral[p])+Int(neutral[p+1])+Int(neutral[p+2])+1)/3)
            flashOracle[p]=0;flashOracle[p+1]=0;flashOracle[p+2]=index;flashOracle[p+3]=255
        }
        guard flashed==flashOracle else {throw PortError("Whole-frame palette lookup differs from oracle")}
        renderer.validationColors()
        guard try draw([],[])==neutral else {throw PortError("Palette removal did not restore exact pixels")}
        renderer.validationColors(fixed:1);let lit=try draw([],[])
        renderer.validationColors(fixed:2);let inverted=try draw([],[])
        for p in stride(from:0,to:lit.count,by:4) {
            guard inverted[p]==255-lit[p],inverted[p+1]==255-lit[p+1],inverted[p+2]==255-lit[p+2] else {throw PortError("Fixed colormap lookup differs from oracle")}
        }
        let mappedActors=try draw([near,far],[3,1])
        var mappedOracle=inverted
        for i in nearMask.indices where nearMask[i] || farMask[i] {
            var color=Int(inverted[i*4])
            if farMask[i] {color=(color+2*55)/3}
            if nearMask[i] {color=(2*color+155)/3}
            for c in 0..<3 {mappedOracle[i*4+c]=UInt8(color)}
        }
        guard mappedActors==mappedOracle else {throw PortError("Fixed colormap/translucency interaction differs from oracle")}
        renderer.validationColors()
        // This angled wall crosses the actor's billboard. Use opaque depth
        // visibility to independently determine per-pixel blend order.
        let wallImage=images[220]!,d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:32,height:64,mipmapped:false)
        d.storageMode = .shared;d.usage = .shaderRead
        let tex=renderer.device.makeTexture(descriptor:d)!
        wallImage.image.rgba.withUnsafeBytes{tex.replace(region:MTLRegionMake2D(0,0,32,64),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:128)}
        d.pixelFormat = .r8Uint;let indexTexture=renderer.device.makeTexture(descriptor:d)!
        wallImage.paletteIndices!.withUnsafeBytes{indexTexture.replace(region:MTLRegionMake2D(0,0,32,64),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:32)}
        func wallVertex(_ x:Float,_ y:Float,_ z:Float,_ u:Float,_ v:Float)->WorldVertex {WorldVertex(position:SIMD4(x,y,z,1),uvLight:SIMD4(u,v,1,1))}
        let polygon=TransparentPolygon(vertices:[wallVertex(-32,0,-64,0,64),wallVertex(32,0,64,32,64),wallVertex(32,64,64,32,0),wallVertex(-32,64,-64,0,0)],material:nil,texture:tex,indices:indexTexture,blend:3,wall:true)
        try renderer.validationWall(polygon,opaque:true)
        let wallOnly=try draw([],[]),opaqueBoth=try draw([near],[0])
        try renderer.validationWall(polygon)
        let transparentBoth=try draw([near],[1])
        var expected=background,frontActor=0,frontWall=0
        for i in nearMask.indices {
            let p=i*4,wall=wallOnly[p..<p+4] != background[p..<p+4],actor=nearMask[i]
            if !wall && !actor {continue}
            var color=(Int(background[p])+Int(background[p+1])+Int(background[p+2])+1)/3
            let fg=(Int(wallOnly[p])+Int(wallOnly[p+1])+Int(wallOnly[p+2])+1)/3
            let actorNear=opaqueBoth[p..<p+4]==nearOpaque[p..<p+4]
            if wall && actor && actorNear {color=(2*color+fg)/3;color=(color+200)/3;frontActor+=1}
            else if wall && actor {color=(color+200)/3;color=(2*color+fg)/3;frontWall+=1}
            else if wall {color=(2*color+fg)/3}
            else {color=(color+200)/3}
            for c in 0..<3 {expected[p+c]=UInt8(color)}
        }
        guard frontActor>100,frontWall>100 else {throw PortError("Wall fixture did not cross the actor")}
        guard transparentBoth==expected else {
            let differences=zip(transparentBoth,expected).filter{$0 != $1}.count
            throw PortError("Wall/actor BSP differs from per-pixel depth oracle in \(differences) bytes")
        }
        try renderer.validationWall(nil)
        print("PASS palette flash/removal, exact fixed-colormap and blend interaction, crossing wall/actor order (\(frontActor) actor-front, \(frontWall) wall-front pixels)")

    }
    for number in [1,13,16] {
        let worker=ExtendedWorker();defer{worker.close()}
        let first=try worker.start(executable:exe,paths:paths,map:number,base:1)
        let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
        let builder=try ExtendedSceneBuilder(resources:resources)
        let (window,view,renderer)=try surface(0),(oracleWindow,oracleView,oracleRenderer)=try surface(650)
        defer{view.delegate=nil;oracleView.delegate=nil;window.close();oracleWindow.close()}
        var state=first,reused=0,total=0,loadTimes:[Double]=[]
        for tic in 0...71 {
            let scene=try builder.prepare(state),before=renderer.validationPreviewBuffers
            let start=ProcessInfo.processInfo.systemUptime
            try renderer.loadExtendedPreview(scene)
            if tic>0 { loadTimes.append((ProcessInfo.processInfo.systemUptime-start)*1000) }
            let after=renderer.validationPreviewBuffers
            for (key,identity) in before where !scene.changedMaterials.contains(key) {
                guard after[key]==identity else { throw PortError("Unchanged GPU buffer replaced") };reused+=1
            }
            total+=after.count
            if [0,1,5,12,36,40,71].contains(tic) {
                try oracleRenderer.loadExtendedPreview(scene.validationReference())
                let actual=try frame(view,renderer),expected=try frame(oracleView,oracleRenderer)
                if number==1 && tic==0 {
                    renderer.validationHUDVisible=false
                    let hidden=try frame(view,renderer)
                    renderer.validationHUDVisible=true
                    let restored=try frame(view,renderer)
                    guard restored==actual else {
                        let differing=stride(from:0,to:actual.count,by:4).filter{actual[$0..<$0+4] != restored[$0..<$0+4]}
                        throw PortError("HUD restoration changed \(differing.count) pixels, first \(differing.first ?? -1), last \(differing.last ?? -1)")
                    }
                    var left=0,right=0
                    let width=Int(view.drawableSize.width),height=Int(view.drawableSize.height)
                    guard actual.count==width*height*4,hidden.count==actual.count else {throw PortError("HUD drawable size changed")}
                    for pixel in 0..<(width*height) where actual[pixel*4..<pixel*4+4] != hidden[pixel*4..<pixel*4+4] {
                        let x=pixel%width,y=pixel/width
                        guard y>=height*3/5 else { throw PortError("HUD changed world pixels above its bottom region") }
                        if x<width/2 {left+=1} else {right+=1}
                    }
                    guard left>20,right>20 else {throw PortError("Missing visible health/armor or weapon/ammo HUD")}
                    renderer.validationColors(palette:1)
                    let flash=try frame(view,renderer),colors=state.blendTables!.palettes
                    let probes=stride(from:0,to:actual.count,by:4).filter{actual[$0..<$0+4] != hidden[$0..<$0+4]}.prefix(64)
                    for p in probes {
                        let rgb=[Int(actual[p+2]),Int(actual[p+1]),Int(actual[p])]
                        let index=(0..<256).min {a,b in
                            func distance(_ i:Int)->Int {(0..<3).reduce(0){sum,c in let d=rgb[c]-Int(colors[i*3+c]);return sum+d*d}}
                            let da=distance(a),db=distance(b);return da==db ? a<b:da<db
                        }!
                        guard flash[p]==colors[768+index*3+2],flash[p+1]==colors[768+index*3+1],flash[p+2]==colors[768+index*3] else {throw PortError("HUD palette mapping failed")}
                    }
                    renderer.validationColors()
                    guard try frame(view,renderer)==actual else {throw PortError("HUD palette removal changed pixels")}
                    print("PASS native \(width)x\(height) HUD pixels left \(left), right \(right), bottom-only composition and exact restoration")
                }
                guard actual==expected else {
                    let count=zip(actual,expected).filter{$0 != $1}.count
                    throw PortError("MAP\(number) tic\(tic): \(count) GPU bytes differ from full reference mesh")
                }
            }
            if tic<71 { state=try worker.tick(buttons:tic==35 ? 2:tic>50 ? 1:0) }
        }
        guard reused>0 else { throw PortError("No Metal buffers reused") }
        print(String(format:"PASS MAP%02d: 7 exact GPU pixel comparisons to old full meshes; %d/%d material-buffer observations reused; native load mean %.2f ms, max %.2f ms",number,reused,total,loadTimes.reduce(0,+)/Double(loadTimes.count),loadTimes.max()!))
    }
    for kind in ["floor","ceiling","both","reverse"] {
        let scrollPaths=paths+[exe.deletingLastPathComponent().appendingPathComponent("fixtures/scroll-\(kind).wad")]
        let worker=ExtendedWorker();defer{worker.close()}
        let first=try worker.start(executable:exe,paths:scrollPaths,map:1,base:1)
        let resources=try WAD(previewResources:scrollPaths,baseIndex:1,profile:1,identity:worker.identity!)
        let builder=try ExtendedSceneBuilder(resources:resources)
        let (window,view,renderer)=try surface(0),(otherWindow,otherView,other)=try surface(650)
        defer{view.delegate=nil;otherView.delegate=nil;window.close();otherWindow.close()}
        try renderer.loadExtendedPreview(builder.prepare(first))
        let before=renderer.validationPreviewBuffers
        let state=try worker.tick(),scene=try builder.prepare(state)
        try renderer.loadExtendedPreview(scene);try other.loadExtendedPreview(scene.validationReference())
        let actual=try frame(view,renderer)
        guard actual == (try frame(otherView,other)) else {throw PortError("Scrolling GPU/reference mismatch")}
        for (key,id) in before where !key.flat {guard renderer.validationPreviewBuffers[key]==id else {throw PortError("Scrolling uploaded wall buffer")}}
        try other.loadExtendedPreview(scene.validationReference(stationaryFlats:true))
        let stationary=try frame(otherView,other)
        let changed=zip(actual,stationary).filter{$0 != $1}.count
        guard changed>100 else {throw PortError("Scrolling did not visibly move the \(kind) material")}
        let saved=try worker.save(),loaded=ExtendedWorker();defer{loaded.close()}
        _=try loaded.start(executable:exe,paths:scrollPaths,map:1,base:1)
        let restored=try loaded.restore(saved),restoredBuilder=try ExtendedSceneBuilder(resources:resources)
        try other.loadExtendedPreview(restoredBuilder.prepare(restored))
        guard actual == (try frame(otherView,other)) else {throw PortError("Saved scrolling frame did not restore exactly")}
        print("PASS \(kind): \(changed) GPU bytes differ from stationary flats, exact reference/save pixels and retained wall buffers")
    }

    do {
        let worker=ExtendedWorker();defer{worker.close()}
        _=try worker.start(executable:exe,paths:paths,map:1,base:1)
        let initial=try worker.tick(count:35)
        let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
        let builder=try ExtendedSceneBuilder(resources:resources)
        let (window,view,renderer)=try surface(0);defer{view.delegate=nil;window.close()}
        renderer.validationTime=0;try renderer.loadExtendedPreview(builder.prepare(initial))
        renderer.setExtendedPlayback(active:true)
        let current=try worker.tick(forward:25,turn:640)
        renderer.validationTime=1.0/35;try renderer.loadExtendedPreview(builder.prepare(current))
        let buffers=renderer.validationPreviewBuffers
        let start=try frame(view,renderer)
        renderer.validationTime=1.5/35;let midpoint=try frame(view,renderer)
        renderer.validationTime=2.0/35;let end=try frame(view,renderer)
        guard start != midpoint,midpoint != end,start != end else {throw PortError("Native interpolation did not render intermediate frames")}
        renderer.validationTime=1.5/35;renderer.setExtendedPlayback(active:false)
        guard try frame(view,renderer)==end else {throw PortError("Pause did not render exact endpoint")}
        renderer.validationTime=100
        guard try frame(view,renderer)==end else {throw PortError("Paused interpolation continued")}
        guard buffers==renderer.validationPreviewBuffers else {throw PortError("Interpolation rebuilt world buffers")}
        guard try worker.geometry().tic==current.tic else {throw PortError("Rendering advanced simulation")}
        print("PASS native distinct start/mid/end frames, exact pause endpoint, no wall uploads or simulation ticks")
    }

}
setbuf(stdout,nil)
do { try runMeshMetalValidation() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) }
