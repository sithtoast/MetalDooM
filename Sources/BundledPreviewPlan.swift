import Foundation

/// Explicit single-player resource roles; siblings are not campaign dependencies.
/// The ordinary picker keeps its existing acceptance rules.
struct BundledPreviewPlan {
    enum Content:String,CaseIterable {case rust,doom2,resources,weapons,textures,music}
    let content:Content,paths:[URL],base:Int,profile:Int,mapLimit:Int,track:String?
    var rustWeapons:Bool {content == .rust || content == .weapons}
    var title:String {
        switch content {
        case .rust:return "Rust world preview"
        case .doom2:return "Doom II bundled preview"
        case .resources:return "Rust resources on Doom II"
        case .weapons:return "Rust weapons on Doom II"
        case .textures:return "Rust textures on Doom II"
        case .music:return "Rust music on Doom II"
        }
    }
    init(root:URL,content:Content,extras:Bool=false,track:String?=nil)throws {
        if let track {
            guard content == .music,track.hasPrefix("D_"),(3...8).contains(track.utf8.count),
                  track.utf8.allSatisfy({(65...90).contains($0)||(48...57).contains($0)||$0==95}) else {throw PortError("Use a D_ music lump name with --content music.")}
        }
        self.content=content;self.track=content == .music ? (track ?? "D_IBEGIN"):nil
        mapLimit=content == .rust ? 16:32
        profile=content == .rust ? 1:content == .resources || content == .weapons ? 2:0
        var names=extras ? ["extras.wad"]:[]
        names += ["id24res.wad","doom2.wad"];base=names.count-1
        switch content {
        case .rust:names += ["id1.wad"]
        case .resources:names += ["id1-res.wad"]
        case .weapons:names += ["id1-res.wad","id1-weap.wad"]
        case .textures:names += ["id1-tex.wad"]
        case .music:names += ["id1-mus.wad"]
        case .doom2:break
        }
        paths=names.map{root.appendingPathComponent($0)}
    }
    static func arguments(_ args:[String])throws->(Self,Int) {
        let legacy=args.contains("--rust-preview")
        guard !(legacy && args.contains("--bundled-preview")),
              let flag=args.firstIndex(of:legacy ? "--rust-preview":"--bundled-preview"),flag+1<args.count,
              !args[flag+1].hasPrefix("--") else {throw PortError("Supply the rerelease directory after --bundled-preview or --rust-preview.")}
        func option(_ key:String)throws->String? {
            let indices=args.indices.filter{args[$0]==key}
            guard indices.count<=1 else {throw PortError("Repeated option: \(key)")}
            guard let i=indices.first else {return nil}
            guard i+1<args.count,!args[i+1].hasPrefix("--") else {throw PortError("Missing value for \(key)")}
            return args[i+1]
        }
        let raw=try option("--content") ?? "rust"
        guard let content=Content(rawValue:raw),!legacy || content == .rust else {throw PortError("Choose --content rust, doom2, resources, weapons, textures or music with --bundled-preview.")}
        let plan=try Self(root:URL(fileURLWithPath:args[flag+1],isDirectory:true),content:content,extras:args.contains("--extras"),track:option("--track"))
        let value=try option("--map") ?? "MAP01"
        let digits=value.uppercased().hasPrefix("MAP") ? String(value.dropFirst(3)):value
        guard let map=Int(digits),(1...plan.mapLimit).contains(map) else {throw PortError("Choose MAP01–MAP\(plan.mapLimit).")}
        return (plan,map)
    }
}
