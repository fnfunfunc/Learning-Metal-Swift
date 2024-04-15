//
//  ViewController.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/15.
//

import UIKit
import Metal
import MetalKit

class ViewController: UIViewController, MTKViewDelegate {
    
    @IBOutlet weak var metalView: MTKView!

    var device: MTLDevice!
    
    var commandQueue: MTLCommandQueue!

    override func viewDidLoad() {
        super.viewDidLoad()
        device = MTLCreateSystemDefaultDevice()
        metalView.device = device
        metalView.delegate = self
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)
        
        commandQueue = device.makeCommandQueue()!
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        guard let renderPassDescriptor = metalView.currentRenderPassDescriptor else {
            return
        }
        
        let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        
        renderCommandEncoder.endEncoding()
        commandBuffer.present(metalView.currentDrawable!)
        
        commandBuffer.commit()
    }

}

