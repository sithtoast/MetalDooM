// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import MetalKit
import Darwin
import CryptoKit

extension App {
    // Launch Services enables HUD machinery via Info.plist; explicitly hide it
    // until requested. This is per-layer and never changes global Metal settings.
    func configureMetalHUD() {
        (view.layer as? CAMetalLayer)?.developerHUDProperties = ["mode":metalHUDEnabled ? "default" : "disabled"]
        metalHUDMenuItem?.state = metalHUDEnabled ? .on : .off
    }

    @objc func selectOPL(_ sender:NSMenuItem) { UserDefaults.standard.set("opl",forKey:"musicBackend");sessionLog.append("Music backend: Classic OPL") }
    @objc func selectAppleMIDI(_ sender:NSMenuItem) { UserDefaults.standard.set("apple",forKey:"musicBackend");sessionLog.append("Music backend: Apple MIDI") }
    @objc func selectAOStrength(_ sender: NSMenuItem) { renderer.setAOSettings(strength:Float(sender.tag)/100) }
    @objc func selectAORadius(_ sender: NSMenuItem) { renderer.setAOSettings(radius:Float(sender.tag)) }
    @objc func toggleAmbientOcclusion() {
        do {
            try renderer.setAmbientOcclusion(!renderer.ambientOcclusionEnabled)
            sessionLog.append("Ray-traced ambient occlusion: \(renderer.ambientOcclusionEnabled ? "On" : "Off")")
        } catch { show(error) }
    }
    @objc func toggleMetalHUD() {
        metalHUDEnabled.toggle()
        configureMetalHUD()
    }

    @objc func toggleDynamicLight() {
        do {
            try renderer.setDynamicLight(!renderer.dynamicLightEnabled)
            sessionLog.append("Moving test light: \(renderer.dynamicLightEnabled ? "On":"Off")")
        } catch { show(error) }
    }
    @objc func toggleDynamicLightShadows() {
        renderer.setDynamicLightShadows(!renderer.dynamicLightShadows)
        sessionLog.append("Test light shadows: \(renderer.dynamicLightShadows ? "On":"Off")")
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
        let fingerprints = wad.map { wad in
            zip(wad.sourceURLs,wad.sourceData).enumerated().map { index,pair in
                "\(index+1). \(pair.0.lastPathComponent): \(SHA256.hash(data:pair.1).map { String(format:"%02x",$0) }.joined())"
            }.joined(separator:"\n")
        } ?? "None"
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
        Music backend: \(MusicPlayer.preferredBackend == "opl" ? "Classic OPL" : "Apple MIDI")
        Ray-traced AO: \(renderer.ambientOcclusionEnabled ? "On (8 rays, alpha-tested world)" : "Off")
        AO strength: \(Int(renderer.aoSettings.strength*100))%
        AO radius: \(Int(renderer.aoSettings.radius)) Doom units
        Moving test light: \(renderer.dynamicLightEnabled ? "On (amber, radius 256, intensity 2, 8-second orbit)":"Off")
        Additional effects: \(SceneEffect.allCases.map { "\($0.title)=\(renderer.sceneEffects.contains($0) ? "On":"Off")" }.joined(separator:", "))
        World light budget: 16 total, up to 4 emissive patches; sprite reception optional; world-only shadow casters
        Soft shadows: 4 fixed samples when selected; particles: maximum 128
        Test light shadows: \(renderer.dynamicLightShadows ? "On (alpha-tested world)":"Off")
        Shared ray occluder triangles: \(renderer.ambientOcclusion?.triangleCount ?? 0)
        Ray tracing in render shaders: \(renderer.ambientOcclusionSupported)
        Recent GPU command duration: \(String(format:"%.3f",renderer.recentGPUTime*1000)) ms (not a benchmark)
        Metal HUD: \(metalHUDEnabled ? "On" : "Off")
        Campaign: \(wad?.gameName ?? "No WAD loaded")
        Base WAD edition: \(wad == nil ? "No WAD loaded" : (wad!.isKEXEdition ? "KEX Edition" : "Not identified as KEX"))
        Map: \(wad == nil ? "None" : (maps.titleOfSelectedItem ?? "None"))
        Presentation: \(attractActive ? (attractDemo ? "Demo playback" : "Title/attract") : "Gameplay/menu")
        Ordered WAD files (base first):
        \(files)
        WAD SHA-256 (ordered; loaded file contents):
        \(fingerprints)

        Add reproduction steps, expected/actual behavior and a screenshot if useful.
        """
    }
}

extension App {
    @objc func toggleSceneEffect(_ sender:NSMenuItem) {
        guard let effect=SceneEffect(rawValue:sender.tag) else { return }
        do {
            try renderer.setSceneEffect(effect,enabled:!renderer.sceneEffects.contains(effect))
            sessionLog.append("\(effect.title): \(renderer.sceneEffects.contains(effect) ? "On":"Off")")
        } catch { show(error) }
    }
}
