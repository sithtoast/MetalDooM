// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

// MUS event translation follows the pinned Chocolate Doom mus2mid.c. State is
// local to each conversion; malformed input cannot leak velocity or timing.
enum MUS {
    static func midi(_ data: Data) throws -> Data {
        if data.starts(with:Array("MThd".utf8)) { return data }
        let bytes = Bytes(data:data)
        guard data.starts(with:[77,85,83,26]), data.count >= 16 else { throw PortError("Invalid MUS music header.") }
        let length = try bytes.u16(4), start = try bytes.u16(6), instruments = try bytes.u16(12)
        guard start >= 16+instruments*2, length > 0, start <= data.count-length else { throw PortError("Truncated MUS score.") }
        let end = start+length
        var cursor = start, pending = 0, track = Data(), channels: [Int:Int] = [:]
        var velocities = [UInt8](repeating:127,count:16)
        let controllers: [UInt8] = [0,32,1,7,10,11,91,93,64,67,120,123,126,127,121]
        func byte() throws -> UInt8 {
            guard cursor < end else { throw PortError("Truncated MUS event.") }
            defer { cursor += 1 }; return data[cursor]
        }
        func variable(_ value: Int) -> [UInt8] {
            var value=value, result=[UInt8(value & 127)]; value >>= 7
            while value > 0 { result.insert(UInt8(value & 127)|128,at:0); value >>= 7 }
            return result
        }
        func emit(_ event: [UInt8]) { track.append(contentsOf:variable(pending)); pending=0; track.append(contentsOf:event) }
        while cursor < end {
            let descriptor = try byte(), type = (descriptor >> 4)&7, source = Int(descriptor&15)
            if type == 6 {
                emit([255,47,0])
                var result=Data([77,84,104,100,0,0,0,6,0,0,0,1,0,70,77,84,114,107])
                let size=UInt32(track.count)
                result.append(contentsOf:[UInt8(size>>24),UInt8((size>>16)&255),UInt8((size>>8)&255),UInt8(size&255)])
                result.append(track); return result
            }
            let channel: Int
            if source == 15 { channel=9 }
            else if let mapped=channels[source] { channel=mapped }
            else {
                let next=channels.count; channel=next >= 9 ? next+1 : next
                channels[source]=channel
                emit([0xB0|UInt8(channel),123,0])
            }
            let c=UInt8(channel)
            switch type {
            case 0: emit([0x80|c,try byte() & 127,0])
            case 1:
                let key=try byte()
                if key&128 != 0 { velocities[channel]=try byte() & 127 }
                emit([0x90|c,key&127,velocities[channel]])
            case 2:
                let pitch=Int(try byte())*64
                emit([0xE0|c,UInt8(pitch&127),UInt8((pitch>>7)&127)])
            case 3:
                let control=Int(try byte())
                guard (10...14).contains(control) else { throw PortError("Invalid MUS system event.") }
                emit([0xB0|c,controllers[control],0])
            case 4:
                let control=Int(try byte()), value=try byte()
                guard control <= 9 else { throw PortError("Invalid MUS controller.") }
                if control == 0 { emit([0xC0|c,value&127]) }
                else { emit([0xB0|c,controllers[control],min(127,value)]) }
            default: throw PortError("Unsupported MUS event.")
            }
            if descriptor&128 != 0 {
                var delay=0, finished=false
                for _ in 0..<4 {
                    let part=try byte(); delay=delay*128+Int(part&127)
                    if part&128 == 0 { finished=true; break }
                }
                guard finished, pending <= 0x0fffffff-delay else { throw PortError("Invalid MUS delay.") }
                pending += delay
            }
        }
        throw PortError("MUS score has no end event.")
    }
}
