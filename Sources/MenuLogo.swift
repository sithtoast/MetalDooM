import Foundation

/// Builds a transparent menu header from the loaded IWAD, without bundling game art.
enum MenuLogo {
    static func ultimate(art: Art) throws -> PixelImage? {
        guard art.wad.sourceURLs.count==1, art.wad.maps.contains("E4M1"), let title=try art.patch(named:"TITLEPIC")?.image,
              let doom=try art.patch(named:"M_DOOM")?.image,
              title.width==320, title.height==200, doom.width==123, doom.height==60 else { return nil }
        // Gold caption above the title's blue Doom letters. The title's lower logo
        // is occluded by Doomguy, so use the transparent M_DOOM for that portion.
        // Caption silhouettes exclude gold from the large title logo behind the
        // word, particularly its counters and the gaps between adjacent letters.
        let letters: [[(Int,Int)]] = [
            [(82,24),(90,24),(90,35),(94,37),(96,35),(96,24),(102,24),(102,37),(99,43),(85,43),(82,37)],
            [(103,24),(110,24),(110,36),(119,36),(119,43),(103,43)],
            [(117,24),(137,24),(137,30),(131,30),(131,43),(123,43),(123,30),(117,30)],
            [(138,24),(146,24),(146,43),(138,43)],
            [(147,24),(154,24),(158,30),(162,24),(169,24),(169,43),(162,43),(162,34),(159,38),(156,38),(154,34),(154,43),(147,43)],
            [(178,24),(185,24),(194,43),(186,43),(184,37),(176,37),(174,43),(167,43)],
            [(190,24),(213,24),(213,30),(205,30),(205,43),(197,43),(197,30),(190,30)],
            [(214,24),(231,24),(231,30),(221,30),(221,31),(226,31),(226,36),(218,36),(218,37),(231,37),(231,43),(207,43)]
        ]
        func inside(_ x:Int,_ y:Int,_ polygon:[(Int,Int)]) -> Bool {
            let px=Double(x)+0.5,py=Double(y)+0.5
            var result=false,j=polygon.count-1
            for i in polygon.indices {
                let a=polygon[i],b=polygon[j]
                if (Double(a.1)>py) != (Double(b.1)>py), px < Double(b.0-a.0)*(py-Double(a.1))/Double(b.1-a.1)+Double(a.0) { result.toggle() }
                j=i
            }
            return result
        }
        let width=156, height=34
        var caption=[UInt8](repeating:0,count:width*height*4)
        var gold=0
        for y in 0..<height { for x in 0..<width {
            let sx=x+79, sy=y+11
            guard (sy<=23 && sx>=137 && sx<=176) || (sy>=24 && sy<=42) else { continue }
            if sy>=24 {
                guard letters.contains(where:{inside(sx,sy,$0)}), !inside(sx,sy,[(180,29),(177,35),(183,35)]) else { continue }
            }
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
