import Foundation

/// The worker selects metadata after G_DoCompleted. The frontend never reparses
/// UMAPINFO or asks either simulation to run a presentation ticker.
struct ExtendedCampaign:Decodable {
    let version:Int,map:Int,tic:Int,nextMap:Int,parTics:Int
    let name:String,levelPic:String,nextName:String,nextPic:String,exitAnim:String,enterAnim:String
    let story:String,storyMusic:String,storyFlat:String,endPic:String,endFinale:String
    let visited:[Int],sounds:[String:String],labels:[String:String]
    init(data:Data,ui:ExtendedUI) throws {
        guard data.count<=1024*1024 else {throw PortError("Campaign metadata is too large")}
        self=try JSONDecoder().decode(Self.self,from:data)
        guard version==1,map==ui.map,tic==ui.tic,nextMap==ui.nextMap,ui.phase>=2,(0...Int(Int32.max)).contains(parTics),
              visited.count<=32,visited.allSatisfy({(1...32).contains($0)}),Set(visited).count==visited.count,
              story.utf8.count<=65536,name.count<=256,nextName.count<=256,labels.count<=64,
              labels.values.allSatisfy({$0.count<=256}),sounds.count<4096 else {throw PortError("Invalid campaign metadata")}
        for value in [levelPic,nextPic,exitAnim,enterAnim,storyMusic,storyFlat,endPic,endFinale]+Array(sounds.values) {try Self.lumpName(value,optional:true)}
        guard sounds.keys.allSatisfy({Int($0).map{(1..<4096).contains($0)} ?? false}) else {throw PortError("Invalid campaign sound ID")}
    }
    static func lumpName(_ value:String,optional:Bool=false) throws {
        guard (optional || !value.isEmpty),value.utf8.count<=8,value.utf8.allSatisfy({(33...126).contains($0) && !($0>=97 && $0<=122)}) else {throw PortError("Invalid campaign lump name: \(value)")}
    }
}
private struct CampaignDocument<T:Decodable>:Decodable {let type:String,version:String,data:T}
private func campaignData(_ name:String,_ wad:WAD) throws -> Data {
    try ExtendedCampaign.lumpName(name)
    guard let bytes=wad.lump(name),bytes.count<=1024*1024 else {throw PortError("Missing or oversized campaign definition: \(name)")}
    return bytes.data
}
private func campaignDocument<T:Decodable>(_ type:String,_ data:Data) throws -> T {
    guard data.count<=1024*1024 else {throw PortError("Oversized campaign definition")}
    let document=try JSONDecoder().decode(CampaignDocument<T>.self,from:data)
    guard document.type==type,document.version=="1.0.0" else {throw PortError("Unsupported campaign schema: \(type)")}
    return document.data
}
struct ExtendedInterlevel:Decodable {
    struct Condition:Decodable {
        let condition:Int,param:Int
        func matches(map:Int,entering:Bool,visited:Set<Int>)->Bool {
            switch condition {
            case 0:return true
            case 1:return map>param
            case 2:return map==param
            case 3:return visited.contains(param)
            case 6:return !entering
            case 7:return entering
            default:return false
            }
        }
        func validate() throws {
            guard [0,1,2,3,6,7].contains(condition),(0...32).contains(param) else {throw PortError("Unsupported interlevel condition")}
        }
    }
    struct Frame:Decodable {let image:String,type:Int,duration:Double,maxduration:Double
        var tics:Int {max(1,Int(duration*35))}
    }
    struct Animation:Decodable {
        let x:Int,y:Int,conditions:[Condition],frames:[Frame]
        func frame(tic:Int)->String {
            var remaining=tic % max(1,frames.reduce(0){$0+$1.tics})
            for frame in frames {
                if frame.type==1 || remaining<frame.tics {return frame.image}
                remaining-=frame.tics
            }
            return frames[0].image
        }
    }
    struct Layer:Decodable {let conditions:[Condition],anims:[Animation]}
    let music:String,backgroundimage:String,layers:[Layer]
    init(name:String,wad:WAD) throws {
        try self.init(data:campaignData(name,wad))
    }
    init(data:Data) throws {
        self=try campaignDocument("interlevel",data)
        try ExtendedCampaign.lumpName(music);try ExtendedCampaign.lumpName(backgroundimage)
        guard layers.count<=32,layers.reduce(0,{$0+$1.anims.count})<=1024 else {throw PortError("Too many interlevel animations")}
        for layer in layers {
            guard layer.conditions.count<=32 else {throw PortError("Too many interlevel conditions")}
            try layer.conditions.forEach{try $0.validate()}
            for anim in layer.anims {
                guard (-4096...4096).contains(anim.x),(-4096...4096).contains(anim.y),anim.conditions.count<=32,(1...256).contains(anim.frames.count) else {throw PortError("Invalid interlevel animation")}
                try anim.conditions.forEach{try $0.validate()}
                guard anim.frames.count==1 || !anim.frames.contains(where:{$0.type==1}) else {throw PortError("Mixed infinite interlevel frames are unsupported")}
                for frame in anim.frames {
                    try ExtendedCampaign.lumpName(frame.image)
                    guard [1,2].contains(frame.type),frame.duration.isFinite,(0...3600).contains(frame.duration),frame.maxduration==0,
                          frame.type==1 || frame.duration>0 else {throw PortError("Unsupported interlevel frame")}
                }
            }
        }
    }
    func animations(map:Int,entering:Bool,visited:Set<Int>)->[Animation] {
        layers.filter{$0.conditions.allSatisfy{$0.matches(map:map,entering:entering,visited:visited)}}.flatMap(\.anims).filter{$0.conditions.allSatisfy{$0.matches(map:map,entering:entering,visited:visited)}}
    }
}
struct ExtendedFinale:Decodable {
    struct Frame:Decodable {let lump:String,flipped:Bool,duration:Double,sound:Int
        let tranmap:String?,translation:String?
        var tics:Int {max(1,Int(duration*35))}
    }
    struct Actor:Decodable {let name:String,alertsound:Int,aliveframes:[Frame],deathframes:[Frame]}
    struct Cast:Decodable {let castanims:[Actor]}
    let type:Int,music:String,musicloops:Bool,background:String,donextmap:Bool,castrollcall:Cast
    init(name:String,wad:WAD,metadata:ExtendedCampaign) throws {
        try self.init(data:campaignData(name,wad),metadata:metadata)
    }
    init(data:Data,metadata:ExtendedCampaign) throws {
        self=try campaignDocument("finale",data)
        guard type==2,!donextmap,(1...64).contains(castrollcall.castanims.count) else {throw PortError("Unsupported custom finale")}
        try ExtendedCampaign.lumpName(music);try ExtendedCampaign.lumpName(background)
        for actor in castrollcall.castanims {
            guard metadata.labels[actor.name] != nil,(1...4096).contains(actor.aliveframes.count),(1...4096).contains(actor.deathframes.count) else {throw PortError("Unsupported cast member")}
            for sound in [actor.alertsound]+(actor.aliveframes+actor.deathframes).map(\.sound) {
                guard sound==0 || metadata.sounds[String(sound)] != nil else {throw PortError("Missing patched cast sound: \(sound)")}
            }
            for frame in actor.aliveframes+actor.deathframes {
                try ExtendedCampaign.lumpName(frame.lump)
                guard frame.duration.isFinite,(0...3600).contains(frame.duration),frame.tranmap?.isEmpty != false,frame.translation?.isEmpty != false else {throw PortError("Unsupported cast frame")}
            }
        }
    }
}

final class ExtendedCampaignSequence {
    enum Stage {case statistics,entering,story,art,cast,complete}
    let metadata:ExtendedCampaign,ui:ExtendedUI,exit:ExtendedInterlevel,entry:ExtendedInterlevel?,finale:ExtendedFinale?
    private(set) var stage=Stage.statistics,tic=0,castIndex=0,frameIndex=0,dead=false
    private(set) var statistics:IntermissionSequence
    private var frameTicks=0
    private(set) var sounds:[String]=[]
    var music:(String,Bool) {
        switch stage {
        case .entering:return (entry!.music,true)
        case .story,.art:return (metadata.storyMusic.isEmpty ? "D_READ_M":metadata.storyMusic,true)
        case .cast:return (finale!.music,finale!.musicloops)
        default:return (exit.music,true)
        }
    }
    var actor:ExtendedFinale.Actor {finale!.castrollcall.castanims[castIndex]}
    var castFrame:ExtendedFinale.Frame {(dead ? actor.deathframes:actor.aliveframes)[frameIndex]}
    var visibleCharacters:Int {min(metadata.story.count,max(0,(tic-10)/3))}
    init(metadata:ExtendedCampaign,ui:ExtendedUI,wad:WAD) throws {
        self.metadata=metadata;self.ui=ui
        exit=try ExtendedInterlevel(name:metadata.exitAnim,wad:wad)
        entry=ui.phase==2 ? try ExtendedInterlevel(name:metadata.enterAnim,wad:wad):nil
        finale=ui.phase==3 && !metadata.endFinale.isEmpty ? try ExtendedFinale(name:metadata.endFinale,wad:wad,metadata:metadata):nil
        if ui.phase==3 && finale==nil {try ExtendedCampaign.lumpName(metadata.endPic)}
        var stats=MD_Progress();stats.kills=Int32(ui.kills);stats.maxKills=Int32(ui.totalKills)
        stats.items=Int32(ui.items);stats.maxItems=Int32(ui.totalItems);stats.secrets=Int32(ui.secrets);stats.maxSecrets=Int32(ui.totalSecrets)
        stats.seconds=Int32(ui.levelTics/35);stats.parSeconds=Int32(metadata.parTics/35)
        statistics=IntermissionSequence(stats)
    }
    func drainSounds()->[String] {defer{sounds=[]};return sounds}
    private func sound(_ id:Int) {if id != 0,let name=metadata.sounds[String(id)] {sounds.append(name)}}
    private func statsSounds(_ values:[Int32]) {for value in values {sound(value==0 ? 1:value==1 ? 82:3)}}
    func press() {
        switch stage {
        case .statistics:
            if statistics.stage != 10 {statsSounds(statistics.update(seconds:0,pressed:true))}
            else {sound(3);if !metadata.story.isEmpty {stage = .story} else {afterStory()};tic=0}
        case .entering:stage = .complete
        case .story:
            if visibleCharacters<metadata.story.count {tic=metadata.story.count*3+10}
            else {afterStory();tic=0}
        case .cast:
            if !dead {dead=true;frameIndex=0;frameTicks=castFrame.tics;sound(castFrame.sound)}
        case .art,.complete:break
        }
    }
    private func afterStory() {
        if ui.phase==2 {stage = .entering}
        else if finale != nil {stage = .cast;startActor()}
        else {stage = .art}
    }
    private func startActor() {
        dead=false;frameIndex=0;frameTicks=castFrame.tics;sound(actor.alertsound);sound(castFrame.sound)
    }
    func tick() {
        tic+=1
        switch stage {
        case .statistics:statsSounds(statistics.update(seconds:1.0/35,pressed:false))
        case .entering:if tic>=140 {stage = .complete}
        case .cast:
            frameTicks-=1
            if frameTicks<=0 {
                frameIndex+=1
                if frameIndex==(dead ? actor.deathframes.count:actor.aliveframes.count) {
                    if dead {castIndex=(castIndex+1)%finale!.castrollcall.castanims.count;startActor();return}
                    frameIndex=0
                }
                frameTicks=castFrame.tics;sound(castFrame.sound)
            }
        default:break
        }
    }
}
