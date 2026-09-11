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
        var value: (() -> String)? = nil
        var adjust: ((Int) -> Void)? = nil
        var meter: (() -> Float)? = nil
        var slot = false
        var textScale: CGFloat = 1
        var help: String? = nil
    }
    struct Editing { let index: Int; var text: String; let commit: (String) -> Void }
    var editing: Editing?
    var labels: [(String,CGFloat,CGFloat)] = []
    var footer: String?
    var onSound: (String) -> Void = { _ in }
    var artwork: [(String,CGFloat,CGFloat)] = []
    var items: [Item] = []
    var selected = 0 { didSet { needsDisplay=true; onSelectionChanged?(selected) } }
    var onSelectionChanged: ((Int) -> Void)?
    var onRefresh: (() -> Void)?
    var onBack: (() -> Void)?
    var patchOrigin: (String) -> CGPoint = { _ in .zero }
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
                guard let self else { return }; self.skull ^= 1; self.onRefresh?(); self.needsDisplay=true
            }
        }
    }
    deinit { timer?.invalidate() }
    func configure() {
        for button in buttons { button.removeFromSuperview() }; buttons=[]
        for (index,item) in items.enumerated() {
            let button=MenuHitButton(title:item.title,target:self,action:#selector(activate(_:)))
            button.setAccessibilityHelp(item.help)
            button.tag=index; button.isEnabled=item.enabled; button.isBordered=false
            button.setAccessibilityLabel(item.slot ? "Slot \(index+1): \(item.title)" : item.title); addSubview(button); buttons.append(button)
        }
        if !items.isEmpty && !items[selected].enabled { selected=items.firstIndex(where:{$0.enabled}) ?? 0 }
        needsLayout=true; needsDisplay=true
    }
    override func layout() {
        super.layout()
        for (index,item) in items.enumerated() {
            buttons[index].frame=NSRect(x:item.x*bounds.width/320,y:item.y*bounds.height/200,
                width:(320-item.x)*bounds.width/320,height:(item.meter == nil ? 16 : 32)*bounds.height/200)
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
        if editing == nil, let index=buttons.firstIndex(where:{$0.isEnabled && $0.frame.contains(point)}), index != selected { selected=index; onSound("DSPSTOP") }
    }
    @objc private func activate(_ sender: NSButton) {
        guard editing == nil else { return }; selected=sender.tag
        if let meter=items[selected].meter, let adjust=items[selected].adjust, let event=NSApp.currentEvent, event.type == .leftMouseUp {
            let x=convert(event.locationInWindow,from:nil).x*320/bounds.width
            let desired=max(0,min(1,(x-items[selected].x-8)/120))
            adjust(Int(((Float(desired)-meter())*15).rounded())); onSound("DSSTNMOV"); needsDisplay=true
        } else { activateSelected() }
    }
    private func activateSelected() {
        if let adjust=items[selected].adjust { adjust(1); onSound("DSSTNMOV"); needsDisplay=true }
        else { onSound("DSPISTOL"); items[selected].action() }
    }
    func edit(index: Int, text: String, commit: @escaping (String) -> Void) {
        var initial=String(text.uppercased().prefix(24))
        while textWidth(initial)>184 { initial.removeLast() }
        selected=index; editing=Editing(index:index,text:initial,commit:commit)
        window?.makeFirstResponder(self); needsDisplay=true
    }
    private func textWidth(_ text: String) -> CGFloat {
        text.uppercased().unicodeScalars.reduce(0) { total,char in
            total + (image(String(format:"STCFN%03d",char.value))?.size.width ?? 4)
        }
    }
    func handle(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection([.command,.control,.option]).isEmpty else { return false }
        if var edit=editing {
            if event.keyCode == 53 { editing=nil; onSound("DSSWTCHX") }
            else if event.keyCode == 36 {
                if !event.isARepeat && !edit.text.trimmingCharacters(in:.whitespaces).isEmpty {
                    editing=nil; onSound("DSPISTOL"); edit.commit(edit.text)
                }
            } else if event.keyCode == 51 { if !edit.text.isEmpty { edit.text.removeLast() }; editing=edit }
            else if let input=event.characters?.uppercased() {
                for char in input.unicodeScalars where (32...95).contains(char.value) {
                    let candidate=edit.text+String(char)
                    if candidate.count<=24 && textWidth(candidate)<=184 { edit.text=candidate }
                }
                editing=edit
            }
            needsDisplay=true; return true
        }
        if event.keyCode == 53 { if !event.isARepeat { onSound("DSSWTCHX"); onBack?() }; return true }
        guard !items.isEmpty else { return false }
        if event.keyCode == 125 || event.keyCode == 126 || event.keyCode == 48 {
            let direction = event.keyCode == 126 || (event.keyCode == 48 && event.modifierFlags.contains(.shift)) ? -1 : 1
            for _ in items.indices {
                selected=(selected+direction+items.count)%items.count
                if items[selected].enabled { break }
            }
            onSound("DSPSTOP"); window?.makeFirstResponder(self); return true
        }
        if event.keyCode == 123 || event.keyCode == 124 {
            if items[selected].enabled, let adjust=items[selected].adjust {
                adjust(event.keyCode == 123 ? -1 : 1); onSound("DSSTNMOV"); needsDisplay=true
            }
            return true
        }
        if event.keyCode == 36 || event.keyCode == 49 {
            if !event.isARepeat && items[selected].enabled { activateSelected() }; return true
        }
        if let letter=event.charactersIgnoringModifiers?.lowercased(), letter.count==1,
           let index=items.indices.first(where:{items[$0].enabled && items[$0].title.lowercased().hasPrefix(letter)}) {
            selected=index; onSound("DSPSTOP"); return true
        }
        return false
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current?.imageInterpolation = .none
        func patch(_ name: String,_ x: CGFloat,_ y: CGFloat,_ alpha: CGFloat = 1,_ size: CGFloat = 1) {
            guard let image=image(name) else { return }
            let origin=patchOrigin(name)
            image.draw(in:NSRect(x:(x-origin.x*size)*bounds.width/320,y:(y-origin.y*size)*bounds.height/200,
                width:image.size.width*size*bounds.width/320,height:image.size.height*size*bounds.height/200),
                from:.zero,operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:nil)
        }
        func text(_ value: String,_ x: CGFloat,_ y: CGFloat,_ alpha: CGFloat = 1,_ maxWidth: CGFloat = 270,_ size: CGFloat = 1) {
            var cursor=x
            for char in value.uppercased().unicodeScalars {
                let name=String(format:"STCFN%03d",char.value), width=(image(name)?.size.width ?? 4)*size
                if cursor+width>x+maxWidth { break }
                patch(name,cursor,y,alpha,size); cursor += width
            }
        }
        for (name,x,y) in artwork { patch(name,x,y) }
        let currentLabels=editing == nil ? labels : [("TYPE NAME - ENTER SAVES",CGFloat(48),CGFloat(168)),("ESC CANCELS - SLOT IS REPLACED",32,182)]
        for (value,x,y) in currentLabels { text(value,x,y) }
        for (index,item) in items.enumerated() {
            let alpha: CGFloat=item.enabled ? 1 : 0.35
            if item.slot {
                patch("M_LSLEFT",item.x-8,item.y+7)
                for segment in 0..<24 { patch("M_LSCNTR",item.x+CGFloat(segment*8),item.y+7) }
                patch("M_LSRGHT",item.x+192,item.y+7)
            }
            if item.patch.isEmpty {
                let value=editing?.index==index ? editing!.text+(skull==0 ? "_" : "") : item.title
                text(value,item.x,item.y,alpha,item.slot ? 192 : 260,item.textScale)
            } else { patch(item.patch,item.x,item.y,alpha) }
            if let value=item.value { text(value(),190,item.y,alpha,116) }
            if let meter=item.meter {
                let x=item.x, y=item.y+16
                patch("M_THERML",x,y)
                for segment in 0..<16 { patch("M_THERMM",x+8+CGFloat(segment*8),y) }
                patch("M_THERMR",x+136,y)
                patch("M_THERMO",x+8+CGFloat(max(0,min(1,meter())))*120,y)
            }
        }
        if let footer {
            let string=NSAttributedString(string:footer,attributes:[.font:NSFont.monospacedSystemFont(ofSize:5.5*bounds.width/320,weight:.regular),.foregroundColor:NSColor.lightGray])
            let size=string.size()
            string.draw(at:NSPoint(x:(bounds.width-size.width)/2,y:bounds.height-size.height-3*bounds.height/200))
        }
        if items.indices.contains(selected), items[selected].enabled {
            patch("M_SKULL\(skull+1)",items[selected].x-32,items[selected].y-5)
        }
    }
}
