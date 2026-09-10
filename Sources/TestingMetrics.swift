// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

final class SessionLog {
    private var entries: [String] = []
    private var dropped = 0
    private let limit: Int
    init(limit: Int = 256) { self.limit = max(1,limit) }
    func append(_ text: String) {
        // Deliberately conservative: omit a path and the remainder of its line.
        let safe = text.replacingOccurrences(of:"(?:file://)?/[^\\n]*",with:"[path omitted]",options:.regularExpression)
        let line = "\(ISO8601DateFormatter().string(from:Date())) \(safe.prefix(1024))"
        if entries.count == limit { entries.removeFirst(); dropped += 1 }
        entries.append(line)
    }
    var text: String { "MetalDooM session log (latest \(limit) entries; \(dropped) older entries discarded)\n" + entries.joined(separator:"\n") + "\n" }
}

final class BenchmarkRun {
    let context: String
    let settings: String
    let warmup: Double
    let duration: Double
    private(set) var start: Double?
    private var previous: Double?
    private(set) var intervals: [Double] = []
    init(context: String, settings: String, warmup: Double = 5, duration: Double = 15) {
        self.context=context;self.settings=settings;self.warmup=warmup;self.duration=duration
    }
    func sample(_ time: Double) -> Bool {
        if start == nil { start=time }
        defer { previous=time }
        let elapsed=time-start!
        if let previous, previous >= start!+warmup, time>previous { intervals.append(time-previous) }
        return elapsed >= warmup+duration
    }
    func progress(_ time: Double) -> String {
        let elapsed=time-(start ?? time)
        return elapsed<warmup ? "Warm-up: \(Int(ceil(warmup-elapsed)))s" : "Measuring: \(Int(ceil(max(0,warmup+duration-elapsed))))s"
    }
    var result: String {
        guard !intervals.isEmpty else { return "No measured frames." }
        let sorted=intervals.sorted(), total=intervals.reduce(0,+)
        let tail=sorted.suffix(max(1,Int(ceil(Double(sorted.count)*0.01))))
        func ms(_ value:Double)->String { String(format:"%.2f ms",value*1000) }
        return """
        MetalDooM benchmark v1 — DEMO1
        Warm-up: \(warmup)s; measured: \(String(format:"%.3f",total))s; intervals: \(intervals.count)
        Average FPS: \(String(format:"%.2f",Double(intervals.count)/total))
        1% low FPS: \(String(format:"%.2f",Double(tail.count)/tail.reduce(0,+)))
        Frame interval: mean \(ms(total/Double(intervals.count))); p99 \(ms(sorted[min(sorted.count-1,Int(ceil(Double(sorted.count)*0.99))-1)])); max \(ms(sorted.last!))
        Timing: CPU frame-submission intervals, not GPU or on-screen presentation timing.
        1% low: reciprocal of mean interval of the slowest 1% (rounded up).
        Mode: current frame cap and display synchronization; not an uncapped throughput test.

        \(context)
        """
    }
}
