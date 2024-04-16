//
//  Renderer.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/15.
//

import Foundation
import Metal
import MetalKit

fileprivate func align(_ value: Int, upTo alignment: Int) -> Int {
    ((value + alignment - 1) / alignment) * alignment
}

fileprivate let MaxOutstandingFrameCount = 3

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let view: MTKView
    
    let useIndexedMesh: Bool = true
    let mesh: SimpleMesh
    
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    
    private var frameSemaphore = DispatchSemaphore(value: MaxOutstandingFrameCount)
    private var frameIndex: Int
    
    private var constantsBuffer: MTLBuffer!
    private let constantsSize: Int
    private let constantsStride: Int
    private var currentConstantBufferOffset: Int
    
    private var time: TimeInterval = 0.0
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.view = view
        self.frameIndex = 0
        self.constantsSize = MemoryLayout<simd_float4x4>.size
        self.constantsStride = align(constantsSize, upTo: 256)
        self.currentConstantBufferOffset = 0
        
        let color = SIMD4<Float>(0.0, 0.5, 0.8, 1.0)
        mesh = useIndexedMesh ?
            SimpleMesh(indexedPlanarPolygonSideCount: 11, radius: 250, color: color, device: device) :
            SimpleMesh(planarPolygonSideCount: 11, radius: 250, color: color, device: device)
        
        super.init()
        
        view.device = device
        view.delegate = self
        view.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        makePipeline()
        makeResource()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        frameSemaphore.wait()
        updateConstants()
        
        guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderCommandEncoder?.setRenderPipelineState(renderPipelineState)
        for (i, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: i)
        }
        renderCommandEncoder?.setVertexBuffer(constantsBuffer, offset: currentConstantBufferOffset, index: 2)
        if let indexBuffer = mesh.indexBuffer {
            renderCommandEncoder?.drawIndexedPrimitives(type: mesh.primitiveType, indexCount: mesh.indexCount, indexType: mesh.indexType, indexBuffer: indexBuffer, indexBufferOffset: 0)
        } else {
            renderCommandEncoder?.drawPrimitives(type: mesh.primitiveType, vertexStart: 0, vertexCount: mesh.vertexCount)
        }
        renderCommandEncoder?.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.frameSemaphore.signal()
        }
        
        commandBuffer.commit()
        
        frameIndex += 1
    }
    
    private func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Unable to create default Metal library")
        }
        
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = mesh.vertexDescritor
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")!
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")!
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Error while creating render pipeline state: \(error)")
        }
    }
    
    private func makeResource() {
        var vertexData: [Float] = [
        //    x     y       r    g    b    a
            -100,  -20,    1.0, 0.0, 1.0, 1.0,
             100, -60,    0.0, 1.0, 1.0, 1.0,
             30,  100,    1.0, 1.0, 0.0, 1.0,
        ]
        vertexBuffer = device.makeBuffer(bytes: &vertexData, length: MemoryLayout<Float>.stride * vertexData.count, options: .storageModeShared)
        constantsBuffer = device.makeBuffer(length: constantsStride * MaxOutstandingFrameCount, options: .storageModeShared)
    }
    
    private func updateConstants() {
//        time += 1.0 / Double(view.preferredFramesPerSecond)
        let t = Float(time)
        
//        let pulseRate: Float = 1.5
//        let scaleFactor = 1.0 + 0.5 * cos(pulseRate * t)
//        let scale = SIMD2<Float>(scaleFactor, scaleFactor)
//        let scaleMatrix = simd_float4x4(scale2D: scale)
        
        let rotationRate: Float = 2.5
        let rotationAngle = rotationRate * t
        let rotationMatrix = simd_float4x4(rotateZ: rotationAngle)
        
//        let orbitalRadius: Float = 200
//        let translation = orbitalRadius * SIMD2<Float>(cos(t), sin(t))
//        let translationMatrix = simd_float4x4(translateXY: translation)
        
//        let modelMatrix = translationMatrix * rotationMatrix * scaleMatrix
        let modelMatrix = rotationMatrix
        
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let canvasWidth: Float = 800
        let canvasHeight = canvasWidth / aspectRatio
        let projectionMatrix = simd_float4x4(orthographicProjectionWithLeft: -canvasWidth / 2, top: canvasHeight / 2, right: canvasWidth / 2, bottom: -canvasHeight / 2, near: 0.0, far: 1.0)
        
        var transformMatrix = projectionMatrix * modelMatrix

        currentConstantBufferOffset = (frameIndex % MaxOutstandingFrameCount) * constantsStride
        let constants = constantsBuffer.contents().advanced(by: currentConstantBufferOffset)
        constants.copyMemory(from: &transformMatrix, byteCount: constantsSize)
    }
}
