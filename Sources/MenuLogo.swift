import Foundation

/// Builds a transparent menu header from the loaded IWAD, without bundling game art.
enum MenuLogo {
    static func ultimate(art: Art) throws -> PixelImage? {
        guard art.wad.maps.contains("E4M1"), let title=try art.patch(named:"TITLEPIC")?.image,
              let doom=try art.patch(named:"M_DOOM")?.image,
              title.width==320, title.height==200, doom.width==123, doom.height==60 else { return nil }
        // Gold caption above the title's blue Doom letters. The title's lower logo
        // is occluded by Doomguy, so use the transparent M_DOOM for that portion.
        let width=156, height=34
        var caption=[UInt8](repeating:0,count:width*height*4)
        var gold=0
        for y in 0..<height { for x in 0..<width {
            let sx=x+79, sy=y+11
            guard (sy<=23 && sx>=137 && sx<=176) || (sy>=24 && sy<=42) else { continue }
            let source=(sy*title.width+sx)*4
            let r=title.rgba[source],g=title.rgba[source+1],b=title.rgba[source+2]
            guard r>=g, g>b, r>=47 else { continue }
            let target=(y*width+x)*4
            caption[target..<target+4]=title.rgba[source..<source+4];gold += 1
        } }
        // A replacement TITLEPIC may use a completely different composition.
        guard gold>=500 else { return nil }
        var outlined=caption
        for y in 0..<height { for x in 0..<width where caption[(y*width+x)*4+3]==0 {
            if (-1...1).contains(where: { dy in (-1...1).contains { dx in
                let nx=x+dx,ny=y+dy
                return nx>=0 && nx<width && ny>=0 && ny<height && caption[(ny*width+nx)*4+3]>0
            } }) { outlined[(y*width+x)*4+3]=255 }
        } }
        let captionHeight=27, resultHeight=captionHeight+doom.height
        var result=[UInt8](repeating:0,count:doom.width*resultHeight*4)
        for y in 0..<captionHeight { for x in 0..<doom.width {
            let source=((y*height/captionHeight)*width+x*width/doom.width)*4
            let target=(y*doom.width+x)*4
            result[target..<target+4]=outlined[source..<source+4]
        } }
        let offset=captionHeight*doom.width*4
        result[offset..<result.count]=doom.rgba[...]
        return PixelImage(width:doom.width,height:resultHeight,rgba:result)
    }
}
