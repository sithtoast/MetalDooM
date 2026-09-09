// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
@main struct ClassicMenuValidation {
    static func main() {
        let menu=ClassicMenuCanvas(frame:NSRect(x:0,y:0,width:640,height:480))
        var chosen=0, backed=false
        var sounds: [String]=[]; menu.onSound={sounds.append($0)}
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
        precondition(sounds.contains("DSPSTOP") && sounds.contains("DSPISTOL") && sounds.contains("DSSWTCHX"))
        var value=0
        menu.items=[.init(title:"Volume",patch:"",x:80,y:64,action:{},adjust:{value += $0},meter:{0.5})]
        menu.selected=0; menu.configure(); menu.layout()
        _ = menu.handle(key(124)); _ = menu.handle(key(123)); precondition(value==0 && sounds.last=="DSSTNMOV")
        precondition(menu.subviews[0].frame.height==76.8)
        var saved=""
        menu.edit(index:0,text:"") { saved=$0 }
        let text=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,characters:"test slot",charactersIgnoringModifiers:"test slot",isARepeat:false,keyCode:0)!
        _ = menu.handle(text); _ = menu.handle(key(51)); _ = menu.handle(key(36))
        precondition(saved=="TEST SLO" && menu.editing==nil)
        menu.edit(index:0,text:"CANCEL") { saved=$0 }; _ = menu.handle(key(53))
        precondition(saved=="TEST SLO" && menu.editing==nil)
        print("PASS: menu sound cues, adjustable rows, bitmap name entry/commit/cancel, and slider hit targets")
        print("PASS: classic menu wraps/skips disabled rows, activates once per press, goes back, and scales hit targets with artwork")
    }
}
