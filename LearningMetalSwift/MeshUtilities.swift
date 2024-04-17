//
//  MeshUtilities.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/16.
//

import MetalKit
import ModelIO

extension MDLVertexDescriptor {
    var vertexAttributes: [MDLVertexAttribute] {
        attributes as! [MDLVertexAttribute]
    }
    
    var bufferLayouts: [MDLVertexBufferLayout] {
        layouts as! [MDLVertexBufferLayout]
    }
}
