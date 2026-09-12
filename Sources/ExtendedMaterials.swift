import Foundation

/// Complete nonidentity animation mapping for one tic. Missing keys map to self.
struct ExtendedMaterials {
    let tic:Int, translations:[MaterialKey:MaterialKey]
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,16)
        let count=try b.i32(12);tic=try b.i32(8)
        guard data.prefix(4)==Data("MMT1".utf8),try b.i32(4)==1,tic>=0,
              (0...65536).contains(count),data.count==16+count*20 else { throw PortError("Invalid material snapshot header/count.") }
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
    }
}
