import Foundation

/// Complete nonidentity animation mapping for one tic. Missing keys map to self.
struct ExtendedMaterials {
    struct Sky {
        let background:SkyTransfer, foreground:SkyTransfer?
        let tint:Int,width:Int,height:Int,pixels:[UInt8]
    }
    let skies:[Int:Sky]
    let tic:Int, translations:[MaterialKey:MaterialKey]
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,16)
        let count=try b.i32(12);tic=try b.i32(8)
        let version=try b.i32(4)
        guard (version==1 || version==2),data.prefix(4)==Data("MMT\(version)".utf8),tic>=0,
              (0...65536).contains(count),data.count>=16+count*20 else { throw PortError("Invalid material snapshot header/count.") }
        func name(_ offset:Int) throws -> String {
            let raw=data[offset..<offset+8],text=raw.prefix{$0 != 0}
            guard !text.isEmpty,text.allSatisfy({(33...126).contains($0)}),raw.dropFirst(text.count).allSatisfy({$0==0}) else { throw PortError("Invalid material resource name.") }
            return String(decoding:text,as:UTF8.self)
        }
        var values:[MaterialKey:MaterialKey]=[:]
        for i in 0..<count {
            let offset=16+i*20,kind=try b.i32(offset+16)
            guard kind==0 || kind==1 else { throw PortError("Invalid material namespace.") }
            let source=try MaterialKey(name:name(offset),flat:kind==1),target=try MaterialKey(name:name(offset+8),flat:kind==1)
            guard values[source]==nil,source != target else { throw PortError("Duplicate or identity material mapping.") }
            values[source]=target
        }
        translations=values
        var cursor=16+count*20,bank:[Int:Sky]=[:]
        if version==2 {
            try b.check(cursor,4);let n=try b.i32(cursor);cursor+=4
            guard (0...4096).contains(n) else {throw PortError("Invalid sky count")}
            for id in 1..<(n+1) {
                try b.check(cursor,68);let kind=try b.i32(cursor)
                guard (0...2).contains(kind) else {throw PortError("Invalid sky type")}
                func layer(_ p:Int)throws->SkyTransfer {
                    let x=Float(try b.i32(p+16))/65536,y=Float(try b.i32(p+20))/65536
                    guard abs(x)>0,abs(x)<=256,y>0,y<=256,(0...255).contains(try b.i32(p+24)) else {throw PortError("Invalid sky scale")}
                    return try SkyTransfer(id:id,name:name(p),angle:UInt32(bitPattern:Int32(b.i32(p+8))),mid:Float(b.i32(p+12))/65536,scale:SIMD2(x,y))
                }
                let bg=try layer(cursor+4),fg=try kind==2 ? layer(cursor+32):nil
                if kind != 2 && !data[cursor+32..<cursor+60].allSatisfy({$0==0}) {throw PortError("Unexpected sky foreground")}
                let w=try b.i32(cursor+60),h=try b.i32(cursor+64);cursor+=68
                guard kind==1 ? (1...4096).contains(w) && (1...4096).contains(h):w==0 && h==0 else {throw PortError("Invalid fire sky size")}
                try b.check(cursor,w*h)
                bank[id]=try Sky(background:bg,foreground:fg,tint:b.i32(cursor-40),width:w,height:h,pixels:Array(data[cursor..<cursor+w*h]));cursor+=w*h
            }
        }
        guard cursor==data.count else {throw PortError("Trailing material snapshot bytes")}
        skies=bank
    }
}
