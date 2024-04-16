//
//  SimpleMesh.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/16.
//

import Foundation
import Metal
import MetalKit

class SimpleMesh {
    private static var defaultVertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD4<Float>>.stride
        return vertexDescriptor
    }
    
    let vertexBuffers: [MTLBuffer]
    let vertexDescritor: MTLVertexDescriptor
    let vertexCount: Int
    let primitiveType: MTLPrimitiveType = .triangle
    
    let indexBuffer: MTLBuffer?
    let indexType: MTLIndexType = .uint16
    let indexCount: Int
    
    init(vertexBuffers: [MTLBuffer], vertexDescritor: MTLVertexDescriptor, vertexCount: Int) {
        self.vertexBuffers = vertexBuffers
        self.vertexDescritor = vertexDescritor
        self.vertexCount = vertexCount
        self.indexBuffer = nil
        self.indexCount = 0
    }
    
    init(vertexBuffers: [MTLBuffer], vertexDescritor: MTLVertexDescriptor, vertexCount: Int, indexBuffer: MTLBuffer, indexCount: Int) {
        self.vertexBuffers = vertexBuffers
        self.vertexDescritor = vertexDescritor
        self.vertexCount = vertexCount
        self.indexBuffer = indexBuffer
        self.indexCount = indexCount
    }
    
    convenience init(planarPolygonSideCount sideCount: Int, radius: Float, color: SIMD4<Float>, device: MTLDevice) {
        var positions = [SIMD2<Float>]()
        var colors = [SIMD4<Float>]()
        
        var angle: Float = .pi / 2
        let deltaAngle = (2 * .pi) / Float(sideCount)
    
        for _ in 0..<sideCount {
            positions.append(SIMD2<Float>(radius * cos(angle), radius * sin(angle)))
            colors.append(color)
            positions.append(SIMD2<Float>(radius * cos(angle + deltaAngle), radius * sin(angle + deltaAngle)))
            colors.append(color)
            positions.append(SIMD2<Float>(0, 0))
            colors.append(color)
            
            angle += deltaAngle
        }
        
        let positionsBuffer = device.makeBuffer(bytes: &positions, length: MemoryLayout<SIMD2<Float>>.stride * positions.count, options: .storageModeShared)!
        let colorsBuffer = device.makeBuffer(bytes: &colors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count, options: .storageModeShared)!
        
        self.init(vertexBuffers: [positionsBuffer, colorsBuffer], vertexDescritor: Self.defaultVertexDescriptor, vertexCount: positions.count)
    }
    
    convenience init(indexedPlanarPolygonSideCount sideCount: Int, radius: Float, color: SIMD4<Float>, device: MTLDevice) {
        precondition(sideCount > 2)
        
        var positions = [SIMD2<Float>]()
        var colors = [SIMD4<Float>]()
        
        var angle: Float = .pi / 2
        let deltaAngle = (2 * .pi) / Float(sideCount)
        
        for _ in 0..<sideCount {
            positions.append(SIMD2<Float>(radius * cos(angle), radius * sin(angle)))
            colors.append(color)
            angle += deltaAngle
        }
        positions.append(SIMD2<Float>(0, 0)) // center point
        colors.append(color)
        
        let positionBuffer = device.makeBuffer(bytes: &positions, length: MemoryLayout<SIMD2<Float>>.stride * positions.count, options: .storageModeShared)!
        positionBuffer.label = "Vertex Positions"
        
        let colorBuffer = device.makeBuffer(bytes: &colors, length: MemoryLayout<SIMD4<Float>>.stride * colors.count, options: .storageModeShared)!
        colorBuffer.label = "Vertex Colors"
        
        let count = UInt16(sideCount)
        var indices = [UInt16]()
        for i in 0..<count {
            indices.append(i)
            indices.append(count)
            indices.append((i + 1) % count)
        }
        
        let indexBuffer = device.makeBuffer(bytes: &indices, length: MemoryLayout<UInt16>.stride * indices.count, options: .storageModeShared)!
        indexBuffer.label = "Polygon Indices"
        
        self.init(vertexBuffers: [positionBuffer, colorBuffer], vertexDescritor: Self.defaultVertexDescriptor, vertexCount: positions.count, indexBuffer: indexBuffer, indexCount: indices.count)
    }
}
