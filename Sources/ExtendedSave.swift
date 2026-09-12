import Foundation
import CryptoKit

/// Private extended saves cannot be passed to the classic save loader. The
/// engine fingerprint pins serialization semantics; content identity pins WAD
/// bytes, order and roles while allowing those same files to move on disk.
struct ExtendedSave {
    static let limit=64*1024*1024
    let payload:Data,identity:String,map:Int,skill:Int,tic:Int
    private let engine:Data
    init(payload:Data,engine:Data) throws {
        guard engine.count==32,!payload.isEmpty,payload.count<=Self.limit,
              let root=try JSONSerialization.jsonObject(with:payload) as? [String:Any],
              let version=root["native_version"] as? Int,version==1,
              let identity=root["identity"] as? String,identity.count==64,identity.utf8.allSatisfy({(48...57).contains($0)||(97...102).contains($0)}),
              let map=root["map"] as? Int,(1...16).contains(map),let skill=root["skill"] as? Int,(1...5).contains(skill),
              let tic=root["tic"] as? Int,(0..<Int(Int32.max)).contains(tic) else {throw PortError("Invalid Rust save metadata")}
        self.payload=payload;self.identity=identity;self.map=map;self.skill=skill;self.tic=tic;self.engine=engine
    }
    init(data:Data,engine:Data,identity:String) throws {
        guard data.count>=80,data.count<=80+Self.limit,data.prefix(4)==Data("MRS1".utf8) else {throw PortError("This is not a Rust preview save")}
        let bytes=Bytes(data:data)
        guard try bytes.i32(4)==1,try bytes.i32(8)==data.count-80,try bytes.i32(12)==0 else {throw PortError("Unsupported or truncated Rust save")}
        guard data[16..<48]==engine else {throw PortError("This save requires the same Rust engine build")}
        let body=Data(data.dropFirst(80))
        guard Data(SHA256.hash(data:body))==data[48..<80] else {throw PortError("Rust save checksum failed")}
        try self.init(payload:body,engine:engine)
        guard self.identity==identity else {throw PortError("This save uses different WAD resources or load order")}
    }
    var data:Data {
        var result=Data("MRS1".utf8)
        for value in [1,UInt32(payload.count),0] as [UInt32] {for byte in 0..<4 {result.append(UInt8(truncatingIfNeeded:value>>(8*byte)))}}
        result.append(engine);result.append(Data(SHA256.hash(data:payload)));result.append(payload)
        return result
    }
    static func engineIdentity(executable:URL) throws -> Data {
        let library=executable.deletingLastPathComponent().appendingPathComponent("libMetalDooMExtended.dylib")
        return Data(SHA256.hash(data:try Data(contentsOf:library)))
    }
    static func read(_ url:URL,engine:Data,identity:String) throws -> Self {
        let file=try FileHandle(forReadingFrom:url);defer{try? file.close()}
        guard try file.seekToEnd()<=UInt64(limit+80) else {throw PortError("Rust save exceeds size limit")}
        try file.seek(toOffset:0)
        let data=try file.read(upToCount:limit+81) ?? Data()
        return try Self(data:data,engine:engine,identity:identity)
    }
    func write(to url:URL) throws {try data.write(to:url,options:.atomic)}
}
