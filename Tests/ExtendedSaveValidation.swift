import Foundation
@main struct SaveValidation {
    static func main() {do {try run()} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}}
    static func run() throws {
        let payload=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
        let engine=Data(repeating:0x31,count:32),save=try ExtendedSave(payload:payload,engine:engine)
        let restored=try ExtendedSave(data:save.data,engine:engine,identity:save.identity)
        guard restored.payload==payload,restored.map==save.map,restored.tic==save.tic else {throw PortError("Envelope round trip mismatch")}
        for mode in 0..<8 {
            var data=save.data,id=save.identity,hash=engine
            switch mode {
            case 0:data[0]=0
            case 1:data[4]=2
            case 2:data[8] ^= 1
            case 3:data[12]=1
            case 4:data.removeLast()
            case 5:data[data.count-1] ^= 1
            case 6:id=String(repeating:"0",count:64)
            default:hash[0] ^= 1
            }
            var rejected=false;do {_=try ExtendedSave(data:data,engine:hash,identity:id)}catch{rejected=true}
            guard rejected else {throw PortError("Accepted malformed Rust envelope \(mode)")}
        }
        let file=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mdrust")
        defer{try? FileManager.default.removeItem(at:file)}
        try save.write(to:file)
        guard try ExtendedSave.read(file,engine:engine,identity:save.identity).payload==payload else {throw PortError("File roundtrip mismatch")}
        try save.write(to:file)
        guard try Data(contentsOf:file)==save.data else {throw PortError("Atomic replacement mismatch")}
        print("PASS Rust save envelope, engine/resource fingerprints, checksum, eight rejection cases, file round trip and atomic replacement")
    }
}
