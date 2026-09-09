// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
@main struct ClassicMenuValidation {
    static func main() {
        let menu=ClassicMenuCanvas(frame:NSRect(x:0,y:0,width:640,height:480))
        var chosen=0, backed=false
        menu.items=[.init(title:"New Game",patch:"M_NGAME",x:97,y:64,action:{chosen=1}),
                    .init(title:"Save Game",patch:"M_SAVEG",x:97,y:80,enabled:false,action:{chosen=2}),
                    .init(title:"Options",patch:"M_OPTION",x:97,y:96,action:{chosen=3})]
        menu.onBack={backed=true}; menu.configure(); menu.layout()
        func key(_ code: UInt16,_ repeatKey: Bool=false) -> NSEvent {
            NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:repeatKey,keyCode:code)!
        }
        let quit=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:0,context:nil,characters:"q",charactersIgnoringModifiers:"q",isARepeat:false,keyCode:12)!
        precondition(!menu.handle(quit))
        precondition(menu.handle(key(125)) && menu.selected==2)
        precondition(menu.handle(key(36,true)) && chosen==0)
        precondition(menu.handle(key(36)) && chosen==3)
        precondition(menu.handle(key(125)) && menu.selected==0)
        precondition(menu.handle(key(126)) && menu.selected==2)
        precondition(menu.handle(key(53)) && backed)
        precondition(menu.subviews[0].frame.minX==194 && menu.subviews[0].frame.minY==153.6)
        print("PASS: classic menu wraps/skips disabled rows, activates once per press, goes back, and scales hit targets with artwork")
    }
}
