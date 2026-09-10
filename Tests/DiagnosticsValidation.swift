// SPDX-License-Identifier: GPL-2.0-or-later
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let subject = App()
subject.applicationDidFinishLaunching(Notification(name:NSApplication.didFinishLaunchingNotification))
let layer = subject.view.layer as! CAMetalLayer
precondition(!subject.metalHUDEnabled && subject.metalHUDMenuItem?.state == .off)
precondition(layer.developerHUDProperties?["mode"] as? String == "disabled")
subject.toggleMetalHUD()
precondition(subject.metalHUDEnabled && subject.metalHUDMenuItem?.state == .on)
precondition(layer.developerHUDProperties?["mode"] as? String == "default")
let report = subject.diagnosticReport()
precondition(report.contains("Metal HUD: On") && report.contains(subject.renderer.device.name))
precondition(report.contains("RAM:") && report.contains("macOS:") && report.contains("Frame limit:"))
if let wad = subject.wad {
    for (i,url) in wad.sourceURLs.enumerated() {
        precondition(report.contains("\(i+1). \(url.lastPathComponent)"))
        precondition(!report.contains(url.deletingLastPathComponent().path))
    }
    precondition(report.contains(wad.gameName))
} else {
    precondition(report.contains("No WAD loaded") && report.contains("Map: None"))
}
// Exercise the menu action and verify the exact text placed on the clipboard.
let pasteboard = NSPasteboard.general
let previous = pasteboard.pasteboardItems?.map { item in
    item.types.compactMap { type in item.data(forType:type).map { (type,$0) } }
} ?? []
subject.copyDiagnosticReport()
precondition(pasteboard.string(forType:.string) == report)
pasteboard.clearContents()
let restored = previous.map { entries -> NSPasteboardItem in
    let item=NSPasteboardItem(); for (type,data) in entries { item.setData(data,forType:type) };return item
}
pasteboard.writeObjects(restored)
subject.toggleMetalHUD()
precondition(!subject.metalHUDEnabled && layer.developerHUDProperties?["mode"] as? String == "disabled")
subject.window.performClose(nil)
subject.advanceAttract()
precondition(subject.shuttingDown)
print("PASS: diagnostics default/toggle, report context, filename-only WAD order, clipboard and shutdown")
