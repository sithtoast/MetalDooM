// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import MetalKit
import Darwin

extension App {
    // Launch Services enables HUD machinery via Info.plist; explicitly hide it
    // until requested. This is per-layer and never changes global Metal settings.
    func configureMetalHUD() {
        (view.layer as? CAMetalLayer)?.developerHUDProperties = ["mode":metalHUDEnabled ? "default" : "disabled"]
        metalHUDMenuItem?.state = metalHUDEnabled ? .on : .off
    }

    @objc func toggleMetalHUD() {
        metalHUDEnabled.toggle()
        configureMetalHUD()
    }

    @objc func copyDiagnosticReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticReport(),forType:.string)
        NSAccessibility.post(element:window as Any,notification:.announcementRequested,
            userInfo:[.announcement:"Diagnostic report copied",.priority:NSAccessibilityPriorityLevel.medium.rawValue])
    }

    func diagnosticReport() -> String {
        func systemString(_ key: String) -> String {
            var size = 0
            guard sysctlbyname(key,nil,&size,nil,0) == 0, size > 0 else { return "Unavailable" }
            var bytes = [CChar](repeating:0,count:size)
            guard sysctlbyname(key,&bytes,&size,nil,0) == 0 else { return "Unavailable" }
            return String(cString:bytes)
        }
        let process = ProcessInfo.processInfo
        let drawable = view.drawableSize
        let files = wad?.sourceURLs.enumerated().map { "\($0.offset + 1). \($0.element.lastPathComponent)" }.joined(separator:"\n") ?? "None"
        let buildDate = Bundle.main.object(forInfoDictionaryKey:"MetalDooMBuildDate") as? String ?? "Unavailable"
        let fps = diagnosticFPS.map { String(format:"%.1f",$0) } ?? "Not sampled yet"
        return """
        MetalDooM Diagnostic Report
        App: \(appTitle)
        Build date (UTC): \(buildDate)
        macOS: \(process.operatingSystemVersionString)
        Mac model: \(systemString("hw.model"))
        Chip: \(systemString("machdep.cpu.brand_string"))
        CPU cores: \(process.processorCount)
        RAM: \(process.physicalMemory / 1_073_741_824) GiB
        GPU: \(renderer.device.name)
        Drawable: \(Int(drawable.width)) x \(Int(drawable.height)) pixels
        Render scale: \(Int(view.renderScale * 100))%
        Display backing scale: \(window.backingScaleFactor)
        Display maximum refresh: \(window.screen?.maximumFramesPerSecond ?? 0) Hz
        Fullscreen: \(window.styleMask.contains(.fullScreen))
        Frame limit: \(view.preferredFramesPerSecond) FPS
        Recent renderer FPS: \(fps) (not a benchmark)
        Metal HUD: \(metalHUDEnabled ? "On" : "Off")
        Campaign: \(wad?.gameName ?? "No WAD loaded")
        Map: \(wad == nil ? "None" : (maps.titleOfSelectedItem ?? "None"))
        Presentation: \(attractActive ? (attractDemo ? "Demo playback" : "Title/attract") : "Gameplay/menu")
        Ordered WAD files (base first):
        \(files)

        Add reproduction steps, expected/actual behavior and a screenshot if useful.
        """
    }
}
