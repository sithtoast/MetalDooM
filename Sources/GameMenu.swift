// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

// Native accessible controls over the paused Metal view, with original IWAD art.
final class GameMenu: NSView {
    unowned let app: App
    private let stack=NSStackView()
    private var menuWidth: NSLayoutConstraint!
    private var classic: ClassicMenuCanvas?
    private var decoder: Art?
    private var origins: [String:CGPoint] = [:]
    private var images: [String:NSImage] = [:]
    private var chosenMap="E1M1"
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
        menuWidth=widthAnchor.constraint(equalToConstant:520)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo:topAnchor,constant:24),stack.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-24),
            stack.leadingAnchor.constraint(equalTo:leadingAnchor,constant:28),stack.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-28),
            menuWidth
        ])
        main()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func reset(_ title: String) {
        classic=nil; menuWidth.constant=520; layer?.backgroundColor=NSColor.black.withAlphaComponent(0.88).cgColor
        layer?.borderWidth=1
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
        if let image=images[name] { return image }
        guard let wad=app.wad else { return nil }
        if decoder == nil { decoder=try? Art(wad:wad) }
        guard let decoder else { return nil }
        let pixels: PixelImage
        if name=="MD_ULTIMATE_LOGO" {
            guard let logo=try? MenuLogo.ultimate(art:decoder) else { return nil }
            pixels=logo;origins[name] = .zero
        } else {
            guard let patch=try? decoder.patch(named:name) else { return nil }
            origins[name]=CGPoint(x:patch.left,y:patch.top);pixels=patch.image
        }
        guard let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels.width,pixelsHigh:pixels.height,
            bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:pixels.width*4,bitsPerPixel:32),let data=rep.bitmapData else { return nil }
        pixels.rgba.withUnsafeBytes { data.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:pixels.rgba.count) }
        let image=NSImage(size:NSSize(width:pixels.width,height:pixels.height)); image.addRepresentation(rep); images[name]=image
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
    private func canvas(_ title: String, art: [(String,CGFloat,CGFloat)], items: [ClassicMenuCanvas.Item], selected: Int=0, labels: [(String,CGFloat,CGFloat)]=[], back: @escaping () -> Void) {
        reset(title)
        for child in stack.arrangedSubviews { stack.removeArrangedSubview(child); child.removeFromSuperview() }
        layer?.backgroundColor=NSColor.clear.cgColor; layer?.borderWidth=0; menuWidth.constant=640
        let canvas=ClassicMenuCanvas(); canvas.image={ [weak self] in self?.image($0) }
        canvas.patchOrigin={ [weak self] in self?.origins[$0] ?? .zero }
        canvas.artwork=art; canvas.items=items; canvas.selected=selected; canvas.onBack=back; canvas.labels=labels
        canvas.onSound={ [weak self] in self?.app.playMenuSound($0) }
        canvas.translatesAutoresizingMaskIntoConstraints=false
        stack.addArrangedSubview(canvas)
        NSLayoutConstraint.activate([canvas.widthAnchor.constraint(equalTo:stack.widthAnchor),canvas.heightAnchor.constraint(equalTo:canvas.widthAnchor,multiplier:0.75)])
        canvas.configure(); classic=canvas; window?.makeFirstResponder(canvas)
    }
    func main() {
        guard app.wad != nil else {
            reset("MetalDooM"); text("Open your Doom WAD to begin.")
            button("Open WAD…") { [weak self] in self?.app.openWAD() }; return
        }
        let canSave = !app.attractActive && MD_GetProgress().phase==0 && MD_GetHUD().health>0
        let ultimate=image("MD_ULTIMATE_LOGO") != nil
        let offset: CGFloat=ultimate ? 24:0
        canvas("Paused",art:[(ultimate ? "MD_ULTIMATE_LOGO":"M_DOOM",98,0)],items:[
            .init(title:"New Game",patch:"M_NGAME",x:97,y:64+offset,action:{ [weak self] in self?.newGame() }),
            .init(title:"Options",patch:"M_OPTION",x:97,y:80+offset,action:{ [weak self] in self?.options() }),
            .init(title:"Load Game",patch:"M_LOADG",x:97,y:96+offset,action:{ [weak self] in self?.slots(saving:false) }),
            .init(title:"Save Game",patch:"M_SAVEG",x:97,y:112+offset,enabled:canSave,action:{ [weak self] in self?.slots(saving:true) }),
            .init(title:"Read This",patch:"M_RDTHIS",x:97,y:128+offset,action:{ [weak self] in self?.readThis() }),
            .init(title:"Quit Game",patch:"M_QUITG",x:97,y:144+offset,action:{ NSApp.terminate(nil) })
        ],back:{ [weak self] in self?.app.dismissGameMenu() })
        classic?.footer=appTitle
    }
    private func readThis() {
        canvas("Help",art:[(app.wad?.lump("HELP1") != nil ? "HELP1" : "CREDIT",0,0)],items:[],back:{ [weak self] in self?.main() })
    }
    func escape() {
        if let classic { classic.onBack?() }
        else if page=="Main" || page=="Paused" { app.closeGameMenu() } else { main() }
    }
    func handleKey(_ event: NSEvent) -> Bool {
        if let classic {
            if page=="Help", event.keyCode==36 { if !event.isARepeat { main() }; return true }
            return classic.handle(event)
        }
        if event.keyCode == 53 { if !event.isARepeat { escape() }; return true }
        return false
    }
    private func newGame() {
        if app.wad?.maps.contains("MAP01")==true { chosenMap="MAP01"; chooseSkill(); return }
        let names=["Knee-Deep in the Dead","The Shores of Hell","Inferno","Thy Flesh Consumed"]
        let items=(1...4).filter { app.wad?.maps.contains("E\($0)M1")==true }.map { i in
            ClassicMenuCanvas.Item(title:names[i-1],patch:"M_EPI\(i)",x:48,y:CGFloat(63+(i-1)*16),action:{ [weak self] in
                self?.chosenMap="E\(i)M1"; self?.chooseSkill()
            })
        }
        canvas("Episode",art:[("M_EPISOD",54,38)],items:items,back:{ [weak self] in self?.main() })
    }
    private func chooseSkill() {
        let names=["I'm too young to die.","Hey, not too rough.","Hurt me plenty.","Ultra-Violence.","Nightmare!"]
        let patches=["M_JKILL","M_ROUGH","M_HURT","M_ULTRA","M_NMARE"]
        let items=names.indices.map { i in
            ClassicMenuCanvas.Item(title:names[i],patch:patches[i],x:48,y:CGFloat(63+i*16),action:{ [weak self] in self?.startGame(skill:Int32(i)) })
        }
        canvas("Difficulty",art:[("M_NEWG",96,14),("M_SKILL",54,38)],items:items,selected:Int(app.renderer.skill),back:{ [weak self] in
            guard let self else { return }
            if self.app.wad?.maps.contains("MAP01")==true { self.main() } else { self.newGame() }
        })
    }
    private func startGame(skill: Int32) {
        guard let wad=app.wad else { return }
        let old=app.renderer.skill; app.renderer.skill=skill
        do {
            app.describe(chosenMap,try app.renderer.load(wad:wad,map:chosenMap)); app.maps.selectItem(withTitle:chosenMap)
            app.closeGameMenu()
        } catch { app.renderer.skill=old; app.show(error) }
    }
    private func options() {
        canvas("Options",art:[("M_OPTTTL",108,15)],items:[
            .init(title:"Sound Volume",patch:"M_SVOL",x:60,y:64,action:{ [weak self] in self?.audioOptions() }),
            .init(title:"Display",patch:"",x:60,y:96,action:{ [weak self] in self?.displayOptions() }),
            .init(title:"Back",patch:"",x:60,y:128,action:{ [weak self] in self?.main() })
        ],labels:[("ENTER SELECT   ESC BACK",48,180)],back:{ [weak self] in self?.main() })
    }
    private func audioOptions() {
        canvas("Audio",art:[("M_SVOL",60,25)],items:[
            .init(title:"Sound effects volume",patch:"M_SFXVOL",x:80,y:64,action:{},
                adjust:{ [weak self] step in
                    guard let self else { return }; self.app.renderer.effectsVolume=max(0,min(1,self.app.renderer.effectsVolume+Float(step)/15))
                },meter:{ [weak self] in self?.app.renderer.effectsVolume ?? 0 }),
            .init(title:"Music volume",patch:"M_MUSVOL",x:80,y:104,action:{},
                adjust:{ [weak self] step in
                    guard let self else { return }; self.app.renderer.musicVolume=max(0,min(1,self.app.renderer.musicVolume+Float(step)/15))
                },meter:{ [weak self] in self?.app.renderer.musicVolume ?? 0 }),
            .init(title:"Music",patch:"",x:80,y:144,action:{},value:{ [weak self] in self?.app.renderer.musicEnabled==true ? "ON" : "OFF" },
                adjust:{ [weak self] _ in self?.app.renderer.musicEnabled.toggle(); self?.app.syncMusicMenu() }),
            .init(title:"Back",patch:"",x:80,y:164,action:{ [weak self] in self?.options() })
        ],labels:[("LEFT/RIGHT ADJUST   ESC BACK",40,188)],back:{ [weak self] in self?.options() })
    }
    private static let sizes=[NSSize(width:960,height:720),NSSize(width:1100,height:760),NSSize(width:1280,height:720),NSSize(width:1600,height:900),NSSize(width:1920,height:1080)]
    private func displayOptions(selected: Int=0) {
        canvas("Display",art:[("M_OPTTTL",108,15)],items:[
            .init(title:"Window",patch:"",x:48,y:52,enabled:!app.window.styleMask.contains(.fullScreen),action:{},value:{
                let i=min(4,max(0,UserDefaults.standard.object(forKey:"windowPreset") as? Int ?? 1)), size=Self.sizes[i]
                return "\(Int(size.width))X\(Int(size.height))"
            },adjust:{ [weak self] step in
                guard let self else { return }
                let i=(min(4,max(0,UserDefaults.standard.object(forKey:"windowPreset") as? Int ?? 1))+step+5)%5
                UserDefaults.standard.set(i,forKey:"windowPreset"); self.app.applyWindowSize(Self.sizes[i])
            }),
            .init(title:"Fullscreen",patch:"",x:48,y:72,action:{},value:{ [weak self] in self?.app.window.styleMask.contains(.fullScreen)==true ? "ON" : "OFF" },
                adjust:{ [weak self] _ in self?.app.window.toggleFullScreen(nil) }),
            .init(title:"Render scale",patch:"",x:48,y:92,action:{},value:{ [weak self] in "\(Int((self?.app.view.renderScale ?? 1)*100))%" },
                adjust:{ [weak self] step in
                    guard let self else { return }; let values: [CGFloat]=[0.5,0.75,1]
                    let i=((values.firstIndex(of:self.app.view.renderScale) ?? 2)+step+3)%3
                    self.app.view.renderScale=values[i]; UserDefaults.standard.set(Double(values[i]),forKey:"renderScale"); self.updateResolutionText()
                }),
            .init(title:"Frame limit",patch:"",x:48,y:112,action:{},value:{ [weak self] in "\(self?.app.view.preferredFramesPerSecond ?? 120) FPS" },
                adjust:{ [weak self] step in
                    guard let self else { return }; let values=[35,60,120]
                    let i=((values.firstIndex(of:self.app.view.preferredFramesPerSecond) ?? 2)+step+3)%3
                    self.app.view.preferredFramesPerSecond=values[i]; UserDefaults.standard.set(values[i],forKey:"frameLimit")
                }),
            .init(title:"Back",patch:"",x:48,y:136,action:{ [weak self] in self?.options() })
        ],selected:selected,labels:[],back:{ [weak self] in self?.options() })
        updateResolutionText()
    }
    func refreshDisplay() {
        if page=="Display" { displayOptions(selected:classic?.selected ?? 0) }
        else { classic?.needsDisplay=true }
    }
    func updateResolutionText() {
        guard page=="Display" else { return }
        let size=app.view.drawableSize
        classic?.labels=[("RENDER: \(Int(size.width))X\(Int(size.height)) PIXELS",32,162),
                         ("WINDOW SIZES IN MACOS POINTS",32,174),("LEFT/RIGHT ADJUST   ESC BACK",32,188)]
        classic?.needsDisplay=true
    }
    private func slots(saving: Bool) {
        guard let wad=app.wad else { return }
        var items: [ClassicMenuCanvas.Item]=[]
        for i in 0..<6 {
            do {
                let url=try SaveStore.slotURL(wad:wad,slot:i)
                let exists=FileManager.default.fileExists(atPath:url.path)
                let save=try? SaveStore.read(from:url,wad:wad)
                let name=save.map { $0.title ?? wad.mapTitle($0.map) } ?? (exists ? "UNREADABLE SAVE" : "EMPTY SLOT")
                items.append(.init(title:name,patch:"",x:80,y:CGFloat(54+i*16),enabled:saving || save != nil,action:{ [weak self] in
                    guard let self else { return }
                    if saving {
                        self.classic?.edit(index:i,text:save?.title ?? "") { [weak self] title in
                            guard let self else { return }
                            do { try self.app.renderer.saveGame(to:url,title:title); self.app.closeGameMenu() }
                            catch { self.app.show(error) }
                        }
                    } else {
                        do { try self.app.renderer.loadGame(from:url); self.app.closeGameMenu() }
                        catch { self.app.show(error) }
                    }
                },slot:true))
            } catch {
                items.append(.init(title:"UNAVAILABLE SLOT",patch:"",x:80,y:CGFloat(54+i*16),enabled:false,action:{},slot:true))
            }
        }
        canvas(saving ? "Save" : "Load",art:[(saving ? "M_SAVEG" : "M_LOADG",72,28)],items:items,
               labels:[("ENTER SELECT   ESC BACK",48,168)],back:{ [weak self] in self?.main() })
    }
}
