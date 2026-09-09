import AppKit

/// North-up automap over the world viewport. Gameplay continues behind it.
final class AutomapView: NSView {
    var title=""
    var close:(()->Void)?
    private var lines=[MD_MapLine]()
    private var center=NSPoint.zero, zoom:CGFloat=0.2, fit:CGFloat=0.2
    private var following=true, ready=false
    private var timer:Timer?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow();timer?.invalidate();timer=nil
        if window != nil { timer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true) { [weak self] _ in self?.needsDisplay=true } }
    }
    deinit { timer?.invalidate() }
    func handle(_ event:NSEvent) -> Bool {
        if !event.modifierFlags.intersection([.command,.control,.option]).isEmpty { return false }
        if event.keyCode==53 || event.keyCode==48 { if !event.isARepeat { close?() };return true }
        let text=event.charactersIgnoringModifiers?.lowercased() ?? ""
        if text=="f" { if !event.isARepeat { following.toggle() };return true }
        if text=="+" || text=="=" { zoom=min(fit*40,zoom*1.2);return true }
        if text=="-" { zoom=max(fit*0.25,zoom/1.2);return true }
        if text=="0" { ready=false;following=false;return true }
        if [123,124,125,126].contains(event.keyCode) {
            following=false;let step=40/max(zoom,0.001)
            if event.keyCode==123 { center.x-=step };if event.keyCode==124 { center.x+=step }
            if event.keyCode==125 { center.y-=step };if event.keyCode==126 { center.y+=step }
            return true
        }
        return false
    }
    override func scrollWheel(with event:NSEvent) { zoom=max(fit*0.25,min(fit*40,zoom*pow(1.05,event.scrollingDeltaY)));needsDisplay=true }
    override func mouseDown(with event:NSEvent) {} // never capture/fire through the map
    override func draw(_ dirtyRect:NSRect) {
        NSColor.black.setFill();bounds.fill()
        let count=Int(MD_CopyMapLines(nil,0));if lines.count != count { lines=Array(repeating:MD_MapLine(),count:count);ready=false }
        _=MD_CopyMapLines(&lines,Int32(lines.count))
        guard !lines.isEmpty else { return }
        let minX=CGFloat(lines.map { min($0.x1,$0.x2) }.min()!), maxX=CGFloat(lines.map { max($0.x1,$0.x2) }.max()!)
        let minY=CGFloat(lines.map { min($0.y1,$0.y2) }.min()!), maxY=CGFloat(lines.map { max($0.y1,$0.y2) }.max()!)
        fit=min(bounds.width/max(1,maxX-minX),(bounds.height-60)/max(1,maxY-minY))*0.9
        if !ready { zoom=fit;center=NSPoint(x:(minX+maxX)/2,y:(minY+maxY)/2);ready=true }
        let player=MD_GetPlayer(),hud=MD_GetHUD()
        if following { center=NSPoint(x:CGFloat(player.x),y:CGFloat(player.y)) }
        func point(_ x:CGFloat,_ y:CGFloat)->NSPoint { NSPoint(x:bounds.midX+(x-center.x)*zoom,y:bounds.midY+(y-center.y)*zoom) }
        for line in lines where line.kind>0 && (line.mapped != 0 || hud.allmap != 0) {
            let color:NSColor
            if line.mapped==0 { color = .darkGray }
            else { color = [NSColor.red,NSColor.brown,NSColor.yellow,NSColor.green][Int(line.kind)-1] }
            color.setStroke();let path=NSBezierPath();path.lineWidth=1.25
            path.move(to:point(CGFloat(line.x1),CGFloat(line.y1)));path.line(to:point(CGFloat(line.x2),CGFloat(line.y2)));path.stroke()
        }
        let p=point(CGFloat(player.x),CGFloat(player.y)),angle=CGFloat(player.angle)
        func arrowPoint(_ x:CGFloat,_ y:CGFloat)->NSPoint { NSPoint(x:p.x+x*cos(angle)-y*sin(angle),y:p.y+x*sin(angle)+y*cos(angle)) }
        NSColor.white.setStroke();let arrow=NSBezierPath();arrow.lineWidth=1.5
        for (a,b) in [(NSPoint(x:-9,y:0),NSPoint(x:12,y:0)),(NSPoint(x:12,y:0),NSPoint(x:3,y:7)),(NSPoint(x:12,y:0),NSPoint(x:3,y:-7))] { arrow.move(to:arrowPoint(a.x,a.y));arrow.line(to:arrowPoint(b.x,b.y)) };arrow.stroke()
        if !following { NSColor.gray.setStroke();let cross=NSBezierPath();cross.move(to:NSPoint(x:bounds.midX-3,y:bounds.midY));cross.line(to:NSPoint(x:bounds.midX+3,y:bounds.midY));cross.move(to:NSPoint(x:bounds.midX,y:bounds.midY-3));cross.line(to:NSPoint(x:bounds.midX,y:bounds.midY+3));cross.stroke() }
        let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:12,weight:.regular),.foregroundColor:NSColor.lightGray]
        let heading=NSAttributedString(string:title,attributes:attributes)
        heading.draw(at:NSPoint(x:max(12,bounds.width-heading.size().width-12),y:bounds.height-24))
        NSAttributedString(string:"TAB close   +/- zoom   arrows pan   F follow \(following ? "ON":"OFF")   0 fit",attributes:attributes).draw(at:NSPoint(x:12,y:10))
    }
}

extension App {
    func closeAutomap() { automapView?.removeFromSuperview();automapView=nil;view.releaseMouse() }
    func toggleAutomap() {
        if automapView != nil { closeAutomap();return }
        guard wad != nil,!attractActive,MD_GetProgress().phase==0 else { return }
        view.releaseMouse();let overlay=AutomapView();overlay.title=summary
        overlay.close={ [weak self] in self?.closeAutomap() };automapView=overlay
        overlay.setAccessibilityLabel("Automap. Tab closes, plus/minus zoom, arrows pan, F follows the player.")
        view.addSubview(overlay);layoutAutomap();window.makeFirstResponder(view)
    }
    func layoutAutomap() {
        guard let overlay=automapView else { return }
        if MD_GetProgress().phase != 0 { closeAutomap();return }
        let scale=max(0.01,view.drawableSize.height/max(1,view.bounds.height))
        let hud=SpriteRenderer.hudHeight(width:view.drawableSize.width)/scale
        overlay.frame=NSRect(x:0,y:hud,width:view.bounds.width,height:max(1,view.bounds.height-hud))
    }
}
