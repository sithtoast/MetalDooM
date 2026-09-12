import Foundation

/// Main-queue, single-request pacing. Late work slows simulation instead of
/// accumulating catch-up tics or sampling a backlog of stale input.
struct ExtendedPlaybackClock {
    static let interval=1.0/35.0
    private(set) var running=false, inFlight=false
    private(set) var deadline=0.0
    private var remaining:Int?
    var busy:Bool { running || inFlight }
    mutating func start(now:Double,steps:Int?=nil) {
        precondition(!busy && (steps == nil || steps!>0))
        remaining=steps;running=true;deadline=now+Self.interval
    }
    mutating func claim(now:Double)->Bool {
        guard running,!inFlight,now>=deadline else { return false }
        inFlight=true;deadline=now+Self.interval
        if let count=remaining { remaining=count-1;if count==1 { running=false } }
        return true
    }
    mutating func finish() { precondition(inFlight);inFlight=false }
    mutating func pause() { running=false;remaining=nil }
}
