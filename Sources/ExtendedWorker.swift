import Foundation
import Darwin

struct ExtendedView {
    let tic: Int, x: Float, y: Float, eyeZ: Float, angle: Float, health: Int, sky: String
    let geometry: ExtendedGeometry?
    let presentation: ExtendedPresentation
    init(data: Data) throws {
        let bytes=Bytes(data:data); try bytes.check(0,44)
        guard data.prefix(4) == Data("MVW2".utf8) else { throw PortError("Invalid worker view header.") }
        let size=try bytes.i32(36), spriteSize=try bytes.i32(40)
        guard size >= 0, spriteSize>=32, data.count == 44+size+spriteSize else { throw PortError("Invalid worker geometry length.") }
        tic=try bytes.i32(4); health=try bytes.i32(24)
        guard tic >= 0 else { throw PortError("Invalid worker tic.") }
        x=Float(try bytes.i32(8))/65536; y=Float(try bytes.i32(12))/65536; eyeZ=Float(try bytes.i32(16))/65536
        angle=Float(UInt32(bitPattern:Int32(try bytes.i32(20)))) * 2 * .pi/4294967296
        sky=try bytes.name(28)
        guard !sky.isEmpty, data[28..<36].prefix(while:{$0 != 0}).allSatisfy({(33...126).contains($0)}) else { throw PortError("Invalid worker sky.") }
        geometry=size == 0 ? nil:try ExtendedGeometry(data:Data(data[44..<44+size]))
        presentation=try ExtendedPresentation(data:Data(data[(44+size)...]))
        guard presentation.tic==tic else { throw PortError("Worker sprite/view tics differ.") }
        guard geometry == nil || geometry?.tic == tic else { throw PortError("Worker view and geometry tics differ.") }
    }
}

/// Blocking API for one caller-owned serial background queue. cancel() alone is
/// thread-safe and interrupts an in-flight read by terminating the owned child.
/// Frame deadlines also bound startup, partial replies and unexpected child loss.
final class ExtendedWorker {
    private let process=Process(), input=Pipe(), output=Pipe()
    private let lock=NSLock()
    private var cancelled=false, sequence:UInt32=0
    private var scratch:URL?, log:FileHandle?
    private var closed=false
    private(set) var identity:String?
    private let timeout:Double
    init(timeout:Double=30) { self.timeout=max(0.1,min(120,timeout)) }
    func start(executable:URL, paths:[URL], map:Int, base:Int, profile:Int=1, skill:Int=3) throws -> ExtendedView {
        guard scratch == nil else { throw PortError("Worker already started.") }
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("metaldoom-worker-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        scratch=directory
        let logURL=directory.appendingPathComponent("worker.log")
        guard FileManager.default.createFile(atPath:logURL.path,contents:nil) else { throw PortError("Cannot create worker log.") }
        log=try FileHandle(forWritingTo:logURL)
        process.executableURL=executable
        process.arguments=[directory.path,String(map),String(base),String(profile),String(skill)]+paths.map(\.path)
        process.standardInput=input;process.standardOutput=output;process.standardError=log
        lock.lock()
        do {
            guard !cancelled else { throw PortError("Worker cancelled.") }
            try process.run();lock.unlock()
        } catch { lock.unlock(); throw error }
        // Only the child owns these ends after launch, so EOF is observable.
        input.fileHandleForReading.closeFile();output.fileHandleForWriting.closeFile()
        do {
            let view=try receive(deadline:deadline())
            guard let geometry=view.geometry, geometry.map.name == String(format:"MAP%02d",map) else { throw PortError("Worker returned the wrong map.") }
            identity=geometry.contentSHA256
            return view
        } catch { cancel(); throw error }
    }
    func geometry() throws -> ExtendedView { try request(operation:2,body:Data()) }
    func tick(forward:Int8=0,side:Int8=0,turn:Int16=0,buttons:UInt8=0,count:Int=1) throws -> ExtendedView {
        guard (1...35).contains(count) else { throw PortError("Worker tick batch must contain 1–35 commands.") }
        let angle=UInt16(bitPattern:turn)
        let command:[UInt8]=[UInt8(bitPattern:forward),UInt8(bitPattern:side),UInt8(truncatingIfNeeded:angle),UInt8(truncatingIfNeeded:angle>>8),buttons,0]
        return try request(operation:1,body:Data((0..<count).flatMap{_ in command}))
    }
    private func request(operation:UInt32,body:Data) throws -> ExtendedView {
        guard identity != nil, sequence < UInt32.max else { throw PortError("Worker is not ready.") }
        sequence += 1
        var bytes=Data("MEQ1".utf8)
        for value in [sequence,operation,UInt32(body.count)] { for i in 0..<4 { bytes.append(UInt8(truncatingIfNeeded:value >> (8*i))) } }
        bytes.append(body)
        let end=deadline()
        do {
            try write(bytes,deadline:end)
            let view=try receive(deadline:end)
            if let geometry=view.geometry, geometry.contentSHA256 != identity { throw PortError("Worker session identity changed.") }
            return view
        } catch { cancel(); throw error }
    }
    private func deadline() -> Double { ProcessInfo.processInfo.systemUptime+timeout }
    private func wait(_ fd:Int32,event:Int16,deadline:Double) throws {
        while true {
            lock.lock();let stopped=cancelled;lock.unlock()
            guard !stopped else { throw PortError("Worker cancelled.") }
            let remaining=deadline-ProcessInfo.processInfo.systemUptime
            guard remaining>0 else { throw PortError("Extended worker timed out.") }
            var descriptor=pollfd(fd:fd,events:event,revents:0)
            let result=Darwin.poll(&descriptor,1,Int32(min(1000,ceil(remaining*1000))))
            if result < 0 && errno != EINTR { throw PortError("Worker pipe failed.") }
            if result <= 0 { continue }
            guard descriptor.revents & (event|Int16(POLLHUP)) != 0 else { throw PortError("Worker pipe closed.") }
            return
        }
    }

    private func read(_ size:Int,deadline:Double) throws -> Data {
        var data=Data(count:size)
        try data.withUnsafeMutableBytes { raw in
            var offset=0
            while offset<size {
                try wait(output.fileHandleForReading.fileDescriptor,event:Int16(POLLIN),deadline:deadline)
                let count=Darwin.read(output.fileHandleForReading.fileDescriptor,raw.baseAddress!.advanced(by:offset),size-offset)
                if count < 0 && errno == EINTR { continue }
                guard count>0 else { throw PortError("Extended worker exited before completing its reply.") }
                offset += count
            }
        }
        return data
    }
    private func write(_ data:Data,deadline:Double) throws {
        // Darwin-specific per-descriptor SIGPIPE suppression leaves global app policy alone.
        _ = fcntl(input.fileHandleForWriting.fileDescriptor,F_SETNOSIGPIPE,1)
        try data.withUnsafeBytes { raw in
            var offset=0
            while offset<data.count {
                try wait(input.fileHandleForWriting.fileDescriptor,event:Int16(POLLOUT),deadline:deadline)
                let count=Darwin.write(input.fileHandleForWriting.fileDescriptor,raw.baseAddress!.advanced(by:offset),data.count-offset)
                if count<0 && errno == EINTR { continue }
                guard count>0 else { throw PortError("Extended worker request failed.") }
                offset += count
            }
        }
    }
    private func receive(deadline:Double) throws -> ExtendedView {
        let header=try read(16,deadline:deadline), bytes=Bytes(data:header)
        guard header.prefix(4)==Data("MER1".utf8), UInt32(bitPattern:Int32(try bytes.i32(4)))==sequence else { throw PortError("Invalid worker reply sequence.") }
        let status=try bytes.i32(8),size=try bytes.i32(12)
        guard (0...1).contains(status), size>=0, size<=160*1024*1024+44, status==0 || size<=2048 else { throw PortError("Invalid worker reply length/status.") }
        let body=try read(size,deadline:deadline)
        guard status==0 else { throw PortError(String(decoding:body,as:UTF8.self)) }
        return try ExtendedView(data:body)
    }
    func cancel() {
        lock.lock();cancelled=true
        if process.isRunning { process.terminate() }
        lock.unlock()
    }
    // Call on the owning queue after cancel() to drain/reap and remove scratch.
    func close() {
        guard !closed else { return };closed=true
        cancel()
        // The bundled child has default SIGTERM handling; reap it before deleting scratch.
        if process.isRunning { process.waitUntilExit() }
        input.fileHandleForWriting.closeFile();output.fileHandleForReading.closeFile();log?.closeFile()
        if let scratch { try? FileManager.default.removeItem(at:scratch) }
    }
    deinit { close() }
}
