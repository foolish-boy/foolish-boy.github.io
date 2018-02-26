---
title:  "《Effective Objective-C 2.0》 阅读笔记5" 
date:   2018-02-09 17:45:23
categories: [iOS]
tags: [iOS]
comments: true
---

#### 43. 掌握GCD及队列的使用时机

解决多线程与任务管理问题，除了GCD，还有NSOperationQueue 技术，即操作队列。操作队列在GCD之前就有，GCD就是基于其中的某些设计原理构建的，而且从iOS4开始，操作队列在底层使用GCD实现的。

GCD是纯C的API， 而操作队列是OC的对象。GCD的任务用块来表示，操作队列的任务是相对重量级的OC对象。

有时候GCD不一定比操作队列更合适。使用NSOperation以及NSOperationQueue的好处有：

1. 取消操作。操作队列可以在运行任务之前在某个NSOperation对象上调用cancel方法。不过已经启动的任务无法取消。而GCD就无法取消任务。
2. 指定操作间的依赖关系。使特定的操作必须在另外一个操作顺利执行完毕后才可以执行。貌似GCD也可以做到这一点！
3. 可以键值观测来监控NSOperation对象属性，比如isCancelled 或者isFinished属性来判断任务状态，这比GCD更为精细。
4. 指定操作优先级。这里的优先级的粒度是操作对象，而GCD的优先级粒度是队列。
5. 重用NSOperation对象。可以自定义NSOperation的子类，实现自己的方法，还可以复用这些类。

#### 44. 使用Dispatch Group机制，根据系统资源状况来执行任务

dispatch group能够把任务分组，调用者可以把将要并发执行的多个任务合为一组，等待这组任务执行完毕，也可以在提供回调函数之后继续执行。这组任务执行完成后，调用者会得到通知。

创建:

``` objective_c
dispatch_group_t dispatch_group_create();
```

任务分组有两个办法：

1:

``` objective_c
void dispatch_group_async(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block);
```

2:

``` objective_c
void dispatch_group_enter(dispatch_group_t group);
void dispatch_group_leave(dispatch_group_t group);
```

还可以使用下面方法等待dispatch group执行完毕：

``` objective_c
long dispatch_group_wait(dispatch_group_t group, dispatch_time_t timeout);
```

timeout可以取常量DISPATCH_TIME_FOREVER。

如果当前线程不想被阻塞，又想在任务组执行完成后收到通知，可以使用下面方法传入一个Block：

``` objective_c
void dispatch_group_notify(dispatch_group_t group, dispatch_queue_t queue, dispatch_block_t block)
```

#### 45. 使用dispatch_once来执行只需要运行一次的线程安全代码

如果没有GCD，我们写单例可能会这样：

``` objective_c
+ (id)sharedInstance {
    static EOCClass *instance = nil;
    @synchronized(self) {
        if (!instance) {
            instance = [[self alloc] init];
        }
    }
    return instance;
}
```

第41条说到这样用同步锁有时候会有问题，也不能保证绝对的线程安全。

GCD提供了更简单更安全的方法：

``` objective_c
+ (id)sharedInstance {
    static EOCClass *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
```

为了保证方法执行一次，每次调用时都要使用完全相同的标记，所以标记要使用static。

这种方法是绝对线程安全的，而且更高效，它没有使用重量级的同步机制，而是用“原子访问”来查询标志，判断对应的代码原来是否执行过。

#### 46. 不要使用dispatch_get_current_queue

这个方法返回当前正在执行代码的队列，但是iOS6.0之后就放弃了此函数。

#### 47. 熟悉系统框架

iOS上用到的一套系统框架称为Cocoa Touch，里面集成了一批常用的框架。

主要的是Foundation框架，像NSObject、NSArray等类都在其中。与其相伴的还有个框架叫做CoreFoundation，其提供C语言的API。无缝桥接(free bridging)技术可以把CoreFoundation中的C语言数据结构与Foundation中的OC 对象相互之间平滑转换。

OC中经常使用C语言级别的API，这样可以绕过OC的运行期系统，提升执行速度。

#### 48.多用块枚举，少用for循环

Objective-C 1.0 使用NSEnumerator遍历。NSEnumerator是个抽象基类，只定义了两个方法：

``` objective_c
- (NSArray *)allObjects;
- (id)nextObject;
```

nextObject返回枚举里下一个对象，每次调用这个方法时，内部迭代器更新，使其下次调用方法时能返回下个对象，等到全部对象都已经返回后，再调用就会返回nil。例如遍历数组：

``` objective_c
NSEnumerator *enumerator = [anArray objectEnumerator];
id object;
while((object = [enumerator nextObject]) != nil) {
    //do something with object
}
```

这种写法通用所有的collection类，而且还有反向枚举器。

Objective-C 2.0 引入了快速遍历功能，即for...in...。

当前Objective-C中最新引入的事基于块遍历。如NSArray提供的方法：

``` objective_c
- (void)enumerateObjectsUsingBlock:(void (^) (id object, NSUInteger idx, BOOL *stop)) block
```

其中，Block的第三个参数stop还可以终止遍历操作，只要*stop = YES。

另外，还可以加入选项掩码：

``` objective_c
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options 
                         usingBlock:(void(^)(id obj, NSUInteger idx, BOOL *stop))block
```

所以，使用块枚举法具有其他遍历方式的优势，还能提供下标、键、值等，而且还有选项开启并发迭代功能。


#### 49. 对自定义其内存管理语义的collection使用无缝桥接

第47条也提到过无缝桥接技术，可以在定义于Foundation框架中的OC类和定义于CoreFoundation框架中的C数据结构之间相互转换。如NSArray与CFArray。看一个例子：

``` objective_c 
NSArray *anArray = @[@1,@2,@3,@4];
CFArrayRef aCFArray = (__bridge CFArrayRef)anNSArray;
```

有三种桥式转换：

1. __bridge

CF和OC对象转化时只涉及对象类型不涉及对象所有权的转化, 即ARC仍然具备这个OC对象的所有权，那上面代码的CF对象就不需要CFRelease。

2. __bridge_retained

常用在将OC对象转化成CF对象，且OC对象的所有权也交给CF对象来管理，即OC对象转化成CF对象时，涉及到对象类型和对象所有权的转化，作用同CFBridgingRetain()。如果上面代码使用这个，就需要在使用完数组之后CFRelease(aCFArray)。

3. __bridge_transfer

与__bridge_retained相反，常用在CF对象转化成OC对象时，将CF对象的所有权交给OC对象，此时ARC就能自动管理该内存,作用同CFBridgingRelease()。


#### 50.构建缓存时选用NSCache而非NSDictionary

NSCache是Foundation框架专门为缓存任务设计的。其优势在于当系统资源要耗尽时，它可以自动删减缓存，而且会使用LRU方式，使用字典就需要自己写这一套复杂的逻辑了。另外，NSCache是线程安全的，而字典不是。

开发者可以操控缓存删减内容的时机，两个与系统资源相关的尺度可供调整，其一是缓存中的对象总数，其二是所有对象的总开销。对象加入缓存时，可以指定开销值。 当对象总数或者开销超过上限时，缓存就可能会删减其中的对象。当然如果计算这个开销值的过程比较复杂，就不适用了。

NSPurgeableData与NSCache搭配起来使用，可以实现自动清除数据。即当NSPurgeabeData对象占用的内存为系统所丢弃时，对象自身也会从缓存中删除。

#### 51.精简initialize和load 的实现方法

OC的类初始化操作可以有initialize和load两种方法。

``` objective_c
+ (void)load
```

对于加入运行期系统中的每个类以及分类来说，必定会调用这个方法而且仅调用一次。

执行load方法时，运行期系统处于“脆弱状态”，因为如果类依赖其他类，但是那个类还没有执行完load。但是往往各个类的载入顺序无法判断。

**注意：**

>1. 如果分类和所属的类都定义了这个方法，则先调用类里面的，再调用分类里的。
2. load方法不像普通方法那样遵从继承规则，如果类本身没有实现load方法，那不管其超类是否实现了此方法，系统都不会调用。
3. 执行子类load方法之前，必定先执行所有超类的load方法。

load方法一定要精简，千万不要做繁杂的操作，更不能等待锁。实际上，除了调试时判断分类是否已经正确载入系统，其他情况下都不应该实现它。

``` objective_c
+ (void)initialize
```

每个类在程序首次使用该类之前调用该方法且仅调用一次。它是运行期系统调用的，不应该代码直接调用。
它与load相似，但区别在：

1. 它是惰性调用的，只有程序使用到相关类时，才会调用。而应用程序必须阻塞并等待所有类的load执行完。
2. 在运行期系统执行它时，是出于正常状态的，此时系统是完整的。
3. 运行期系统能确保initialize方法一定会在线程安全环境中执行，即只有执行initialize的那个线程可以操作类或实例，其他线程都要阻塞等此方法执行完。
4. 它跟普通方法一样遵从继承规则，如果本类没有实现，可以调用超类的方法。

同样，initialize方法也要精简，最好只用来设置内部数据，不要调用其他方法尤其是其他类的方法。

#### 52.别忘记NSTimer会保留其目标对象

例如下面方法创建计时器：

``` objective_c
+ (NSTimer *)scheduleTimerWithTimeInterval:(NSTimeInterval)seconds
                    target:(id)target selector:(SEL)sel 
                    userInfo:(id)userInfo repeats:(BOOL)repeats
```

计时器会保留target对象，等计时器失效时再释放此对象。一次性的计时器在执行完任务后会失效，但若是重复执行模式，那么就要开发者自己调用invalidate方法使计时器失效。这就有可能引入一个保留环问题。
假如计时器作为对象的一个实例变量，计时器的目标对象又是self，那么就会相互持有，除非调用了invalidate方法，但是这是不保证一定被执行到的。
解决这个问题可以扩展一个NSTimer的分类，传递一个block, 把target封装到NSTimer类对象自身。


