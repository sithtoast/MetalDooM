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
}
setbuf(stdout,nil)
do { try runMeshMetalValidation() } catch { fputs("FAIL: \(error)\n",stderr);exit(1) }
