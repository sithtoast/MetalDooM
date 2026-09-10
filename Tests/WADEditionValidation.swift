import Foundation
@main struct WADEditionValidation {
 static func main() throws {
    let root=URL(fileURLWithPath:CommandLine.arguments[1]), original=URL(fileURLWithPath:CommandLine.arguments[2])
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:dir) }
    for name in ["doom.wad","doom2.wad","tnt.wad","plutonia.wad"] {
        let wad=try WAD(url:root.appendingPathComponent(name));precondition(wad.isKEXEdition)
        let renamed=dir.appendingPathComponent("renamed.wad");try wad.sourceData[0].write(to:renamed)
        let copy=try WAD(url:renamed);precondition(copy.isKEXEdition)
        precondition(wad.displayName == wad.gameName+" (KEX Edition)")
        // Corrupt metadata while keeping every resource and campaign marker.
        var bytes=wad.sourceData[0]
        let metadata=wad.lump("GAMECONF")!.data
        let start=bytes.range(of:metadata)!.lowerBound
        bytes[start]=0x21;try bytes.write(to:renamed)
        let invalid=try WAD(url:renamed)
        precondition(!invalid.isKEXEdition && invalid.gameName == wad.gameName)
    }
    let classic=try WAD(url:original);precondition(!classic.isKEXEdition && classic.displayName==classic.gameName)
    let sigil=root.appendingPathComponent("sigil.wad")
    let modernStack=try WAD(url:root.appendingPathComponent("doom.wad"),addOns:[sigil])
    let classicStack=try WAD(url:original,addOns:[sigil])
    precondition(modernStack.isKEXEdition && !classicStack.isKEXEdition)
    let extra=try WAD(url:sigil);precondition(!extra.isKEXEdition)
    print("PASS: four KEX IWADs, renamed copies, malformed metadata, original IWAD and base-only stack identity")
 }
}
