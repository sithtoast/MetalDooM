// SPDX-License-Identifier: GPL-2.0-or-later
import simd

/// One camera-relative test light. Game tics make motion deterministic and pauseable.
struct DynamicLightUniforms {
    var positionRadius: SIMD4<Float> = .zero
    var colorIntensity: SIMD4<Float> = .zero
    var options: SIMD4<Float> = .zero

    static func moving(eye: SIMD3<Float>, yaw: Float, tics: Int32, shadows: Bool) -> Self {
        let phase=Float(tics % 280)/280 * 2 * Float.pi
        let forward=SIMD3(cos(yaw),Float(0),-sin(yaw))
        let right=SIMD3(sin(yaw),Float(0),cos(yaw))
        let position=eye+forward*(40+16*cos(phase))+right*(32*sin(phase))+SIMD3(0,12,0)
        return Self(positionRadius:SIMD4(position,256),colorIntensity:SIMD4(1,0.35,0.08,2),
                    options:SIMD4(shadows ? 1:0,0,0,0))
    }
}
