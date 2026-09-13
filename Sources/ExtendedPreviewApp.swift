import AppKit
import MetalKit
import UniformTypeIdentifiers

/// Explicit command-line development preview; it never changes the WAD picker
/// acceptance rules or launches the classic simulation.
final class ExtendedPreviewApp:NSObject,NSApplicationDelegate,NSWindowDelegate {
    private var window:NSWindow!, view:GameView!, renderer:Renderer!
    private let status=NSTextField(labelWithString:"Loading worker…")
    private let queue=DispatchQueue(label:"MetalDooM.extended-preview")
    private var worker=ExtendedWorker(),pendingWorker:ExtendedWorker?
    private var workerExecutable:URL?
    private var plan:BundledPreviewPlan!
    private var launchReported=false,openingPicker=false
    private var saveButton:NSButton!,loadButton:NSButton!
    private var audioPlayer:ExtendedSoundPlayer?
    private var soundToggle:NSButton!, musicToggle:NSButton!, runButton:NSButton!, restartButton:NSButton!, continueButton:NSButton!
    private var levelUI:ExtendedUI?, changingLevel=false
    private var campaign:ExtendedCampaignSequence?,campaignView:ExtendedCampaignView?
    private var campaignSound:SoundPlayer?,campaignTimer:Timer?,campaignRunning=false
    private var campaignTrack=""
    private let completion=NSTextField(wrappingLabelWithString:"")
    private var musicPlayer:MusicPlayer?,musicGeneration=0
    private var clock=ExtendedPlaybackClock(), wake:DispatchWorkItem?
    private var playbackGeneration=0, manualTag:Int?, ready=false, stopped=false
    private var keyMonitor:Any?
    private var turnHeld=0
    private let mode=NSTextField(labelWithString:"Paused")
    private var sceneBuilder:ExtendedSceneBuilder?, buttons:[NSButton]=[], closed=false
    func applicationDidFinishLaunching(_ notification:Notification) {
        do {
            let parsed=try BundledPreviewPlan.arguments(CommandLine.arguments)
            plan=parsed.0;let map=parsed.1
            window=NSWindow(contentRect:NSRect(x:0,y:0,width:1100,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.title="\(appTitle) — \(plan.title) — \(String(format:"MAP%02d",map))"
            window.delegate=self;window.isReleasedWhenClosed=false
            // Manual buttons deliberately block gameplay input, but Escape must
            // still interrupt their finite sequence (including button focus).
            keyMonitor=NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
                guard let self,event.window==self.window else { return event }
                if event.keyCode==53 {self.pause();return nil}
                if !event.isARepeat,event.modifierFlags.intersection([.command,.option,.control]).isEmpty,
                   [14,49,36].contains(Int(event.keyCode)),self.levelUI?.phase==1 {
                    self.changeLevel(restart:true);return nil
                }
                if !event.isARepeat,event.modifierFlags.intersection([.command,.option,.control]).isEmpty,
                   [14,49,36,3].contains(Int(event.keyCode)),self.campaign != nil {
                    self.continueLevel();return nil
                }
                return event
            }
            view=GameView(frame:.zero,device:MTLCreateSystemDefaultDevice())
            view.colorPixelFormat = .bgra8Unorm;view.depthStencilPixelFormat = .depth32Float
            view.clearColor=MTLClearColorMake(0,0,0,1);view.preferredFramesPerSecond=60
            view.inputBlocked=true;view.framebufferOnly=false
            renderer=try Renderer(view:view);renderer.extendedRustWeaponNames=plan.rustWeapons;view.delegate=renderer
            view.onEscape={ [weak self] in self?.pause() }
            renderer.onError={ [weak self] error in self?.failed(error) }
            let controls=NSStackView();controls.orientation = .horizontal;controls.spacing=8
            for (tag,title) in [(1,"Forward"),(2,"Back"),(3,"Turn left"),(4,"Turn right"),(6,"Use"),(7,"Fire"),(8,"Fire 1 second"),(5,"Step 1 second")] {
                let button=NSButton(title:title,target:self,action:#selector(step(_:)));button.tag=tag;button.isEnabled=false
                controls.addArrangedSubview(button);buttons.append(button)
            }
            soundToggle=NSButton(checkboxWithTitle:"Sound",target:self,action:#selector(toggleSound))
            soundToggle.state = .on;controls.addArrangedSubview(soundToggle)
            musicToggle=NSButton(checkboxWithTitle:"Music",target:self,action:#selector(toggleMusic))
            musicToggle.state = .on;controls.addArrangedSubview(musicToggle)
            runButton=NSButton(title:"Run",target:self,action:#selector(toggleRunning))
            runButton.isEnabled=false
            restartButton=NSButton(title:"Restart level",target:self,action:#selector(restartLevel))
            continueButton=NSButton(title:"Continue",target:self,action:#selector(continueLevel))
            restartButton.isEnabled=false;continueButton.isHidden=true
            saveButton=NSButton(title:"Save…",target:self,action:#selector(saveGame))
            loadButton=NSButton(title:"Load…",target:self,action:#selector(loadGame))
            saveButton.isEnabled=false;loadButton.isEnabled=false
            let transport=NSStackView(views:[runButton,restartButton,saveButton,loadButton,continueButton,mode]);transport.spacing=12
            completion.isHidden=true;completion.font=NSFont.systemFont(ofSize:16,weight:.semibold)
            let caption=NSTextField(labelWithString:"WASD move · Arrows turn/move · Shift run · E use · F fire · 1–7 weapon · Click to aim · Esc pause")
            caption.textColor = .secondaryLabelColor
            let stack=NSStackView(views:[transport,controls,caption,completion,status,view]);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8
            stack.translatesAutoresizingMaskIntoConstraints=false;view.translatesAutoresizingMaskIntoConstraints=false
            let content=NSView();window.contentView=content;content.addSubview(stack)
            NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:12),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-12),stack.topAnchor.constraint(equalTo:content.topAnchor,constant:12),stack.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-12),view.widthAnchor.constraint(equalTo:stack.widthAnchor),view.heightAnchor.constraint(greaterThanOrEqualToConstant:300)])
            let menu=NSMenu(),item=NSMenuItem(),submenu=NSMenu()
            submenu.addItem(withTitle:"Choose WADs…",action:#selector(chooseWADs),keyEquivalent:"o").target=self
            submenu.addItem(withTitle:"Quit preview",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
            item.submenu=submenu;menu.addItem(item);NSApp.mainMenu=menu
            window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
            let paths=plan.paths,base=plan.base,profile=plan.profile
            let executable=Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MetalDooMWorker")
            workerExecutable=executable
            queue.async { [self] in
                do {
                    let state=try worker.start(executable:executable,paths:paths,map:map,base:base,profile:profile)
                    guard let identity=worker.identity else { throw PortError("Missing worker identity.") }
                    let resources=try WAD(previewResources:paths,baseIndex:base,profile:profile,identity:identity)
                    let builder=try ExtendedSceneBuilder(resources:resources);self.sceneBuilder=builder
                    let scene=try builder.prepare(state)
                    DispatchQueue.main.async { [weak self] in self?.presentInitial(scene) }
                } catch { DispatchQueue.main.async { [weak self] in self?.failed(error) } }
            }
        } catch {
            if window != nil { failed(error) }
            else { let alert=NSAlert();alert.messageText="Cannot open Rust preview";alert.informativeText=String(describing:error);alert.runModal();NSApp.terminate(nil) }
        }
    }
    @objc private func step(_ sender:NSButton) {
        guard ready,!stopped,!changingLevel,levelUI?.playing==true,!clock.busy else { return }
        manualTag=sender.tag
        clock.start(now:ProcessInfo.processInfo.systemUptime,steps:sender.tag<=2 ? 8:(sender.tag==5 || sender.tag==8) ? 35:1)
        updateControls();musicPlayer?.update(active:true);schedule()
    }
    @objc private func toggleRunning() {
        if campaign != nil {
            if campaignRunning {pause()} else {do {try setCampaignRunning(true)} catch {failed(error)}}
            return
        }
        if clock.running { pause();return }
        guard ready,!stopped,!changingLevel,levelUI?.playing==true,!clock.busy else { return }
        manualTag=nil;view.releaseMouse();turnHeld=0
        clock.start(now:ProcessInfo.processInfo.systemUptime)
        renderer.setExtendedPlayback(active:true)
        view.inputBlocked=false;window.makeFirstResponder(view)
        updateControls();musicPlayer?.update(active:true);schedule()
    }
    private func pause(preserveEffects:Bool=false) {
        clock.pause();renderer?.setExtendedPlayback(active:false);wake?.cancel();wake=nil;playbackGeneration+=1
        campaignTimer?.invalidate();campaignTimer=nil;campaignRunning=false
        campaignSound?.stopAll();try? campaignSound?.setActive(false)
        view?.inputBlocked=true;view?.releaseMouse();turnHeld=0
        if !preserveEffects {audioPlayer?.stop()};musicPlayer?.update(active:false);updateControls()
    }
    private func updateControls() {
        let available=ready && !closed && !stopped && !changingLevel,playing=levelUI?.playing==true
        buttons.forEach{$0.isEnabled=available && playing && !clock.busy}
        runButton?.title=(clock.running || campaignRunning) ? "Pause":"Run"
        runButton?.isEnabled=available && (playing || campaign != nil) && (clock.running || !clock.inFlight)
        restartButton?.isEnabled=available && !clock.inFlight
        saveButton?.isEnabled=available && playing && !clock.inFlight
        loadButton?.isEnabled=available && !clock.inFlight
        continueButton?.isHidden=campaign == nil || campaign?.stage == .art
        if let campaign {
            switch campaign.stage {
            case .statistics:continueButton?.title=campaign.statistics.stage==10 ? "Continue":"Show totals"
            case .entering:continueButton?.title="Enter \(String(format:"MAP%02d",campaign.metadata.nextMap))"
            case .story:continueButton?.title=campaign.visibleCharacters<campaign.metadata.story.count ? "Show story":"Continue"
            case .cast:continueButton?.title=campaign.dead ? "Cast roll call":"Fire"
            case .art,.complete:break
            }
        }
        continueButton?.isEnabled=available && !clock.busy && campaign?.dead != true
        if campaign != nil {mode.stringValue=campaignRunning ? "Intermission · E / Space / Return / F to advance":"Intermission paused";return}
        mode.stringValue=changingLevel ? "Loading level…":stopped ? "Stopped":levelUI?.phase==1 ? "You died":levelUI?.phase==2 ? "Level complete":levelUI?.phase==3 ? "Episode complete":clock.running ? (manualTag == nil ? "Running · 35 tics/s target":"Stepping") : clock.inFlight ? "Pausing…":"Paused"
    }
    private func schedule() {
        guard clock.running,!closed,!stopped else { return }
        let token=playbackGeneration
        let work=DispatchWorkItem { [weak self] in
            guard let self,self.playbackGeneration==token else { return };self.advance()
        }
        wake=work
        DispatchQueue.main.asyncAfter(deadline:.now()+max(0,clock.deadline-ProcessInfo.processInfo.systemUptime),execute:work)
    }
    private func command()->(Int8,Int8,Int16,UInt8) {
        if let tag=manualTag {
            return (tag==1 ? 25:tag==2 ? -25:0,0,tag==3 ? 8192:tag==4 ? -8192:0,tag==6 ? 2:(tag==7 || tag==8) ? 1:0)
        }
        let keys=view.consumeMovement(),speed=view.running ? 50:25,strafe=view.running ? 40:24
        var forward=0,side=0,turn=Int((-view.mouseMotion.x*0.0025*65536/(2 * .pi)).clamped(-30000,30000))
        view.mouseMotion = .zero
        if keys.contains(13) || keys.contains(126) { forward+=speed }
        if keys.contains(1) || keys.contains(125) { forward-=speed }
        if keys.contains(0) { side-=strafe };if keys.contains(2) { side+=strafe }
        turnHeld=(keys.contains(123) || keys.contains(124)) ? turnHeld+1:0
        let turnSpeed=turnHeld<6 ? 320:view.running ? 1280:640
        if keys.contains(123) { turn+=turnSpeed };if keys.contains(124) { turn-=turnSpeed }
        var buttons=UInt8(view.consumeAttack())
        if view.useQueued || view.keys.contains(14) || view.keys.contains(49) { buttons |= 2 }
        view.useQueued=false
        let weapon=view.consumeWeapon();if weapon>=0 { buttons |= UInt8(4 | weapon<<3) }
        return (Int8(forward),Int8(side),Int16(clamping:turn),buttons)
    }
    private func advance() {
        guard !closed,!stopped else { return }
        guard clock.claim(now:ProcessInfo.processInfo.systemUptime) else { schedule();return }
        let input=command(),token=playbackGeneration
        queue.async { [self] in
            do {
                guard let sceneBuilder else { throw PortError("Preview resources unavailable.") }
                let state=try worker.tick(forward:input.0,side:input.1,turn:input.2,buttons:input.3,count:1)
                let scene=try sceneBuilder.prepare(state)
                let presentation=state.ui.phase>=2 ? try ExtendedCampaignSequence(metadata:ExtendedCampaign(data:worker.campaign(),ui:state.ui),ui:state.ui,wad:scene.resources):nil
                DispatchQueue.main.async { [weak self] in
                    guard let self,!self.closed,!self.stopped else { return }
                    do {
                        try self.display(scene,audible:self.playbackGeneration==token)
                        self.clock.finish()
                        if !scene.view.ui.playing {self.pause(preserveEffects:true)}
                        if let presentation {try self.beginCampaign(presentation,wad:scene.resources,running:self.playbackGeneration==token+1)}
                        self.musicPlayer?.update(active:self.clock.busy || self.campaignRunning);self.updateControls();self.schedule()
                    } catch { self.failed(error) }
                }
            } catch { DispatchQueue.main.async { [weak self] in self?.failed(error) } }
        }
    }
    private func presentInitial(_ scene:ExtendedScene) {
        guard !closed,!stopped else { return }
        do { try display(scene,audible:false);ready=true;updateControls();try reportLaunch("ready") }
        catch { failed(error) }
    }
    private func display(_ scene:ExtendedScene,audible:Bool) throws {
        try renderer.loadExtendedPreview(scene)
        let ui=scene.view.ui;levelUI=ui
        window.title="\(appTitle) — \(plan.title) — \(String(format:"MAP%02d",ui.map))"
        completion.isHidden=ui.playing
        if ui.phase==1 {completion.stringValue="You died. Restart level, or press E, Space or Return."}
        else if ui.phase>=2 {
            let seconds=ui.levelTics/35
            let heading=ui.phase==3 ? "Episode complete": "\(ui.secretExit ? "Secret exit" : "Level complete") → \(String(format:"MAP%02d",ui.nextMap))"
            completion.stringValue="\(heading)   ·   Kills \(ui.kills)/\(ui.totalKills)   Items \(ui.items)/\(ui.totalItems)   Secrets \(ui.secrets)/\(ui.totalSecrets)   Time \(seconds/60):\(String(format:"%02d",seconds%60))"
            continueButton.title="Continue to \(String(format:"MAP%02d",ui.nextMap))"
        }
        if ui.musicGeneration != musicGeneration {
            if musicPlayer==nil { musicPlayer=try MusicPlayer(wad:scene.resources,map:scene.copiedGeometry.map.name,track:plan.track ?? ui.music,backend:"apple") }
            else { try musicPlayer?.select(plan.track ?? ui.music) }
            musicPlayer?.looping=ui.looping;musicPlayer?.enabled=musicToggle.state == .on
            musicGeneration=ui.musicGeneration;musicPlayer?.update(active:clock.busy && audible)
        }
        if audioPlayer==nil { audioPlayer=try ExtendedSoundPlayer(resources:scene.resources) }
        audioPlayer?.muted=soundToggle.state != .on
        try audioPlayer?.present(scene.view.audio,audible:audible)
        status.stringValue="Tic \(scene.view.tic) · \(scene.geometry.triangleCount.formatted()) triangles · Sky \(scene.view.sky) · Health \(scene.view.health) · Ammo \(scene.view.presentation.ammo) · \(scene.view.presentation.actors.count) actors"
    }
    @objc private func restartLevel() {changeLevel(restart:true)}
    @objc private func continueLevel() {
        guard let campaign,!changingLevel,!closed,!stopped else {return}
        campaign.press()
        do {try updateCampaign()} catch {failed(error)}
    }
    private func beginCampaign(_ sequence:ExtendedCampaignSequence,wad:WAD,running:Bool) throws {
        let overlay=try ExtendedCampaignView(sequence:sequence,wad:wad)
        overlay.frame=view.bounds;overlay.autoresizingMask=[.width,.height]
        view.addSubview(overlay);campaignView=overlay;campaign=sequence
        // Completed worlds are frozen; MTKView does not need to redraw under art.
        view.isPaused=true;completion.isHidden=true
        campaignSound=try SoundPlayer(wad:wad,onlyLumps:[],voiceCount:4)
        var sounds=Set(sequence.metadata.sounds.values.filter{["DSPISTOL","DSBAREXP","DSSGCOCK"].contains($0)})
        // Resolve even BEX-renamed intermission cues and every custom cast cue.
        for id in [1,3,82] {if let name=sequence.metadata.sounds[String(id)] {sounds.insert(name)}}
        if let finale=sequence.finale {
            for actor in finale.castrollcall.castanims {
                for id in [actor.alertsound]+(actor.aliveframes+actor.deathframes).map(\.sound) {
                    if let name=sequence.metadata.sounds[String(id)] {sounds.insert(name)}
                }
            }
        }
        try campaignSound?.prepare(lumps:Set(sounds.compactMap{name in wad.lumps.lastIndex{$0.name==name}}),wad:wad)
        campaignTrack="";try updateCampaign();try setCampaignRunning(running && NSApp.isActive)
    }
    private func setCampaignRunning(_ running:Bool) throws {
        guard campaign != nil,!closed,!stopped,!changingLevel else {return}
        campaignTimer?.invalidate();campaignTimer=nil;campaignRunning=running
        try campaignSound?.setActive(running && soundToggle.state == .on)
        musicPlayer?.update(active:running)
        if running {
            // A delayed UI wake advances one presentation tic; no catch-up debt.
            let timer=Timer(timeInterval:1.0/35,repeats:true) { [weak self] _ in
                guard let self,self.campaignRunning else {return}
                self.campaign?.tick()
                do {try self.updateCampaign()} catch {self.failed(error)}
            }
            campaignTimer=timer;RunLoop.main.add(timer,forMode:.common)
        }
        updateControls()
    }
    private func updateCampaign() throws {
        guard let campaign,let wad=sceneBuilder?.resources else {return}
        if campaign.stage == .complete {changeLevel(restart:false);return}
        let track=campaign.music
        if campaignTrack != track.0 {
            try musicPlayer?.select(plan.track ?? track.0);musicPlayer?.looping=track.1
            campaignTrack=track.0;musicPlayer?.update(active:campaignRunning)
        }
        musicPlayer?.update(active:campaignRunning)
        let sounds=campaign.drainSounds()
        if campaignRunning && soundToggle.state == .on {
            for (channel,name) in sounds.enumerated() {
                guard let lump=wad.lumps.lastIndex(where:{$0.name==name}) else {throw PortError("Missing presentation sound")}
                var event=MD_SoundEvent();event.lump=Int32(lump);event.channel=Int32(channel%4);event.volume=1;event.pan=0
                campaignSound?.play(event)
            }
        }
        campaignView?.needsDisplay=true;updateControls()
    }
    private func changeLevel(restart:Bool) {
        guard ready,!closed,!stopped,!changingLevel,!clock.inFlight, restart || levelUI?.phase==2 else {return}
        pause();changingLevel=true
        campaignView?.removeFromSuperview();campaignView=nil;campaign=nil;campaignSound=nil;campaignTrack=""
        view.isPaused=false;updateControls()
        queue.async { [self] in
            do {
                guard let resources=sceneBuilder?.resources else {throw PortError("Missing session resources")}
                let state=try worker.advance(restart:restart)
                let builder=try ExtendedSceneBuilder(resources:resources)
                let scene=try builder.prepare(state);sceneBuilder=builder
                DispatchQueue.main.async { [weak self] in
                    guard let self,!self.closed,!self.stopped else {return}
                    do {
                        // New world/tic-zero snapshots must not reuse old mesh, sprite,
                        // audio sequence or input state. Resource identity stays fixed.
                        let renderer=try Renderer(view:self.view);renderer.extendedRustWeaponNames=self.plan.rustWeapons
                        renderer.onError={ [weak self] in self?.failed($0) }
                        self.renderer=renderer;self.view.delegate=renderer
                        self.audioPlayer=nil;self.musicPlayer=nil;self.musicGeneration=0
                        self.clock=ExtendedPlaybackClock();self.manualTag=nil
                        self.changingLevel=false
                        self.presentInitial(scene)
                    } catch {self.failed(error)}
                }
            } catch {DispatchQueue.main.async { [weak self] in self?.failed(error) }}
        }
    }
    @objc private func saveGame() {
        guard ready,!stopped,!closed,!changingLevel,!clock.inFlight,levelUI?.playing==true else {return}
        pause();changingLevel=true;updateControls()
        let panel=NSSavePanel();panel.title="Save Rust game";panel.nameFieldStringValue=String(format:"Rust-MAP%02d.mdrust",levelUI!.map)
        panel.allowedContentTypes=[UTType(exportedAs:"dev.metaldoom.rust-save",conformingTo:.data)]
        panel.beginSheetModal(for:window) { [weak self] response in
            guard let self,!self.closed else {return}
            self.changingLevel=false
            if response == .OK,let url=panel.url {self.save(to:url)} else {self.updateControls()}
        }
    }
    @objc private func loadGame() {
        guard ready,!stopped,!closed,!changingLevel,!clock.inFlight else {return}
        pause();changingLevel=true;updateControls()
        let panel=NSOpenPanel();panel.title="Load Rust game";panel.allowsMultipleSelection=false;panel.canChooseDirectories=false
        panel.allowedContentTypes=[UTType(exportedAs:"dev.metaldoom.rust-save",conformingTo:.data)]
        panel.beginSheetModal(for:window) { [weak self] response in
            guard let self,!self.closed else {return}
            self.changingLevel=false
            if response == .OK,let url=panel.url {self.restore(from:url)} else {self.updateControls()}
        }
    }
    private func save(to url:URL) {
        guard ready,!stopped,!closed,!changingLevel,!clock.inFlight,levelUI?.playing==true,let executable=workerExecutable else {return}
        pause();changingLevel=true;updateControls()
        queue.async { [self] in
            let payload:Data
            do {payload=try worker.save()}
            catch {DispatchQueue.main.async { [weak self] in self?.failed(error)};return}
            do {
                let snapshot=try ExtendedSave(payload:payload,engine:ExtendedSave.engineIdentity(executable:executable))
                try snapshot.write(to:url)
                DispatchQueue.main.async { [weak self] in
                    guard let self,!self.closed else {return}
                    self.changingLevel=false;self.status.stringValue="Saved \(url.lastPathComponent) · MAP\(snapshot.map) · tic \(snapshot.tic)";self.updateControls()
                }
            } catch {DispatchQueue.main.async { [weak self] in self?.saveFailed(error)}}
        }
    }
    private func restore(from url:URL) {
        guard ready,!stopped,!closed,!changingLevel,!clock.inFlight,let executable=workerExecutable,let resources=sceneBuilder?.resources else {return}
        pause();changingLevel=true;updateControls()
        let candidate=ExtendedWorker();pendingWorker=candidate
        queue.async { [self] in
            do {
                guard let identity=worker.identity else {throw PortError("Missing resource identity")}
                let saved=try ExtendedSave.read(url,engine:ExtendedSave.engineIdentity(executable:executable),identity:identity)
                guard (1...plan.mapLimit).contains(saved.map) else {throw PortError("Saved map is outside this content profile")}
                _=try candidate.start(executable:executable,paths:resources.sourceURLs,map:saved.map,base:plan.base,profile:plan.profile,skill:saved.skill)
                let state=try candidate.restore(saved.payload)
                guard state.ui.playing,state.tic==saved.tic,state.ui.map==saved.map,state.geometry != nil else {throw PortError("Restored state does not match save")}
                let builder=try ExtendedSceneBuilder(resources:resources),scene=try builder.prepare(state)
                DispatchQueue.main.async { [weak self] in
                    guard let self,!self.closed else {candidate.cancel();self?.queue.async{candidate.close()};return}
                    do {
                        // Prepare every fallible native resource before retiring the
                        // current worker. Bad saves leave that paused game intact.
                        let renderer=try Renderer(view:self.view);renderer.extendedRustWeaponNames=self.plan.rustWeapons;try renderer.loadExtendedPreview(scene)
                        let audio=try ExtendedSoundPlayer(resources:resources,initialTic:state.tic);try audio.prepare(state.audio)
                        let music=try MusicPlayer(wad:resources,map:scene.copiedGeometry.map.name,track:self.plan.track ?? state.ui.music,backend:"apple")
                        music.looping=state.ui.looping;music.enabled=self.musicToggle.state == .on;music.update(active:false)
                        renderer.onError={ [weak self] in self?.failed($0) }
                        let previous=self.worker;self.worker=candidate;self.pendingWorker=nil;self.sceneBuilder=builder
                        self.campaignView?.removeFromSuperview();self.campaignView=nil;self.campaign=nil;self.campaignSound=nil;self.campaignTrack=""
                        self.renderer=renderer;self.view.delegate=renderer;self.view.isPaused=false
                        self.audioPlayer=audio;self.musicPlayer=music;self.musicGeneration=state.ui.musicGeneration
                        self.clock=ExtendedPlaybackClock();self.manualTag=nil;self.changingLevel=false
                        self.presentInitial(scene)
                        self.status.stringValue="Loaded \(url.lastPathComponent) · MAP\(saved.map) · tic \(saved.tic) · Paused"
                        previous.cancel();self.queue.async{previous.close()}
                    } catch {candidate.cancel();self.queue.async{candidate.close()};self.saveFailed(error)}
                }
            } catch {candidate.close();DispatchQueue.main.async { [weak self] in self?.saveFailed(error)}}
        }
    }
    private func saveFailed(_ error:Error) {
        guard !closed else {return}
        pendingWorker=nil;changingLevel=false;status.stringValue="Save/load failed: \(error)";updateControls()
    }
    func applicationDidResignActive(_ notification:Notification) { pause() }
    func windowDidResignKey(_ notification:Notification) { pause() }
    @objc private func toggleMusic() { musicPlayer?.enabled=musicToggle.state == .on;musicPlayer?.update(active:clock.busy || campaignRunning) }
    @objc private func toggleSound() {
        audioPlayer?.muted=soundToggle.state != .on
        if soundToggle.state != .on {campaignSound?.stopAll()}
        do {try campaignSound?.setActive(campaignRunning && soundToggle.state == .on)} catch {failed(error)}
    }
    @objc private func chooseWADs() {
        guard !openingPicker else {return};pause();openingPicker=true
        let configuration=NSWorkspace.OpenConfiguration();configuration.createsNewApplicationInstance=true
        configuration.arguments=["--choose-wads"]
        // Keep the current paused preview and its unsaved game available.
        NSWorkspace.shared.openApplication(at:Bundle.main.bundleURL,configuration:configuration) { [weak self] _,error in
            DispatchQueue.main.async {
                self?.openingPicker=false
                if let error {NSAlert(error:error).runModal()}
            }
        }
    }
    private func reportLaunch(_ result:String)throws {
        guard !launchReported,let i=CommandLine.arguments.firstIndex(of:"-switch-ready"),i+1<CommandLine.arguments.count else {return}
        try result.write(toFile:CommandLine.arguments[i+1],atomically:true,encoding:.utf8);launchReported=true
    }
    private func failed(_ error:Error) {
        try? reportLaunch("failed")
        guard !closed else { return }
        changingLevel=false;stopped=true;pause();worker.cancel();status.stringValue="Preview stopped: \(error)"
    }
    func windowWillClose(_ notification:Notification) { shutdown() }
    func applicationWillTerminate(_ notification:Notification) { shutdown() }
    private func shutdown() {
        guard !closed else { return };closed=true;pause()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor);self.keyMonitor=nil }
        worker.cancel();pendingWorker?.cancel();musicPlayer=nil;view?.isPaused=true;view?.delegate=nil
    }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        shutdown()
        queue.async { [self] in
            worker.close();pendingWorker?.close()
            DispatchQueue.main.async { sender.reply(toApplicationShouldTerminate:true) }
        }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
