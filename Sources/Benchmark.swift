// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit
import MetalKit
import UniformTypeIdentifiers

extension App {
    var benchmarkSettings: String {
        "\(view.drawableSize)|\(view.renderScale)|\(view.preferredFramesPerSecond)|\(window.styleMask.contains(.fullScreen))|\(window.backingScaleFactor)|\(metalHUDEnabled)|\(MusicPlayer.preferredBackend)|\(renderer.ambientOcclusionEnabled)|\(renderer.aoSettings.strength)|\(renderer.aoSettings.radius)|\(renderer.dynamicLightEnabled)|\(renderer.dynamicLightShadows)|\(renderer.sceneEffectsKey)|\(renderer.hdrEnabled)|\(renderer.hdrPeak)|\(renderer.fogDensity)|\(renderer.highRayQuality)|\(renderer.lightGain)|\(renderer.bloomStrength)|\(renderer.hdrSpriteBoost)"
    }
    @objc func runBenchmark() {
        guard benchmark == nil else { return }
        guard let wad, attractActive, wad.sourceURLs.count == 1 else {
            show(PortError("Save your game and return to the title screen before benchmarking. Use a base IWAD without add-ons."));return
        }
        let alert=NSAlert();alert.messageText="Run DEMO1 benchmark?"
        alert.informativeText="5 seconds of warm-up, then 15 seconds of measurement using current rendering settings and frame cap. Keep this window focused and unchanged. Escape cancels. Returns to the title screen when finished."
        alert.addButton(withTitle:"Start Capped Run");alert.addButton(withTitle:"Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            endAttract();gameMenu?.removeFromSuperview();gameMenu=nil
            if consoleVisible { toggleConsole() }
            closeAutomap();view.releaseMouse();view.keys.removeAll()
            try playDemo("DEMO1")
            attractActive=false;view.inputBlocked=true;maps.isEnabled=false
            benchmark=BenchmarkRun(context:diagnosticReport(),settings:benchmarkSettings)
            sessionLog.append("Benchmark started: DEMO1, warm-up 5s, sample 15s, cap \(view.preferredFramesPerSecond)")
        } catch { beginAttract();show(error) }
    }
    func benchmarkFrame(_ time: Double) {
        guard let run=benchmark else { return }
        guard NSApp.isActive, window.isKeyWindow, window.attachedSheet == nil,
              benchmarkSettings == run.settings, !renderer.paused, MD_DemoPlaying() != 0 else {
            finishBenchmark(reason:"Interrupted: focus, settings, playback or window state changed.");return
        }
        summary="BENCHMARK — \(run.progress(time)) — Esc cancels"
        if run.sample(time) { finishBenchmark(reason:nil) }
    }
    @objc func cancelBenchmark() { finishBenchmark(reason:"Cancelled by user.") }
    func finishBenchmark(reason: String?, notify: Bool = true) {
        guard let run=benchmark else { return }
        benchmark=nil;maps.isEnabled=wad != nil
        if let reason { sessionLog.append("Benchmark cancelled: \(reason)") }
        else { lastBenchmarkReport=run.result;sessionLog.append("Benchmark complete: \(run.intervals.count) measured intervals") }
        guard !shuttingDown else { return }
        beginAttract()
        summary = "Title screen — " + (wad?.displayName ?? "MetalDooM")
        guard notify else { return }
        // Leave the render callback before displaying a modal result.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.shuttingDown else { return }
            let alert=NSAlert();alert.messageText=reason == nil ? "Benchmark complete" : "Benchmark cancelled"
            alert.informativeText=reason ?? run.result.components(separatedBy:"\n").prefix(7).joined(separator:"\n")
            alert.addButton(withTitle:"OK")
            if reason == nil { alert.addButton(withTitle:"Copy Full Result") }
            if alert.runModal() == .alertSecondButtonReturn {
                NSPasteboard.general.clearContents();NSPasteboard.general.setString(run.result,forType:.string)
            }
        }
    }
    @objc func exportSessionLog() {
        sessionLog.append("Session log export requested")
        exportText(diagnosticReport()+"\n\n"+sessionLog.text,name:"MetalDooM-session.txt")
    }
    @objc func exportBenchmarkResult() {
        guard let result=lastBenchmarkReport else { show(PortError("Complete a benchmark first."));return }
        exportText(result,name:"MetalDooM-benchmark.txt")
    }
    func exportText(_ text: String, name: String) {
        view.releaseMouse()
        let panel=NSSavePanel();panel.allowedContentTypes=[.plainText];panel.nameFieldStringValue=name
        panel.beginSheetModal(for:window) { [weak self] response in
            guard response == .OK, let url=panel.url else { return }
            do { try text.write(to:url,atomically:true,encoding:.utf8) }
            catch { self?.show(error) }
        }
    }
    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(selectOPL(_:)) { item.state=MusicPlayer.preferredBackend == "opl" ? .on : .off }
        if item.action == #selector(selectAppleMIDI(_:)) { item.state=MusicPlayer.preferredBackend == "apple" ? .on : .off }
        if benchmark != nil { return item.action == #selector(cancelBenchmark) || item.action == #selector(NSApplication.terminate(_:)) }
        if item.action == #selector(selectGraphicsPreset(_:)), Self.graphicsPresets.indices.contains(item.tag) {
            let (scale,fps)=Self.graphicsPresets[item.tag]
            item.state=view.renderScale==scale && view.preferredFramesPerSecond==fps ? .on:.off
        }
        if item.action == #selector(selectEffectsPreset(_:)) {
            let preset=EffectsPreset.builtins.indices.contains(item.tag) ? EffectsPreset.builtins[item.tag]:savedEffectsPreset
            guard let preset else { return false }
            item.state=EffectsPreset(renderer:renderer)==preset ? .on:.off
            return (!preset.hdr || hdrDisplayAvailable) && (!(preset.ao || preset.testLight || preset.switches.contains(where: { $0.needsRays })) || renderer.ambientOcclusionSupported)
        }
        if item.action == #selector(toggleHDR) {
            item.state=renderer.hdrEnabled ? .on:.off
            return renderer.hdrEnabled || hdrDisplayAvailable
        }
        if item.action == #selector(selectRayQuality(_:)) {
            item.state=renderer.highRayQuality == (item.tag==1) ? .on:.off
            return renderer.ambientOcclusionSupported
        }
        if item.action == #selector(toggleHDRSpriteBoost) {
            item.state=renderer.hdrSpriteBoost ? .on:.off;return renderer.hdrEnabled
        }
        if item.action == #selector(selectLightGain(_:)) {
            item.state=abs(renderer.lightGain-Float(item.tag)/100)<0.00001 ? .on:.off;return true
        }
        if item.action == #selector(selectBloomStrength(_:)) {
            item.state=abs(renderer.bloomStrength-Float(item.tag)/100)<0.00001 ? .on:.off;return true
        }
        if item.action == #selector(selectHDRPeak(_:)) {
            item.state=renderer.hdrPeak==Float(item.tag) ? .on:.off;return true
        }
        if item.action == #selector(selectFogDensity(_:)) {
            item.state=abs(renderer.fogDensity-Float(item.tag)/1000)<0.00001 ? .on:.off
            return renderer.ambientOcclusionSupported
        }
        if item.action == #selector(selectAOStrength(_:)) {
            item.state=Int(renderer.aoSettings.strength*100)==item.tag ? .on:.off
            return renderer.ambientOcclusionSupported
        }
        if item.action == #selector(selectAORadius(_:)) {
            item.state=Int(renderer.aoSettings.radius)==item.tag ? .on:.off
            return renderer.ambientOcclusionSupported
        }
        if item.action == #selector(toggleSceneEffect(_:)), let effect=SceneEffect(rawValue:item.tag) {
            item.state=renderer.sceneEffects.contains(effect) ? .on:.off
            return !effect.needsRays || renderer.ambientOcclusionSupported
        }
        if item.action == #selector(toggleAmbientOcclusion) {
            item.state=renderer.ambientOcclusionEnabled ? .on : .off
            return renderer.ambientOcclusionSupported
        }
        if item.action == #selector(toggleDynamicLight) {
            item.state=renderer.dynamicLightEnabled ? .on:.off
            return renderer.ambientOcclusionSupported
        }
        if item.action == #selector(toggleDynamicLightShadows) {
            item.state=renderer.dynamicLightShadows ? .on:.off
            return renderer.ambientOcclusionSupported && renderer.dynamicLightEnabled
        }
        if item.action == #selector(cancelBenchmark) { return false }
        if item.action == #selector(exportBenchmarkResult) { return lastBenchmarkReport != nil }
        return true
    }
}
