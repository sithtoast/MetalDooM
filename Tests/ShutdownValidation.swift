// SPDX-License-Identifier: GPL-2.0-or-later
// App source is combined with this harness by test-shutdown.sh.
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let subject = App()
// Leave the application delegate unset so last-window termination does not exit
// the harness before it can inspect the closed window and drain pending timers.
subject.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
precondition(subject.wad != nil && subject.attractTimer?.isValid == true)
precondition(!subject.window.isReleasedWhenClosed)
if CommandLine.arguments.contains("--gameplay") { subject.endAttract() }
let timer = subject.attractTimer
if CommandLine.arguments.contains("--quit") {
    subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
} else {
    subject.window.performClose(nil)
}
precondition(subject.shuttingDown && subject.attractTimer == nil && timer?.isValid != true)
precondition(!subject.attractActive && subject.titleMusic == nil)
precondition(subject.view.isPaused && subject.view.delegate == nil && subject.menuKeyMonitor == nil)
// Repeated shutdown and an already-delivered attract callback must be harmless.
subject.applicationWillTerminate(Notification(name:NSApplication.willTerminateNotification))
subject.advanceAttract()
RunLoop.current.run(until:Date().addingTimeInterval(0.35))
precondition(subject.window.title.contains("MetalDooM"))
print("PASS: loaded-WAD shutdown cancels callbacks, pauses rendering and retains a valid closed window")
