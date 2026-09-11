// SPDX-License-Identifier: GPL-2.0-or-later
import AppKit

struct EffectsPreset: Codable, Equatable {
    var effects: Set<Int> = []
    var ao=false, testLight=false, testShadows=true, hdr=false
    var strength: Float=0.5, radius: Float=48, density: Float=0.003, peak: Float=4
    var switches: Set<SceneEffect> { Set(effects.compactMap(SceneEffect.init(rawValue:))) }
    static let names=["Classic", "Enhanced", "Atmospheric", "HDR Showcase"]
    static let builtins: [Self] = {
        let enhanced: Set<SceneEffect>=[.torches,.projectiles,.muzzleFlash,.shadows,.emissive,.bloom,.spriteLighting]
        return [Self(),Self(effects:Set(enhanced.map(\.rawValue)),ao:true,strength:0.5,radius:32),
                Self(effects:Set(SceneEffect.allCases.map(\.rawValue)),ao:true),
                Self(effects:Set(SceneEffect.allCases.map(\.rawValue)),ao:true,hdr:true)]
    }()
    init(renderer:Renderer) {
        effects=Set(renderer.sceneEffects.map(\.rawValue));ao=renderer.ambientOcclusionEnabled
        testLight=renderer.dynamicLightEnabled;testShadows=renderer.dynamicLightShadows;hdr=renderer.hdrEnabled
        strength=renderer.aoSettings.strength;radius=renderer.aoSettings.radius
        density=renderer.fogDensity;peak=renderer.hdrPeak
    }
    init(effects:Set<Int>=[],ao:Bool=false,hdr:Bool=false,strength:Float=0.5,radius:Float=48) {
        self.effects=effects;self.ao=ao;self.hdr=hdr;self.strength=strength;self.radius=radius
    }
}

extension App {
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
        let graphics=submenu("Graphics Presets")
        for (i,title) in ["Performance — 50%, 120 FPS","Balanced — 75%, 120 FPS","Native — 100%, 120 FPS","Quiet — 75%, 60 FPS"].enumerated() {
            let item=graphics.addItem(withTitle:title,action:#selector(selectGraphicsPreset(_:)),keyEquivalent:"");item.tag=i;item.target=self
        }
        let effects=submenu("Effects Presets")
        for (i,title) in EffectsPreset.names.enumerated() {
            let item=effects.addItem(withTitle:title,action:#selector(selectEffectsPreset(_:)),keyEquivalent:"");item.tag=i;item.target=self
        }
        effects.addItem(.separator())
        effects.addItem(withTitle:"Save Current as Custom",action:#selector(saveEffectsPreset),keyEquivalent:"").target=self
        let custom=effects.addItem(withTitle:"Apply Saved Custom",action:#selector(selectEffectsPreset(_:)),keyEquivalent:"");custom.tag=4;custom.target=self
        menu.addItem(withTitle:"HDR Display Output",action:#selector(toggleHDR),keyEquivalent:"").target=self
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
    static let graphicsPresets:[(CGFloat,Int)]=[(0.5,120),(0.75,120),(1,120),(0.75,60)]
    @objc func selectGraphicsPreset(_ sender:NSMenuItem) {
        guard Self.graphicsPresets.indices.contains(sender.tag) else { return }
        let (scale,fps)=Self.graphicsPresets[sender.tag]
        view.renderScale=scale;view.preferredFramesPerSecond=fps
        UserDefaults.standard.set(Double(scale),forKey:"renderScale");UserDefaults.standard.set(fps,forKey:"frameLimit")
    }
    @objc func selectEffectsPreset(_ sender:NSMenuItem) {
        let preset=EffectsPreset.builtins.indices.contains(sender.tag) ? EffectsPreset.builtins[sender.tag]:savedEffectsPreset
        guard let preset else { return }
        do { try renderer.applyEffectsPreset(preset,view:view);sessionLog.append("Effects preset: \(effectsPresetName)") }
        catch { show(error) }
    }
    @objc func saveEffectsPreset() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(EffectsPreset(renderer:renderer)),forKey:"customEffectsPreset.v1") }
        catch { show(error) }
    }
    @objc func toggleHDR() {
        do { try renderer.setHDR(!renderer.hdrEnabled,view:view) } catch { show(error) }
    }
    @objc func selectHDRPeak(_ sender:NSMenuItem) { renderer.setHDRPeak(Float(sender.tag)) }
    @objc func selectFogDensity(_ sender:NSMenuItem) { renderer.setFogDensity(Float(sender.tag)/1000) }
}
