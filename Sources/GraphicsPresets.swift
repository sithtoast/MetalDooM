// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

struct EffectsPreset: Codable, Equatable {
    var effects: Set<Int> = []
    // Optional for backward-compatible decoding of saved build-104 custom presets.
    var highRayQuality: Bool? = nil
    var lightGain: Float? = nil, bloomStrength: Float? = nil
    var hdrSpriteBoost: Bool? = nil
    var ao=false, testLight=false, testShadows=true, hdr=false
    var strength: Float=0.5, radius: Float=48, density: Float=0.003, peak: Float=4
    var switches: Set<SceneEffect> { Set(effects.compactMap(SceneEffect.init(rawValue:))) }
    static let names=["Classic", "Medium", "High", "Medium HDR", "Ludicrous"]
    // Short lines fit the original Doom menu's pixel font at its smallest size.
    static let descriptions: [[String]] = [
        ["Original lighting and textures.", "No added effects or HDR.", "Lowest GPU cost."],
        ["Lights, soft shadows and subtle AO.", "Glow, bloom and smoother textures.", "Balanced rays; standard range."],
        ["Medium plus surface lights,", "particles and light haze.", "More GPU work; standard range."],
        ["High effects with HDR highlights.", "Restrained bloom; up to 4x white.", "Requires an HDR display."],
        ["Stronger AO, lights and bloom.", "Denser haze; high ray quality.", "HDR up to 8x white. Highest cost."]
    ]
    static let builtins: [Self] = {
        let enhanced: Set<SceneEffect>=[.torches,.projectiles,.muzzleFlash,.shadows,.emissive,.bloom,.spriteLighting,.softShadows,.textureFiltering]
        var ludicrous=Self(effects:Set(SceneEffect.allCases.map(\.rawValue)),ao:true,hdr:true,strength:0.5,radius:48,density:0.003)
        ludicrous.highRayQuality=true;ludicrous.peak=8
        ludicrous.lightGain=2;ludicrous.bloomStrength=0.3;ludicrous.hdrSpriteBoost=true
        return [Self(),Self(effects:Set(enhanced.map(\.rawValue)),ao:true,strength:0.25,radius:16),
                Self(effects:Set(SceneEffect.allCases.map(\.rawValue)),ao:true,strength:0.25,radius:32,density:0.001),
                Self(effects:Set(SceneEffect.allCases.map(\.rawValue)),ao:true,hdr:true,strength:0.25,radius:32,density:0.001),ludicrous]
    }()
    init(renderer:Renderer) {
        highRayQuality=renderer.highRayQuality ? true:nil
        lightGain=renderer.lightGain == 1 ? nil:renderer.lightGain
        bloomStrength=renderer.bloomStrength == 0.12 ? nil:renderer.bloomStrength
        hdrSpriteBoost=renderer.hdrSpriteBoost ? true:nil
        effects=Set(renderer.sceneEffects.map(\.rawValue));ao=renderer.ambientOcclusionEnabled
        testLight=renderer.dynamicLightEnabled;testShadows=renderer.dynamicLightShadows;hdr=renderer.hdrEnabled
        strength=renderer.aoSettings.strength;radius=renderer.aoSettings.radius
        density=renderer.fogDensity;peak=renderer.hdrPeak
    }
    init(effects:Set<Int>=[],ao:Bool=false,hdr:Bool=false,strength:Float=0.5,radius:Float=48,density:Float=0.003) {
        self.effects=effects;self.ao=ao;self.hdr=hdr;self.strength=strength;self.radius=radius;self.density=density
    }
}

extension App {
    var effectsActive: Bool {
        renderer.ambientOcclusionEnabled || renderer.dynamicLightEnabled || renderer.hdrEnabled || !renderer.sceneEffects.isEmpty
    }
    var effectsPresetName: String {
        let current=EffectsPreset(renderer:renderer)
        if let i=EffectsPreset.builtins.firstIndex(of:current) { return EffectsPreset.names[i] }
        return current==savedEffectsPreset ? "Saved Custom":"Custom"
    }
    var savedEffectsPreset: EffectsPreset? {
        guard let data=UserDefaults.standard.data(forKey:"customEffectsPreset.v1") else { return nil }
        return try? JSONDecoder().decode(EffectsPreset.self,from:data)
    }
    var hdrDisplayAvailable: Bool { (window?.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1)>1 }
    func addGraphicsMenus(to menu:NSMenu) {
        func submenu(_ title:String) -> NSMenu {
            let item=NSMenuItem(title:title,action:nil,keyEquivalent:"")
            let child=NSMenu(title:title);item.submenu=child;menu.addItem(item);return child
        }
        let toggle=menu.addItem(withTitle:"Toggle Classic / Medium",action:#selector(toggleClassicMedium),keyEquivalent:"e")
        toggle.target=self;toggle.keyEquivalentModifierMask=[.command,.shift]
        let graphics=submenu("Graphics Presets")
        for (i,title) in ["Performance — 50%, 120 FPS","Balanced — 75%, 120 FPS","Native — 100%, 120 FPS","Quiet — 75%, 60 FPS","Sharp — 150%, 120 FPS","Supersampled — 200%, 60 FPS"].enumerated() {
            let item=graphics.addItem(withTitle:title,action:#selector(selectGraphicsPreset(_:)),keyEquivalent:"");item.tag=i;item.target=self
        }
        menu.addItem(withTitle:"MetalFX Spatial Upscaling",action:#selector(toggleMetalFX),keyEquivalent:"").target=self
        let quality=submenu("Ray Quality")
        for (i,title) in ["Balanced", "High"].enumerated() {
            let item=quality.addItem(withTitle:title,action:#selector(selectRayQuality(_:)),keyEquivalent:"");item.tag=i;item.target=self
        }
        let effects=submenu("Effects Presets")
        for (i,title) in EffectsPreset.names.enumerated() {
            let item=effects.addItem(withTitle:title,action:#selector(selectEffectsPreset(_:)),keyEquivalent:"");item.tag=i;item.target=self
        }
        effects.addItem(.separator())
        effects.addItem(withTitle:"Save Current as Custom",action:#selector(saveEffectsPreset),keyEquivalent:"").target=self
        let custom=effects.addItem(withTitle:"Apply Saved Custom",action:#selector(selectEffectsPreset(_:)),keyEquivalent:"");custom.tag = -1;custom.target=self
        menu.addItem(withTitle:"HDR Display Output",action:#selector(toggleHDR),keyEquivalent:"").target=self
        menu.addItem(withTitle:"HDR Fullbright Sprite Boost",action:#selector(toggleHDRSpriteBoost),keyEquivalent:"").target=self
        let lights=submenu("Added Light Strength")
        for n in [50,100,200] {
            let item=lights.addItem(withTitle:"\(n)%",action:#selector(selectLightGain(_:)),keyEquivalent:"");item.tag=n;item.target=self
        }
        let bloom=submenu("Bloom Strength")
        for n in [6,12,30] {
            let item=bloom.addItem(withTitle:"\(n)%",action:#selector(selectBloomStrength(_:)),keyEquivalent:"");item.tag=n;item.target=self
        }
        let peak=submenu("HDR Highlight Peak")
        for n in [2,4,8] {
            let item=peak.addItem(withTitle:"Up to \(n)× Standard White",action:#selector(selectHDRPeak(_:)),keyEquivalent:"");item.tag=n;item.target=self
        }
        let fog=submenu("Volumetric Density")
        for (n,title) in [(1,"Light Haze"),(3,"Atmospheric"),(6,"Dense"),(10,"Thick")] {
            let item=fog.addItem(withTitle:title,action:#selector(selectFogDensity(_:)),keyEquivalent:"");item.tag=n;item.target=self
        }
        menu.addItem(.separator())
    }
    static let graphicsPresets:[(CGFloat,Int)]=[(0.5,120),(0.75,120),(1,120),(0.75,60),(1.5,120),(2,60)]
    @objc func toggleMetalFX() {
        view.metalFXEnabled.toggle();UserDefaults.standard.set(view.metalFXEnabled,forKey:"metalFXSpatial")
        gameMenu?.refreshDisplay()
    }
    @objc func selectGraphicsPreset(_ sender:NSMenuItem) {
        guard Self.graphicsPresets.indices.contains(sender.tag) else { return }
        let (scale,fps)=Self.graphicsPresets[sender.tag]
        view.renderScale=scale;view.preferredFramesPerSecond=fps
        UserDefaults.standard.set(Double(scale),forKey:"renderScale");UserDefaults.standard.set(fps,forKey:"frameLimit")
    }
    @objc func selectEffectsPreset(_ sender:NSMenuItem) {
        let preset=EffectsPreset.builtins.indices.contains(sender.tag) ? EffectsPreset.builtins[sender.tag]:savedEffectsPreset
        guard let preset else { return }
        applyEffectsPreset(preset)
    }
    func effectsPresetUnavailableReason(_ preset:EffectsPreset) -> String? {
        if shuttingDown { return "Game is closing." }
        if benchmark != nil { return "Wait for the benchmark to finish." }
        if preset.hdr && !hdrDisplayAvailable { return "Requires an HDR display." }
        if (preset.ao || preset.testLight || preset.switches.contains(where: { $0.needsRays })) && !renderer.ambientOcclusionSupported {
            return "Requires Metal ray tracing."
        }
        return nil
    }
    func applyEffectsPreset(_ preset:EffectsPreset) {
        guard effectsPresetUnavailableReason(preset) == nil else { gameMenu?.refreshEffects(); return }
        do {
            try renderer.applyEffectsPreset(preset,view:view)
            sessionLog.append("Effects preset: \(effectsPresetName)")
            renderer.notice="Effects: \(effectsPresetName)";renderer.noticeUntil=CACurrentMediaTime()+2
            gameMenu?.refreshEffects()
        }
        catch { show(error) }
    }
    @objc func toggleClassicMedium() {
        guard !shuttingDown, benchmark == nil, effectsActive || renderer.ambientOcclusionSupported else { return }
        if let event=NSApp.currentEvent, event.type == .keyDown, event.isARepeat { return }
        applyEffectsPreset(EffectsPreset.builtins[effectsActive ? 0:1])
    }
    @objc func saveEffectsPreset() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(EffectsPreset(renderer:renderer)),forKey:"customEffectsPreset.v1") }
        catch { show(error) }
    }
    @objc func toggleHDR() {
        do { try renderer.setHDR(!renderer.hdrEnabled,view:view) } catch { show(error) }
    }
    @objc func toggleHDRSpriteBoost() { renderer.setHDRSpriteBoost(!renderer.hdrSpriteBoost) }
    @objc func selectLightGain(_ sender:NSMenuItem) { renderer.setLightGain(Float(sender.tag)/100) }
    @objc func selectBloomStrength(_ sender:NSMenuItem) { renderer.setBloomStrength(Float(sender.tag)/100) }
    @objc func selectRayQuality(_ sender:NSMenuItem) { renderer.setHighRayQuality(sender.tag==1) }
    @objc func selectHDRPeak(_ sender:NSMenuItem) { renderer.setHDRPeak(Float(sender.tag)) }
    @objc func selectFogDensity(_ sender:NSMenuItem) { renderer.setFogDensity(Float(sender.tag)/1000) }
}
