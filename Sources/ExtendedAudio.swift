import Foundation

struct ExtendedSoundEvent {
    let tic:Int, channel:Int, operation:Int, name:String, volume:Float, pan:Float
}
struct ExtendedAudio {
    let tic:Int, events:[ExtendedSoundEvent]
    init(data:Data) throws {
        let b=Bytes(data:data);try b.check(0,16)
        tic=try b.i32(8);let count=try b.i32(12)
        guard data.prefix(4)==Data("MSA1".utf8),try b.i32(4)==1,tic>=0,
              (0...4096).contains(count),data.count==16+count*28 else { throw PortError("Invalid audio snapshot header/count.") }
        var result:[ExtendedSoundEvent]=[],previous=0
        for i in 0..<count {
            let p=16+i*28,tick=try b.i32(p),channel=try b.i32(p+4),op=try b.i32(p+8),volume=try b.i32(p+20),pan=try b.i32(p+24)
            let raw=data[(p+12)..<(p+20)],text=raw.prefix{$0 != 0}
            guard tick>=previous,tick<=tic,(0..<32).contains(channel),(0...2).contains(op),
                  (0...127).contains(volume),(-128...128).contains(pan),
                  text.allSatisfy({(33...126).contains($0)}),raw.dropFirst(text.count).allSatisfy({$0==0}),
                  op==1 ? !text.isEmpty:text.isEmpty,op != 0 || (volume==0 && pan==0) else { throw PortError("Invalid sound event.") }
            result.append(ExtendedSoundEvent(tic:tick,channel:channel,operation:op,name:String(decoding:text,as:UTF8.self),volume:Float(volume)/127,pan:Float(pan)/128));previous=tick
        }
        events=result
    }
}
