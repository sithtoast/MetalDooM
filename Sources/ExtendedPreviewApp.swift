import AppKit
import MetalKit

/// Explicit command-line development preview; it never changes the WAD picker
/// acceptance rules or launches the classic simulation.
final class ExtendedPreviewApp:NSObject,NSApplicationDelegate,NSWindowDelegate {
    private var window:NSWindow!, view:GameView!, renderer:Renderer!
    private let status=NSTextField(labelWithString:"Loading worker…")
    private let queue=DispatchQueue(label:"MetalDooM.extended-preview")
    private let worker=ExtendedWorker()
    private var resources:WAD?, buttons:[NSButton]=[], closed=false
    func applicationDidFinishLaunching(_ notification:Notification) {
        do {
            let args=CommandLine.arguments
            guard let flag=args.firstIndex(of:"--rust-preview"), flag+1<args.count else { throw PortError("Supply the rerelease directory after --rust-preview.") }
            let root=URL(fileURLWithPath:args[flag+1],isDirectory:true)
            var map=1
            if let option=args.firstIndex(of:"--map") {
                guard option+1<args.count, let number=Int(args[option+1].uppercased().replacingOccurrences(of:"MAP",with:"")), (1...16).contains(number) else { throw PortError("Choose MAP01–MAP16.") }
                map=number
            }
            window=NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.title="\(appTitle) — Rust world preview — \(String(format:"MAP%02d",map))"
            window.delegate=self;window.isReleasedWhenClosed=false
            view=GameView(frame:.zero,device:MTLCreateSystemDefaultDevice())
            view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float
            view.clearColor=MTLClearColorMake(0,0,0,1);view.preferredFramesPerSecond=60
            view.inputBlocked=true;view.framebufferOnly=false
            renderer=try Renderer(view:view);view.delegate=renderer
            renderer.onError={ [weak self] error in self?.failed(error) }
            let controls=NSStackView();controls.orientation = .horizontal;controls.spacing=8
            for (tag,title) in [(1,"Forward"),(2,"Back"),(3,"Turn left"),(4,"Turn right"),(6,"Use"),(5,"Step 1 second")] {
                let button=NSButton(title:title,target:self,action:#selector(step(_:)));button.tag=tag;button.isEnabled=false
                controls.addArrangedSubview(button);buttons.append(button)
            }
            let caption=NSTextField(labelWithString:"World-only simulation preview · Actors, weapons and audio are not shown")
            caption.textColor = .secondaryLabelColor
            let stack=NSStackView(views:[controls,caption,status,view]);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8
            stack.translatesAutoresizingMaskIntoConstraints=false;view.translatesAutoresizingMaskIntoConstraints=false
            let content=NSView();window.contentView=content;content.addSubview(stack)
            NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:12),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-12),stack.topAnchor.constraint(equalTo:content.topAnchor,constant:12),stack.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-12),view.widthAnchor.constraint(equalTo:stack.widthAnchor),view.heightAnchor.constraint(greaterThanOrEqualToConstant:300)])
            let menu=NSMenu(),item=NSMenuItem(),submenu=NSMenu()
            submenu.addItem(withTitle:"Quit preview",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            item.submenu=submenu;menu.addItem(item);NSApp.mainMenu=menu
            window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
            let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
            let executable=Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MetalDooMWorker")
            queue.async { [self] in
                do {
                    let state=try worker.start(executable:executable,paths:paths,map:map,base:1)
                    guard let identity=worker.identity else { throw PortError("Missing worker identity.") }
                    let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:identity)
                    self.resources=resources
                    let scene=try ExtendedScene(view:state,resources:resources)
                    DispatchQueue.main.async { [weak self] in self?.present(scene) }
                } catch { DispatchQueue.main.async { [weak self] in self?.failed(error) } }
            }
        } catch {
            if window != nil { failed(error) }
            else { let alert=NSAlert();alert.messageText="Cannot open Rust preview";alert.informativeText=String(describing:error);alert.runModal();NSApp.terminate(nil) }
        }
    }
    @objc private func step(_ sender:NSButton) {
        buttons.forEach{$0.isEnabled=false};status.stringValue="Updating worker world…"
        let tag=sender.tag
        queue.async { [self] in
            do {
                guard let resources else { throw PortError("Preview resources unavailable.") }
                _=try worker.tick(forward:tag==1 ? 25:tag==2 ? -25:0,turn:tag==3 ? 8192:tag==4 ? -8192:0,buttons:tag==6 ? 2:0,count:tag<=2 ? 8:tag==5 ? 35:1)
                let scene=try ExtendedScene(view:worker.geometry(),resources:resources)
                DispatchQueue.main.async { [weak self] in self?.present(scene) }
            } catch { DispatchQueue.main.async { [weak self] in self?.failed(error) } }
        }
    }
    private func present(_ scene:ExtendedScene) {
        guard !closed else { return }
        do {
            try renderer.loadExtendedPreview(scene)
            status.stringValue="Tic \(scene.view.tic) · \(scene.geometry.triangleCount.formatted()) triangles · Sky \(scene.view.sky) · Simulation health \(scene.view.health)"
            buttons.forEach{$0.isEnabled=true}
        } catch { failed(error) }
    }
    private func failed(_ error:Error) {
        guard !closed else { return }
        worker.cancel();status.stringValue="Preview stopped: \(error)";buttons.forEach{$0.isEnabled=false}
    }
    func windowWillClose(_ notification:Notification) { shutdown() }
    func applicationWillTerminate(_ notification:Notification) { shutdown() }
    private func shutdown() {
        guard !closed else { return };closed=true
        worker.cancel();view?.isPaused=true;view?.delegate=nil
    }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        shutdown()
        queue.async { [self] in
            worker.close()
            DispatchQueue.main.async { sender.reply(toApplicationShouldTerminate:true) }
        }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
