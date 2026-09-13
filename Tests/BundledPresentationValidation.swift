// Appended to Renderer.swift by test-bundled-presentation.sh for production shader access.
extension Renderer {
    func validateSkyPixels(_ wad:WAD)throws {
        let palette=Array(wad.lump("PLAYPAL")!.data.prefix(768)),maps=Array(wad.lump("COLORMAP")!.data)
        func texture(_ w:Int,_ h:Int,_ pixels:[UInt8],format:MTLPixelFormat = .rgba8Unorm) -> MTLTexture {
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:w,height:h,mipmapped:false);d.storageMode = .shared;d.usage=[.shaderRead,.renderTarget]
            let t=device.makeTexture(descriptor:d)!
            pixels.withUnsafeBytes {t.replace(region:MTLRegionMake2D(0,0,w,h),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:w*4)};return t
        }
        let w=96,h=64,tw=256,th=128
        let output=texture(w,h,[UInt8](repeating:0,count:w*h*4),format:.bgra8Unorm)
        let dd=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:w,height:h,mipmapped:false);dd.usage = .renderTarget
        let depth=device.makeTexture(descriptor:dd)!
        let pbuf=device.makeBuffer(bytes:palette,length:palette.count,options:.storageModeShared)!,mbuf=device.makeBuffer(bytes:maps,length:maps.count,options:.storageModeShared)!
        var probes=0
        for frame in 0...1 {for layered in [false,true] {for surface in [false,true] {
            func index(_ x:Int,_ y:Int,_ foreground:Bool)->Int {foreground ? ((x/32+y/16)%2==0 ? 0:200):(10+((x/32+y/16+frame)%4)*45)}
            func pixels(_ foreground:Bool)->[UInt8] {(0..<tw*th).flatMap {v -> [UInt8] in let i=index(v%tw,v/tw,foreground);return [palette[i*3],palette[i*3+1],palette[i*3+2],foreground && i==0 ? 0:255]}}
            let bg=texture(tw,th,pixels(false)),fg=texture(tw,th,pixels(true))
            let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=output;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
            pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare
            let cmd=queue.makeCommandBuffer()!,e=cmd.makeRenderCommandEncoder(descriptor:pass)!
            e.setRenderPipelineState(surface ? skySurfacePipeline:skyPipeline)
            var camera=surface ? SIMD4<Float>(0,0,-2,1):SIMD4<Float>(0,0,1,0),power=SIMD4<Float>(0,0,0,-1)
            var mapping=SIMD4<Float>(64+Float(frame)*3,100,1,1),front=SIMD4<Float>(-45+Float(frame)*7,60,layered ? 0.5:0,1.25)
            e.setFragmentBytes(&camera,length:16,index:0);e.setFragmentBytes(&power,length:16,index:2)
            e.setFragmentBuffer(pbuf,offset:0,index:3);e.setFragmentBuffer(mbuf,offset:0,index:4)
            e.setFragmentBytes(&mapping,length:16,index:6);e.setFragmentBytes(&front,length:16,index:7)
            e.setFragmentTexture(bg,index:0);e.setFragmentTexture(fg,index:4)
            if surface {
                func v(_ x:Float,_ y:Float)->WorldVertex {WorldVertex(position:SIMD4(x,y,0,1),uvLight:.zero)}
                let vertices=[v(-1,-1),v(1,-1),v(1,1),v(-1,-1),v(1,1),v(-1,1)]
                var matrix=matrix_identity_float4x4;e.setVertexBytes(&matrix,length:64,index:1);e.setVertexBytes(vertices,length:vertices.count*48,index:0)
            }
            e.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:surface ? 6:3);e.endEncoding();cmd.commit();cmd.waitUntilCompleted()
            guard cmd.status == .completed else {throw PortError("Sky GPU failure")}
            var bytes=[UInt8](repeating:0,count:w*h*4);output.getBytes(&bytes,bytesPerRow:w*4,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
            for y in 0..<h {for x in 0..<w {
                let sx=(Double(x)+0.5)/Double(w)*2-1,sy=1-(Double(y)+0.5)/Double(h)*2
                let direction=surface ? SIMD3<Double>(sx,sy,2):SIMD3<Double>(1,sy*0.57735027,sx*0.57735027)
                func sample(_ m:SIMD4<Float>,_ foreground:Bool)->Int {
                    let angle=atan2(-direction.z,direction.x)/(2*Double.pi)+Double(m.x)/1024
                    let col=floor((angle-floor(angle))*1024)*Double(m.z)
                    let row=Double(m.y)-160*direction.y/hypot(direction.x,direction.z)*Double(m.w)
                    func wrap(_ value:Double,_ n:Int)->Int {let i=Int(floor(value));return (i%n+n)%n}
                    return index(wrap(col,tw),wrap(row,th),foreground)
                }
                var selected=sample(mapping,false)
                if layered {let f=sample(front,true);if f != 0 {selected=f}}
                for c in 0..<3 {guard bytes[(y*w+x)*4+c]==palette[selected*3+2-c] else {throw PortError("Sky pixel mismatch at \(x),\(y), surface \(surface), layered \(layered)")}}
                probes+=1
            }}
        }}}
        print("PASS \(probes) fullscreen/sector sky pixels, two changing backgrounds, independent layer offsets/scales and index-zero transparency")
    }
    func validateBundledPresentation(root:URL,executable:URL)throws {
        for content in BundledPreviewPlan.Content.allCases {
            let plan=try BundledPreviewPlan(root:root,content:content,extras:true),worker=ExtendedWorker();defer{worker.close()}
            let initial=try worker.start(executable:executable,paths:plan.paths,map:1,base:plan.base,profile:plan.profile)
            let wad=try WAD(previewResources:plan.paths,baseIndex:plan.base,profile:plan.profile,identity:worker.identity!)
            let definition=try StatusBarDefinition(data:wad.lump("SBARDEF")!.data)
            guard definition.bars.count==3,definition.bars[0].height==32,!definition.bars[0].fullscreen,definition.bars[1].fullscreen,definition.bars[2].nodes.isEmpty else {throw PortError("Unexpected bundled HUD variants")}
            let hud=try SpriteRenderer(device:device,wad:wad,preload:false,hudOnly:true);hud.previewUI=initial.ui;hud.rustWeaponIcons=plan.rustWeapons
            let dd=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:640,height:400,mipmapped:false);dd.usage = .renderTarget
            let depth=device.makeTexture(descriptor:dd)!
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:640,height:400,mipmapped:false);d.storageMode = .shared;d.usage = .renderTarget
            // Pipelines are created for the test view's BGRA format.
            d.pixelFormat = .bgra8Unorm;let output=device.makeTexture(descriptor:d)!
            var results=[Data]()
            for choice in [0,1,-1] {
                hud.previewHUD=choice
                let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=output;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
                pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare
                let command=queue.makeCommandBuffer()!,e=command.makeRenderCommandEncoder(descriptor:pass)!;e.setRenderPipelineState(spritePipeline);bindColors(e)
                var power=SIMD4<Float>.zero;e.setFragmentBytes(&power,length:16,index:2)
                var state=MD_HUD();state.health=100;state.readyAmmo=50;state.weapons=initial.ui.weapons
                hud.drawHUD(encoder:e,state:state,width:640,height:400,style:choice==0 ? .classic:.minimal)
                e.endEncoding();command.commit();command.waitUntilCompleted();guard command.status == .completed else {throw PortError("HUD GPU failure")}
                var pixels=[UInt8](repeating:0,count:640*400*4);output.getBytes(&pixels,bytesPerRow:2560,from:MTLRegionMake2D(0,0,640,400),mipmapLevel:0)
                guard pixels.contains(where:{$0 != 0}) else {throw PortError("Empty HUD")};results.append(Data(pixels))
            }
            guard Set(results).count==3 else {throw PortError("HUD choices did not change presentation")}
            if content == .doom2 {
                guard MusicPlayer.recordedTrack("D_RUNNIN",wad:wad)=="H_RUNNIN",MusicPlayer.recordedTrack("D_STLKS2",wad:wad)=="H_STALKS" else {throw PortError("Recorded track/alias selection failed")}
                let player=try MusicPlayer(wad:wad,map:"MAP01",track:"D_DM2TTL",backend:"apple",preferRecorded:true)
                guard player.backend=="recorded",player.duration>10,!player.isPlaying else {throw PortError("Recorded player initialization failed")}
                player.volume=0;player.update(active:true);RunLoop.current.run(until:Date().addingTimeInterval(0.15))
                guard player.isPlaying,player.position>0 else {throw PortError("Recorded player did not advance")}
                player.update(active:false);let position=player.position;RunLoop.current.run(until:Date().addingTimeInterval(0.05));guard !player.isPlaying,abs(player.position-position)<0.01 else {throw PortError("Recorded player did not pause")}
                player.looping=false;player.validationNearEnd();player.update(active:true)
                RunLoop.current.run(until:Date().addingTimeInterval(0.2));player.update(active:true)
                guard !player.isPlaying,player.loopCount==0 else {throw PortError("Non-looping recorded music restarted")}
                try player.select("D_DM2TTL");player.looping=true;player.validationNearEnd();player.update(active:true)
                RunLoop.current.run(until:Date().addingTimeInterval(0.2));player.update(active:true)
                guard player.isPlaying,player.loopCount==1 else {throw PortError("Recorded music failed to loop")}
                player.update(active:false)
                guard try player.validationStaleCompletion() else {throw PortError("Old track completion stopped its replacement")}
                player.preferRecorded=false;try player.select("D_DM2TTL");guard player.backend=="apple",player.resolvedTrackName=="D_DM2TTL" else {throw PortError("MIDI fallback selection failed")}
            }
            print("PASS \(content.rawValue) authored HUD tree, status/fullscreen/native GPU presentation, resource overrides")
        }
        print("PASS recorded alias selection, native audio start/advance/pause, looping/non-looping completion and original MIDI selection")
    }
}
