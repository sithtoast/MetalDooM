// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import MetalKit

@main struct InputValidation {
    static func main() {
        let view = GameView(frame:.zero,device:nil)
        func event(_ type: NSEvent.EventType, _ code: UInt16, _ repeatKey: Bool = false) -> NSEvent {
            NSEvent.keyEvent(with:type,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,
                             characters:"",charactersIgnoringModifiers:"",isARepeat:repeatKey,keyCode:code)!
        }
        // Both events arrive before a simulation tic; the tap must survive once.
        view.keyDown(with:event(.keyDown,1)); view.keyUp(with:event(.keyUp,1))
        precondition(view.consumeMovement().contains(1))
        precondition(!view.consumeMovement().contains(1))
        view.keyDown(with:event(.keyDown,13))
        precondition(view.consumeMovement().contains(13))
        precondition(view.consumeMovement().contains(13))
        view.keyUp(with:event(.keyUp,13)); precondition(!view.consumeMovement().contains(13))
        view.keyDown(with:event(.keyDown,14)); view.keyUp(with:event(.keyUp,14)); precondition(view.useQueued)
        view.keyDown(with:event(.keyDown,0)); view.releaseMouse()
        precondition(view.consumeMovement().isEmpty && !view.useQueued)
        print("PASS: native brief taps survive one tic, holds persist, use queues, and focus release clears input")
    }
}
