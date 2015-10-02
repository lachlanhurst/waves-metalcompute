//
//  ViewController.swift
//  metal-watersimulation
//
//  Created by Lachlan Hurst on 1/10/2015.
//  Copyright © 2015 Lachlan Hurst. All rights reserved.
//

import UIKit
import SceneKit

class ViewController: UIViewController, SCNSceneRendererDelegate {

    
    @IBOutlet var scenekitView: SCNView!
    
    var device:MTLDevice!
    var threadGroupCount:MTLSize!
    var threadGroups: MTLSize!
    var pipelineState: MTLComputePipelineState!
    var defaultLibrary: MTLLibrary! = nil
    var commandQueue: MTLCommandQueue! = nil
    
    var textures:[MTLTexture] = []
    var quadMaterial:SCNMaterial!

    let quadSizeX:Float = 100
    let quadSizeZ:Float = 200
    
    let textureSizeX:Int = 100 * 2
    let textureSizeY:Int = 200 * 2
    
    
    let bytesPerPixel = Int(4)
    let bitsPerComponent = Int(8)
    let bitsPerPixel:Int = 32
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    
    func setupScene() {
        let scene = SCNScene()
        
        let quad = SCNPlane(width: CGFloat(quadSizeX), height: CGFloat(quadSizeZ))
        quadMaterial = quad.materials.first

        let quadNode = SCNNode(geometry: quad)
        //quadNode.rotation = SCNVector4Make(1, 0, 0, -30 * Float(M_PI) / 180)
        scene.rootNode.addChildNode(quadNode)
        
        scenekitView.scene = scene
    }
    
    
    func setupMetal() {
        if self.scenekitView.renderingAPI == SCNRenderingAPI.Metal {
            
            device = scenekitView.device
            
            defaultLibrary = device.newDefaultLibrary()
            commandQueue = device.newCommandQueue()
            
            let kernelFunction = defaultLibrary.newFunctionWithName("waveShader")
            
            do {
                pipelineState = try! device.newComputePipelineStateWithFunction(kernelFunction!)
            }
            
            threadGroupCount = MTLSizeMake(16, 16, 1)
            threadGroups = MTLSizeMake(Int(textureSizeX) / threadGroupCount.width+1, Int(textureSizeY) / threadGroupCount.height + 1, 1)
            
            self.scenekitView.delegate = self
        }
    }
    
    func setupTextures() {
        var rawData0 = [UInt8](count: Int(textureSizeX) * Int(textureSizeY) * 4, repeatedValue: 0)
        var rawData1 = [UInt8](count: Int(textureSizeX) * Int(textureSizeY) * 4, repeatedValue: 0)
        var rawData2 = [UInt8](count: Int(textureSizeX) * Int(textureSizeY) * 4, repeatedValue: 0)
        
        let bytesPerRow = 4 * Int(textureSizeX)
        let bitmapInfo = CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue
        
        let context = CGBitmapContextCreate(&rawData0, Int(textureSizeX), Int(textureSizeY), bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        CGContextSetFillColorWithColor(context, UIColor.blackColor().CGColor)
        CGContextFillRect(context, CGRectMake(0, 0, CGFloat(textureSizeX), CGFloat(textureSizeY)))
        
        let contextB = CGBitmapContextCreate(&rawData1, Int(textureSizeX), Int(textureSizeY), bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        CGContextSetFillColorWithColor(contextB, UIColor.blackColor().CGColor)
        CGContextFillRect(contextB, CGRectMake(0, 0, CGFloat(textureSizeX), CGFloat(textureSizeY)))
        
        let contextC = CGBitmapContextCreate(&rawData2, Int(textureSizeX), Int(textureSizeY), bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        CGContextSetFillColorWithColor(contextC, UIColor.blackColor().CGColor)
        CGContextFillRect(contextC, CGRectMake(0, 0, CGFloat(textureSizeX), CGFloat(textureSizeY)))
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(textureSizeX), height: Int(textureSizeY), mipmapped: false)
        
        let textureA = device.newTextureWithDescriptor(textureDescriptor)
        textureA.label = "A"
        
        let outTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(textureA.pixelFormat, width: textureA.width, height: textureA.height, mipmapped: false)
        let textureB = device.newTextureWithDescriptor(outTextureDescriptor)
        textureB.label = "B"
        let out2TextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(textureA.pixelFormat, width: textureA.width, height: textureA.height, mipmapped: false)
        let textureC = device.newTextureWithDescriptor(out2TextureDescriptor)
        textureC.label = "C"
        
        let region = MTLRegionMake2D(0, 0, Int(textureSizeX), Int(textureSizeY))
        textureA.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData0, bytesPerRow: Int(bytesPerRow))
        textureC.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData1, bytesPerRow: Int(bytesPerRow))
        textureB.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData2, bytesPerRow: Int(bytesPerRow))
        
        self.textures = [textureA,textureB, textureC]
    }
    
    func renderer(renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: NSTimeInterval) {
        
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.computeCommandEncoder()
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        commandQueue = device.newCommandQueue()
        
        commandEncoder.setTexture(textures[0], atIndex: 0)
        commandEncoder.setTexture(textures[1], atIndex: 1)
        commandEncoder.setTexture(textures[2], atIndex: 2)
        
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        //commandBuffer.waitUntilCompleted()
        
        quadMaterial.diffuse.contents = textures[1]
        
        
        let first = textures.removeFirst()
        textures.append(first)

    }
    
    func doSplash(x:Int, y:Int) {
        let bytesPerRow = 4 * 2
        let bitmapInfo = CGBitmapInfo.ByteOrder32Big.rawValue | CGImageAlphaInfo.PremultipliedLast.rawValue
        var rawData = [UInt8](count: 2 * 2 * 4, repeatedValue: 1)
        
        
        let context = CGBitmapContextCreate(&rawData, Int(2), Int(2), bitsPerComponent, bytesPerRow, rgbColorSpace, bitmapInfo)
        CGContextSetFillColorWithColor(context, UIColor.redColor().CGColor)
        CGContextFillRect(context, CGRectMake(0, 0, 2, 2))
        
        let tex0 = textures[0]
        let tex1 = textures[1]
        let tex2 = textures[2]
        
        let region = MTLRegionMake2D(x, y, 2, 2)
        
        tex0.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData, bytesPerRow: bytesPerRow)
        tex1.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData, bytesPerRow: bytesPerRow)
        tex2.replaceRegion(region, mipmapLevel: 0, withBytes: &rawData, bytesPerRow: bytesPerRow)
    }
    
    func doTouches(touches: Set<UITouch>) {
        
        for touch in touches {
            let pt = touch.locationInView(self.scenekitView)
            
            let hits = self.scenekitView.hitTest(pt, options: nil)
            
            for hit in hits {
                var x = Int(hit.localCoordinates.x + quadSizeX/2) * textureSizeX / Int(quadSizeX)
                if x >= textureSizeX - 4 {
                    x = textureSizeX - 4
                }
                
                var y = textureSizeY - Int(hit.localCoordinates.y + quadSizeZ/2) * textureSizeY / Int(quadSizeZ)
                if y >= textureSizeY - 4 {
                    y = textureSizeY - 4
                }
                
                doSplash(x, y: y)
            }
        }
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        doTouches(touches)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        doTouches(touches)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        doSplash(textureSizeX / 2, y: textureSizeY / 2)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupScene()
        setupMetal()
        setupTextures()
        
        scenekitView.backgroundColor = UIColor.lightGrayColor()
        //scenekitView.allowsCameraControl = true
        //scenekitView.debugOptions = .ShowWireframe
        scenekitView.showsStatistics = true
        scenekitView.autoenablesDefaultLighting = true
        
        scenekitView.playing = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

