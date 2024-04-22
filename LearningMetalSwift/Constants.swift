//
//  NodeConstants.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/20.
//

import Foundation
import simd

struct LightConstants {
    var intensity: simd_float3
    var direction: simd_float3
    var type: UInt32
}

struct NodeConstants {
    var modelViewMatrix: simd_float4x4
}

struct FrameConstants {
    var projectionMatrix: simd_float4x4
    var lightCount: UInt32
}
