//
//  Node.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/17.
//

import Foundation
import Metal
import MetalKit


class Node {
    var mesh: MTKMesh?
    var color = SIMD4<Float>(1, 1, 1, 1)
    var transform: simd_float4x4 = matrix_identity_float4x4

    weak var parentNode: Node?
    private(set) var childNodes = [Node]()

    var worldTransform: simd_float4x4 {
        if let parent = parentNode {
            parent.worldTransform * transform
        } else {
            transform
        }
    }

    init() {}

    init(mesh: MTKMesh) {
        self.mesh = mesh
    }

    func addChildNode(_ node: Node) {
        childNodes.append(node)
        node.parentNode = self
    }

    func removeFromParent() {
        parentNode?.removeChildNode(self)
    }

    private func removeChildNode(_ node: Node) {
        childNodes.removeAll(where: { $0 === node })
    }
}
