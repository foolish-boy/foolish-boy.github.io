---
title:  "学习Objective-C-（一）-初窥"
date:   2015-12-05 21:24:23
categories: [iOS]
tags: [iOS]
---
iOS中的动画默认是指`Core Animation`，当然还有第三方的比如Facebook的`Pop`等。`Core Animation`是作用在图层`Layer`上的，所以本文分别介绍`Layer`和`Animation`。

###  Layer 与 View ###

![View与Layer关系](http://upload-images.jianshu.io/upload_images/1136939-51c6feba4f43ea62.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

在iOS中，每一个`UIView`背后都有一个`Layer`，这个我们可以通过`view.layer`获得。而`View`是`Layer`的`delegate`。这个`delegate`是这样定义的：

``` obbjective_c
@interface NSObject (CALayerDelegate)
...

/* If defined, called by the default implementation of the
 * -actionForKey: method. Should return an object implementating the
 * CAAction protocol. May return 'nil' if the delegate doesn't specify
 * a behavior for the current event. Returning the null object (i.e.
 * '[NSNull null]') explicitly forces no further search. (I.e. the
 * +defaultActionForKey: method will not be called.) */

- (nullable id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event;

@end
```

`Layer`是真正做显示和动画的，而`View`是一种高级封装，并提供用户交互功能。

**Q:** 既然每个`View`都有一个`Layer`，为什么要分开成两种对象呢，为什么不把这些功能全部放到`View`本身去？

**A:** 这是苹果为了跨平台考虑的。 因为iOS和Mac OS 对用户的交互处理是有很大区别的，一个是多点触控，一个是键盘鼠标。而两者对于界面元素显示和动画处理确是相似的。这样，将`Layer`分离出来可以起到职责分离、代码复用的作用，同时也方便第三方库的开发者。

大家也许注意到了，图中的`Layer`标记为`Root Layer`。我们可以把View本身携带的既创建`View`时创建的`Layer`称为`Root Layer`，相反，把那些单独的`Layer`称为`非Root Layer`。

**Q:** Root Layer 和 非 Root Layer有什么区别？

**A:** 改变一个非Root Layer的可做动画属性(Animatable Property)时，属性值从起点到终点有一个平滑过渡的过程，既`隐式动画`，默认时长是0.25秒。而改变一个Root Layer的可做动画属性时，是直接改变的，没有动画的。我们可以用下面的代码演示改变两种layer的颜色。

``` objctive_c
- (void)changeColor {
    [CATransaction begin];
    //为了方便观察，将时长改为2秒
    [CATransaction setAnimationDuration:2.0];
    
    CGFloat red = arc4random() / (CGFloat)INT_MAX;
    CGFloat green = arc4random() / (CGFloat)INT_MAX;
    CGFloat blue = arc4random() / (CGFloat)INT_MAX;
    //改变 非Root Layer的背景色 会有隐式动画
    self.colorLayer.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:1.0].CGColor;
    //改变 Root Layer的背景色 没有隐式动画
    self.colorView.layer.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:1.0].CGColor;

    [CATransaction commit];
}
```

![改变颜色动画1](http://upload-images.jianshu.io/upload_images/1136939-2043d8858125c51b.gif?imageMogr2/auto-orient/strip)

当然，要想让`Root Layer`改变颜色时有动画也是办法的，我们只需要把它放在一个block中。

``` objective_c
//在block中， 改变 Root Layer的背景色 会有隐式动画
[UIView animateWithDuration:2.0 animations:^{
  self.colorView.layer.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:1.0].CGColor;
}]; 
```
![改变颜色动画 2](http://upload-images.jianshu.io/upload_images/1136939-634c2f3e5d435193.gif?imageMogr2/auto-orient/strip)



这又是为什么呢？

其实，官方文档已经对此有简单的说明。

> The UIView Class disables layer animation by default but reenables them inside animation blocks.

继续死磕，会发现原因跟上面提到的`CALayerDelegate`里面的`actionForLayer:forKey`方法有关。这个方法有三种返回结果：

>1. 返回非空值，既某种行为。这样就是动画效果。
2. 返回nil，不做什么行为，继续去其他地方寻找合适的actions。
3. 返回Null，停止寻找。

至此，我们知道了根因，就是默认情况下，UIview的`actionForLayer:forKey`方法返回nil。而在block中时，返回一个非空值。

### Layer Tree ###

![图层树状结构以及对应的视图层级](http://upload-images.jianshu.io/upload_images/1136939-7d2a2ce51406898f.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

每一个视图都有一个父视图以及若干个子视图，这形成了一个树状的层级关系。对应地，每个视图的图层也有一个平行的层级关系，称之为`图层树(Layer Tree)`。直接创建的或者通过UIView获得的(view.layer)用于显示的图层树,称之为`模型树(Model Tree)`,模型树的背后还存在两份图层树的拷贝,一个是`呈现树(Presentation Tree)`,一个是`渲染树(Render Tree)`。

模型树则可以通过modelLayer属性获得，而呈现树可以通过模型树的layer.presentationLayer获得。模型树的属性值就是我们看到的动画起始和结束时的值，是静态的;呈现树的属性值和动画运行过程中界面上看到的是一致的，是动态的。而渲染树是私有的,你无法访问到,渲染树是对呈现树的数据进行渲染,为了不阻塞主线程,渲染的过程是在单独的进程或线程中进行的,所以你会发现Animation的动画并不会阻塞主线程。

### Layer Property ###

Layer有很多属性，这里强调两个属性：

**anchorPoint**

锚点是按照layer的`bounds`比例取值的，其值是左上角（0，0）到右下角（1，1），默认是（0.5, 0.5）既中心点。形象地，我们可以认为是动画（平移、缩放、旋转）的支点。
下面的动画演示了使用默认的锚点（0.5，0.5）和（0，1）的区别。

![默认锚点(0.5,0.5)，铅笔的中心点在路径上移动](http://upload-images.jianshu.io/upload_images/1136939-4b68c78f7db6e30b.gif?imageMogr2/auto-orient/strip)

![锚点改为(0,1.0)，铅笔的笔尖在路径上移动](http://upload-images.jianshu.io/upload_images/1136939-49ffe31d7d4b904a.gif?imageMogr2/auto-orient/strip)

**position**

`position`有点类似于UIView的`center`，但不总是中心点，它是`anchorPoint`相对于父layer的位置。所以layer的frame不变时，改变anchorPoint也会改变position的值；同样，position不变时，改变anchorPoint值也会改变frame的origin的值。




![anchorPoint与position关系](http://upload-images.jianshu.io/upload_images/1136939-7db6a2ee5437942f.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### Animations ###

动画有`隐式动画`和`显式动画`之分。前面我们以及介绍了`隐式动画`的原理了，接下来主要讲`显式动画`。
`显式动画`就是我们在layer上调用了`addAnimation:forKey`方法。这里一旦一个layer添加了一个动画时，就拷贝了一份Animation对象，所以接下来的对Animation对象的修改只会对后面添加的layer起作用。

动画的基类是`CAAnimation`，它与各派生类的关系见下图：


![CAAnimation 继承关系](http://upload-images.jianshu.io/upload_images/1136939-d8257a03369247d1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们看一个简单的CABasicAnimation的例子，平移一个圆块。

``` objective_c
CABasicAnimation *animation = [CABasicAnimation animation];
animation.keyPath = @"position.x";
animation.fromValue = @0;
animation.toValue = @200;
animation.duration = 1;
[circle.layer animation forKey:@"basic"];
```

![basicAnimation](http://upload-images.jianshu.io/upload_images/1136939-f2e13d94624dfb1a.gif?imageMogr2/auto-orient/strip)


我们发现，动画结束后立马回到原点。 这就牵扯到我们前面提到的`Model Tree`和`Presentation Tree`了。

圆块移动过程中，改变的是`Presentation Tree`的layer属性值，而`Model Tree`的layer值没变，动画结束时默认是删除的，所以又变回`Model Tree`的layer属性值了，既回到原点。解决办法有两个：
* 动画结束后，手动修改Model Tree的layer属性值

``` objective_c
circle.layer.position = CGPointMake(200, 220);
```

* 动画结束时不删除

``` objective_c
animation.fillMode = kCAFillModeForwards;
animation.removedOnCompletion = NO;
```

两种方案都可以使圆块保持在最末端，但推荐第一种，因为第二种没有删除动画，会浪费渲染资源，而且也造成`Model Tree`与 `Presentation Tree`不同步。


### 时间系统 ###

 `CAMediaTiming`是一个协议，控制了动画运行时间相关的系数。`CALayer`与`CAAnimtion`都实现了这个协议。它有一些重要的参数。

* beginTime 
动画开始的延迟时间，相对于父layer的时间。一般取值为

``` objective_c
   layer.beginTime = CACurrentMediaTime() + 延迟的秒数
```

* speed
动画执行的速度，有叠加效果。比如layer的速度是2，父layer的速度是2，那这个layer上动画执行的速度就是4。speed还可以是负值，这会导致动画反向执行。

* repeatCount

动画执行的次数，可以为小数，0.5代表动画执行一般就结束。

* repeatDuration 

动画重复的时长，可以比duration小，那就中途结束。

* timeOffset

可以把动画时间想象成一个圆环，从中间一个位置开始执行，到结尾再循环执行到刚刚开始的地方。

* autoreverses

为True时，动画再反向执行一遍。

* fillMode

动画开始之前或者结束之后的填充行为，默认是`kCAFillModeRemoved`。前面用到的`kCAFillModeForwards`是动画结束之后保持最后状态，`kCAFillModeBackwards`是动画开始之前就保持最开始的状态。

下图可以清晰地看出各个参数的含义，动画演示的是从橘色变成蓝色的过程，横向带变动画时刻。


![CAMediaTiming 参数行为](http://upload-images.jianshu.io/upload_images/1136939-707a3e0e41060dbf.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

特别指出，这里的`speed`为0代表动画暂停，与`timeOffset`一起可以暂停/恢复 动画。
 
``` objctive_c
- (void)pauseAnimation:(CALayer *)layer {
    CFTimeInterval pauseTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0;
    layer.timeOffset = pauseTime;
}

- (void)resumeAnimation:(CALayer *)layer {
    CFTimeInterval pauseTime = [layer timeOffset];
    layer.speed = 1;
    layer.timeOffset = 0;
    layer.beginTime = 0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pauseTime;
    layer.beginTime = timeSincePause;
}
```

![暂停/恢复动画](http://upload-images.jianshu.io/upload_images/1136939-999c49c39e3241c2.gif?imageMogr2/auto-orient/strip)



### CAMediaTimingFunction ###

用于计算起点与终点之间的插值，控制动画的节奏，基本有四种，起变换节奏曲线如下图：


![CAMediaTimingFunction](http://upload-images.jianshu.io/upload_images/1136939-7933d67991d5da16.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### POP ###

[POP](https://github.com/facebook/pop)是facebook开源独立于CoreAnimation的动画方案。与CoreAnimation的区别主要是：

> 1.POP 在动画的任意时刻，可以保持Model Layer与 Presentation Layer同步，CoreAnimation做不到。
2. POP可以应用于任意NSObject对象，CoreAnimation只能应用于CALayer。

基本的POP动画有

* POPBasicAnimation
用法类似于CABasicAnimation。
* POPSpringAnimation
有弹簧效果，节奏曲线如下图：

![POPSpringAnimation节奏曲线](http://upload-images.jianshu.io/upload_images/1136939-40e62b86c457b310.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

可以用`springSpeed`,`springBounciness`等控制弹簧的效果。

* POPDecayAnimation
衰减效果，常见于ScrollView滑动时停止的衰减效果。

* POPCustomAnimation
自定义动画。

### Shimmer ###

[Shimmer](https://github.com/facebook/Shimmer)也是facebook出品的实现闪动效果的动画，iPhone滑动解锁的效果就可以用这个实现。

``` objective_c
shimmerView.contentView = shimmerLabel;
shimmerView.shimmeringOpacity = 0.1;
shimmerView.shimmeringAnimationOpacity = 1.0;
shimmerView.shimmeringBeginFadeDuration = 0.3;
shimmerView.shimmering = YES;
```

![Shimmer动画](http://upload-images.jianshu.io/upload_images/1136939-14102f15d968ad18.gif?imageMogr2/auto-orient/strip)


其原理也很简单，就是添加contentView 作为subView, 然后创建一个CAGradientLayer 作为contentView.layer的mask。移动gradientLayer就可以有这个效果。

### 参考文章 ###
[ios core animation advanced techniques](http://www.ebooksbucket.com/uploads/itprogramming/iosappdevelopment/iOS_Core_Animation_Advanced_Techniques.pdf)

[obj.io](https://www.objc.io/issues/12-animations/)

[controlling-animation-timing](http://ronnqvi.st/controlling-animation-timing/)

[POP 介绍与实践](http://adad184.com/2015/03/11/intro-to-pop/)

[谈谈iOS Animation](http://geeklu.com/2012/09/animation-in-ios/)
