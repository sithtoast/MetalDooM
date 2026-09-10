// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

@main struct SigilSpriteValidation {
    static func main() throws {
        let base=URL(fileURLWithPath:CommandLine.arguments[1])
        let wad=try WAD(url:base,addOns:[URL(fileURLWithPath:CommandLine.arguments[2])])
        let configured=wad.sourceURLs.map(\.path).joined(separator:"\n").withCString { paths in
            wad.engineOrder.withUnsafeBufferPointer { MD_ConfigureWADStack(paths,$0.baseAddress,Int32($0.count)) }
        }
        precondition(configured != 0 && MD_Load(base.path,5,2) != 0)
        for demo in ["DEMO1","DEMO2"] {
            precondition(MD_StartDemo(demo) != 0)
            var sawImp=false, sawCorpse=false
            for _ in 0..<420 {
                precondition(MD_Tick(0,0,0,0) != 0)
                let count=Int(MD_CopyThings(nil,0,0,0))
                var things=[MD_Thing](repeating:MD_Thing(),count:count)
                let copied=things.withUnsafeMutableBufferPointer { MD_CopyThings($0.baseAddress,Int32($0.count),0,0) }
                precondition(Int(copied)==count)
                for thing in things {
                    precondition(thing.doomedType != 14,"Invisible teleport destination leaked into sprite list")
                    if thing.doomedType == 3001 {
                        sawImp=true
                        if wad.lumps[Int(thing.lump)].name=="TROOM0" { sawCorpse=true }
                    }
                }
            }
            precondition(sawImp,"Real imps must remain visible")
            if demo=="DEMO1" { precondition(sawCorpse,"Dead imps must remain visible") }
            print("PASS: \(demo) opening hides teleport markers and retains real imps")
        }
    }
}
