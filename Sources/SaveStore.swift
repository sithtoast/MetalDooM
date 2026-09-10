// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import CryptoKit

struct SavedGame: Codable {
    let format: String, version: Int, wadSHA256: String, map: String
    let title: String?
    let savedAt: Date, pitch: Float
    let payload: Data, payloadSHA256: String
}
enum SaveStore {
    static func digest(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    static func wadDigest(_ wad: WAD) throws -> String {
        if wad.sourceData.count==1 { return digest(wad.sourceData[0]) }
        // Fixed-length per-file digests preserve order and avoid concatenation ambiguity.
        return digest(Data(("MetalDooM WAD stack v1\n"+wad.sourceData.map(digest).joined(separator:"\n")).utf8))
    }
    static func quickURL(wad: WAD) throws -> URL {
        let base = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
        let folder = base.appendingPathComponent("MetalDooM/Saves",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        return folder.appendingPathComponent("\(try wadDigest(wad)).mdsave")
    }
    static func slotURL(wad: WAD, slot: Int) throws -> URL {
        guard (0..<6).contains(slot) else { throw PortError("Invalid save slot.") }
        let quick=try quickURL(wad:wad)
        let folder=quick.deletingPathExtension().appendingPathExtension("slots")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        return folder.appendingPathComponent("slot-\(slot+1).mdsave")
    }
    static func temporaryURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("MetalDooM-\(UUID().uuidString).payload") }
    static func write(to url: URL, wad: WAD, map: String, pitch: Float, title: String? = nil) throws {
        guard !wad.sourceURLs.contains(where:{$0.resolvingSymlinksInPath() == url.standardizedFileURL.resolvingSymlinksInPath()}) else { throw PortError("Choose a save file, not the WAD itself.") }
        let temporary = temporaryURL(); defer { try? FileManager.default.removeItem(at:temporary) }
        guard MD_WriteSave(temporary.path) != 0 else { throw PortError(String(cString:MD_LastError())) }
        let payload = try Data(contentsOf:temporary)
        let save = SavedGame(format:"MetalDooM Save",version:1,wadSHA256:try wadDigest(wad),map:map,title:title,savedAt:Date(),pitch:pitch,payload:payload,payloadSHA256:digest(payload))
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        // Replace the destination only after the entire archive and container succeed.
        try encoder.encode(save).write(to:url,options:.atomic)
    }
    static func read(from url: URL, wad: WAD) throws -> SavedGame {
        let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 32*1024*1024 else { throw PortError("Invalid or oversized save file.") }
        let save: SavedGame
        do { save = try PropertyListDecoder().decode(SavedGame.self,from:Data(contentsOf:url)) }
        catch { throw PortError("This is not a valid MetalDooM save file.") }
        guard save.format == "MetalDooM Save", save.version == 1 else { throw PortError("Unsupported MetalDooM save version.") }
        guard save.wadSHA256 == (try wadDigest(wad)) else { throw PortError("This save belongs to a different WAD stack. Open the same base, add-ons and load order first.") }
        guard save.payload.count >= 50, digest(save.payload) == save.payloadSHA256,
              save.pitch.isFinite, (-1.2...1.2).contains(save.pitch) else { throw PortError("This save is damaged; its integrity check failed.") }
        let episode = Int(save.payload[41]), number = Int(save.payload[42])
        let map = wad.maps.contains("MAP01") ? String(format:"MAP%02d",number) : "E\(episode)M\(number)"
        guard map == save.map, wad.maps.contains(map) else { throw PortError("This save references an invalid map.") }
        return save
    }
}
