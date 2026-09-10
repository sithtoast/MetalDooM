import AppKit

final class AttractScreen: NSView {
    private let picture: NSImage
    var activate: (() -> Void)?
    init(wad: WAD, lump: String) throws {
        guard let patch=try Art(wad:wad).patch(named:lump) else { throw PortError("Missing title artwork: \(lump)") }
        let pixels=patch.image
        guard let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels.width,pixelsHigh:pixels.height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:pixels.width*4,bitsPerPixel:32), let data=rep.bitmapData else { throw PortError("Cannot decode title artwork.") }
        pixels.rgba.withUnsafeBytes { data.update(from:$0.baseAddress!.assumingMemoryBound(to:UInt8.self),count:pixels.rgba.count) }
        picture=NSImage(size:NSSize(width:pixels.width,height:pixels.height));picture.addRepresentation(rep)
        super.init(frame:.zero);setAccessibilityLabel("\(wad.displayName) title screen. Press a key for the menu.")
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) unavailable") }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.black.setFill();bounds.fill();NSGraphicsContext.current?.imageInterpolation = .none
        let w=min(bounds.width,bounds.height*4/3),h=w*3/4
        picture.draw(in:NSRect(x:(bounds.width-w)/2,y:(bounds.height-h)/2,width:w,height:h))
    }
    override func mouseDown(with event:NSEvent) { activate?() }
}

extension App {
    func beginAttract() {
        guard !shuttingDown, wad != nil else { return }
        closeAutomap()
        gameMenu?.removeFromSuperview();gameMenu=nil
        if consoleVisible { toggleConsole() }
        MD_StopDemo();attractActive=true;attractDemo=false;attractIndex=0;cheatBuffer=""
        showAttractPage("TITLEPIC")
        if attractTimer==nil {
            attractTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.advanceAttract() }
        }
    }
    func endAttract() {
        attractTimer?.invalidate(); attractTimer=nil
        attractActive=false;attractDemo=false;MD_StopDemo();titleScreen?.removeFromSuperview();titleScreen=nil
        titleMusic?.update(active:false);titleMusic=nil;view.inputBlocked=consoleVisible
    }
    func showAttractPage(_ name:String) {
        guard let wad else { return }
        titleScreen?.removeFromSuperview();titleScreen=nil;attractDemo=false;MD_StopDemo()
        renderer.paused=true;view.releaseMouse();view.inputBlocked=true;attractElapsed=0
        do {
            let page=try AttractScreen(wad:wad,lump:wad.lump(name) != nil ? name:"TITLEPIC")
            page.activate={ [weak self] in self?.openGameMenu() };page.translatesAutoresizingMaskIntoConstraints=false
            window.contentView!.addSubview(page);titleScreen=page
            NSLayoutConstraint.activate([page.topAnchor.constraint(equalTo:view.topAnchor),page.bottomAnchor.constraint(equalTo:view.bottomAnchor),page.leadingAnchor.constraint(equalTo:view.leadingAnchor),page.trailingAnchor.constraint(equalTo:view.trailingAnchor)])
            if titleMusic==nil { titleMusic=try MusicPlayer(wad:wad,map:wad.maps[0]);try titleMusic?.select(wad.maps.contains("MAP01") ? "D_DM2TTL":"D_INTRO") }
        } catch { console?.append("Title: \(error)");endAttract();openGameMenu() }
    }
    func advanceAttract() {
        guard !shuttingDown, attractActive else { return }
        let active=NSApp.isActive && window.isKeyWindow && window.attachedSheet==nil && gameMenu==nil && !consoleVisible
        titleMusic?.enabled=renderer.musicEnabled;titleMusic?.volume=renderer.musicVolume
        titleMusic?.update(active:active && !attractDemo)
        guard active else { return }
        if attractDemo {
            if MD_DemoPlaying()==0 { attractIndex += 1;showAttractPage(attractIndex%2==0 ? "TITLEPIC":"CREDIT") }
        } else {
            attractElapsed += 0.1
            guard attractElapsed>=11 else { return }
            let count=wad?.lump("DEMO4") != nil ? 4:3
            let demo="DEMO\(attractIndex%count+1)"
            do { try playDemo(demo) }
            catch { console?.append("\(demo): \(error)");attractIndex += 1;attractElapsed=0 }
        }
    }
    func playDemo(_ name:String) throws {
        guard let wad, let bytes=wad.lump(name), bytes.count>=14 else { throw PortError("Missing or truncated demo: \(name)") }
        let episode=Int(bytes.data[2]),number=Int(bytes.data[3])
        let map=wad.maps.contains("MAP01") ? String(format:"MAP%02d",number):"E\(episode)M\(number)"
        guard wad.maps.contains(map) else { throw PortError("Demo map is absent.") }
        let selectedSkill=renderer.skill
        let result=try renderer.load(wad:wad,map:map,demo:name)
        renderer.skill=selectedSkill
        describe(map,result);maps.selectItem(withTitle:map)
        titleScreen?.removeFromSuperview();titleScreen=nil;titleMusic?.update(active:false)
        summary += " · DEMO PLAYBACK — press a key for menu"
        attractActive=true;attractDemo=true;view.releaseMouse();view.inputBlocked=true
        renderer.paused=gameMenu != nil || consoleVisible
    }
    func dismissGameMenu() {
        if attractActive {
            gameMenu?.removeFromSuperview();gameMenu=nil;renderer.paused = !attractDemo || consoleVisible
            window.makeFirstResponder(view)
        } else { closeGameMenu() }
    }
    @objc func returnToTitle() { beginAttract() }
    static let typedCheats=["iddqd","idkfa","idfa","idclip","idspispopd","idchoppers","idbeholdv","idbeholds","idbeholdi","idbeholdr","idbeholda","idbeholdl"]
    func typeCheat(_ characters:String) -> Bool {
        guard characters.count==1,characters.first!.isASCII else { cheatBuffer="";return false }
        cheatBuffer += characters.lowercased()
        if Self.typedCheats.contains(cheatBuffer) {
            let result=runCheat(cheatBuffer);cheatBuffer="";console?.append(result);return true
        }
        if cheatBuffer.hasPrefix("idclev"),cheatBuffer.count==8 {
            let code=String(cheatBuffer.suffix(2));cheatBuffer=""
            if renderer.skill==4 { return true }
            let map=wad?.maps.contains("MAP01")==true ? "MAP\(code)":"E\(code.prefix(1))M\(code.suffix(1))"
            _=executeConsole("map \(map)");return true
        }
        if Self.typedCheats.contains(where:{$0.hasPrefix(cheatBuffer)}) || "idclev".hasPrefix(cheatBuffer) || (cheatBuffer.hasPrefix("idclev") && cheatBuffer.count<8 && cheatBuffer.dropFirst(6).allSatisfy(\.isNumber)) { return true }
        cheatBuffer=characters.lowercased()=="i" ? "i":"";return !cheatBuffer.isEmpty
    }
    func runCheat(_ name:String) -> String {
        guard !attractActive else { return "Cheats are disabled during title/demo playback." }
        guard MD_Cheat(name) != 0 else { return "Cheat unavailable: requires a living player outside Nightmare difficulty." }
        var hud=MD_GetHUD()
        return withUnsafePointer(to:&hud.message) { $0.withMemoryRebound(to:CChar.self,capacity:128) { String(cString:$0) } }
    }
}
