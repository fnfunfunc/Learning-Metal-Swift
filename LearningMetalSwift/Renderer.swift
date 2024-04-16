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
    private var renderPipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer!
    
    private var frameSemaphore = DispatchSemaphore(value: MaxOutstandingFrameCount)
    private var frameIndex: Int
    
    private var constantsBuffer: MTLBuffer!
    private let constantsSize: Int
    private let constantsStride: Int
    private var currentConstantBufferOffset: Int
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.view = view
        self.frameIndex = 0
        self.constantsSize = MemoryLayout<SIMD2<Float>>.size
        self.constantsStride = align(constantsSize, upTo: 256)
        self.currentConstantBufferOffset = 0
        
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
        renderCommandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderCommandEncoder?.setVertexBuffer(constantsBuffer, offset: currentConstantBufferOffset, index: 1)
        renderCommandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 6
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
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
            -0.8,  0.4,    1.0, 0.0, 1.0, 1.0,
             0.4, -0.8,    0.0, 1.0, 1.0, 1.0,
             0.8,  0.8,    1.0, 1.0, 0.0, 1.0,
        ]
        vertexBuffer = device.makeBuffer(bytes: &vertexData, length: MemoryLayout<Float>.stride * vertexData.count, options: .storageModeShared)
        constantsBuffer = device.makeBuffer(length: constantsStride * MaxOutstandingFrameCount, options: .storageModeShared)
    }
    
    private func updateConstants() {
        let time = CACurrentMediaTime()
        let speedFactor = 3.0
        let rotationAngle = Float(fmod(speedFactor * time, .pi * 2))
        let rotationMagnitude: Float = 0.1
        var positionOffset = SIMD2<Float>(cos(rotationAngle), sin(rotationAngle)) * rotationMagnitude

        currentConstantBufferOffset = (frameIndex % MaxOutstandingFrameCount) * constantsStride
        let constants = constantsBuffer.contents().advanced(by: currentConstantBufferOffset)
        constants.copyMemory(from: &positionOffset, byteCount: constantsSize)
    }
}
