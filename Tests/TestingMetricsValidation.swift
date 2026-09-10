import Foundation

@main struct Validation {
    static func main() {
        let log=SessionLog(limit:2)
        log.append("old");log.append("Error opening /Users/test/Private Folder/game.wad");log.append(String(repeating:"x",count:5000))
        precondition(log.text.contains("1 older entries discarded"))
        precondition(!log.text.contains("Private") && !log.text.contains("/Users"))
        precondition(log.text.contains("[path omitted]") && log.text.count<2300)
        let run=BenchmarkRun(context:"fixture",settings:"60 FPS",warmup:1,duration:2)
        for frame in 0...180 { _=run.sample(Double(frame)/60) }
        precondition(run.intervals.count==120)
        precondition(run.result.contains("Average FPS: 60.00"))
        precondition(run.result.contains("1% low FPS: 60.00"))
        let spike=BenchmarkRun(context:"fixture",settings:"",warmup:0,duration:2)
        _=spike.sample(0)
        for frame in 1...99 { _=spike.sample(Double(frame)*0.01) }
        _=spike.sample(1.09)
        precondition(spike.result.contains("1% low FPS: 10.00"))
        precondition(spike.result.contains("max 100.00 ms"))
        print("PASS: bounded path-redacted logs, warm-up exclusion, FPS and slowest-1% math")
    }
}
