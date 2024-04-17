//
//  Node.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/17.
//

import Foundation
import Metal
import MetalKit


struct Node {
    var mesh: MTKMesh
    var modelMatrix: simd_float4x4 = matrix_identity_float4x4
}
