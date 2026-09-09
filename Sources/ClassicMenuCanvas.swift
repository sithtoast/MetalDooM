// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

private final class MenuHitButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {} // Canvas draws the original patch.
}

// Original 320x200 menu coordinates, corrected to 4:3 with unfiltered pixels.
final class ClassicMenuCanvas: NSView {
    struct Item {
        let title, patch: String
        let x, y: CGFloat
        var enabled = true
        let action: () -> Void
    }
    var artwork: [(String,CGFloat,CGFloat)] = []
    var items: [Item] = []
    var selected = 0 { didSet { needsDisplay=true } }
    var onBack: (() -> Void)?
    var image: (String) -> NSImage? = { _ in nil }
    private var buttons: [NSButton] = []
    private var tracking: NSTrackingArea?
    private var timer: Timer?
    private var skull = 0
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); timer?.invalidate(); timer=nil
        if window != nil {
            timer=Timer.scheduledTimer(withTimeInterval:8.0/35.0,repeats:true) { [weak self] _ in
                guard let self else { return }; self.skull ^= 1; self.needsDisplay=true
            }
        }
    }
    deinit { timer?.invalidate() }
    func configure() {
        for button in buttons { button.removeFromSuperview() }; buttons=[]
        for (index,item) in items.enumerated() {
            let button=MenuHitButton(title:item.title,target:self,action:#selector(activate(_:)))
            button.tag=index; button.isEnabled=item.enabled; button.isBordered=false
            button.setAccessibilityLabel(item.title); addSubview(button); buttons.append(button)
        }
        if !items.isEmpty && !items[selected].enabled { selected=items.firstIndex(where:{$0.enabled}) ?? 0 }
        needsLayout=true; needsDisplay=true
    }
    override func layout() {
        super.layout()
        for (index,item) in items.enumerated() {
            buttons[index].frame=NSRect(x:item.x*bounds.width/320,y:item.y*bounds.height/200,
                width:(320-item.x)*bounds.width/320,height:16*bounds.height/200)
        }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking=NSTrackingArea(rect:.zero,options:[.mouseMoved,.activeInKeyWindow,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(tracking!)
    }
    override func mouseMoved(with event: NSEvent) {
        let point=convert(event.locationInWindow,from:nil)
        if let index=buttons.firstIndex(where:{$0.isEnabled && $0.frame.contains(point)}) { selected=index }
    }
    @objc private func activate(_ sender: NSButton) { selected=sender.tag; items[selected].action() }
    func handle(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command,.control,.option]).isEmpty else { return false }
        if event.keyCode == 53 { if !event.isARepeat { onBack?() }; return true }
        guard !items.isEmpty else { return false }
        if event.keyCode == 125 || event.keyCode == 126 || event.keyCode == 48 {
            let direction = event.keyCode == 126 || (event.keyCode == 48 && event.modifierFlags.contains(.shift)) ? -1 : 1
            for _ in items.indices {
                selected=(selected+direction+items.count)%items.count
                if items[selected].enabled { break }
            }
            window?.makeFirstResponder(self); return true
        }
        if event.keyCode == 36 || event.keyCode == 49 {
            if !event.isARepeat && items[selected].enabled { items[selected].action() }; return true
        }
        if let letter=event.charactersIgnoringModifiers?.lowercased(), letter.count==1,
           let index=items.indices.first(where:{items[$0].enabled && items[$0].title.lowercased().hasPrefix(letter)}) {
            selected=index; return true
        }
        return false
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.imageInterpolation = .none
        func patch(_ name: String,_ x: CGFloat,_ y: CGFloat,_ alpha: CGFloat = 1) {
            guard let image=image(name) else { return }
            image.draw(in:NSRect(x:x*bounds.width/320,y:y*bounds.height/200,
                width:image.size.width*bounds.width/320,height:image.size.height*bounds.height/200),
                from:.zero,operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:nil)
        }
        for (name,x,y) in artwork { patch(name,x,y) }
        for item in items { patch(item.patch,item.x,item.y,item.enabled ? 1 : 0.35) }
        if items.indices.contains(selected), items[selected].enabled {
            patch("M_SKULL\(skull+1)",items[selected].x-32,items[selected].y-5)
        }
    }
}
