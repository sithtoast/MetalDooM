// SPDX-License-Identifier: GPL-2.0-or-later
import simd

/// One camera-relative test light. Game tics make motion deterministic and pauseable.
struct DynamicLightUniforms {
    var positionRadius: SIMD4<Float> = .zero
    var colorIntensity: SIMD4<Float> = .zero
    var options: SIMD4<Float> = .zero
    var facing: SIMD4<Float> = .zero // xyz: one-sided emitter normal; zero for point lights

    static func moving(eye: SIMD3<Float>, yaw: Float, tics: Int32, shadows: Bool) -> Self {
        let phase=Float(tics % 280)/280 * 2 * Float.pi
        let forward=SIMD3(cos(yaw),Float(0),-sin(yaw))
        let right=SIMD3(sin(yaw),Float(0),cos(yaw))
        let position=eye+forward*(40+16*cos(phase))+right*(32*sin(phase))+SIMD3(0,12,0)
        return Self(positionRadius:SIMD4(position,256),colorIntensity:SIMD4(1,0.35,0.08,2),
                    options:SIMD4(shadows ? 1:0,0,0,0))
    }
}

/// Session-local switches: none changes the simulation or save format.
enum SceneEffect: Int, CaseIterable {
    case torches, projectiles, muzzleFlash, shadows, emissive, bloom
    case spriteLighting, surfaceLighting, softShadows, particles, volumetrics
    var title: String {
        switch self {
        case .torches: return "Torch & Lamp Lights"
        case .projectiles: return "Projectile Lights"
        case .muzzleFlash: return "Muzzle Flash Light"
        case .shadows: return "Gameplay Light Shadows"
        case .emissive: return "Emissive Surfaces"
        case .bloom: return "Bloom"
        case .spriteLighting: return "Sprite Lighting"
        case .surfaceLighting: return "Emissive Surface Lighting"
        case .softShadows: return "Soft Shadows"
        case .volumetrics: return "Volumetric Lighting"
        case .particles: return "Embers & Projectile Trails"
        }
    }
    var needsRays: Bool { self == .volumetrics || self == .torches || self == .projectiles || self == .muzzleFlash || self == .spriteLighting || self == .surfaceLighting }
}

extension DynamicLightUniforms {
    static let limit=16
    static func gameplay(things: [MD_Thing], hud: MD_HUD, eye: SIMD3<Float>,
                         effects: Set<SceneEffect>) -> [Self] {
        let shadow:Float=effects.contains(.shadows) ? 1:0
        var result:[Self]=[]
        if effects.contains(.muzzleFlash) && hud.weaponFlash != 0 {
            let color:SIMD3<Float> = hud.readyWeapon==5 ? SIMD3(0.2,0.5,1)
                : hud.readyWeapon==6 ? SIMD3(0.2,1,0.25):SIMD3(1,0.6,0.2)
            result.append(Self(positionRadius:SIMD4(eye+SIMD3(0,-4,0),192),
                               colorIntensity:SIMD4(color,2.5),options:SIMD4(shadow,0,0,0)))
        }
        // Nearest sources first; preserve engine order for equal distances.
        var nearby:[(Int,MD_Thing,Float)]=[]
        for (index,thing) in things.enumerated() {
            let decoration=thing.lightKind>0 && thing.lightKind<=3
            let projectile=thing.lightKind>=4 && thing.lightKind<=6
            guard (decoration && effects.contains(.torches)) || (projectile && effects.contains(.projectiles)) else { continue }
            let point=SIMD3<Float>(thing.x,thing.lightZ,-thing.y)
            let distance:Float=simd_length_squared(point-eye)
            if distance<1_048_576 { nearby.append((index,thing,distance)) }
        }
        nearby.sort { lhs,rhs in lhs.2==rhs.2 ? lhs.0<rhs.0:lhs.2<rhs.2 }
        for (_,thing,_) in nearby.prefix(max(0,Self.limit-result.count)) {
            let kind=thing.lightKind, decoration=kind<=3
            let color:SIMD3<Float> = kind==1 || kind==4 ? SIMD3(0.2,0.45,1)
                : kind==2 || kind==5 ? SIMD3(0.2,1,0.25):SIMD3(1,0.35,0.08)
            let phase:Float=Float(hud.levelTics % 350)*0.71 + thing.x*0.03 + thing.y*0.07
            let flicker:Float=decoration ? 0.92+0.08*sin(phase):1
            result.append(Self(positionRadius:SIMD4(thing.x,thing.lightZ,-thing.y,decoration ? 224:176),
                               colorIntensity:SIMD4(color,1.8*flicker),options:SIMD4(shadow,0,0,0)))
        }
        return result
    }
}

/// Conservative original-material families; only their bright texels self-illuminate.
/// Animation frames retain the same family. Unknown custom materials remain classic.
func emissionSettings(_ material: MaterialKey) -> SIMD4<Float> {
    let name=material.name
    if name.hasPrefix("LITE") || name.hasPrefix("TLITE") || name.hasPrefix("GATE") {
        return SIMD4(0.55,1.25,0,0)
    }
    if name.hasPrefix("COMP") {
        return SIMD4(0.3,1.25,1,0)
    }
    if name.hasPrefix("NUKAGE") || name.hasPrefix("LAVA") || name.hasPrefix("FIRE") {
        return SIMD4(0.25,1.25,0,0)
    }
    return .zero
}
