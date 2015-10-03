//
//  ViewController.swift
//  HelloMetal
//
//  Created by codeGlider on 15/10/3.
//  Copyright © 2015年 codeGlider. All rights reserved.
//

import UIKit
import MetalKit
import MetalPerformanceShaders

class ViewController: UIViewController,MTKViewDelegate{

    @IBOutlet weak var blurRadius: UISlider!
    
    var metalView: MTKView!
    
    var commandQueue: MTLCommandQueue!
    
    var sourceTexture: MTLTexture!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMetalView()
        loadAssets()
       
    }
    func setUpMetalView(){
        metalView = MTKView(frame: CGRect(origin: CGPointZero, size: CGSize(width: 300, height: 300)))
        metalView.center = view.center
        metalView.layer.borderColor = UIColor.whiteColor().CGColor
        metalView.layer.borderWidth = 5
        metalView.layer.cornerRadius = 20
        metalView.clipsToBounds = true
        view.addSubview(metalView)

        
        
        //读取默认设备.
        metalView.device = MTLCreateSystemDefaultDevice()
        
        //确保当前设备支持MetalPerformanceShaders
        guard let metalView = metalView where MPSSupportsMTLDevice(metalView.device) else {
            print("该设备不支持MetalPerformanceShaders!")
            return }
        
        
        
        //配置MTKview属性
        metalView.delegate = self
        metalView.depthStencilPixelFormat = .Depth32Float_Stencil8
        
        // 设置输入/输出数据的纹理(texture)格式
        metalView.colorPixelFormat = .BGRA8Unorm
        
        //将`currentDrawable.texture`设置为可写
        metalView.framebufferOnly = false
    
    
    }
    func loadAssets() {
        // 创建新的命令队列
        commandQueue = metalView.device!.newCommandQueue()
        
        //设置纹理加载器
        let textureLoader = MTKTextureLoader(device: metalView.device!)
        //对图片进行加载和设置
        let image = UIImage(named: "AnimalImage")
        //处理后的图片是倒置，要先将其倒置过来才能显示出正图像
        let mirrorImage = UIImage(CGImage: (image?.CGImage)!, scale: 1, orientation: UIImageOrientation.DownMirrored)
        //将图片调整至所需大小
        let scaledImage = UIImage.scaleToSize(mirrorImage, size: CGSize(width:600, height: 600))
        
        let cgimage = scaledImage.CGImage
        
        
        // 将图片加载到 MetalPerformanceShaders的输入纹理(source texture)
        do {
            
            sourceTexture = try textureLoader.newTextureWithCGImage(cgimage!, options: [:])
            
            
        }
        catch let error as NSError {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
     
    }
    // MARK: MTKViewDelegate
    func drawInMTKView(view: MTKView) {
        //得到MetalPerformanceShaders需要使用的命令缓存区
        let commandBuffer = commandQueue.commandBuffer()
        
        // 初始化MetalPerformanceShaders高斯模糊，模糊半径(sigma)为slider所设置的值
        let gaussianblur = MPSImageGaussianBlur(device: view.device!, sigma: self.blurRadius.value)
        
        // 运行MetalPerformanceShader高斯模糊
        gaussianblur.encodeToCommandBuffer(commandBuffer, sourceTexture: sourceTexture, destinationTexture: view.currentDrawable!.texture)
        
        
        // 提交`commandBuffer`
        commandBuffer.presentDrawable(view.currentDrawable!)
        commandBuffer.commit()
    }
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    @IBAction func blurRadiusDidChanged(sender: UISlider) {
        metalView.setNeedsDisplay()
    }

}
extension UIImage{
    
    class func scaleToSize(image:UIImage,size:CGSize)->UIImage{
        UIGraphicsBeginImageContext(size)
        image.drawInRect(CGRect(origin: CGPointZero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage
        
        
    }
    
}
