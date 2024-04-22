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
fileprivate let MaxObjectCount = 16

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let view: MTKView
    
    var vertexDescriptor: MTLVertexDescriptor!
    var cowNode: Node!
    var nodes = [Node]()
    
    private var renderPipelineState: MTLRenderPipelineState!
    private var depthStencilState: MTLDepthStencilState!
    private var samplerState: MTLSamplerState!
    
    private var frameSemaphore = DispatchSemaphore(value: MaxOutstandingFrameCount)
    private var frameIndex: Int
    private var time: TimeInterval = 0
    
    private var constantsBuffer: MTLBuffer!
    private let constantsSize: Int
    private let constantsStride: Int
    
    init(device: MTLDevice, view: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.view = view
        self.frameIndex = 0
        self.constantsSize = MemoryLayout<NodeConstants>.size
        self.constantsStride = align(constantsSize, upTo: 256)
        
        super.init()
        
        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        
        loadAsset()
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
        renderCommandEncoder?.setDepthStencilState(depthStencilState)
        renderCommandEncoder?.setFrontFacing(.counterClockwise)
        renderCommandEncoder?.setCullMode(.back)
        
        for (objectIndex, node) in nodes.enumerated() {
            guard let mesh = node.mesh else {
                continue
            }
            
            renderCommandEncoder?.setVertexBuffer(constantsBuffer, offset: constantBufferOffset(objectIndex: objectIndex, frameIndex: frameIndex), index: 2)
            for (i, meshBuffer) in mesh.vertexBuffers.enumerated() {
                renderCommandEncoder?.setVertexBuffer(meshBuffer.buffer, offset: meshBuffer.offset, index: i)
            }
            
            renderCommandEncoder?.setFragmentTexture(node.texture, index: 0)
            renderCommandEncoder?.setFragmentSamplerState(samplerState, index: 0)
            
            for submesh in mesh.submeshes {
                let indexBuffer = submesh.indexBuffer
                renderCommandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
            }
        }
        
        renderCommandEncoder?.endEncoding()
        
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.frameSemaphore.signal()
        }
        
        commandBuffer.commit()
        
        frameIndex += 1
    }
    
    private func loadAsset() {
        let allocator = MTKMeshBufferAllocator(device: device)
        
        let mdlVertexDescriptor = MDLVertexDescriptor()
        let positionAttribute = mdlVertexDescriptor.vertexAttributes[0]
        let normalAttribute = mdlVertexDescriptor.vertexAttributes[1]
        let textureCoordAttribute = mdlVertexDescriptor.vertexAttributes[2]
        positionAttribute.name = MDLVertexAttributePosition
        positionAttribute.format = .float3
        positionAttribute.offset = 0
        positionAttribute.bufferIndex = 0
        normalAttribute.name = MDLVertexAttributeNormal
        normalAttribute.format = .float3
        normalAttribute.offset = MemoryLayout<SIMD3<Float>>.stride
        normalAttribute.bufferIndex = 0
        textureCoordAttribute.name = MDLVertexAttributeTextureCoordinate
        textureCoordAttribute.format = .float2
        textureCoordAttribute.offset = 2 * MemoryLayout<SIMD3<Float>>.stride
        textureCoordAttribute.bufferIndex = 0
        mdlVertexDescriptor.bufferLayouts[0].stride = 2 * MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
        
        vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mdlVertexDescriptor)
        
        let assetURL = Bundle.main.url(forResource: "spot_triangulated", withExtension: "obj")
        let mdlAsset = MDLAsset(url: assetURL, vertexDescriptor: mdlVertexDescriptor, bufferAllocator: allocator)
        
        mdlAsset.loadTextures()
        
        let meshes = mdlAsset.childObjects(of: MDLMesh.self) as? [MDLMesh]
        guard let mdlMesh = meshes?.first else {
            fatalError("Did not find any meshes in the Model I/O asset")
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [
            .textureUsage : MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode : MTLStorageMode.private.rawValue,
            .origin : MTKTextureLoader.Origin.bottomLeft.rawValue
        ]
        
        var texture : MTLTexture?
        let firstSubmesh = mdlMesh.submeshes?.firstObject as? MDLSubmesh
        let material = firstSubmesh?.material
        if let baseColorProperty = material?.property(with: MDLMaterialSemantic.baseColor) {
            if baseColorProperty.type == .texture, let textureURL = baseColorProperty.urlValue {
                texture = try? textureLoader.newTexture(URL: textureURL, options: options)
            }
        }
        
        let mesh = try! MTKMesh(mesh: mdlMesh, device: device)

        cowNode = Node(mesh: mesh)
        cowNode.texture = texture
        
        nodes = [cowNode]
    }
    
    private func makePipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Unable to create default Metal library")
        }
        
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")!
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")!
        
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            fatalError("Error while creating render pipeline state: \(error)")
        }
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        let samplerDescritor = MTLSamplerDescriptor()
        samplerDescritor.normalizedCoordinates = true
        samplerDescritor.magFilter = .linear
        samplerDescritor.minFilter = .linear
        samplerDescritor.mipFilter = .nearest
        samplerDescritor.sAddressMode = .repeat
        samplerDescritor.tAddressMode = .repeat
        samplerState = device.makeSamplerState(descriptor: samplerDescritor)!
    }
    
    private func makeResource() {
        constantsBuffer = device.makeBuffer(length: constantsStride * MaxObjectCount * MaxOutstandingFrameCount, options: .storageModeShared)
        constantsBuffer.label = "Dynamic Constant Buffer"
    }
    
    private func updateConstants() {
        time += (1.0 / Double(view.preferredFramesPerSecond))
        let t = Float(time)
        
        let cameraPosition = SIMD3<Float>(0, 0, 2)
        let viewMatrix = simd_float4x4(translate: -cameraPosition)
        
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = simd_float4x4(perspectiveProjectionFoVY: .pi / 3, aspectRatio: aspectRatio, near: 0.01, far: 100)
        
        let rotationAxis = normalize(SIMD3<Float>(0, 1, 0))
        let rotationMatrix = simd_float4x4(rotateAbout: rotationAxis, byAngle: t)
        
        cowNode.transform = rotationMatrix * simd_float4x4(translate: SIMD3<Float>(0, -0.5, 0))
        
        for (objectIndex, node) in nodes.enumerated() {
            let transformMatrix = projectionMatrix * viewMatrix * node.worldTransform
            var constants = NodeConstants(modelViewProjectionMatrix: transformMatrix)
            let offset = constantBufferOffset(objectIndex: objectIndex, frameIndex: frameIndex)
            let constantsPointer = constantsBuffer.contents().advanced(by: offset)
            constantsPointer.copyMemory(from: &constants, byteCount: constantsSize)
        }
    }
    
    private func constantBufferOffset(objectIndex: Int, frameIndex: Int) -> Int {
        let frameConstantsOffset = (frameIndex % MaxOutstandingFrameCount) * MaxObjectCount * constantsStride
        let objectConstantOffset = frameConstantsOffset + (objectIndex * constantsStride)
        return objectConstantOffset
    }
}
