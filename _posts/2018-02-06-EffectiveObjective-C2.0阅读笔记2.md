---
title:  "《Effective Objective-C 2.0》 阅读笔记2" 
date:   2018-02-06 17:45:23
categories: [iOS]
tags: [iOS]
comments: true
---

#### 12. 理解消息转发(message forwarding)

紧接着第11条的消息传递机制，如果对象无法解读接收到的消息时就会启动消息转发机制。

向类发送其无法解读的消息时，编译期不会报错，只有运行期才可以检查出来。

消息转发有两个阶段：

（一）动态方法解析
    
对象收到无法解读的消息后，首先调用类的方法：

``` objective_c
+ (BOOL)resolveInstanceMethod:(SEL)selector;//selector是实例方法
+ (BOOL)resolveClassMethod:(SEL)selector;//selector是类方法
```

使用此方法的前提是相关方法的实现代码已经写好，只等着运行的时候动态插在类里面

表示这个类是否能新增一个实例方法来处理这个选择器。

（二）完整的消息转发机制
    
（1）备援接收者
    
当前接收者还有第二次机会能处理未知的选择器，对应的方法如下：
     
``` objective_c
- (id)forwardingTargetForSelector:(SEL)selector;
```
（2）完整消息转发

首先创建NSInvocation对象，把与尚未处理的那条消息有关的全部细节都封于其中，包含选择器、目标以及参数。消息派发系统（message-dispatch system）将调用下面方法来转发消息：

``` objective_c
- (void)forwardInvocation:(NSInvocation *)invocation;
```

实现此方法较为有用的方式是：在出发消息前，先以某种方式改变消息内容，比如追加另外一个参数或者改变选择器等。如果某调用操作不由本类处理，需要调用超类的同名方法，直至NSObject。最后还是不能调用方法，就抛出异常“doesNotRecognizeSelector”。

综上全部的消息转发流程可见下图：


![消息转发全流程](http://upload-images.jianshu.io/upload_images/1136939-3b771b2cc828458d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/960/h/480)
    
#### 13. method swizzling（方法混合）

此方法堪称经典的“黑魔法”。

类似于C++的虚函数表，OC的类也有方法列表，列表项会将选择器的名称映射到方法的实现指针上。比如NSString的几个常用方法映射情况：

![NSString 方法映射表](http://upload-images.jianshu.io/upload_images/1136939-eb7e53a369e3286e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640/h/480)

OC Runtime系统方法可以操作这个表，具体地，开发者可以向其中增加选择器或者交换选择器的实现方法。经过几次改变后的映射表变成如下：

![变换后的NSString方法映射表](http://upload-images.jianshu.io/upload_images/1136939-abbecbe0802ed2de.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/640/h/480)

可见method swizzling可以无需编写子类就可以实现如此强大的功能。

具体的交换代码逻辑如下：

``` objective_c
Method originalMethod = class_getInstanceMethod([NSString Class],@selector(lowercaseString));
Method swappedMethod = class_getInstanceMethod([NSString Class],@selector(uppercaseString));
method_exchangeImplementations(originalMethod, swappedMethod);
```

实际应用中，仅仅交换两个方法的实现是意义不大的，一般我们使用这种手段来为方法新增一些功能，比如埋点。我们需要知道一共调用多少次lowercaseString， 如果我们没个调用的地方都去埋点，就很麻烦也很容易漏掉统计，这时候我们就可以用方法混合技术简单实现。

我们先做一个NSString 的分类 

``` objective_c
@interface NSString (EOCMyAdditions)
- (NSString*)eoc_myLowercaseString;
- @end

@implementation NSString (EOCMyAdditions)
- (NSString *)eoc_myLowercaseString {
    NSString *lowercase = [self eoc_myLowercaseString];
    NSLog(@"%@",lowercase);
    return lowercase;
}
@end
```

注意，这里会让人误解为死循环调用，其实不是，在调用此方法前，已经做过"lowercaseString"与"eoc_lowercaseString"方法的交换了，此时"[self eoc_myLowercaseString]"实际上会调用的是“lowercaseString“。

至此，所有NSString实例调用lowercaseString方法都会输出日志。

#### 14. 理解"类对象"

这个关于OC类对象继承体系与元类的知识点在很多地方都会讲到，详细知识点直接去参考runtime中关于Class类的相关定义。

本节的重点有几个：

1）类型信息查询（introspection，内省），在运行时起检查对象的类型。

   isMemberOfClass可以判断出对象是否是某个特定类的实例； isKindOfClass可以判断出对象是否是某类或者其派生类的实例。还可以使用==操作符来判断对象是否是某类的实例([obj class] == [EOCSomaClass Class])
   
   我们应该尽可能使用内省的方法而非直接比较类对象方法来判断，因为前者可以正确处理那些使用了消息传递机制的对象。比如代理对象(NSProxy)，在此代理对象上调用class方法返回的是代理对象本身而非接受代理的对象类；然而使用isKindOfClass，代理对象就会吧这条消息转发给接受代理的对象。
   
2）类对象结构

OC中每个对象结构体的首个成员是Class类的变量，该变量定义了对象所属的类，称为"is a"指针。Class结构体存放类的“元数据”，其首个变量也是isa指针，说明**Class本身也是Objective-C对象**，这个isa表示类对象是一个“元类”类型的对象。类方法就放在元类中，类似于实例方法放在类对象中一样。

**每个类仅有一个类对象，每个类对象仅有一个元类**

![类继承体系与元类](http://upload-images.jianshu.io/upload_images/1136939-1a292f8258712189.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640/h/480)

#### 15. 用前缀避免命名空间冲突

OC没有namespace机制，需要前缀命名法避免重复符号。

避免命名空间冲突的场景主要有：

1） 类名，一般加上公司、App有关联的前缀名。

2）纯C函数与全局变量，因为它们算作顶级符号，会与其他地方定义的函数或变量重名。

3）使用第三方库(a)再次开发自己的第三方库(b)时，别人在使用你发布的第三方库(b)的应用程序里可能也引 
   入了第三方库(a)，此时应该将b中引入的a库代码上都加上你自己的前缀。
   
#### 16. 提供全能初始化方法

可为对象提供必要信息以便其完成工作的初始化方法叫做“全能初始化方法”。

一个类可能有很多个初始化方法，必须有一个全能初始化方法，让其他所有初始化方法都调用它。

如果子类的全能初始化方法与超类的方法名称不同，那么应该覆写超类的全能初始化方法。如果超类的全能初始化方法不适用于子类，可以覆写超类的方法并在其中抛出异常。

#### 17. 实现description方法

在打印对象信息时用到：

``` objective_c
NSLog(@"%@",obj);
```

可以自定义上述的输出格式。

NSObject还有一个debugDescription方法，此方法是为了自定义控制台po命令时的对象信息输出格式。
我们可能不想把类名与指针地址等信息放在普通的描述信息中，确又想在调试时候能看到他们，就可以实现两个描述方法。NSArray就这这么做的。

#### 18. 尽量使用不可变对象

实际编码时，尽量把对外公布的属性设为只读，而且只在确有必要时才将属性对外公布。当然，我们可以在类的内部实现中再次将这些属性设置为读写的。

在表示各种collection的属性时，可以设为不可变的，然后提供修改方法操作这个collection，内部维持一个可变的collection，返回其拷贝给外部。

#### 19. 使用清晰协调的命名方式

OC方法名一般相对比较冗长，但是却可以相对清晰完整地表达含义，向日常句子一样。

使用OC规范的驼峰命名法。

坚持统一风格。

#### 20. 为私有方法名加前缀

这样容易将私有方法与公有方法区别开来，方便调试。

建议使用p_前缀。

不要用一个单一的下划线做前缀，这是苹果公司预留的。

#### 21. 理解OC错误模型。

OC不像Java那样频繁地抛出异常，因为OC很难做到“异常安全”。在ARC模式下，抛出异常后，那些本应该在作用域末尾释放的对象就不能自动释放了。非ARC模式下，即使在抛出异常之前手动释放资源，但是如果释放的资源太多或者代码执行路径很复杂时，就会使代码和乱。

可以设置编译器标志来实现异常安全代码，即打开-fobjc-arc-exceptions。但这样会引入额外代码，在不抛出异常时，也会执行代码。

所以只有发生了导致crash的严重错误时，才使用异常。

其他不严重的情况，可以使用delegate来处理NSError对象。

#### 22. 理解NSCopying协议

自定义对象要支持拷贝操作，需要实现NSCopying协议，并覆写

``` objective_c
- (id)copyWithZone:(NSZone*)zone;
```

方法，这里的NSZone是历史遗留问题，现在都是default zone，不用管。

同理，如果要获取可变版本的拷贝时，需要遵守NSMutableCopying协议并覆写

``` objective_c
- (id)mutableCopyWithZone:(NSZone*)zone;
```

方法。

拷贝时，有深拷贝与浅拷贝之分。

**深拷贝:** 在拷贝对象本身时，将其底层数据也一并复制过去。
**浅拷贝:** 只拷贝对象本身，不复制其中数据。

Foundation框架中的所有collection类默认情况下都执行浅拷贝

NSSet 有一个深拷贝的初始化方法：

``` objective_c
- (id)initWithSet:(NSArray *)array copyItems:(BOOL)copyItmes;
```



