import AppKit
import MetalKit
import UniformTypeIdentifiers

let version = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development"
let buildNumber = Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unbundled"
let appTitle = "MetalDooM \(version) (build \(buildNumber))"

final class MessageLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var view: GameView!
    var renderer: Renderer!
    var status: NSTextField!
    var maps: NSPopUpButton!
    var message: MessageLabel!
    var wad: WAD?
    var summary = "Open a Doom WAD to explore a map"
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let menu = NSMenu(), appMenu = NSMenu()
            let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
            appMenu.addItem(withTitle:"About MetalDooM",action:#selector(about),keyEquivalent:"").target = self
            appMenu.addItem(.separator())
            appMenu.addItem(withTitle:"Quit MetalDooM",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            let fileItem = NSMenuItem(), fileMenu = NSMenu(title:"File"); fileItem.submenu = fileMenu; menu.addItem(fileItem)
            fileMenu.addItem(withTitle:"Open WAD…",action:#selector(openWAD),keyEquivalent:"o").target = self
            NSApp.mainMenu = menu
            window = NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:760),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            window.title = "\(appTitle) — Gameplay Preview"; window.minSize = NSSize(width:720,height:480)
            window.delegate = self; window.acceptsMouseMovedEvents = true
            let root = NSView(); window.contentView = root
            view = GameView(frame:.zero,device:MTLCreateSystemDefaultDevice())
            view.colorPixelFormat = .bgra8Unorm; view.depthStencilPixelFormat = .depth32Float
            view.clearColor = MTLClearColor(red:0,green:0,blue:0,alpha:1)
            view.preferredFramesPerSecond = 120; view.framebufferOnly = true
            renderer = try Renderer(view:view); view.delegate = renderer
            let button = NSButton(title:"Open WAD…",target:self,action:#selector(openWAD))
            maps = NSPopUpButton(); maps.target = self; maps.action = #selector(changeMap); maps.isEnabled = false
            let label = NSTextField(labelWithString:"METALDOOM   /   GAMEPLAY PREVIEW")
            label.font = .monospacedSystemFont(ofSize:12,weight:.bold)
            let spacer = NSView()
            let toolbar = NSStackView(views:[label,spacer,maps,button]); toolbar.spacing = 16
            status = NSTextField(labelWithString:summary); status.font = .monospacedSystemFont(ofSize:11,weight:.regular)
            status.lineBreakMode = .byTruncatingTail
            let help = NSTextField(labelWithString:"WASD move · Shift run · E / Space use · Click to capture, then fire · F fire · 1–7 weapons · Esc release · R restart")
            help.font = .systemFont(ofSize:11); help.textColor = .secondaryLabelColor
            for child in [toolbar,view!,status!,help] { child.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(child) }
            message = MessageLabel(labelWithString:""); message.translatesAutoresizingMaskIntoConstraints = false
            message.font = .monospacedSystemFont(ofSize:14,weight:.bold); message.textColor = .yellow
            message.backgroundColor = NSColor.black.withAlphaComponent(0.7); message.drawsBackground = true; message.isHidden = true
            root.addSubview(message)
            NSLayoutConstraint.activate([
                toolbar.topAnchor.constraint(equalTo:root.topAnchor,constant:12),toolbar.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),toolbar.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),toolbar.heightAnchor.constraint(equalToConstant:30),
                view.topAnchor.constraint(equalTo:toolbar.bottomAnchor,constant:12),view.leadingAnchor.constraint(equalTo:root.leadingAnchor),view.trailingAnchor.constraint(equalTo:root.trailingAnchor),view.bottomAnchor.constraint(equalTo:status.topAnchor,constant:-10),
                status.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),status.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),status.bottomAnchor.constraint(equalTo:help.topAnchor,constant:-6),
                help.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),help.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-10),
                message.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:16),message.topAnchor.constraint(equalTo:view.topAnchor,constant:16),
                message.trailingAnchor.constraint(lessThanOrEqualTo:view.trailingAnchor,constant:-16)
            ])
            renderer.onFrame = { [weak self] fps in
                guard let self else { return }
                self.status.stringValue = "\(self.summary) · \(self.renderer.playerStatus) · \(Int(fps)) FPS"
                self.message.stringValue = self.renderer.pickupMessage; self.message.isHidden = self.message.stringValue.isEmpty
            }
            renderer.onMapChanged = { [weak self] name in
                guard let self else { return }
                self.maps.selectItem(withTitle:name); self.summary = name
                self.window.title = "\(appTitle) — \(self.wad?.url.lastPathComponent ?? "Doom") — \(name)"
            }
            renderer.onError = { [weak self] error in self?.show(error) }
            window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view); NSApp.activate(ignoringOtherApps:true)
            let arguments = CommandLine.arguments
            if let index = arguments.firstIndex(of:"-iwad"), index+1 < arguments.count {
                load(URL(fileURLWithPath:NSString(string:arguments[index+1]).expandingTildeInPath))
            }
            if let index = arguments.firstIndex(of:"-warp"), index+1 < arguments.count {
                maps.selectItem(withTitle:arguments[index+1].uppercased()); changeMap()
            }
        } catch { show(error) }
    }
    @objc func openWAD() {
        view.releaseMouse()
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension:"wad") ?? .data]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for:window) { [weak self] response in if response == .OK, let url = panel.url { self?.load(url) } }
    }
    func load(_ url: URL) {
        do {
            let candidate = try WAD(url:url)
            let selected = candidate.maps.contains("E1M1") ? "E1M1" : candidate.maps[0]
            let result = try renderer.load(wad:candidate,map:selected)
            wad = candidate; maps.removeAllItems(); maps.addItems(withTitles:candidate.maps); maps.selectItem(withTitle:selected); maps.isEnabled = true
            describe(selected,result)
            window.title = "\(appTitle) — \(url.lastPathComponent) — \(selected)"
            window.makeFirstResponder(view)
        } catch { show(error) }
    }
    @objc func changeMap() {
        guard let wad, let name = maps.titleOfSelectedItem else { return }
        view.releaseMouse()
        do { describe(name,try renderer.load(wad:wad,map:name)); window.makeFirstResponder(view) }
        catch { show(error) }
    }
    func describe(_ name: String, _ result: (triangles:Int,missing:[String])) {
        window.title = "\(appTitle) — \(name)"
        summary = name
        if !result.missing.isEmpty { summary += " · \(result.missing.count) missing textures" }
        status.stringValue = summary
        print("Loaded \(name): \(result.triangles) triangles. Missing textures: \(result.missing)")
    }
    @objc func about() {
        view.releaseMouse()
        let alert = NSAlert(); alert.messageText = appTitle
        let date = Bundle.main.object(forInfoDictionaryKey:"MetalDooMBuildDate") as? String ?? "Unknown"
        alert.informativeText = "Native Apple Silicon / Metal gameplay preview.\nBuilt: \(date)\n\nChocolate Doom combat, monsters, pickups, doors, Metal weapon sprites, and native sound effects. Level exits, classic intermission stats, inventory carryover, and live switch textures. Music, saves, and original finale sequences remain pending.\n\nGPL-2.0-or-later. Includes Chocolate Doom code by id Software, Simon Howard, and contributors."
        alert.runModal()
    }
    func show(_ error: Error) {
        view?.releaseMouse()
        let alert = NSAlert(); alert.messageText = "Unable to load MetalDooM"; alert.informativeText = String(describing:error); alert.runModal()
    }
    func windowDidResignKey(_ notification: Notification) { view.releaseMouse(); renderer.pauseAudio() }
    func applicationWillResignActive(_ notification: Notification) { view.releaseMouse(); renderer.pauseAudio() }
    func applicationWillTerminate(_ notification: Notification) { view?.releaseMouse() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = App()
app.delegate = delegate
app.run()
