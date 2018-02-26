---
title:  "《Effective Objective-C 2.0》 阅读笔记3" 
date:   2018-02-07 17:45:23
categories: [iOS]
tags: [iOS]
comments: true
---

#### 23. 通过委托与数据源协议进行对象间通信

我们实际编码时已经经常使用到protocol的技术了（委托代理模式）

定义代理属性时，切记使用weak而非strong，避免“保留环”

``` objective_c
@property (nonatomic, weak) id<EOCSomeDelegate> delegate;
```

#### 24. 将类的实现代码分散到便于管理的几个分类中

为了避免一个实现文件太大，实现的方法太多，可以根据功能将类的实现分到不同的分类中。

EOCPerson类可以分成几个不同的实现文件:

> EOCPerson+Friendship(.h/.m)
> EOCPerson+Work(.h/.m)
> EOCPerson+Play(.h/.m)

如果要使用分类中的方法，记得引入分类的头文件。

这样分散到分类中的好处是：

1. 便于调试，编译后的符号表中，分类中的方法符号会出现分类的名称。
2. 如果将私有方法放在名为Private的分类中，那很容易看到调试错误原因，并且在编写通用库供他人使用时，私有分类的头文件不公开，只能程序库自己能用。

#### 25. 为第三方类的分类名称加前缀

分类机制常用在向无源码的类中新增功能。

将分类方法加入源类的操作是在运行期间系统加载分类时完成的。

如果分类中的方法名称与类中已有的方法名一样，分类中的方法就会覆盖原来的实现。解决办法就是给方法加前缀。

在整个应用程序中，类的每个实例都可以调用分类的方法。

#### 26. 勿在分类中声明属性

除了"class-cotinuation分类"，其他分类都无法向类中新增实例变量，它们无法把实现属性所需的实例变量合成。

当然，使用关联对象可以解决这种无法合成实例变量的问题：

``` objective_c
#import <objc/runtime.h>

static const char *kFriendsPropertyKey = "kFriendsPropertyKey";
@implementation EOCPerson (Friendship)

- (NSArray *)friends {
    return objc_getAssociatedObject(self,kFriendsPropertyKey);
}

- (void)setFriends:(NSArray *)friends {
    objc_setAssociatedObject(self,kFriendsPropertyKey,
                            friends,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
```

但是这样不理想，因为内存管理语义容易出错。万一你修改了属性的内存管理语义，还要记得在设置方法中修改关联对象所用的内存管理语义。所以不推荐这样做。

属性应该都定义在主接口里。分类的目的在于扩展功能，而非封装数据。

#### 27. 使用"class-continuation分类"隐藏实现细节

"class-continuation分类"就是我们常写在实现文件中的这样一段代码：

``` objective_c
@interface EOCPerson ()
//property here
@end
```

这样，可以将方法或者实例变量隐藏在本类中使用，而不暴露给公共接口。

如果属性在主接口中声明为只读，而类内部又要修改属性值，就可以在class-continuation分类中将其扩展为可读写。


#### 28. 通过协议提供匿名对象

协议可以在某种程度上提供匿名类型。具体的对象类型可以淡化成遵守某协议的id类型。

使用匿名对象来隐藏类型名称。

如果具体类型不重要，重要的是对象能够响应特定方法，那么可使用匿名对象来表示。

#### 29. 引用计数

引用计数变为0后“可能”就释放内存了，其实只是放回“可用内存池”，如果没有被覆写之前仍然可以访问，但这是很危险的，因为这样很可能出现野指针，造成程序崩溃。

弱引用避免保留环。

OC的对象生命周期取决于引用计数。

#### 30. 以ARC简化引用计数

ARC是会自动执行retain、release、autorelease的，所以在ARC模式下是不可以直接调用内存管理方法的，具体如下方法：

* retain
* release
* autorelease
* dealloc

实际上，ARC不是通过OC的消息派发机制的，而是直接调用底层的C语言版本比如objc_retain。可以节省很多CPU周期。

若方法名以下列词语开头，则返回的对象归调用者所有, 即调用的代码要负责释放对象。

* alloc
* new
* copy
* mutableCopy

若方法名不以上述四个词语开头，则表示返回的对象不归调用者所有，返回的对象会自动释放。

这些规则所需要的内存管理事宜都有ARC自动处理。

ARC在运行期还可以起到优化作用， 比如在autorelease之后立马又调用retain的场景下，ARC在运行期可以检测这种多余的操作，利用全局数据结构中的一个标志位来决定是否需要真正执行autorelease和retain操作。

ARC只负责管理OC对象的内存，而CoreFoundation对象不归ARC管理，还需要开发者适当调用CFRetain／CFRelease。

#### 31. 在dealloc方法中只释放引用并解除监听

每个对象生命周期结束后最终为系统回收，执行一次且仅一次dealloc方法。

在此方法中释放对象所拥有的所有引用，ARC会自动生成.cxx_destruct方法。

此方法还要做一件重要的事情，就是把配置的observation behavior都清理掉，比如NSNotificationCenter给此对象订阅过某种通知，那么应该在此注销。否则继续给对象发送通知的话会导致crash。

``` objective_c
- (void)dealloc {
    CFRelease(coreFoundationObject);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
```

如果非ARC模式，最后还要调用[super dealloc]，ARC模式下就不需要。

对于开销较大或者系统稀缺的资源（如文件描述符、套接字、大块内存等），应该使用"清理方法"而非dealloc来释放。比如网络连接使用完毕后，调用close方法。
这样做的原因是：

1. 避免保留稀缺资源的时间过长。
2. 系统为了优化程序效率，不保证每个对象的dealloc方法都被执行。

在dealloc中，可以检测资源是否执行了清理操作，没有的话可以输出错误信息并执行一次清理操作。

有些方法不应该在dealloc方法里调用，比如

* 执行异步任务的方法
* 需要切换到特定线程执行的方法
* 属性的存取方法

#### 32. 编写“异常安全代码”时留意内存管理问题

虽然OC中异常只应发生在严重的错误中，但是有时候还是要编写代码来捕获异常。

在捕获异常时要管理好内存，防止泄漏。

比较下面的两种处理方法，明显后者更合适：

（1）
 
 ``` objective_c
@try {
    EOCSomeClass *object = [[EOCSomeClass alloc] init];
    [object doSomethingThatMayThrow];
    [object release];//此处可能执行不到，造成内存泄漏
}
@catch (...) {
    NSLog(@"exception");
}
 ```
 
 （2）
 
 ``` objective_c
 EOCSomeClass *object;
 @try {
    object = [[EOCSomeClass alloc] init];
    [object doSomethingThatMayThrow];
 }
 @catch (...) {
    NSLog(@"exception");
 }
 @finally {
    [object release];//此处总会执行到。
 }
 ```
 
 以上是非ARC模式下的做法，如果是ARC模式也这样try/catch就有很大问题了，因为ARC针对这种情况不会自动处理release，这样做的代价很大。但是ARC还是可以生成安全处理异常所用的代码，只需要打开-fobjc-arc-exceptions编译器标志。
 
 所以，总的来说，如果非ARC模式下必须捕获异常，那就设法保证代码能把对象清理干净； 如果是ARC下必须捕获异常，就要打开-fobjc-arc-exceptions标志。当然，如果发现程序有大量异常捕获操作时，说明你的代码需要重构了。

