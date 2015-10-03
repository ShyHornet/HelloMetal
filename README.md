iOS9在MetalKit中新增了MetalPerformanceShaders类，可以使用GPU进行高效的图像计算，比如高斯模糊，图像直方图计算，索贝尔边缘检测算法等。我最近刚开始学习Metal的使用，并做了一个高斯模糊的例子作为"HelloWorld"程序,下面分享一下我的学习成果~
####注意:运行该程序需要有一个系统版本为iOS9的iOS设备，因为Metal只能在真机上运行。
首先建立工程:
![屏幕快照 2015-10-03 上午10.54.16.png](http://upload-images.jianshu.io/upload_images/727794-d6391af06e604956.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
在`ViewContoller.swift`文件中导入需要的`framework`:
```swift
import MetalKit
import MetalPerformanceShaders
```
如果出现未识别的错误不要担心，把你的设备选到`iOS Device`而不是模拟器，错误就会消失。
导入需要的资源图片到工程里:

![AnimalImage.png](http://upload-images.jianshu.io/upload_images/727794-9d1b3de527549dd1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
只要拖到工程文件夹中就可以了，不需要拖入`Assets.xcassets`中:

![屏幕快照 2015-10-03 上午11.05.07.png](http://upload-images.jianshu.io/upload_images/727794-10146f32805302b3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
打开`Main.storyboard`,拖一个`UISlider`进去，这个用来控制高斯模糊的半径。
最大值设为100:
![屏幕快照 2015-10-03 上午11.08.04.png](http://upload-images.jianshu.io/upload_images/727794-e1d558b42dfe2f66.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240) 
设置好约束:

![屏幕快照 2015-10-03 上午11.09.22.png](http://upload-images.jianshu.io/upload_images/727794-5190a07339bb29e5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![屏幕快照 2015-10-03 上午11.09.36.png](http://upload-images.jianshu.io/upload_images/727794-d7c24b1cd575e3fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![屏幕快照 2015-10-03 上午11.09.50.png](http://upload-images.jianshu.io/upload_images/727794-367de0dfa8023e2a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
最后类似于这样:

![屏幕快照 2015-10-03 上午11.10.49.png](http://upload-images.jianshu.io/upload_images/727794-5976c9c64c2825aa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
向`ViewContoller.swift`文件中拖一个outlet,用来获取模糊半径:

![屏幕快照 2015-10-03 上午11.13.57.png](http://upload-images.jianshu.io/upload_images/727794-e1ee6cfd441aa666.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
还有一个`valueChanged`的监控方法，用来实时改变模糊效果:

![屏幕快照 2015-10-03 上午11.14.26.png](http://upload-images.jianshu.io/upload_images/727794-3250b19a477b65fc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
背景设置为黑色:

![屏幕快照 2015-10-03 下午2.51.24.png](http://upload-images.jianshu.io/upload_images/727794-9aa5f34d1f41d8b9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
然后开始配置我们Metal代码,首先了解一下`MetalPerformanceShaders`的使用流程：
 1. 配置`MTKView`用来承载模糊的结果
 2. 为`MTKView`创建新的命令队列`MTLCommandQueue`
 3. 读取资源数据,创建`MTLTexture`，作为高斯模糊的数据源。
 4. 创建高斯模糊对象
 5. 运行高斯模糊，并绘制结果到`MTKView`
了解了需要哪几步之后我们正式开始写代码,首先添加一些需要的变量:

```swift

    var metalView: MTKView!
    
    var commandQueue: MTLCommandQueue!
    
    var sourceTexture: MTLTexture!
    
```
使`ViewController`遵循`MTKViewDelegate`协议:
```
class ViewController: UIViewController,MTKViewDelegate{
.........
}
```
实现它的两个代理方法:
```
  func drawInMTKView(view: MTKView) {
        
    }
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
```
第一个方法用来绘制我们的`MTKView`，第二个方法在`MTKView`的可绘制区域改变时会调用。

新建一个方法` func setUpMetalView()`来配置`MTKView`,添加以下代码:

```swift
    func setUpMetalView(){
        //设置metalView大小，边框等属性
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
```
新建一个方法` func loadAssets()`,用来加载资源数据等操作:
```
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

```
这里我们自定义了一个`UIImage`的类方法,在`UIImage`的`extension`中添加这个方法:
```
extension UIImage{
    
    class func scaleToSize(image:UIImage,size:CGSize)->UIImage{
        UIGraphicsBeginImageContext(size)
        image.drawInRect(CGRect(origin: CGPointZero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaledImage
        
    
    }

}
```
在`viewDidLoad`方法中调用这两个方法:

```swift

        setUpMetalView()
        loadAssets()

```
到了最后一步了~在`drawInMTKView(view: MTKView)`方法中绘制我们的`metalView`:
 ```swift
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
```
我们在每次滑块滑动后重新绘制`metalView`:
```
@IBAction func blurRadiusDidChanged(sender: UISlider) {
        metalView.setNeedsDisplay()
    }
```
然后应该就可以运行了~结果如下:

![运行结果](http://upload-images.jianshu.io/upload_images/727794-6733bccd6aef2b46.gif?imageMogr2/auto-orient/strip)
当然真机效果比这个要好很多，插上手机亲自试一下吧~
