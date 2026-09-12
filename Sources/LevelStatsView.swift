// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

// IWAD font pixels, recolored for the live counters. This overlay never captures input.
final class LevelStatsView: NSView {
    private var glyphs: [String:NSImage] = [:]
    private var origins: [UInt32:CGPoint] = [:]
    private var loadedURLs: [URL] = []
    private var art: Art?
    private var presentationKey = ""
    static func scale(for width: CGFloat) -> CGFloat { max(1,min(2,floor(width/360)*0.75)) }
    private var hud = MD_HUD()
    private var showStats=false, showPar=false, secret=false
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    func update(wad: WAD?, hud: MD_HUD?, stats: Bool, par: Bool, secret: Bool) {
        if loadedURLs != (wad?.sourceURLs ?? []) {
            loadedURLs=wad?.sourceURLs ?? []; art=wad.flatMap { try? Art(wad:$0) }; glyphs.removeAll(); origins.removeAll(); presentationKey=""
        }
        let h=hud ?? MD_HUD()
        let key="\(hud != nil):\(stats):\(par):\(secret):\(stats ? h.levelTics/35 : 0):\(h.parSeconds):\(h.kills)/\(h.totalKills):\(h.items)/\(h.totalItems):\(h.secrets)/\(h.totalSecrets)"
        guard key != presentationKey else { return }; presentationKey=key
        self.hud=hud ?? MD_HUD(); showStats=stats && hud != nil; showPar=par; self.secret=secret && hud != nil
        isHidden = !showStats && !self.secret
        setAccessibilityLabel(showStats ? "Time \(LevelStatsText.time(self.hud.levelTics)), kills \(self.hud.kills) of \(self.hud.totalKills), items \(self.hud.items) of \(self.hud.totalItems), secrets \(self.hud.secrets) of \(self.hud.totalSecrets)" : "Secret found")
        needsDisplay = !isHidden
    }
    private func glyph(_ code: UInt32, color: Int) -> NSImage? {
        let key="\(code):\(color)"
        if let image=glyphs[key] { return image }
        guard let art, let patch=try? art.patch(named:String(format:"STCFN%03d",code)) else { return nil }
        origins[code]=CGPoint(x:patch.left,y:patch.top)
        let pixels=patch.image
        guard let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels.width,pixelsHigh:pixels.height,
                bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,
                bytesPerRow:pixels.width*4,bitsPerPixel:32), let data=rep.bitmapData else { return nil }
        let colors: [(Double,Double,Double)] = [(1,1,1),(0.35,1,0.35),(0.55,0.5,1),(1,0.15,0.1),(1,0.85,0.2),(0,0,0)]
        let tint=colors[color]
        for i in stride(from:0,to:pixels.rgba.count,by:4) {
            let light=Double(max(pixels.rgba[i],pixels.rgba[i+1],pixels.rgba[i+2]))
            data[i]=UInt8(light*tint.0); data[i+1]=UInt8(light*tint.1); data[i+2]=UInt8(light*tint.2); data[i+3]=pixels.rgba[i+3]
        }
        let image=NSImage(size:NSSize(width:pixels.width,height:pixels.height)); image.addRepresentation(rep)
        glyphs[key]=image; return image
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.imageInterpolation = .none
        let scale=Self.scale(for:bounds.width)
        func width(_ text: String) -> CGFloat {
            text.unicodeScalars.reduce(0) { $0+(glyph($1.value,color:0)?.size.width ?? 4)*scale }
        }
        @discardableResult func text(_ value: String, x: CGFloat, y: CGFloat, color: Int) -> CGFloat {
            var cursor=x
            for char in value.unicodeScalars {
                if let image=glyph(char.value,color:color) {
                    let origin=origins[char.value] ?? .zero
                    let rect=NSRect(x:cursor-origin.x*scale,y:y-origin.y*scale,width:image.size.width*scale,height:image.size.height*scale)
                    glyph(char.value,color:5)?.draw(in:rect.offsetBy(dx:scale,dy:scale),from:.zero,operation:.sourceOver,fraction:0.9,respectFlipped:true,hints:nil)
                    image.draw(in:rect,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
                    cursor += image.size.width*scale
                } else { cursor += 4*scale }
            }
            return cursor
        }
        let margin: CGFloat=12
        if showStats {
            var x=text("TIME ",x:margin,y:margin,color:0)
            x=text(LevelStatsText.time(hud.levelTics),x:x,y:margin,color:1)
            if showPar {
                x=text("  PAR ",x:x,y:margin,color:0)
                text(LevelStatsText.par(hud.parSeconds),x:x,y:margin,color:hud.parSeconds >= 0 && hud.levelTics/35 >= hud.parSeconds ? 4 : 1)
            }
            x=margin
            for (label,current,total) in [("K",hud.kills,hud.totalKills),("I",hud.items,hud.totalItems),("S",hud.secrets,hud.totalSecrets)] {
                x=text(label+" ",x:x,y:margin+12*scale,color:3)
                x=text("\(current)/\(total) ",x:x,y:margin+12*scale,color:total>0 && current>=total ? 1 : 2)
            }
        }
        if secret {
            let value="SECRET FOUND!"
            text(value,x:max(margin,(bounds.width-width(value))/2),y:margin+(showStats ? 27*scale : 0),color:4)
        }
    }
}

extension App {
    func applyMinimalHUDPortrait(_ visible:Bool) {
        guard benchmark == nil else { return }
        renderer.setMinimalHUDPortrait(visible)
        UserDefaults.standard.set(visible,forKey:"minimalHUDPortrait")
        gameMenu?.refreshHUD()
    }
    @objc func toggleMinimalHUDPortrait() { applyMinimalHUDPortrait(!renderer.minimalHUDPortrait) }
    func applyHUDStyle(_ style:HUDStyle) {
        guard benchmark == nil else { return }
        renderer.setHUDStyle(style)
        UserDefaults.standard.set(style.rawValue,forKey:"hudStyle")
        gameMenu?.refreshHUD()
    }
    @objc func selectHUDStyle(_ sender:NSMenuItem) {
        guard let style=HUDStyle(rawValue:sender.tag) else { return }
        applyHUDStyle(style)
    }
    func applyHUDSize(_ percent:Int) {
        guard benchmark == nil else { return }
        renderer.setHUDSize(percent)
        UserDefaults.standard.set(renderer.hudSizePercent,forKey:"hudStatusBarSize")
        gameMenu?.refreshHUD()
    }
    @objc func selectHUDSize(_ sender:NSMenuItem) { applyHUDSize(sender.tag) }

    @objc func toggleLevelStats() { levelStatsVisible.toggle(); UserDefaults.standard.set(levelStatsVisible,forKey:"showLevelStats"); updateLevelStats() }
    @objc func toggleParTime() { parTimeVisible.toggle(); UserDefaults.standard.set(parTimeVisible,forKey:"showParTime"); updateLevelStats() }
    @objc func toggleSecretNotifications() { secretNotifications.toggle(); UserDefaults.standard.set(secretNotifications,forKey:"secretNotifications"); updateLevelStats() }
    func updateLevelStats() {
        let hud = attractActive ? nil : renderer.levelHUD
        levelStatsView?.update(wad:wad,hud:hud,stats:levelStatsVisible,par:parTimeVisible,secret:secretNotifications && renderer.secretFound)
        levelStatsMenuItem?.state=levelStatsVisible ? .on : .off
        parTimeMenuItem?.state=parTimeVisible ? .on : .off
        secretMenuItem?.state=secretNotifications ? .on : .off
        // Pickup messages stay below the counters and dedicated secret notification.
        messageTop?.constant=levelStatsVisible && hud != nil ? 12+40*LevelStatsView.scale(for:view.bounds.width) : (secretNotifications && renderer.secretFound ? 44 : 16)
    }
}
