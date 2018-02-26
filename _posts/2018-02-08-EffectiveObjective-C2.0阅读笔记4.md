---
title:  "《Effective Objective-C 2.0》 阅读笔记4" 
date:   2018-02-08 17:45:23
categories: [iOS]
tags: [iOS]
comments: true
---

#### 33. 用弱引用避免保留环

前面已经提到好多次“保留环”了，顾名思义就是对象之间相互引用，导致都无法释放，内存被泄漏。

避免保留环的最佳方式就是使用弱引用，表示“非拥有关系”。将属性声明为unsafe_unretained。

unsafe_unretained语义同assign等价，只不过assign通常只用于int、float等整体类型，unsafe_unretained多用于对象类型。OC中与ARC相伴的运行期特性weak也是这个语义，但是此类属性在被系统回收后会自动置为nil。

![unsafe_unretained与weak区别](http://upload-images.jianshu.io/upload_images/1136939-4348df6bbee610f8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640/h/480)

#### 34. 以“自动释放池块”降低内存峰值

OC释放对象有两种模式，一是调用release方法，使其保留计数立即减少；另外一种是使用autorelease方法，将其加入自动释放池。 自动释放池存放那些稍后某个时刻(runloop)需要释放的对象。清空自动释放池时，系统会向其中的对象发送release消息。 

语法如下：

``` objective_c
@autoreleasepool {
    //...
}
```

一般情况下我们不需要自己创建自动释放池，因为系统自动创建的线程默认都有自动释放池。只有main函数里，我们通常需要创建自动释放池。理论上，连这里也不是必须要有自动释放池，因为这里就要结束整个程序了，系统会把程序占用的全部内存都清理，但是不写的话，UIApplicationMain函数自动释放的对象就没有池子容纳了，会发出警告信息。

自动释放池可以嵌套，借此可以控制应用程序的内存峰值：

``` objective_c
@autoreleasepool {
    NSString *str = [NSString stringWithFormat:@"1 = %i", 1];
    @autoreleasepool {
        NSNumber *num = [NSNumber numberWithInt:1];
    }
}
```

比如下面这段代码：

``` objective_c
NSArray *databaseRecords = /*...*/
NSMutableArray *people = [NSMutableArray new];
for (NSDictionary *record in databaseRecords) {
    EOCPerson *person = [[EOCPerson alloc] initWithRecord:record];
    [people addObject:person];
}
```

其中初始化函数可能创建一些临时的对象，如果数据库中记录很多，就会有很多不必要的临时对象，它们本来应该提早回收的，却必须等到for循环结束后在主释放池中释放，使内存一瞬间增高和减少。此时可以嵌套一个自动释放池，那些临时对象就会在这个池里及时释放了。

``` objective_c
NSArray *databaseRecords = /*...*/
NSMutableArray *people = [NSMutableArray new];
for (NSDictionary *record in databaseRecords) {
    @autoreleasepool {
        EOCPerson *person = [[EOCPerson alloc] initWithRecord:record];
        [people addObject:person];
    }
}
```

使用autoreleasepool还可以避免无意间误用那些在清空池后已经为系统回收的对象，因为每个自动释放池都有范围，对象出了外围后就不可用了。

自动释放池类似栈，创建好自动释放池后就将其推入栈中，清空自动释放池后相当于从栈中弹出，对象上执行自动释放操作，等于将其放入栈顶的池里。

#### 35. 用“僵尸对象”调试内存管理问题

向已经回收的对象发送消息是不安全的，有时候可行，有时候不可行。可行的情况是要么那块内存没有被其他内容覆写，要么那块内存被另外一个有效且可以接受此消息的对象占用。反正这样做，要么崩溃，要么结果不是预期的。

Cocoa提供了僵尸对象（Zombie Object）功能来调试内存管理问题，启用此功能后，runtime系统会把所有回收的实例转换成僵尸对象，不做真正的回收，而且对象所在的核心内存无法被覆写。这种僵尸对象收到消息后，会抛出异常，并说明发送来的消息以及回收之前的对象信息。

XCode中，选择Edit Scheme->Run->Diagnostics，勾选Enable Zombie Objects选项。一般在遇到EXC_BAD_ACCESS(code=1,address=0x4000)这种错误提示，知道是内存管理问题，但是不知道具体原因，就可以开启僵尸对象功能调试。

为了说明其工作原理，用一段非ARC的代码：

``` objective_c
void printClassInfo(id obj) {
    Class cls = object_getClass(obj);
    Class superCls = object_getSuperclass(cls);
    NSLog(@"===%s : %s ===",class_getName(cls),class_getName(superCls));
}

int main(int argc, char *argv[]) {
    EOCClass *obj = [[EOCClass alloc] init];
    NSLog(@"Before Release");
    printClassInfo(obj);
    
    [obj release];
    NSLog(@"After Release");
    printClassInfo(obj);
}
```

输出结果为：

```
Before Release
===EOCClass : NSObject===
After Release
===_NSZombie_EOCClass : nil ===
```

可以看到对象所属的类已经变成_NSZombie_EOCClass了，其实际上是在运行期生成的，当首次碰到EOCClass类的对象要变成僵尸对象时，就会创建这个类。下面伪代码演示僵尸类如何把待回收的对象转化为僵尸对象。

``` objective_c
Class cls = objc_getClass(self);
const char *clsName = class_getName(cls);
const char *zombieClsName = "_NSZombie_"+clsName;
//see if the specific zombie class exists
class zombieCls = objc_lookUpClass(zombieClsName);
//if not exists,create it.
if(!zombieCls) {
    //obtain the template zombie class called _NSZombie_
    Class baseZombieCls = objc_lookUpClass("_NSZombie_");
    //duplicate the base zombie class
    zombieCls = objc_duplicateClass(baseZombieCls,zombieClsName,0);
}
//perform normal desrtuction of the object being deallocated
objc_destructInstance(self);
//set the class of the object being deallocated to the zombie class
objc_setClass(self, zombieCls);
//the class of self is now _NSZombie_OriginalClass
```

其实runtime如果发现设置了NSZombieEnabled环境变量已设置，就把dealloc方法swizzle到上面代码执行。

系统为每个变为僵尸的类都创建新类的目的是在向僵尸对象发送消息后，系统可以据此知道对象原来所属的类。

创建类由运行期函数objc_duplicateClass()完成，它从名为_NSZombie_的类模版中复制出来，并赋予其新的名字。

僵尸类与NSObject一样没有超类，是个根类。只有一个实例变量isa，不实现任何方法，所以给它的消息都要经过“完整的消息转发机制”。在这个机制中，__forwarding__是核心，它首先检查对象所属的类名，如果前缀为_NSZombie_，就终止程序，并打印一条错误消息，比如：

``` objective_c
*** -[CFString respondsToSelector:]message sent to deallocated instance 0x7ff9e9c080e0
```

这样的消息就对调试很有帮助了。

#### 36. 不要使用retainCount

- (NSUInteger)retainCount;方法是在非ARC时期使用的方法，在ARC模式下被废弃了。

#### 37. 理解"Block"

首先看一个block的定义：

``` objective_c
int (^addBlock)(int a, int b) = ^(int a, int b) {
    return a + b;
};
```

在声明Block的范围里，所有变量都可以被捕获，但是不可以修改，除非变量声明时加上__block修饰符。

Block所捕获的变量如果是对象类型，就会自动保留它，同时，Block本身也可以视为对象，也有引用计数。当最后一个指向块的引用移走之后，块就回收了，回收时也会释放块所捕获的变量。

如果Block定义在Objective-C类的实例方法中，那么除了可以访问类的所有实例变量之外，还可以使用self变量。块总能修改实例变量，所以在声明时无须加__block。如果通过读取或者写入操作捕获了实例变量，那么也会自动把self变量一并捕获了。

``` objective_c
@interface EOCClass 

- (void)anInstanceMethod {
    void (^someBlock)() = ^{
        _anInstanceVariable = @"something";
        NSLog(@"_anInstanceVariable = %@",_anInstanceVariable);
    };
}
```

所以如果self保留了Block,就会导致保留环。

块本身是对象，其内存区域的首个变量仍然是isa。其内存布局如下图

![Block内存布局](http://upload-images.jianshu.io/upload_images/1136939-64f2764f915c9129.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/640/480)

其中，invoke变量实际就是函数指针，执行Block的实现代码，其至少接受一个void*类型的参数代表Block本身，因为在执行时，需要从内存中读取Block捕获的变量；descriptor变量是指向结构体的指针，其中声明了块对象的总体大小，还声明了copy和dispose这两个辅助函数对应的函数指针。copy在拷贝块时执行操作，dispose在丢弃块时执行操作。

Block会把它所捕获的所有变量都拷贝一份。注意拷贝的不是对象本身，而是指向这些对象的指针变量。

定义Block的时候，其占有的内存区域是分配在栈中的，只在定义它的范围内有效。一般会将Block copy到堆上。一旦复制到堆上，Block就变成带引用计数的对象了，后续的copy操作只是递增引用计数了。

除了“栈Block”和"堆Block",还有“全局Block"，全局Block不会捕捉任何状态，运行时也无须有状态参与。Block所使用的整个内存区域，在编译器就完全确定了。全局Block声明在全局内存里。

关于Block的更多原理可以参考我的另外三篇翻译文章：[窥探Blocks 1](https://www.jianshu.com/p/1e4177d6b576)、[窥探Blocks 2](https://www.jianshu.com/p/981325a70689)、[窥探Blocks 3](https://www.jianshu.com/p/93f96c6aa530)

#### 38. 为常用的Block类型创建typedef

``` objective_c
typedef int (^EOCSomeBlock) (BOOL flag, int value);
```

好处是：

1. 可读性强。
2. 修改简单，不必逐处添加／修改参数。

#### 39. 用handler块降低代码分散程度

用委托模式执行异步任务：

``` objective_c
- (void)fetchFooData {
    EOCNetworkFetcher *fetcher = [[EOCNetworkFetcher alloc] initWithURL:url];
    fetcher.delegate = self;
    [fetcher start];
}
...

- (void)networkFetcher:(EOCNetworkFetcher *)networkFetcher didFinishWithData:(NSData *)data {
    //...
}
```

用completionhandler定义为块类型方式执行异步任务：

``` objective_c
- (void)fetchFooData {
     EOCNetworkFetcher *fetcher = [[EOCNetworkFetcher alloc] initWithURL:url];
    [fetcher startWithCompletionHandler:^(NSData *data) {
        //...
    }];
}
```

明显用块写出来的代码更好，其几个优点：

1. 代码更整洁，更集中。
2. 块可以访问获取器范围里的全部变量，无须保存变量和获取器。
3. 委托模式要有多个获取器，就需要在回调方法中来区分。
4. 可以将成功和失败的情况放在一起写。

#### 40. 用块引用其所属对象时不要出现保留环

如果块捕获的对象直接或间接地保留了块本身，就有可能出现保留环问题。

#### 41. 多用GCD队列，少用同步锁

多线程执行同一段代码时，需要同步机制。GCD之前有两种方式：

1. 内置同步块：

``` objective_c
- (void)synchronizedMethod {
    @synchronized(self) {
        //safe
    }
}
```

这大部分可以执行，但是滥用这种同步锁会降低代码效率，也有可能造成死锁。

2. 直接使用NSLock对象

``` objective_c
_lock = [[NSLock alloc] init];
- (void)synchronizedMethod {
    [_lock lock];
    //safe
    [_lock unlock];
}
```

也可以使用NSRecursiveLock这种递归锁，线程能多次持有该锁，不会出现死锁。

使用同步锁虽然可以提供某种程度上的线程安全，但无法保证绝对的线程安全，比如在同一个线程上多次调用获取方法，每次获取的值不一定相同，因为在两次访问之间，其他线程可能会写入新的值。

使用GCD之后可以更简答、更高效的形式加锁，而且可以保证线程安全。比如上述场景就可以使用“串形同步队列”做，把读写操作都放在一个队列里。所有的加锁任务都在GCD中处理，而GCD是在相当深的底层实现的。

串形队列中的块总是按顺序逐个执行，并发队列中的块是随时执行的。如果在并发队列中不想让有些块随时执行，可以使用栅栏。

``` objective_c
- (void)dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block);
- (void)dispatch_barrier_sync(dispatch_queue_t queue, dispatch_block_t block);
```

栅栏只对并发队列有意义，并发队列如果发现接下来要处理的块是个栅栏块，就一直要等当前所有并发块都执行完毕，才会单独执行这个栅栏块，待其执行完毕后，再按照正常方式继续向下处理。

可以在并发队列中使用栅栏，起到同步与异步结合使用的效果。

#### 42. 多用GCD，少用performSelector系列方法

OC的动态性允许开发者在运行时选择调用方法的时机和所在线程。

系列方法有：

``` objective_c
- (id)performSelector:(SEL)selector;
- (id)performSelector:(SEL)selector withObject:(id)object;
- (id)performSelector:(SEL)selector withObject:(id)objectA withObject:(id)objectB;
- (id)performSelector:(SEL)selector withObject:(id)object afterDelay:(NSTimeInterval)delay;
- (id)performSelector:(SEL)selector onThread:(NSThread*)thread withObject:(id)object waitUntilDone:(BOOL)wait;
- (id)performSelectorOnMainThread:(SEL)selector withObject:(id)object waitUntilDone:(BOOL)wait;
```

下面两个方法执行效果相同。

``` objective_c
1.[object performSelector:@selector(selectorName)];
2.[object selectorName];
```

这虽然看上去使用performSelector:比较多余，但如果选择器是运行期决定的，那就体现优势了，比如：

``` objective_c
SEL selector;
if (/*some condition*/) {
    selector = @selector(foo);
} else if (/*other condition*/) {
    selector = @selector(bar);
} else {
    selector = @selector(baz);
}
[object performSelector:selector];
```

这看上去很好，但是在ARC下会收到编译器警告：

> waring: performSelector may cause a leak because its selector is unknow

为什么会可能内存泄漏，因为编译器不知道将要调用的选择器是什么，所以不了解其方法签名和返回值，甚至连是否有返回值都不清楚。而且由于编译器不知道方法名，所以就没有办法运用ARC的内存管理规则来判定返回值是不是应该释放，于是ARC就直接不添加释放操作。

少用performSelector系列方法的其他原因有：
1. 参数值和返回值都是id类型的，这就要求对应传入的参数和返回值必须是对象类型。
2. 最多只能接受两个参数。

那所有这些方法都可以使用GCD的方法替代：dispatch_after, dispatch_async。


