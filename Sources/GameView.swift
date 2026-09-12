// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import MetalKit

final class GameView: MTKView {
    var onBlockedClick: (() -> Void)?
    var inputBlocked = false
    var keys = Set<UInt16>()
    private var movementQueued = Set<UInt16>()
    var mouseMotion = SIMD2<Float>.zero
    var captured = false
    var running = false
    var useQueued = false
    var attackQueued = false, mouseFire = false
    var weaponQueued: Int32 = -1
    var continueQueued = false
    var onEscape: (() -> Void)?
    var renderScale: CGFloat = 1 { didSet {
        if !renderScale.isFinite || renderScale < 0.5 || renderScale > 2 { renderScale=1 }
        updateResolution()
    } }
    var metalFXEnabled = true
    var worldSize: CGSize {
        CGSize(width:max(1,(drawableSize.width*renderScale).rounded()),height:max(1,(drawableSize.height*renderScale).rounded()))
    }
    func updateResolution() {
        autoResizeDrawable=false
        let scale=(window?.backingScaleFactor ?? 2)
        drawableSize=CGSize(width:max(1,(bounds.width*scale).rounded()),height:max(1,(bounds.height*scale).rounded()))
    }
    override func layout() { super.layout(); updateResolution() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); updateResolution() }
    func consumeAttack() -> Int32 {
        let fire = attackQueued || mouseFire || keys.contains(3)
        attackQueued = false; return fire ? 1 : 0
    }
    func consumeWeapon() -> Int32 { let value = weaponQueued; weaponQueued = -1; return value }
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if inputBlocked || event.isARepeat || event.modifierFlags.contains(.command) { return }
        if event.keyCode == 36 { continueQueued = true }
        if event.keyCode == 3 { attackQueued = true } // F: keyboard fire
        let slots: [UInt16:Int32] = [18:0,19:1,20:2,21:3,23:4,22:5,26:6]
        if let slot = slots[event.keyCode] { weaponQueued = slot }
        if [0,1,2,13,123,124,125,126].contains(Int(event.keyCode)) { movementQueued.insert(event.keyCode) }
        if event.keyCode == 14 || event.keyCode == 49 { useQueued = true }
        if event.keyCode == 53 { releaseMouse(); onEscape?() } else { keys.insert(event.keyCode) }
    }
    override func keyUp(with event: NSEvent) { keys.remove(event.keyCode) }
    override func flagsChanged(with event: NSEvent) { running = event.modifierFlags.contains(.shift) }
    func consumeMovement() -> Set<UInt16> {
        let result = keys.union(movementQueued); movementQueued.removeAll(); return result
    }
    override func mouseDown(with event: NSEvent) {
        guard !inputBlocked else { onBlockedClick?();return }
        window?.makeFirstResponder(self)
        if !captured {
            captured = true
            CGAssociateMouseAndMouseCursorPosition(0)
            NSCursor.hide()
        } else { mouseFire = true; attackQueued = true }
    }
    override func mouseUp(with event: NSEvent) { mouseFire = false }
    override func mouseMoved(with event: NSEvent) {
        if captured { mouseMotion += SIMD2(Float(event.deltaX),Float(event.deltaY)) }
    }
    override func mouseDragged(with event: NSEvent) { mouseMoved(with:event) }
    func releaseMouse() {
        attackQueued = false; mouseFire = false; weaponQueued = -1; continueQueued = false
        keys.removeAll(); movementQueued.removeAll(); mouseMotion = .zero; running = false; useQueued = false
        if captured { captured = false; CGAssociateMouseAndMouseCursorPosition(1); NSCursor.unhide() }
    }
}

