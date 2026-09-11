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
    var statusBar: NSView!
    var statusBarHeight: NSLayoutConstraint!
    var statusBarMenuItem: NSMenuItem?
    var statusBarVisible = UserDefaults.standard.object(forKey:"showStatusBar") as? Bool ?? true
    var levelStatsView: LevelStatsView?
    var levelStatsMenuItem: NSMenuItem?, parTimeMenuItem: NSMenuItem?, secretMenuItem: NSMenuItem?
    var messageTop: NSLayoutConstraint?
    var levelStatsVisible = UserDefaults.standard.object(forKey:"showLevelStats") as? Bool ?? true
    var parTimeVisible = UserDefaults.standard.bool(forKey:"showParTime")
    var secretNotifications = UserDefaults.standard.object(forKey:"secretNotifications") as? Bool ?? true
    var maps: NSPopUpButton!
    var message: MessageLabel!
    var wad: WAD?
    var stackPanel: WADStackPanel?
    var switchingWAD = false
    var wadSwitchTimer: Timer?
    var menuAudio: SoundPlayer?
    var automapView: AutomapView?
    var attractActive=false, attractDemo=false, attractIndex=0, attractElapsed=0.0
    var attractTimer: Timer?
    private(set) var shuttingDown = false
    var titleScreen: AttractScreen?
    var titleMusic: MusicPlayer?
    var cheatBuffer=""
    var console: DeveloperConsole?
    var consoleVisible = false
    var gameMenu: GameMenu?
    var menuKeyMonitor: Any?
    var musicMenuItem: NSMenuItem?
    var metalHUDMenuItem: NSMenuItem?
    var metalHUDEnabled = false
    var diagnosticFPS: Double?
    let sessionLog = SessionLog()
    var benchmark: BenchmarkRun?
    var lastBenchmarkReport: String?
    var loggedSettings = ""
    var summary = "Open a Doom WAD to explore a map"
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing=false
        do {
            let menu = NSMenu(), appMenu = NSMenu()
            let appItem = NSMenuItem(); appItem.submenu = appMenu; menu.addItem(appItem)
            appMenu.addItem(withTitle:"About MetalDooM",action:#selector(about),keyEquivalent:"").target = self
            appMenu.addItem(.separator())
            appMenu.addItem(withTitle:"Quit MetalDooM",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            let fileItem = NSMenuItem(), fileMenu = NSMenu(title:"File"); fileItem.submenu = fileMenu; menu.addItem(fileItem)
            fileMenu.addItem(withTitle:"Open WAD…",action:#selector(openWAD),keyEquivalent:"o").target = self
            fileMenu.addItem(withTitle:"Return to Title Screen",action:#selector(returnToTitle),keyEquivalent:"").target=self
            fileMenu.addItem(.separator())
            fileMenu.addItem(withTitle:"Save Game…",action:#selector(saveGame),keyEquivalent:"s").target = self
            fileMenu.addItem(withTitle:"Load Game…",action:#selector(loadGame),keyEquivalent:"l").target = self
            let quickSave = fileMenu.addItem(withTitle:"Quick Save",action:#selector(quickSaveGame),keyEquivalent:"s")
            quickSave.target = self; quickSave.keyEquivalentModifierMask = [.command,.shift]
            let quickLoad = fileMenu.addItem(withTitle:"Quick Load",action:#selector(quickLoadGame),keyEquivalent:"l")
            quickLoad.target = self; quickLoad.keyEquivalentModifierMask = [.command,.shift]
            let viewItem=NSMenuItem(), viewMenu=NSMenu(title:"View")
            viewItem.submenu=viewMenu; menu.addItem(viewItem)
            addGraphicsMenus(to:viewMenu)
            statusBarMenuItem=viewMenu.addItem(withTitle:"Show Status Bar",action:#selector(toggleStatusBar),keyEquivalent:"")
            statusBarMenuItem?.target=self
            levelStatsMenuItem=viewMenu.addItem(withTitle:"Show Level Stats",action:#selector(toggleLevelStats),keyEquivalent:"")
            levelStatsMenuItem?.target=self
            parTimeMenuItem=viewMenu.addItem(withTitle:"Show Par Time",action:#selector(toggleParTime),keyEquivalent:"")
            parTimeMenuItem?.target=self
            secretMenuItem=viewMenu.addItem(withTitle:"Secret Notifications",action:#selector(toggleSecretNotifications),keyEquivalent:"")
            secretMenuItem?.target=self
            viewMenu.addItem(withTitle:"Ray-Traced Ambient Occlusion (Experimental)",action:#selector(toggleAmbientOcclusion),keyEquivalent:"").target=self
            let strengthItem=NSMenuItem(title:"AO Strength",action:nil,keyEquivalent:"")
            let strengthMenu=NSMenu(title:"AO Strength");strengthItem.submenu=strengthMenu;viewMenu.addItem(strengthItem)
            for value in [0,25,50,75,100] {
                let item=strengthMenu.addItem(withTitle:"\(value)%"+(value==50 ? " (Default)":""),action:#selector(selectAOStrength(_:)),keyEquivalent:"")
                item.tag=value;item.target=self
            }
            let radiusItem=NSMenuItem(title:"AO Radius",action:nil,keyEquivalent:"")
            let radiusMenu=NSMenu(title:"AO Radius");radiusItem.submenu=radiusMenu;viewMenu.addItem(radiusItem)
            for (value,title) in [(16,"Compact — 16 units"),(32,"Near — 32 units"),(48,"Default — 48 units"),(96,"Wide — 96 units")] {
                let item=radiusMenu.addItem(withTitle:title,action:#selector(selectAORadius(_:)),keyEquivalent:"")
                item.tag=value;item.target=self
            }
            viewMenu.addItem(withTitle:"Moving Test Light (Experimental)",action:#selector(toggleDynamicLight),keyEquivalent:"").target=self
            viewMenu.addItem(withTitle:"Test Light Shadows",action:#selector(toggleDynamicLightShadows),keyEquivalent:"").target=self
            let effectsItem=NSMenuItem(title:"More Metal Effects",action:nil,keyEquivalent:"")
            let effectsMenu=NSMenu(title:"More Metal Effects");effectsItem.submenu=effectsMenu;viewMenu.addItem(effectsItem)
            for effect in SceneEffect.allCases {
                let item=effectsMenu.addItem(withTitle:effect.title,action:#selector(toggleSceneEffect(_:)),keyEquivalent:"")
                item.tag=effect.rawValue;item.target=self
            }
            let audioItem=NSMenuItem(), audioMenu=NSMenu(title:"Audio")
            audioItem.submenu=audioMenu; menu.addItem(audioItem)
            let musicItem=audioMenu.addItem(withTitle:"Music",action:#selector(toggleMusic(_:)),keyEquivalent:"m")
            musicMenuItem=musicItem
            musicItem.target=self; musicItem.keyEquivalentModifierMask=[.command,.shift]
            musicItem.state=UserDefaults.standard.bool(forKey:"musicMuted") ? .off : .on
            let diagnosticsItem = NSMenuItem(), diagnosticsMenu = NSMenu(title:"Diagnostics")
            diagnosticsItem.submenu = diagnosticsMenu; menu.addItem(diagnosticsItem)
            metalHUDMenuItem = diagnosticsMenu.addItem(withTitle:"Metal Performance HUD",action:#selector(toggleMetalHUD),keyEquivalent:"")
            metalHUDMenuItem?.target = self
            diagnosticsMenu.addItem(withTitle:"Copy Diagnostic Report",action:#selector(copyDiagnosticReport),keyEquivalent:"").target = self
            diagnosticsMenu.addItem(withTitle:"Export Session Log…",action:#selector(exportSessionLog),keyEquivalent:"").target=self
            diagnosticsMenu.addItem(.separator())
            diagnosticsMenu.addItem(withTitle:"Run Benchmark…",action:#selector(runBenchmark),keyEquivalent:"").target=self
            diagnosticsMenu.addItem(withTitle:"Cancel Benchmark",action:#selector(cancelBenchmark),keyEquivalent:"").target=self
            diagnosticsMenu.addItem(withTitle:"Export Benchmark Result…",action:#selector(exportBenchmarkResult),keyEquivalent:"").target=self
            let oplItem=audioMenu.addItem(withTitle:"Classic OPL",action:#selector(selectOPL(_:)),keyEquivalent:"");oplItem.target=self
            let appleItem=audioMenu.addItem(withTitle:"Apple MIDI",action:#selector(selectAppleMIDI(_:)),keyEquivalent:"");appleItem.target=self
            NSApp.mainMenu = menu
            window = NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:760),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            window.title = "\(appTitle) — Gameplay Preview"; window.minSize = NSSize(width:720,height:640)
            window.tabbingMode = .disallowed
            window.isReleasedWhenClosed = false
            window.delegate = self; window.acceptsMouseMovedEvents = true
            let root = NSView(); window.contentView = root
            view = GameView(frame:.zero,device:MTLCreateSystemDefaultDevice())
            view.colorPixelFormat = .bgra8Unorm; view.depthStencilPixelFormat = .depth32Float
            view.clearColor = MTLClearColor(red:0,green:0,blue:0,alpha:1)
            view.preferredFramesPerSecond = 120; view.framebufferOnly = false
            configureMetalHUD()
            renderer = try Renderer(view:view); view.delegate = renderer
            view.onEscape = { [weak self] in self?.openGameMenu() }
            view.onBlockedClick = { [weak self] in if self?.attractActive==true && self?.consoleVisible==false { self?.openGameMenu() } }
            view.renderScale=CGFloat(UserDefaults.standard.object(forKey:"renderScale") as? Double ?? 1)
            view.preferredFramesPerSecond=UserDefaults.standard.object(forKey:"frameLimit") as? Int ?? 120
            menuKeyMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
                guard let self, !self.shuttingDown, self.window.isKeyWindow, self.window.attachedSheet == nil else { return event }
                if self.benchmark != nil {
                    if event.keyCode == 53 { self.cancelBenchmark() }
                    return nil
                }
                let modified = !event.modifierFlags.intersection([.command,.control,.option]).isEmpty
                if !modified, ["`","~"].contains(event.characters ?? "") {
                    if !event.isARepeat { self.toggleConsole() }; return nil
                }
                if self.consoleVisible {
                    if event.keyCode == 53 { self.toggleConsole(); return nil }
                    if self.window.firstResponder === self.view { self.window.makeFirstResponder(self.console?.input) }
                    return event
                }
                if self.gameMenu == nil, !modified {
                    if let map=self.automapView, map.handle(event) { return nil }
                    if event.keyCode==48 && !self.attractActive { if !event.isARepeat { self.toggleAutomap() };return nil }
                    if self.attractActive { if !event.isARepeat { self.openGameMenu() };return nil }
                    if !event.isARepeat, self.typeCheat(event.characters ?? "") { return nil }
                }
                return self.gameMenu?.handleKey(event) == true ? nil : event
            }
            maps = NSPopUpButton(); maps.target = self; maps.action = #selector(changeMap); maps.isEnabled = false
            maps.setAccessibilityLabel("Map")
            status = NSTextField(labelWithString:summary); status.font = .monospacedSystemFont(ofSize:11,weight:.regular)
            status.lineBreakMode = .byTruncatingTail
            status.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
            let help = NSTextField(labelWithString:"WASD move · Shift run · E / Space use · Click to capture, then fire · F fire · 1–7 weapons · Esc menu · Tab map · ~ console · R restart")
            help.font = .systemFont(ofSize:11); help.textColor = .secondaryLabelColor
            help.lineBreakMode = .byTruncatingTail
            statusBar=NSView()
            for child in [view!,statusBar!] { child.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(child) }
            for child in [maps!,status!,help] { child.translatesAutoresizingMaskIntoConstraints = false; statusBar.addSubview(child) }
            statusBarHeight=statusBar.heightAnchor.constraint(equalToConstant:60)
            message = MessageLabel(labelWithString:""); message.translatesAutoresizingMaskIntoConstraints = false
            message.font = .monospacedSystemFont(ofSize:14,weight:.bold); message.textColor = .yellow
            message.backgroundColor = NSColor.black.withAlphaComponent(0.7); message.drawsBackground = true; message.isHidden = true
            let levelStats=LevelStatsView(); levelStats.translatesAutoresizingMaskIntoConstraints=false
            root.addSubview(levelStats); levelStatsView=levelStats
            NSLayoutConstraint.activate([
                levelStats.leadingAnchor.constraint(equalTo:view.leadingAnchor),levelStats.trailingAnchor.constraint(equalTo:view.trailingAnchor),
                levelStats.topAnchor.constraint(equalTo:view.topAnchor),levelStats.bottomAnchor.constraint(equalTo:view.bottomAnchor)
            ])
            root.addSubview(message)
            messageTop=message.topAnchor.constraint(equalTo:view.topAnchor,constant:16)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo:root.topAnchor),view.leadingAnchor.constraint(equalTo:root.leadingAnchor),view.trailingAnchor.constraint(equalTo:root.trailingAnchor),view.bottomAnchor.constraint(equalTo:statusBar.topAnchor),
                statusBar.leadingAnchor.constraint(equalTo:root.leadingAnchor),statusBar.trailingAnchor.constraint(equalTo:root.trailingAnchor),statusBar.bottomAnchor.constraint(equalTo:root.bottomAnchor),statusBarHeight,
                maps.leadingAnchor.constraint(equalTo:statusBar.leadingAnchor,constant:12),maps.topAnchor.constraint(equalTo:statusBar.topAnchor,constant:8),maps.widthAnchor.constraint(equalToConstant:100),maps.heightAnchor.constraint(equalToConstant:26),
                status.leadingAnchor.constraint(equalTo:maps.trailingAnchor,constant:12),status.trailingAnchor.constraint(equalTo:statusBar.trailingAnchor,constant:-16),status.centerYAnchor.constraint(equalTo:maps.centerYAnchor),
                help.leadingAnchor.constraint(equalTo:statusBar.leadingAnchor,constant:16),help.trailingAnchor.constraint(equalTo:statusBar.trailingAnchor,constant:-16),help.topAnchor.constraint(equalTo:statusBar.topAnchor,constant:39),
                message.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:16),messageTop!,
                message.trailingAnchor.constraint(lessThanOrEqualTo:view.trailingAnchor,constant:-16)
            ])
            updateStatusBar()
            renderer.onHUDFrame = { [weak self] in self?.updateLevelStats() }
            updateLevelStats()
            renderer.onFrame = { [weak self] fps in
                guard let self else { return }
                self.diagnosticFPS = fps
                let settings=self.benchmarkSettings
                if settings != self.loggedSettings {
                    self.loggedSettings=settings
                    self.sessionLog.append("Rendering settings: " + settings)
                }
                self.layoutAutomap()
                self.status.stringValue = "\(self.summary) · \(self.renderer.playerStatus) · \(Int(fps)) FPS"
                self.message.stringValue = self.renderer.pickupMessage; self.message.isHidden = self.message.stringValue.isEmpty
            }
            renderer.onMapChanged = { [weak self] name in
                guard let self else { return }
                self.closeAutomap();self.maps.selectItem(withTitle:name); self.summary = self.wad?.mapTitle(name) ?? name
                self.updateTitle(map:name)
                self.sessionLog.append("Map changed: \(name)")
            }
            renderer.onSubmittedFrame = { [weak self] time in self?.benchmarkFrame(time) }
            renderer.onWarning = { [weak self] text in
                self?.sessionLog.append(text)
                self?.finishBenchmark(reason:"Metal command failed.")
            }
            MusicPlayer.onError = { [weak self] error in self?.show(error) }
            sessionLog.append("Started " + appTitle + "; GPU: " + renderer.device.name)
            renderer.onError = { [weak self] error in self?.show(error) }
            let sizes=[NSSize(width:960,height:720),NSSize(width:1100,height:760),NSSize(width:1280,height:720),NSSize(width:1600,height:900),NSSize(width:1920,height:1080)]
            let preset=UserDefaults.standard.object(forKey:"windowPreset") as? Int ?? 1
            applyWindowSize(sizes[min(4,max(0,preset))])
            window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(view); NSApp.activate(ignoringOtherApps:true)
            let arguments = CommandLine.arguments
            if let index = arguments.firstIndex(of:"-iwad"), index+1 < arguments.count {
                let addOns: [URL]
                if let files=arguments.firstIndex(of:"-file") {
                    addOns=arguments.dropFirst(files+1).prefix(while:{!$0.hasPrefix("-")}).map { URL(fileURLWithPath:NSString(string:$0).expandingTildeInPath) }
                } else { addOns=[] }
                load(URL(fileURLWithPath:NSString(string:arguments[index+1]).expandingTildeInPath),addOns:addOns,showTitle:!arguments.contains("-warp"))
            }
            if let index = arguments.firstIndex(of:"-switch-ready"), index+1 < arguments.count {
                try? (wad == nil ? "failed" : "ready").write(toFile:arguments[index+1],atomically:true,encoding:.utf8)
            }
            if let index = arguments.firstIndex(of:"-warp"), index+1 < arguments.count {
                maps.selectItem(withTitle:arguments[index+1].uppercased()); changeMap()
            }
            if wad == nil { openGameMenu() }
        } catch { show(error) }
    }
    @objc func toggleStatusBar() {
        statusBarVisible.toggle()
        UserDefaults.standard.set(statusBarVisible,forKey:"showStatusBar")
        updateStatusBar()
    }
    func updateStatusBar() {
        // Only AppKit chrome changes; the renderer's classic Doom HUD stays intact.
        if !statusBarVisible, window.firstResponder === maps { window.makeFirstResponder(view) }
        statusBar.isHidden = !statusBarVisible
        statusBarHeight.constant = statusBarVisible ? 60 : 0
        statusBarMenuItem?.state = statusBarVisible ? .on : .off
        window.contentView?.layoutSubtreeIfNeeded()
    }
    @objc func quickSaveGame() {
        view.releaseMouse()
        do {
            guard let wad, !attractActive else { throw PortError("Start a game before saving.") }
            try renderer.saveGame(to:SaveStore.quickURL(wad:wad))
        } catch { show(error) }
    }
    @objc func quickLoadGame() {
        view.releaseMouse()
        do {
            guard let wad else { throw PortError("Open the matching WAD before loading.") }
            let url = try SaveStore.quickURL(wad:wad)
            guard FileManager.default.fileExists(atPath:url.path) else { throw PortError("No quick save exists for this WAD yet.") }
            try renderer.loadGame(from:url);endAttract();renderer.paused=gameMenu != nil || consoleVisible
        } catch { show(error) }
    }
    @objc func saveGame() {
        view.releaseMouse(); renderer.pauseAudio()
        guard let wad, !attractActive else { show(PortError("Start a game before saving.")); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension:"mdsave") ?? .data]
        panel.nameFieldStringValue = "\(wad.gameName) - \(maps.titleOfSelectedItem ?? "Save").mdsave"
        panel.beginSheetModal(for:window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do { try self.renderer.saveGame(to:url) } catch { self.show(error) }
        }
    }
    @objc func loadGame() {
        view.releaseMouse(); renderer.pauseAudio()
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension:"mdsave") ?? .data]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.beginSheetModal(for:window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            do { try self.renderer.loadGame(from:url);self.endAttract();self.renderer.paused=self.gameMenu != nil || self.consoleVisible } catch { self.show(error) }
        }
    }
    @objc func openWAD() {
        guard !switchingWAD, window.attachedSheet == nil else { return }
        view.releaseMouse()
        let stack=WADStackPanel(base:wad?.sourceURLs.first,addOns:wad.map { Array($0.sourceURLs.dropFirst()) } ?? [],replacingGame:wad != nil)
        stackPanel=stack
        stack.onPlay={ [weak self] url,extras in
            guard let self else { return }
            self.stackPanel=nil
            if self.wad == nil { self.load(url,addOns:extras) }
            else { self.switchWAD(url,addOns:extras) }
        }
        stack.onCancel={ [weak self] in self?.stackPanel=nil }
        window.beginSheet(stack)
    }
    // Chocolate Doom owns process-global WAD resources. Hand off only after the
    // replacement instance reports a successful load, preserving this game on failure.
    func switchWAD(_ url: URL, addOns: [URL]) {
        do {
            _ = try WAD(url:url,addOns:addOns)
            let directory=FileManager.default.temporaryDirectory.appendingPathComponent("MetalDooM-switch-" + UUID().uuidString)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
            let ready=directory.appendingPathComponent("ready")
            let wasPaused=renderer.paused
            switchingWAD=true; renderer.paused=true
            let configuration=NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance=true
            configuration.arguments=["-iwad",url.path,"-switch-ready",ready.path]
            if !addOns.isEmpty { configuration.arguments += ["-file"] + addOns.map(\.path) }
            NSWorkspace.shared.openApplication(at:Bundle.main.bundleURL,configuration:configuration) { [weak self] application,error in
                DispatchQueue.main.async {
                    guard let self else { try? FileManager.default.removeItem(at:directory); return }
                    func finish(_ success:Bool) {
                        self.wadSwitchTimer?.invalidate(); self.wadSwitchTimer=nil
                        try? FileManager.default.removeItem(at:directory)
                        self.switchingWAD=false
                        if success { NSApp.terminate(nil) }
                        else {
                            application?.terminate()
                            self.renderer.paused=wasPaused
                            NSApp.activate(ignoringOtherApps:true)
                            self.show(error ?? PortError("The selected WAD could not be opened. Your current game is still available."))
                        }
                    }
                    guard application != nil, error == nil else { finish(false); return }
                    let deadline=Date().addingTimeInterval(60)
                    self.wadSwitchTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { _ in
                        if let result=try? String(contentsOf:ready,encoding:.utf8) { finish(result == "ready") }
                        else if application?.isTerminated == true || Date() >= deadline { finish(false) }
                    }
                }
            }
        } catch { show(error) }
    }
    func load(_ url: URL, addOns: [URL] = [], showTitle:Bool=true) {
        do {
            let candidate = try WAD(url:url,addOns:addOns)
            let selected = candidate.isSigil ? "E5M1" : candidate.maps.contains("E1M1") ? "E1M1" : candidate.maps[0]
            let result = try renderer.load(wad:candidate,map:selected)
            sessionLog.append("Loaded " + candidate.displayName + "; WAD stack: " + candidate.displayFiles)
            wad = candidate; maps.removeAllItems(); maps.addItems(withTitles:candidate.maps); maps.selectItem(withTitle:selected); maps.isEnabled = true
            describe(selected,result)
            if showTitle { beginAttract() }
            else if gameMenu != nil { gameMenu?.main() } else { window.makeFirstResponder(view) }
        } catch { show(error) }
    }
    @objc func changeMap() {
        guard let wad, let name = maps.titleOfSelectedItem else { return }
        view.releaseMouse()
        do { endAttract();describe(name,try renderer.load(wad:wad,map:name));renderer.paused=gameMenu != nil || consoleVisible; window.makeFirstResponder(view) }
        catch { show(error) }
    }
    func updateTitle(map name: String) {
        guard let wad else { return }
        window.title = "\(appTitle) — \(wad.displayName) — \(wad.displayFiles) — \(wad.mapTitle(name))"
    }
    func describe(_ name: String, _ result: (triangles:Int,missing:[String])) {
        closeAutomap();updateTitle(map:name)
        summary = wad?.mapTitle(name) ?? name
        if !result.missing.isEmpty { summary += " · \(result.missing.count) missing textures" }
        status.stringValue = summary
        sessionLog.append("Loaded \(name): \(result.triangles) triangles; missing textures: \(result.missing)")
        print("Loaded \(name): \(result.triangles) triangles. Missing textures: \(result.missing)")
    }
    @objc func about() {
        view.releaseMouse()
        let alert = NSAlert(); alert.messageText = appTitle
        let date = Bundle.main.object(forInfoDictionaryKey:"MetalDooMBuildDate") as? String ?? "Unknown"
        alert.informativeText = "Classic Doom for Apple Silicon, rendered with Metal.\nBuilt: \(date)\n\nGameplay powered by Chocolate Doom.\nCode by id Software, Simon Howard and contributors.\nOPL emulation by Nuked OPL3 (Nuke.YKT and contributors).\n\nGPL-2.0-or-later · Nuked OPL3: LGPL-2.1-or-later\nGame data supplied separately."
        alert.runModal()
    }
    func show(_ error: Error) {
        sessionLog.append("Error: \(error)")
        if benchmark != nil { finishBenchmark(reason:"Renderer error",notify:false) }
        view?.releaseMouse()
        let alert = NSAlert(); alert.messageText = "MetalDooM"; alert.informativeText = String(describing:error); alert.runModal()
    }
    @objc func toggleMusic(_ sender: NSMenuItem) {
        renderer.musicEnabled.toggle(); syncMusicMenu()
    }
    func playMenuSound(_ name: String) {
        guard let wad, let index=wad.lumps.lastIndex(where:{$0.name==name}) else { return }
        do {
            if menuAudio == nil { menuAudio=try SoundPlayer(wad:wad,onlyLumps:["DSPSTOP","DSSTNMOV","DSPISTOL","DSSWTCHN","DSSWTCHX"]) }
            menuAudio?.volume=renderer.effectsVolume; try menuAudio?.setActive(true)
            menuAudio?.play(MD_SoundEvent(channel:0,lump:Int32(index),volume:0.7,pan:0))
        } catch { fputs("Menu sound: \(error)\n",stderr) }
    }
    func syncMusicMenu() { musicMenuItem?.state=renderer.musicEnabled ? .on : .off }
    func openGameMenu() {
        guard gameMenu == nil, !consoleVisible else { return }
        cheatBuffer="";view.releaseMouse(); renderer.paused=true; playMenuSound("DSSWTCHN")
        let panel=GameMenu(app:self); gameMenu=panel
        panel.translatesAutoresizingMaskIntoConstraints=false; window.contentView!.addSubview(panel)
        NSLayoutConstraint.activate([panel.centerXAnchor.constraint(equalTo:window.contentView!.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo:window.contentView!.centerYAnchor)])
        window.makeFirstResponder(panel)
    }
    func closeGameMenu() {
        guard wad != nil else { return }
        endAttract();gameMenu?.removeFromSuperview(); gameMenu=nil; view.releaseMouse(); renderer.paused=consoleVisible
        window.makeFirstResponder(consoleVisible ? console?.input : view)
    }
    func toggleConsole() {
        if consoleVisible {
            console?.removeFromSuperview(); consoleVisible=false; view.inputBlocked=attractActive; gameMenu?.isHidden=false
            view.releaseMouse(); renderer.paused = gameMenu != nil || (attractActive && !attractDemo)
            window.makeFirstResponder(gameMenu ?? view)
            return
        }
        cheatBuffer="";view.releaseMouse(); view.inputBlocked=true; renderer.paused=true; gameMenu?.isHidden=true
        if console == nil {
            let panel=DeveloperConsole(frame:.zero)
            panel.execute={ [weak self] in self?.executeConsole($0) ?? "" }
            panel.close={ [weak self] in self?.toggleConsole() }
            console=panel
        }
        guard let panel=console else { return }
        consoleVisible=true; panel.translatesAutoresizingMaskIntoConstraints=false
        window.contentView!.addSubview(panel)
        NSLayoutConstraint.activate([panel.topAnchor.constraint(equalTo:view.topAnchor),
            panel.leadingAnchor.constraint(equalTo:view.leadingAnchor),panel.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            panel.heightAnchor.constraint(equalTo:view.heightAnchor,multiplier:0.55)])
        window.makeFirstResponder(panel.input)
    }
    func executeConsole(_ text: String) -> String {
        do {
            let raw=text.lowercased().trimmingCharacters(in:.whitespacesAndNewlines)
            let aliases=["god":"iddqd","noclip":"idclip","give all":"idkfa","give ammo":"idfa"]
            if let cheat=aliases[raw] { return runCheat(cheat) }
            if Self.typedCheats.contains(raw) { return runCheat(raw) }
            switch try ConsoleCommand.parse(text) {
            case .simple(let name):
                switch name {
                case "help": return "help / clear / status / maps / map <name> / restart / close\nvolume <0–1> / musicvolume <0–1> / music on|off\nrender_scale <50|75|100> / fps <35|60|120> / fullscreen on|off\ngod / noclip / give all / give ammo (or classic cheat codes)\nMap and restart begin a fresh level; save your progress first."
                case "give": return "Usage: give all | give ammo"
                case "clear": console?.clear(); return ""
                case "close": toggleConsole(); return ""
                case "maps": return wad?.maps.joined(separator:"  ") ?? "No WAD loaded."
                case "restart":
                    guard wad != nil else { throw ConsoleError("No WAD loaded.") }
                    endAttract();try renderer.reset(); return "Level restarted."
                default:
                    let size=view.drawableSize
                    return "\(appTitle)\n\(wad?.displayName ?? "No WAD") — \(summary)\n\(renderer.playerStatus)\nGPU: \(renderer.device.name)\nRender: \(Int(size.width))x\(Int(size.height)) at \(Int(view.renderScale*100))%; limit \(view.preferredFramesPerSecond) FPS\nEffects: \(renderer.effectsVolume); music: \(renderer.musicVolume) (\(renderer.musicEnabled ? "on" : "off"))"
                }
            case .map(let name):
                guard let wad else { throw ConsoleError("No WAD loaded.") }
                guard wad.maps.contains(name) else { throw ConsoleError("Map \(name) is not in this WAD. Type maps.") }
                endAttract()
                let result=try renderer.load(wad:wad,map:name)
                maps.selectItem(withTitle:name); describe(name,result)
                return "Loaded \(wad.mapTitle(name)). Missing textures: \(result.missing.isEmpty ? "none" : result.missing.joined(separator:", "))"
            case .number(let name, let value):
                switch name {
                case "volume": renderer.effectsVolume=value
                case "musicvolume": renderer.musicVolume=value
                case "fps": view.preferredFramesPerSecond=Int(value); UserDefaults.standard.set(Int(value),forKey:"frameLimit")
                default: view.renderScale=CGFloat(value/100); UserDefaults.standard.set(Double(value/100),forKey:"renderScale")
                }
                gameMenu?.updateResolutionText(); return "\(name) = \(value)"
            case .toggle(let name, let enabled):
                if name=="music" { renderer.musicEnabled=enabled; syncMusicMenu() }
                else if window.styleMask.contains(.fullScreen) != enabled { window.toggleFullScreen(nil) }
                return "\(name) \(enabled ? "on" : "off")"
            }
        } catch { return "Error: \(error)" }
    }
    func applyWindowSize(_ size: NSSize) {
        guard !window.styleMask.contains(.fullScreen) else { return }
        let available=(window.screen ?? NSScreen.main)?.visibleFrame.size ?? size
        window.setContentSize(NSSize(width:min(size.width,available.width),height:min(size.height,available.height-32)))
        window.center(); window.contentView?.layoutSubtreeIfNeeded(); view?.updateResolution()
        gameMenu?.updateResolutionText()
    }
    func windowDidResize(_ notification: Notification) { view?.updateResolution(); gameMenu?.updateResolutionText() }
    func windowDidEnterFullScreen(_ notification: Notification) { gameMenu?.refreshDisplay(); view.updateResolution() }
    func windowDidExitFullScreen(_ notification: Notification) { gameMenu?.refreshDisplay(); view.updateResolution() }
    func windowDidResignKey(_ notification: Notification) { view.releaseMouse(); renderer.pauseAudio(); try? menuAudio?.setActive(false) }
    func applicationWillResignActive(_ notification: Notification) { view.releaseMouse(); renderer.pauseAudio(); try? menuAudio?.setActive(false) }
    // Both the close button and Quit must stop callbacks before AppKit tears down
    // the window. This may be called twice during last-window termination.
    private func shutdown() {
        guard !shuttingDown else { return }
        shuttingDown = true
        finishBenchmark(reason:"Application closed",notify:false)
        sessionLog.append("Application shutdown")
        endAttract()
        view?.releaseMouse()
        view?.inputBlocked = true
        view?.isPaused = true
        view?.delegate = nil
        wadSwitchTimer?.invalidate(); wadSwitchTimer=nil
        renderer?.paused = true
        renderer?.pauseAudio()
        renderer?.releaseMusic()
        try? menuAudio?.setActive(false)
        if let menuKeyMonitor { NSEvent.removeMonitor(menuKeyMonitor); self.menuKeyMonitor = nil }
    }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        shutdown()
    }
    func applicationWillTerminate(_ notification: Notification) { shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = App()
app.delegate = delegate
app.run()
