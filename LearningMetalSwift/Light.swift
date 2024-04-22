//
//  Light.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/22.
//

import Foundation

enum LightType: UInt32 {
    case ambient
    case directional
}

class Light {
    var type: LightType = .directional
    var color = SIMD3<Float>(repeating: 1)
    var intensity: Float = 1.0
    var direction = SIMD3<Float>(0, 0, -1)
}
