---
title:  "MBProgressHUD 源码解析"
date:   2017-08-24 17:58:23
categories: [iOS]
tags: [iOS]
comments: true
---

`HUD`在iOS中一般特指“透明提示层”，常见的有[SVProgressHUD](https://github.com/TransitApp/SVProgressHUD)、[JGProgressHUD](https://github.com/JonasGessner/JGProgressHUD)、[Toast](https://github.com/scalessec/Toast)以及本文将要分析的[MBProgressHUD](https://github.com/jdg/MBProgressHUD)。

>本文是基于MBProgressHUD 1.0.0分析的。


#### 1.视图层次

![视图层次](http://upload-images.jianshu.io/upload_images/1136939-989e8b1d03f1ba57.png?imageMogr2/auto-orient/strip%7CimageView2/2/h/480)

图中可以看到视图都是比较简单的。但并不是所有的视图都是可见的，由于使用了自动布局以及intrinsicContentSize，所以label和button有内容时才可见。

#### 2.自定义视图类

上面的所有视图除了标准的UILabel和UIButton之外，主要是几个自定义的视图类：

1. MBRoundProgressView 圆形进度框

属性有：

``` objective_c
//进度值
@property (nonatomic, assign) float progress;

//进度条颜色
@property (nonatomic, strong) UIColor *progressTintColor;

//圆形边框的颜色
@property (nonatomic, strong) UIColor *backgroundTintColor;

//是否是环状的 
@property (nonatomic, assign, getter = isAnnular) BOOL annular;

```

![annular = false](http://upload-images.jianshu.io/upload_images/1136939-b282de4a937766f0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/480)annular = false  ![annular = false preiOS7](http://upload-images.jianshu.io/upload_images/1136939-7aa67112255779a4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)annular = false preiOS7
![annular = true](http://upload-images.jianshu.io/upload_images/1136939-6ee3d0c1224055bc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/480)    annular = true    

这种环形的进度条使用Quartz2D绘制图。

``` objective_c
//获取当前绘图上下文
CGContextRef context = UIGraphicsGetCurrentContext();
    BOOL isPreiOS7 = kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0;
    
if (_annular) {
        // 绘制背景圆形边框
        CGFloat lineWidth = isPreiOS7 ? 5.f : 2.f;
        UIBezierPath *processBackgroundPath = [UIBezierPath bezierPath];
        ...
        CGFloat radius = (self.bounds.size.width - lineWidth)/2;
        CGFloat startAngle = - ((float)M_PI / 2); // -90 degrees
        CGFloat endAngle = (2 * (float)M_PI) + startAngle;
        //使用addArcWithCenter:radius:startAngle:endAngle:clockwise:
        //绘制贝塞尔曲线
        [processBackgroundPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        //使用_backgroundTintColor颜色填充和绘制
        [_backgroundTintColor set];
        //绘制圆环路径
        [processBackgroundPath stroke];
        // 绘制环形进度条
        UIBezierPath *processPath = [UIBezierPath bezierPath];
        ...
        //每次更新process都会在这里重绘，计算endAngle
        endAngle = (self.progress * 2 * (float)M_PI) + startAngle;
        //使用addArcWithCenter:radius:startAngle:endAngle:clockwise:
        //绘制圆形贝塞尔曲线
        [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
        //使用_progressTintColor颜色填充和绘制
        [_progressTintColor set];
        //绘制进度条
        [processPath stroke];
    } else {
        //绘制背景圆形边框
        ...
        //使用_progressTintColor颜色画线
        [_progressTintColor setStroke];
        //使用_backgroundTintColor颜色填充 iOS7之前才起作用
        [_backgroundTintColor setFill];
        CGContextSetLineWidth(context, lineWidth);
        if (isPreiOS7) {
            //iOS7之前使用CGContextFillEllipseInRect方法
            //圆环内有填充颜色
            CGContextFillEllipseInRect(context, circleRect);
        }
        //iOS7之后使用CGContextStrokeEllipseInRect方法
        //圆环内没有填充颜色
        CGContextStrokeEllipseInRect(context, circleRect);
        // 90 degrees
        CGFloat startAngle = - ((float)M_PI / 2.f);
        // 绘制环形进度条
        if (isPreiOS7) {
            //iOS7 之前画的是饼图
            CGFloat radius = (CGRectGetWidth(self.bounds) / 2.f) - lineWidth;
            CGFloat endAngle = (self.progress * 2.f * (float)M_PI) + startAngle;
            [_progressTintColor setFill];
            //绘制饼图
            CGContextMoveToPoint(context, center.x, center.y);
            CGContextAddArc(context, center.x, center.y, radius, startAngle, endAngle, 0);
            CGContextClosePath(context);
            CGContextFillPath(context);
        } else {
            //iOS7之后画的只是圆环线
            UIBezierPath *processPath = [UIBezierPath bezierPath];
            processPath.lineCapStyle = kCGLineCapButt;
            processPath.lineWidth = lineWidth * 2.f;
            CGFloat radius = (CGRectGetWidth(self.bounds) / 2.f) - (processPath.lineWidth / 2.f);
            CGFloat endAngle = (self.progress * 2.f * (float)M_PI) + startAngle;
            ////绘制圆形贝塞尔曲线
            [processPath addArcWithCenter:center radius:radius startAngle:startAngle endAngle:endAngle clockwise:YES];
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            [_progressTintColor set];
            [processPath stroke];
        }
}
```

* MBBarProgressView   长条形进度框

属性有:

``` objective_c
//进度值
@property (nonatomic, assign) float progress;

//边框线颜色  默认是白色
@property (nonatomic, strong) UIColor *lineColor;

//内部空白填充颜色 默认无颜色
@property (nonatomic, strong) UIColor *progressRemainingColor;

//进度条颜色 默认白色
@property (nonatomic, strong) UIColor *progressColor;

```

![MBBarProgressView](http://upload-images.jianshu.io/upload_images/1136939-10c0d528129e5708.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里的绘制也是基于Quartz2D，但是作者写的不够完美，马上会讲到。

``` objective_c

CGContextRef context = UIGraphicsGetCurrentContext();
    
CGContextSetLineWidth(context, 2);
//设置填充颜色 和 画线颜色 ，供下面选用
CGContextSetStrokeColorWithColor(context,[_lineColor CGColor]);
CGContextSetFillColorWithColor(context, [_progressRemainingColor CGColor]);
    
//画背景
CGFloat radius = (rect.size.height / 2) - 2;
//左上角的小圆弧
CGContextMoveToPoint(context, 2, rect.size.height/2);
CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
//上边的边界线
CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
//右上角的小圆弧
CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
//右下角的小圆弧
CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
//下边的边界线
CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
//左下角的小圆弧
CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
//使用_progressRemainingColor颜色填充 产生两头有弧度的中空区域
CGContextFillPath(context);
    
//绘制边界线，路径跟上面完全一样，只不过最后用的是stroke方法
CGContextMoveToPoint(context, 2, rect.size.height/2);
CGContextAddArcToPoint(context, 2, 2, radius + 2, 2, radius);
CGContextAddLineToPoint(context, rect.size.width - radius - 2, 2);
CGContextAddArcToPoint(context, rect.size.width - 2, 2, rect.size.width - 2, rect.size.height / 2, radius);
CGContextAddArcToPoint(context, rect.size.width - 2, rect.size.height - 2, rect.size.width - radius - 2, rect.size.height - 2, radius);
CGContextAddLineToPoint(context, radius + 2, rect.size.height - 2);
CGContextAddArcToPoint(context, 2, rect.size.height - 2, 2, rect.size.height/2, radius);
CGContextStrokePath(context);

//绘制进度条    
CGContextSetFillColorWithColor(context, [_progressColor CGColor]);
radius = radius - 2;
CGFloat amount = self.progress * rect.size.width;
    
// 进度条尾部在中间
if (amount >= radius + 4 && amount <= (rect.size.width - radius - 4)) {
    CGContextMoveToPoint(context, 4, rect.size.height/2);
    CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
    CGContextAddLineToPoint(context, amount, 4);
    CGContextAddLineToPoint(context, amount, radius + 4);
    
    CGContextMoveToPoint(context, 4, rect.size.height/2);
    CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
    CGContextAddLineToPoint(context, amount, rect.size.height - 4);
    CGContextAddLineToPoint(context, amount, radius + 4);
    
    CGContextFillPath(context);
}
    
// 进度条右端的圆弧
else if (amount > radius + 4) {
    CGFloat x = amount - (rect.size.width - radius - 4);
    
    CGContextMoveToPoint(context, 4, rect.size.height/2);
    CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
    CGContextAddLineToPoint(context, rect.size.width - radius - 4, 4);
    CGFloat angle = -acos(x/radius);
    if (isnan(angle)) angle = 0;
    CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, M_PI, angle, 0);
    CGContextAddLineToPoint(context, amount, rect.size.height/2);
    
    CGContextMoveToPoint(context, 4, rect.size.height/2);
    CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
    CGContextAddLineToPoint(context, rect.size.width - radius - 4, rect.size.height - 4);
    angle = acos(x/radius);
    if (isnan(angle)) angle = 0;
    CGContextAddArc(context, rect.size.width - radius - 4, rect.size.height/2, radius, -M_PI, angle, 1);
    CGContextAddLineToPoint(context, amount, rect.size.height/2);
    
    CGContextFillPath(context);
}
    
// 进度条很短 只画左端的圆弧
else if (amount < radius + 4 && amount > 0) {
    CGContextMoveToPoint(context, 4, rect.size.height/2);
    CGContextAddArcToPoint(context, 4, 4, radius + 4, 4, radius);
    CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
    
    CGContextMoveToPoint(context, 4, rect.size.height/2);
    CGContextAddArcToPoint(context, 4, rect.size.height - 4, radius + 4, rect.size.height - 4, radius);
    CGContextAddLineToPoint(context, radius + 4, rect.size.height/2);
    
 CGContextFillPath(context);
}

```

这里作者至少有两个**不够完美**的地方：

1. 绘制边界线的时候，设置了重复的路径，仅仅是因为一个子路径的fill和stroke不可能同时产生效果，谁先调用就展示谁的效果。然而作者可能不记得有`CGContextDrawPath`方法，我们可以完全重复利用子路径，并注释`CGContextFillPath`和`CGContextStrokePath`方法，替换为：

    ``` objective_c
    CGContextDrawPath(context, kCGPathFillStroke);
    ```
2. 与`CGContextAddArcToPoint`类似的还有`CGContextAddArc`方法，区别是前者不仅画一个圆弧，还会从`(x1, y1)' 到 `(x2, y2)' 画一条线。所以，用这个方法就没有必要再用`CGContextAddLineToPoint`方法去画线了，显得多余。

* MBBackgroundView    背景视图

属性有：

``` objective_c
//背景风格。 iOS7以后默认的是高斯模糊背景。
//iOS 7（不包括7）之后的模糊图都是用UIVisualEffectView实现的。
@property (nonatomic) MBProgressHUDBackgroundStyle style;
//背景颜色
@property (nonatomic, strong) UIColor *color;
```

这个类产生了两个对象，一个是大的透明的背景，一个是容纳所有小视图的小背景。

#### 流程图

方法主要就是`Show`和`Hide`, 下面借用其他地方的一张图：

![859001-fe3f0f393bcc3b9c.png](http://upload-images.jianshu.io/upload_images/1136939-76b4dd981f7d9691.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
图片来自网络

初始化的方法都会走到:

``` objective_c
- (void)commonInit {
    // Set default values for properties
    ...
    // Default color, depending on the current iOS version
    ...
    // Transparent background
    ...
    // Make it invisible for now
    self.alpha = 0.0f;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.layer.allowsGroupOpacity = NO;
    
    [self setupViews];
    [self updateIndicators];
    [self registerForNotifications];
}

```

可以看到除了变量初始化之外，主要就是调用了三个方法：
 
* setupViews 
 
 生成所有的视图控件。其中有个`updateBezelMotionEffects`方法，是为了使bezelView可以跟随屏幕倾斜移动。

* updateIndicators

更新indicator样式。每次更新MBProgressHUDMode时都会调用。作者用了简单的if else方式来处理不同的hudModel的indicator样式


在`showUsingAnimation:`方法中还调用了`setNSProgressDisplayLinkEnabled:`方法:

 ``` objective_c
 - (void)setNSProgressDisplayLinkEnabled:(BOOL)enabled {
    // 使用 CADisplayLink来刷新progress, 它会以与显示器的刷新界面相同的频率进行绘图
    if (enabled && self.progressObject) {
        if (!self.progressObjectDisplayLink) {
            self.progressObjectDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateProgressFromProgressObject)];
        }
    } else {
        self.progressObjectDisplayLink = nil;
    }
}
 ```

可以去看看[CADisplayLink与NSTimer的区别](http://www.jianshu.com/p/cf6f87f7b59f)

然后定时地调用`updateProgressFromProgressObject`方法，进而调用各种indicator的`setProgress`方法去重绘。

#### 自动布局

MBProgressHUD里用到`NSLayoutConstraint`来自动布局，主要涉及到的是`updateConstraints`和`updatePaddingConstraints`方法。

大致流程可以描述为：

1. 先移除现有的约束设置
2. bezel始终处于中心位置的约束
3. 确保边界最小空间间隔
4. 确保bezel的最小尺寸
5. bezel是否正方形的约束
6. 上下间隔约束
7. 各subView的约束

其中用到最多的方法就是:

``` objective_c
/* Create constraints explicitly.  Constraints are of the form "view1.attr1 = view2.attr2 * multiplier + constant" 
 If your equation does not have a second view and attribute, use nil and NSLayoutAttributeNotAnAttribute.
 */
+(instancetype)constraintWithItem:(id)view1 attribute:(NSLayoutAttribute)attr1 relatedBy:(NSLayoutRelation)relation toItem:(nullable id)view2 attribute:(NSLayoutAttribute)attr2 multiplier:(CGFloat)multiplier constant:(CGFloat)c;

```

释义以及很清楚了，就不再解释了。


#### 动画

在显示和隐藏HUD的时候有动画效果。
ZoomIn,ZoomOut分别理解为`拉近镜头`,`拉远镜头`
因此MBProgressHUDAnimationZoomIn先把形变缩小到0.5倍,再恢复到原状,产生放大效果。
反之MBProgressHUDAnimationZoomOut先把形变放大到1.5倍,再恢复原状,产生缩小效果。
要注意的是,形变的是整个`MBProgressHUD`,而不是中间可视部分。

动画用到的transform可以参考[CGAffineTransform](http://www.jianshu.com/p/6c09d138b31d)


#### 三个Timer
[转载自J_Knight_](http://www.jianshu.com/p/6a5bd5fd8124)


``` objective_c
@property (nonatomic, weak) NSTimer *graceTimer; //执行一次：在show方法触发后到HUD真正显示之前,前提是设定了graceTime，默认为0
@property (nonatomic, weak) NSTimer *minShowTimer;//执行一次：在HUD显示后到HUD被隐藏之前
@property (nonatomic, weak) NSTimer *hideDelayTimer;//执行一次：在HUD被隐藏的方法触发后到真正隐藏之前
```

* graceTimer：用来推迟HUD的显示。如果设定了graceTime，那么HUD会在show方法触发后的graceTime时间后显示。它的意义是：如果任务完成所消耗的时间非常短并且短于graceTime，则HUD就不会出现了，避免HUD一闪而过的差体验。
* minShowTimer：如果设定了minShowTime，就会在hide方法触发后判断任务执行的时间是否短于minShowTime。因此即使任务在minShowTime之前完成了，HUD也不会立即消失，它会在走完minShowTime之后才消失，这应该也是避免HUD一闪而过的情况。
* hideDelayTimer：用来推迟HUD的隐藏。如果设定了delayTime，那么在触发hide方法后HUD也不会立即隐藏，它会在走完delayTime之后才隐藏。

这三者的关系可以由下面这张图来体现（并没有包含所有的情况）：

![859001-c9f49bfcec64dd0e.png](http://upload-images.jianshu.io/upload_images/1136939-68d6de81256239ba.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)





