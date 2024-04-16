//
//  ViewController.swift
//  LearningMetalSwift
//
//  Created by eternal on 2024/4/15.
//

import UIKit
import Metal
import MetalKit

class ViewController: UIViewController {
    
    @IBOutlet weak var metalView: MTKView!

    var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        let device = MTLCreateSystemDefaultDevice()!
        renderer = Renderer(device: device, view: metalView)
    }

}

