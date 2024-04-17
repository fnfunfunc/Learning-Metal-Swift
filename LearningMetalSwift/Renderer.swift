//
//  Renderer.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/15.
//

import Foundation
import Metal
import MetalKit


fileprivate let MaxOutstandingFrameCount = 3

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let view: MTKView
    
    var mesh: MTKMesh!
    
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    
    private var frameSemaphore = DispatchSemaphore(value: MaxOutstandingFrameCount)
    private var frameIndex: Int
    private var time: TimeInterval = 0
    
    private var constantsBuffer: MTLBuffer!
    private let constantsSize: Int
    private let constantsStride: Int
    private var currentConstantBufferOffset: Int
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.view = view
        self.frameIndex = 0
        self.constantsSize = MemoryLayout<simd_float4x4>.size
        self.constantsStride = align(constantsSize, upTo: 256)
        self.currentConstantBufferOffset = 0
        
        super.init()
        
        view.device = device
        view.delegate = self
        view.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        makeResource()
        makePipeline()
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
        renderCommandEncoder?.setFrontFacing(.counterClockwise)
        renderCommandEncoder?.setCullMode(.back)
        renderCommandEncoder?.setVertexBuffer(constantsBuffer, offset: currentConstantBufferOffset, index: 2)
        for (i, meshBuffer) in mesh.vertexBuffers.enumerated() {
            renderCommandEncoder?.setVertexBuffer(meshBuffer.buffer, offset: meshBuffer.offset, index: i)
        }
        
        for submesh in mesh.submeshes {
            let indexBuffer = submesh.indexBuffer
            renderCommandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
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
        let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)!
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")!
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")!
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Error while creating render pipeline state: \(error)")
        }
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    private func makeResource() {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(sphereWithExtent: SIMD3<Float>(1, 1, 1), segments: SIMD2<UInt32>(24, 24), inwardNormals: false, geometryType: .triangles, allocator: allocator)
        
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.vertexAttributes[0].name = MDLVertexAttributePosition
        vertexDescriptor.vertexAttributes[0].format = .float3
        vertexDescriptor.vertexAttributes[0].offset = 0
        vertexDescriptor.vertexAttributes[0].bufferIndex = 0
        vertexDescriptor.vertexAttributes[1].name = MDLVertexAttributeNormal
        vertexDescriptor.vertexAttributes[1].format = .float3
        vertexDescriptor.vertexAttributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.vertexAttributes[1].bufferIndex = 0
        vertexDescriptor.bufferLayouts[0].stride = MemoryLayout<SIMD3<Float>>.stride * 2
        mdlMesh.vertexDescriptor = vertexDescriptor
        
        mesh = try! MTKMesh(mesh: mdlMesh, device: device)
        
        constantsBuffer = device.makeBuffer(length: constantsStride * MaxOutstandingFrameCount, options: .storageModeShared)
        constantsBuffer.label = "Dynamic Constant Buffer"
    }
    
    private func updateConstants() {
        time += (1.0 / Double(view.preferredFramesPerSecond))
        let t = Float(time)
        let modelMatrix = simd_float4x4(rotateAbout: SIMD3<Float>(0, 1, 0), byAngle: t)
        
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let canvasWidth: Float = 5
        let canvasHeight = canvasWidth / aspectRatio
        let projectionMatrix = simd_float4x4(orthographicProjectionWithLeft: -canvasWidth / 2, top: canvasHeight / 2, right: canvasWidth / 2, bottom: -canvasHeight / 2, near: -1.0, far: 1.0)
        
        var transformMatrix = projectionMatrix * modelMatrix

        currentConstantBufferOffset = (frameIndex % MaxOutstandingFrameCount) * constantsStride
        let constants = constantsBuffer.contents().advanced(by: currentConstantBufferOffset)
        constants.copyMemory(from: &transformMatrix, byteCount: constantsSize)
    }
}
