// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

// Native accessible controls over the paused Metal view, with original IWAD art.
final class GameMenu: NSView {
    unowned let app: App
    private let stack=NSStackView()
    private var mainButtons: [NSButton] = []
    private var selected = 0
    override var acceptsFirstResponder: Bool { true }
    private var actions: [() -> Void] = []
    private var episode: NSPopUpButton?, difficulty: NSPopUpButton?
    private var slotName: NSTextField?
    private var resolutionLabel: NSTextField?
    private(set) var page="Main"
    init(app: App) {
        self.app=app
        super.init(frame:.zero)
        wantsLayer=true; layer?.backgroundColor=NSColor.black.withAlphaComponent(0.88).cgColor
        layer?.borderColor=NSColor.systemRed.withAlphaComponent(0.6).cgColor; layer?.borderWidth=1
        layer?.cornerRadius=8
        stack.orientation = .vertical; stack.spacing=12; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints=false; addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo:topAnchor,constant:24),stack.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-24),
            stack.leadingAnchor.constraint(equalTo:leadingAnchor,constant:28),stack.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-28),
            widthAnchor.constraint(equalToConstant:520)
        ])
        main()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func reset(_ title: String) {
        page=title; actions=[]; mainButtons=[]; selected=0; resolutionLabel=nil
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
        let heading=NSTextField(labelWithString:title.uppercased()); heading.font = .monospacedSystemFont(ofSize:24,weight:.heavy)
        heading.textColor = .systemRed; stack.addArrangedSubview(heading)
    }
    private func text(_ value: String) {
        let label=NSTextField(wrappingLabelWithString:value); label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize:12); stack.addArrangedSubview(label)
    }
    private func image(_ name: String) -> NSImage? {
        guard let wad=app.wad, let art=try? Art(wad:wad), let patch=try? art.patch(named:name) else { return nil }
        let pixels=patch.image
        guard let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels.width,pixelsHigh:pixels.height,
            bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:pixels.width*4,bitsPerPixel:32),let data=rep.bitmapData else { return nil }
        pixels.rgba.withUnsafeBytes { data.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:pixels.rgba.count) }
        let image=NSImage(size:NSSize(width:pixels.width*2,height:Int(Double(pixels.height)*2.4))); image.addRepresentation(rep)
        return image
    }
    @discardableResult private func button(_ title: String, art: String? = nil, enabled: Bool = true, action: @escaping () -> Void) -> NSButton {
        let button=NSButton(title:title,target:self,action:#selector(invoke(_:)))
        button.tag=actions.count; actions.append(action); button.isEnabled=enabled; button.bezelStyle = .rounded
        if let art, let image=image(art) {
            button.image=image; button.imageScaling = .scaleProportionallyDown; button.imagePosition = .imageOnly; button.isBordered=false
            button.setAccessibilityLabel(title)
            button.heightAnchor.constraint(equalToConstant:30).isActive=true
        }
        stack.addArrangedSubview(button); if page=="Paused" && enabled { mainButtons.append(button) }; return button
    }
    @objc private func invoke(_ sender: NSButton) { actions[sender.tag]() }
    private func back() { button("Back — Esc") { [weak self] in self?.main() } }
    func main() {
        reset("Paused")
        if let logo=image("M_DOOM") {
            let imageView=NSImageView(); imageView.image=logo; imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.heightAnchor.constraint(equalToConstant:72).isActive=true; stack.addArrangedSubview(imageView)
        }
        button("Resume",enabled:app.wad != nil) { [weak self] in self?.app.closeGameMenu() }.keyEquivalent="\r"
        button("New Game",art:"M_NGAME",enabled:app.wad != nil) { [weak self] in self?.newGame() }
        button("Options",art:"M_OPTION") { [weak self] in self?.options() }
        button("Save Game",art:"M_SAVEG",enabled:app.wad != nil && MD_GetProgress().phase==0 && MD_GetHUD().health>0) { [weak self] in self?.slots(saving:true) }
        button("Load Game",art:"M_LOADG",enabled:app.wad != nil) { [weak self] in self?.slots(saving:false) }
        button("Open WAD…") { [weak self] in self?.app.openWAD() }
        button("Quit Game",art:"M_QUITG") { NSApp.terminate(nil) }
        text("Game paused · Esc resumes · Tab selects controls")
    }
    func escape() { if page=="Main" || page=="Paused" { app.closeGameMenu() } else { main() } }
    func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { if !event.isARepeat { escape() }; return true }
        guard page=="Paused", !mainButtons.isEmpty else { return false }
        if event.keyCode == 125 || event.keyCode == 126 {
            mainButtons[selected].highlight(false)
            selected=(selected+(event.keyCode == 125 ? 1 : mainButtons.count-1)) % mainButtons.count
            mainButtons[selected].highlight(true); window?.makeFirstResponder(self); return true
        }
        if event.keyCode == 36 { if !event.isARepeat { mainButtons[selected].performClick(nil) }; return true }
        return false
    }
    private func newGame() {
        reset("New Game")
        let episodes=NSPopUpButton()
        if app.wad?.maps.contains("MAP01")==true { episodes.addItem(withTitle:"Doom II"); episodes.lastItem?.representedObject="MAP01" }
        else {
            let names=["Knee-Deep in the Dead","The Shores of Hell","Inferno","Thy Flesh Consumed"]
            for i in 1...4 where app.wad?.maps.contains("E\(i)M1")==true {
                episodes.addItem(withTitle:names[i-1]); episodes.lastItem?.representedObject="E\(i)M1"
            }
        }
        episode=episodes; row("Episode",episodes)
        let skills=NSPopUpButton(); skills.addItems(withTitles:["I'm too young to die.","Hey, not too rough.","Hurt me plenty.","Ultra-Violence.","Nightmare!"])
        skills.selectItem(at:Int(app.renderer.skill)); difficulty=skills; row("Difficulty",skills)
        text("Starting a new game replaces the current unsaved run. Nightmare uses fast, respawning monsters.")
        button("Start Game") { [weak self] in
            guard let self, let map=self.episode?.selectedItem?.representedObject as? String, let wad=self.app.wad else { return }
            let old=self.app.renderer.skill; self.app.renderer.skill=Int32(self.difficulty?.indexOfSelectedItem ?? 2)
            do {
                self.app.describe(map,try self.app.renderer.load(wad:wad,map:map)); self.app.maps.selectItem(withTitle:map)
                self.app.closeGameMenu()
            } catch { self.app.renderer.skill=old; self.app.show(error) }
        }
        back()
    }
    private func row(_ title: String,_ control: NSView) {
        let label=NSTextField(labelWithString:title); label.widthAnchor.constraint(equalToConstant:110).isActive=true
        let row=NSStackView(views:[label,control]); row.spacing=12; stack.addArrangedSubview(row)
    }
    private func options() {
        reset("Options")
        let sizes=NSPopUpButton(); sizes.addItems(withTitles:["960 × 720","1100 × 760","1280 × 720","1600 × 900","1920 × 1080"])
        let current=UserDefaults.standard.object(forKey:"windowPreset") as? Int ?? 1; sizes.selectItem(at:min(4,max(0,current)))
        sizes.target=self; sizes.action=#selector(windowSize(_:)); sizes.isEnabled = !app.window.styleMask.contains(.fullScreen)
        row("Window size",sizes)
        let fullscreen=NSButton(checkboxWithTitle:"Fullscreen",target:self,action:#selector(fullscreen(_:)))
        fullscreen.state=app.window.styleMask.contains(.fullScreen) ? .on : .off; stack.addArrangedSubview(fullscreen)
        let scale=NSPopUpButton(); scale.addItems(withTitles:["50%","75%","100% (native)"])
        scale.selectItem(at:[CGFloat(0.5),0.75,1].firstIndex(of:app.view.renderScale) ?? 2)
        scale.target=self; scale.action=#selector(renderScale(_:)); row("Render scale",scale)
        let fps=NSPopUpButton(); fps.addItems(withTitles:["35 FPS","60 FPS","120 FPS"])
        fps.selectItem(at:[35,60,120].firstIndex(of:app.view.preferredFramesPerSecond) ?? 2)
        fps.target=self; fps.action=#selector(frameRate(_:)); row("Frame limit",fps)
        resolutionLabel=NSTextField(labelWithString:""); stack.addArrangedSubview(resolutionLabel!)
        updateResolutionText()
        text("Window sizes are macOS points. Fullscreen uses the display's current mode. Render scale changes the Metal pixel resolution.")
        let music=NSSlider(value:Double(app.renderer.musicVolume),minValue:0,maxValue:1,target:self,action:#selector(musicVolume(_:)))
        music.setAccessibilityLabel("Music volume"); row("Music volume",music)
        let effects=NSSlider(value:Double(app.renderer.effectsVolume),minValue:0,maxValue:1,target:self,action:#selector(effectsVolume(_:)))
        effects.setAccessibilityLabel("Sound effects volume"); row("Effects volume",effects)
        let enabled=NSButton(checkboxWithTitle:"Music enabled",target:self,action:#selector(musicEnabled(_:)))
        enabled.state=app.renderer.musicEnabled ? .on : .off; stack.addArrangedSubview(enabled)
        back()
    }
    func updateResolutionText() {
        let size=app.view.drawableSize
        resolutionLabel?.stringValue="Rendering at \(Int(size.width)) × \(Int(size.height)) pixels"
    }
    @objc private func windowSize(_ sender: NSPopUpButton) {
        let sizes=[NSSize(width:960,height:720),NSSize(width:1100,height:760),NSSize(width:1280,height:720),NSSize(width:1600,height:900),NSSize(width:1920,height:1080)]
        app.applyWindowSize(sizes[sender.indexOfSelectedItem]); UserDefaults.standard.set(sender.indexOfSelectedItem,forKey:"windowPreset")
    }
    @objc private func fullscreen(_ sender: NSButton) { app.window.toggleFullScreen(nil) }
    @objc private func renderScale(_ sender: NSPopUpButton) {
        app.view.renderScale=[0.5,0.75,1][sender.indexOfSelectedItem]; UserDefaults.standard.set(Double(app.view.renderScale),forKey:"renderScale"); updateResolutionText()
    }
    @objc private func frameRate(_ sender: NSPopUpButton) {
        app.view.preferredFramesPerSecond=[35,60,120][sender.indexOfSelectedItem]; UserDefaults.standard.set(app.view.preferredFramesPerSecond,forKey:"frameLimit")
    }
    @objc private func musicVolume(_ sender: NSSlider) { app.renderer.musicVolume=sender.floatValue }
    @objc private func effectsVolume(_ sender: NSSlider) { app.renderer.effectsVolume=sender.floatValue }
    @objc private func musicEnabled(_ sender: NSButton) { app.renderer.musicEnabled=sender.state == .on; app.syncMusicMenu() }
    private func slots(saving: Bool) {
        reset(saving ? "Save Game" : "Load Game")
        guard let wad=app.wad else { return }
        if saving {
            let field=NSTextField(string:app.wad?.mapTitle(app.maps.titleOfSelectedItem ?? "") ?? "Saved game")
            field.placeholderString="Save name"; field.setAccessibilityLabel("Save name"); slotName=field; row("Name",field)
            text("Choose a slot to save. Choosing an occupied slot replaces that save.")
        }
        for i in 0..<6 {
            do {
                let url=try SaveStore.slotURL(wad:wad,slot:i)
                let exists=FileManager.default.fileExists(atPath:url.path)
                let save=try? SaveStore.read(from:url,wad:wad)
                let name=save.map { "\($0.title ?? wad.mapTitle($0.map)) — \($0.savedAt.formatted(date:.abbreviated,time:.shortened))" } ?? (exists ? "Unreadable save" : "Empty")
                button("\(i+1). \(name)",enabled:saving || save != nil) { [weak self] in
                    guard let self else { return }
                    do {
                        if saving {
                            let name=String((self.slotName?.stringValue ?? "Saved game").trimmingCharacters(in:.whitespacesAndNewlines).prefix(80))
                            try self.app.renderer.saveGame(to:url,title:name.isEmpty ? "Saved game" : name)
                        } else { try self.app.renderer.loadGame(from:url) }
                        self.app.closeGameMenu()
                    } catch { self.app.show(error) }
                }
            } catch { text("Slot \(i+1): \(error)") }
        }
        back()
    }
}
