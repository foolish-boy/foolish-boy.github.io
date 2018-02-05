---
title:  "《Effective Objective-C 2.0》 阅读笔记1" 
date:   2018-02-05 14:45:23
categories: [iOS]
tags: [iOS]
comments: true
---
#### 1： Objective-C语言起源

Objective-C（以下简称OC）由[SmallTalk](https://zh.wikipedia.org/zh-hans/Smalltalk)语言演化而来。OC采用"消息结构"的语法方式，是一种动态语言。与传统的“函数调用”式语言相比，OC实际执行的动作由运行时而非编译期决定。就好像是“函数调用”式的函数是多态一样。

OC的***对象***总是分配在“堆”上的。但是我们不需要使用 malloc 和 free来分配和释放这些内存，这些工作由OC的“引用计数“自动完成。

#### 2： 在类的头文件中尽量少引用其他头文件

在C语言中我们已经知道这一规则，即“前置声明“（forward declaring）。在不需要知道某个类的详细细节的时候，我们最好在头文件中前置声明该类，然后在实现文件中引用类的头文件。如EPerson类有一个EEmployer的成员：

``` objective_c
//EPerson.h

@class EEmployer;//前置声明
@interface EPerson : NSObject
...
@property (nonatomic, strong) EEmployer *employer;
@end

//EPerson.mm

#import "EPerson.h"
#import "EEmployer.h"

@implementation EPerson
...
@end
```

这样做有几个好处： 一是可以优化编译时间；而是可以避免头文件循环引用。
虽然#import指令可以避免死循环，但意味着有一个类文件无法被正确编译。

#### 3. 多用字面量语法(string literal)

用类似C语言的语法,如：

``` objective_c
NSString *somStr = @"This is a string literal";

NSNumber *someNum = @1;
NSNumber *floatNum = @2.5f;
NSNumber *boolNum = @YES;

NSArray *animals = @[@"cat",@"dog",@"mouse"];

NSDictionary *personDic = @{@"firstName":@"Matt", @"lastName":@"Galloway"};
```

优点：

1. 简洁易读。
2. 编写、修改简单。
3. 对于数组和字典，还可以及早抛出异常。比如其中有nil的元素，字面量语法会直接抛出异常，但普通的alloc方法生成的数组或字典只会截取nil之前的元素，会误导我们。

缺点：

1. 除了字符串以外，字面量语法创建的对象必须属于Foundation框架，不能属于自定义的类。
2. 字面量语法创建的对象是不可变的，若要可变版本的对象，还要复制一份。


#### 4.用类型常量代替宏定义

这点在C语言中就提到过，好处就是利用编译器特性，可以验证类型。

如果常量只用在一个编译单元内，则在其.m文件中用`static const`修饰

如果常量需要全局可见，则在一个头文件中使用extern声明全局变量，并在某一个实现文件中定义其值。这种常量出现在全局符号表中，通常用与之相关的类名做前缀。

#### 5. 枚举类型

``` objective_c
typedef NS_ENUM(NSUInteger, EOCConnectionState) {
    EOCConnectStateDisconnected,
    EOCConnectStateConnecting,
    EOCConnectStateConnected    
}

typedef NS_OPTIONS(NSUInteger, EOCPermittedDirection) {
    EOCPermittedDirectionUp     = 1 << 0,
    EOCPermittedDirectDown      = 1 << 1,
    EOCPermittedDirectLeft      = 1 << 2,
    EOCPermittedDirectRight     = 1 << 3,
}
```

#### 6. 理解"属性"

@synthesize 可以更改默认的实例变量名，但一半不推荐使用，为了使代码可读性更强。

@dynamic 可以阻止编译器自动合成存取方法。而且编译时发现没有定义存取方法，也不会报错，它相信这些方法能在运行期间找到。

* 原子性

用在多线程同时访问一个属性的场景。开发中我们一般都用的是`nonatomic`，原因是原子性要使用同步锁，这种开销比较大，而且在一个线程在连续多次读取某属性值的时候有别的线程在同时改写该值，那么即便将该属性声明为`nonatomic`，还是会读到不同的属性值，因而还是不能保证“线程安全”。若真想实现“线程安全“，还要更深层的锁定机制。

* 读写权限

* 内存管理语义

* 方法名


#### 7. 对象内部尽量直接访问实例变量

直接使用实例变量`_firstName`与使用存取方法`self.firstName`有几个区别：

1). 直接访问实例变量不需要消息转发机制，编译器生成带啊直接访问实例变量所在的内存区域，速度快。

2). 直接访问实例变量不会调用”设置方法“，这样绕过了属性相关的"内存管理语义“，这样不太好。

3). 直接访问实例变量，不会触发KVO通知，也有可能出现问题。

4). 使用属性方法助于断点调试

这种方案是： **写入实例变量时，使用设置方法，读取实例变量时，直接访问**。这样既可以提高读写速度，又可以确保属性的“内存管理语义”。

这个方案注意亮点：

1). 在初始化方法中基本总是应该直接访问实例变量，除非待初始化的变量是声明在超类里，我们又在子类中无法直接访问。

2). 使用了懒加载技术后，都要通过存取方法来访问。

#### 8. 理解“对象等同性”

比较对象时，“==”操作符只是比较两者指针本身，应该使用"isEqual"方法或者对象本身提供的"等同性判断方法"，后者要求受测对象属于同一个类。

NSObject协议中，有两个用于判断等同性的关键方法：

``` objective_c
- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;
```

**如果isEqual方法判定两个对象相等，那么hash方法也必须返回同一个值； 如果两个对象的hash方法返回同一个值，那么isEqual方法未必认为两者相等。**

覆写hash方法时，既要考虑效率也要考虑碰撞率。

一些特定类具有自己的等同性判断方法：

>NSString -> isEqualToString
>NSArray  -> isEqualToArray
>NSDictionary -> isEqualToDictionary

我们可以自己来判断等同性，这样既可以无须检查参数类型，提升检测速度，也使代码更美观易读。

等同性判定有深度之分，比如NSArray可以比较每个元素是否相等(深度等同性判定)，也可以只判定部分数据是否相等。要根据具体需求制定检测方案。

把可变对象放入容器之后，尽量不要再改变对象内容，这样有隐患。


#### 9. 类族模式

类族模式可以隐藏抽象基类背后的实现细节。

“工厂模式”是其中之一。

Cocoa系统框架中有很多类族，如UIKit、NSArray等。

#### 10. 关联对象

这个在做method swizzling的时候会经常用到。

将两个对象关联起来，再别的地方需要用到的时候再读取出来，类似给对象动态添加属性。

关联时要指定存储策略，类似于属性添加内存语义。

UIAlertView是一个好例子：

``` objective_c
- (void)askUserQuestion {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Question" 
    message:"What do you want to do?" delegate:self
    cancelButtonTitle:@"cancel" otherButtonTitle:@"ok", nil];
    
    void (^block)(NSInteger) = ^(NSInteger buttonIndex) {
        if (buttonIndex == 0) {
            [self doCancel];
        } else {
            [self doContinue];
        }
    };
    
    objc_setAssociatedObject(alert, EOCMyAlertViewKey, block, BJC_ASSOCIATION_COPY);
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    void (^block)(NSInteger) = objc_getAssociatedObject(alertView, EOCMyAlertViewKey);
    block(buttonIndex);
}
```

#### 11. 理解消息传递(objc_msgSend)

这个术语我们已经很熟悉了，Objective-C中就是objc_msgSend，使用动态绑定机制，在运行时才决定调用那种方法。

编译器会将所有的消息转换为一条标准的C语言调用：

``` objective_c
void objc_msgSend(id self, SEL cmd, ...);
```

objc_msgSend会依据接受者与选择器的类型来动态调用适当的方法。首先，在接收者所属的类中搜寻“方法列表”，若找到与选择器名称相符合的方法，就跳转至其实现的代码；若找不到，就沿着继承体系继续向上查找；若最终没有找到，就执行“消息转发“(message forwarding)机制。
同时，objc_msgSend会将匹配的结果缓存在类的“快速映射表”中，以后遇到与选择器相同的消息就可以直接执行了。

每个类中有函数指针表（类似于C++中的虚函数表），指针指向函数的实现地址，选择器的名称是查表时用的key。

