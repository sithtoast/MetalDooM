import Foundation

@main struct ExtendedWorkerValidation {
    static func main() throws {
        let args=CommandLine.arguments, executable=URL(fileURLWithPath:args[1]), base=URL(fileURLWithPath:args[2]), root=URL(fileURLWithPath:args[3])
        do {
            let worker=ExtendedWorker()
            let first=try worker.start(executable:executable,paths:[base],map:1,base:0,profile:0)
            guard first.tic==0, first.health==100, first.geometry != nil else { throw PortError("Invalid initial worker view.") }
            let map=first.geometry!.map, sector=first.geometry!.map.sectors[first.geometry!.map.sector(at:first.geometry!.map.start)]
            guard first.eyeZ == min(sector.floor+41,sector.ceiling-4), map.name=="MAP01" else { throw PortError("Incorrect initial view height.") }
            let moved=try worker.tick(forward:25,count:35)
            guard moved.tic==35, moved.geometry==nil, abs(moved.x-first.x)+abs(moved.y-first.y)>1 else { throw PortError("Remote movement failed.") }
            let copied=try worker.geometry()
            guard copied.tic==35, copied.geometry?.tic==35 else { throw PortError("Remote geometry tic mismatch.") }
            worker.cancel()
            var rejected=false
            do { _=try worker.geometry() } catch { rejected=true }
            guard rejected else { throw PortError("Cancelled worker accepted a command.") }
            print("PASS framed worker startup, movement, geometry identity/tics and cancellation")
        }
        let paths=["id24res.wad","doom2.wad","id1.wad"].map{root.appendingPathComponent($0)}
        for map in 1...16 {
            let worker=ExtendedWorker()
            let first=try worker.start(executable:executable,paths:paths,map:map,base:1)
            let resources=try WAD(previewResources:paths,baseIndex:1,profile:1,identity:worker.identity!)
            var rejected=false
            do { _=try WAD(previewResources:paths,baseIndex:0,profile:1,identity:worker.identity!) } catch { rejected=true }
            guard rejected, resources.signature=="PWAD" else { throw PortError("Resource identity mismatch accepted.") }
            let scene=try ExtendedScene(view:first,resources:resources)
            guard scene.geometry.triangleCount>0 else { throw PortError("Invalid scene.") }
            print("PASS Rust MAP\(map): \(scene.geometry.triangleCount) textured triangles, \(scene.images.count) materials, sky \(first.sky), eyeZ \(first.eyeZ)")
            worker.cancel()
        }
        for mode in ["stall","oversize","sequence","truncated"] {
            let worker=ExtendedWorker(timeout:0.2), start=ProcessInfo.processInfo.systemUptime
            var rejected=false
            do { _=try worker.start(executable:executable.deletingLastPathComponent().appendingPathComponent("fake-"+mode),paths:[base],map:1,base:0) } catch { rejected=true }
            guard rejected, ProcessInfo.processInfo.systemUptime-start<2 else { throw PortError("Unbounded or accepted bad reply: \(mode)") }
            print("PASS client rejects \(mode) reply within deadline")
        }
    }
}
