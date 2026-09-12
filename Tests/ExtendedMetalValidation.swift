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
        view.autoResizeDrawable=false;view.drawableSize=CGSize(width:640,height:400)
        return (window,view,renderer)
    }
    func frame(_ view:GameView,_ renderer:Renderer) throws -> Data {
        guard let drawable=view.currentDrawable else { throw PortError("No validation drawable") }
        let texture=drawable.texture,w=texture.width,h=texture.height
        view.draw()
        let buffer=renderer.device.makeBuffer(length:w*h*4,options:.storageModeShared)!
        let command=renderer.queue.makeCommandBuffer()!,encoder=command.makeBlitCommandEncoder()!
        encoder.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:w,height:h,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:w*4,destinationBytesPerImage:w*h*4)
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        guard command.status == .completed else { throw PortError("GPU readback failed") }
        return Data(bytes:buffer.contents(),count:w*h*4)
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
