import AppKit

/// Native, palette-correct WAD presentation. Images are decoded once; all patch
/// anchors use their original offsets in Doom's 320x200 logical coordinates.
final class ExtendedCampaignView:NSView {
    private struct Patch {let image:NSImage,width:Int,height:Int,left:Int,top:Int}
    let sequence:ExtendedCampaignSequence
    private var patches:[String:Patch]=[:]
    override var isFlipped:Bool {true}
    override var isOpaque:Bool {true}
    init(sequence:ExtendedCampaignSequence,wad:WAD) throws {
        self.sequence=sequence;super.init(frame:.zero)
        let art=try Art(wad:wad),m=sequence.metadata
        var names=Set(["WIF","WIENTER","WIOSTK","WIOSTI","WISCRT2","WITIME","WIPAR","WIPCNT","WICOLON"]+(0...9).map{"WINUM\($0)"})
        names.formUnion([m.levelPic,m.nextPic,m.endPic].filter{!$0.isEmpty})
        names.formUnion(wad.lumps.map(\.name).filter{$0.hasPrefix("STCFN")})
        for interlevel in [sequence.exit,sequence.entry].compactMap({$0}) {
            names.insert(interlevel.backgroundimage)
            names.formUnion(interlevel.layers.flatMap(\.anims).flatMap(\.frames).map(\.image))
        }
        if let finale=sequence.finale {names.insert(finale.background)}
        var decodedBytes=0
        func insert(_ key:String,_ image:PixelImage,_ left:Int=0,_ top:Int=0) throws {
            decodedBytes+=image.rgba.count
            guard decodedBytes<=256*1024*1024 else {throw PortError("Campaign artwork exceeds cache budget")}
            guard let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:image.width,pixelsHigh:image.height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:image.width*4,bitsPerPixel:32),let bytes=rep.bitmapData else {throw PortError("Cannot allocate campaign artwork")}
            image.rgba.withUnsafeBytes {bytes.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:image.rgba.count)}
            let native=NSImage(size:NSSize(width:image.width,height:image.height));native.addRepresentation(rep)
            patches[key]=Patch(image:native,width:image.width,height:image.height,left:left,top:top)
        }
        for name in names where name != "TNT1A0" {
            guard let patch=try art.patch(named:name) else {throw PortError("Missing campaign artwork: \(name)")}
            try insert(name,patch.image,patch.left,patch.top)
        }
        if !m.story.isEmpty {
            try ExtendedCampaign.lumpName(m.storyFlat)
            guard let flat=wad.flatLump(m.storyFlat),flat.count==4096 else {throw PortError("Missing campaign story flat")}
            try insert("story-flat",PixelImage(width:64,height:64,rgba:flat.data.flatMap{art.color($0)}))
        }
        if let finale=sequence.finale {
            for name in Set(finale.castrollcall.castanims.flatMap{$0.aliveframes+$0.deathframes}.map(\.lump)) where name != "TNT1A0" {
                guard let index=wad.spriteLumpIndex(name) else {throw PortError("Missing cast sprite: \(name)")}
                let patch=try art.patch(lump:index);try insert("cast-"+name,patch.image,patch.left,patch.top)
            }
        }
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) has not been implemented")}
    override func draw(_ dirtyRect:NSRect) {
        NSColor.black.setFill();bounds.fill()
        guard bounds.width>0,bounds.height>0 else {return}
        NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
        NSGraphicsContext.current?.imageInterpolation = .none
        let scale=min(bounds.width/320,bounds.height/240)
        let transform=AffineTransform(translationByX:(bounds.width-320*scale)/2,byY:(bounds.height-240*scale)/2)
        (transform as NSAffineTransform).concat()
        let sizing=NSAffineTransform();sizing.scaleX(by:scale,yBy:scale*1.2);sizing.concat()
        NSRect(x:0,y:0,width:320,height:200).clip()
        func draw(_ name:String,_ x:Double,_ y:Double,anchored:Bool=false,flip:Bool=false) {
            guard let patch=patches[name] else {return}
            let left=flip ? patch.width-patch.left:patch.left
            let rect=NSRect(x:x-Double(anchored ? left:0),y:y-Double(anchored ? patch.top:0),width:Double(patch.width),height:Double(patch.height))
            NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
            if flip {let t=NSAffineTransform();t.translateX(by:rect.minX+rect.maxX,yBy:0);t.scaleX(by:-1,yBy:1);t.concat()}
            patch.image.draw(in:rect,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.none.rawValue])
        }
        func center(_ name:String,_ y:Double) {draw(name,(320-Double(patches[name]?.width ?? 0))/2,y)}
        func text(_ value:String,_ startX:Double,_ startY:Double,centered:Bool=false) {
            let letters=Array(value.uppercased().unicodeScalars)
            let width=letters.reduce(0){$0+(patches[String(format:"STCFN%03d",$1.value)]?.width ?? 4)}
            var x=centered ? (320-Double(width))/2:startX,y=startY
            for c in letters {
                if c.value==10 {x=startX;y+=11;continue}
                let name=String(format:"STCFN%03d",c.value),w=Double(patches[name]?.width ?? 4)
                if x+w>320 {x=startX;y+=11}
                draw(name,x,y);x+=w
            }
        }
        func number(_ value:String,_ right:Double,_ y:Double) {
            var x=right
            for c in value.reversed() {let name=c==":" ? "WICOLON":"WINUM\(c)";x-=Double(patches[name]?.width ?? 0);draw(name,x,y)}
        }
        let m=sequence.metadata
        switch sequence.stage {
        case .statistics,.entering,.complete:
            let entering=sequence.stage != .statistics,definition=entering ? sequence.entry!:sequence.exit
            center(definition.backgroundimage,0)
            for anim in definition.animations(map:entering ? m.nextMap:m.map,entering:entering,visited:Set(m.visited)) {draw(anim.frame(tic:sequence.tic),Double(anim.x),Double(anim.y),anchored:true)}
            if entering {center("WIENTER",2);if !m.nextPic.isEmpty {center(m.nextPic,20)} else {text(m.nextName,0,20,centered:true)}}
            else {
                if !m.levelPic.isEmpty {center(m.levelPic,2)} else {text(m.name,0,2,centered:true)}
                center("WIF",20)
                for (index,label) in ["WIOSTK","WIOSTI","WISCRT2"].enumerated() {
                    let y=50+Double(index)*26;draw(label,50,y)
                    let value=sequence.statistics.values[index]
                    if value>=0 {draw("WIPCNT",270,y);number(String(value),270,y)}
                }
                for (index,label,x) in [(3,"WITIME",16.0),(4,"WIPAR",176.0)] {
                    draw(label,x,168);let value=sequence.statistics.values[index]
                    if value>=0 {number(String(format:"%d:%02d",value/60,value%60),x+128,184)}
                }
            }
        case .story:
            for y in stride(from:0,to:200,by:64) {for x in stride(from:0,to:320,by:64) {draw("story-flat",Double(x),Double(y))}}
            text(String(m.story.prefix(sequence.visibleCharacters)),10,10)
        case .art:center(m.endPic,0)
        case .cast:
            center(sequence.finale!.background,0)
            let frame=sequence.castFrame;draw("cast-"+frame.lump,160,170,anchored:true,flip:frame.flipped)
            text(m.labels[sequence.actor.name]!,0,180,centered:true)
        }
    }
}
