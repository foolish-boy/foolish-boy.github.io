---
title:  "学习Objective-C-（二）-重拾"
date:   2016-04-13 11:24:23
categories: [iOS]
tags: [iOS]
---
![objective-c](http://upload-images.jianshu.io/upload_images/1136939-b8820371e0d6b9bc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

本文绝大部分知识将是参考[Learn Objective-C](http://cocoadevcentral.com/d/learn_objectivec/)的。

**1. 调用成员方法**

在OC中，调用成员方法其实就是给对象发送一个消息。基本的语法是：

``` objective_c
[object method];
[object methodWithParam:param];
```

方法可以有返回值：

``` objective_c
output = [object method];
output = [object methodWithParam:param];
```

我们也可以用类本身而不是实例来调用方法，即类方法，声明时在最前面用`+`号表示。下面的例子中，string是类`NSString`的类方法，返回一个`NSString`对象。

``` objective_c
id myObject = [NSString string];
```

其中，`id`表示myObject可以指向任意类型的对象，类似于C语言中的void*。这是OC中动态绑定的基础，编译器是不知道myObject的类型的，只有在运行时才能判断。关于动态绑定和多态，将在本文最后讲解。

当然，这里可以使用静态类型，即制定myObject的类型。

``` objective_c
NSString* myString = [NSString string];
```

注意，所有的OC实例变量都是指针类型的，由于`id`是预编译为指针类型，所以不用显示表示。

在OC中，支持嵌套消息。

``` objective_c
［NSString stringWithFormat: [prefs format]];
```

考虑可读性，尽量避免一行中超过两层的消息嵌套。

OC中多参数的方法用冒号分成几段，比如一个方法的声明是：

``` objective_c
-(BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
```

那么调用方式：

``` objective_c
BOOL res = [myData writeToFile:@"/tmp/log.txt" atomically:NO];
```

在运行时系统中，这个方法的名字是：

``` objective_c
writeToFile:atomically:
```

这个方法名和一般的C函数有很大区别了，注意两个冒号。

**2. 访问成员**

OC中的成员变量默认都是私有的，所以需要用访问方法来获取/设置它们的值。一般有两种方式，最原始的是：

``` objective_c
[photo setCaption:@"Day at th Beach"];
cap = [photo caption];
```

第二行的caption不是直接取成员变量，而是调用一个叫caption的方法。
另外一种简单的方式是用点操作符：

``` objective_c
photo.caption = @"Day at the Beach";
cap = photo.caption;
```

在一个工程里面，最好统一一种方式。***第二种方式只能用于`setter`和`getter`***

**3. 创建对象**

前面讲到，创建一个对象可以用下面的方法：

``` objective_c
NSString* myString = [NSString string];
```

实际上许多时候，我们创建一个对象是这样做的：

``` objective_c
NSString* myString = [[NSString alloc] init];
```
两者的区别是前者创建的是`autoreleased`对象，可以自动释放，
而后者需要手动释放。详见下面的内存管理。

**4. 基本的内存管理**

如果手动用`alloc`方式创建对象，你需要释放它，但是你不能手动释放一个`autoreleased`对象，那将会是程序崩溃。

``` objective_c
    // string1 will be released automatically
    NSString* string1 = [NSString string];
    // must release this when done
    NSString* string2 = [[NSString  alloc] init];
    [string2 *release*];
```

**5. 类的设计与实现**

例如一个类的头文件photo.h，声明了类名、基类、成员变量或方法。

``` objective_c
    #import <Cocoa/Cocoa.h>
    @interface Photo : NSObject
    {
      NSString* caption;
      NSString* photographer;
    }
    -(NSString*) caption; //getter
    -(NSString*) photographer;//getter
    -(void) setCaption: (NSString*)input;//setter
    -(void) setPhotographer: (NSString*)input;//setter
    @end
```

对应的实现文件是photo.m:
    
``` objective_c
#import <Cocoa/Cocoa.h>
#import "Photo.h"
@implementation Photo
-(NSString*) caption {
 	return caption;
}
-(NSString*) photographer {
	return photographer;
}
-(void) setCaption : (NSString*)input {
	[caption autorelease];
	caption = [input retain];
}
-(void) setPhotographer : (NSString*)input {
	[photographer autorelease];
	photographer = [input retain];
}
@end
```


如果在一个垃圾可回收的环境中，我们可以直接赋值。

``` objective_c
- (void) setCaption: (NSString*)input { 
	caption = input;
} 
```

但是如果不能垃圾回收，需要`release`旧的对象，并`retain`新对象。
通常有两种方式来释放一个对象：`release`和`autorelease`。标准的`release`会立即删除引用，而`autorelease`会在将来某个时候才删除，一般会保持到当前函数结束，除非你显示改变它。
在`setter`中，`autorelease`方法更安全，因为有时候你不想在`retain`的时候立马`release`。关于内存管理的详细知识将在下文说明。

我们可以给我们的实例变量创建一个初始化方法。

``` objective_c
- (id) init 
{ 
	if ( self = [super init] ) {
        [self setCaption:@"Default Caption"]; 
        [self setPhotographer:@"Default Photographer"]; 
  	}
  	return self;
}
```

对应地，有dealloc方法：

``` objective_c
- (void) dealloc 
{ 
  	[caption release]; 
    [photographer release];
    [super dealloc];
}
```

类似于C＋＋中的析构函数，先`release`所有子对象，最后要`release`超类对象，否则会有内存泄漏。同样，如果有垃圾回收功能，就不用调研`dealloc`方法了。

**6. 详解内存管理**

OC的内存管理机制叫做引用计数。你要做的就是追踪你的引用。`alloc`和`retain`都会增加一次计数，`release`会减少一次计数。

![reference conunting](http://upload-images.jianshu.io/upload_images/1136939-b134b569e317fd57.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
实际上，创建一个对象通常有两种原因，一是维护一个成员变量，二是在函数中临时使用。
大部分情况，一个成员变量的`setter`方法会`autorelease`老对象，并且`retain`新对象，你只需要保证在`dealloc`方法中`release`这个新对象。
那么，对于函数中的临时变量，只有一个规则：

 >如果你用alloc或者copy创建一个对象，那就在函数结束时给对象发送release或者autorelease；如果用其他方法创建，Do Nothing!

下面是管理一个成员变量例子：

``` objective_c
-(void) setTotalAmount : (NSNumber*) input
{
	[totalAmount autorelease];
    totalAmount = [input retain];
}
-(void) dealloc
{
	[totalAmount release];
   	[super dealloc];
}
```
下面是局部变量的例子：

``` objective_c
NSNumber* value1 = [[NSNumber alloc] initWithFloat:8.75];
NSNumber* value2 = [NSNumber numberWithFloat:14.78];

//only release value1, not value2
[value1 release];
```

只需要release用alloc创建的对象。

**7. Logging**

OC中的NSLog()函数类似于C语言的printf()，不同的是有个%@格式符，针对对象的。

``` objective_c
NSLog( @"The current date and time is: %@", [NSDate date] );
```

**8. 操作Nil对象**

OC中的nil对象功能同其他语言中的空指针NULL一样，区别是OC可以调用nil对象的方法而不崩溃。所以即使不事先检查nil，直接调用方法也没问题，只是返回的对象是nil。
基于这种特性我们可以把dealloc写的更好：

``` objective_c
-(void) dealloc 
{
	self.caption = nil;
	self.photographer = nil;
	[super dealloc];
}
```

这种方法也是可行的，因为其相当于setter方法retain nil,而且release老的对象。这样的好处是，不会出现野指针。

>注意，这里用self.caption = nil而不是直接caption = nil;因为前者是用setter方法的，会管理好内存，而后者会造成内存泄漏。

**9. 范畴(Categories)**

`Categories`是OC最有用的特性之一。`Categories`可以允许你扩展一个已经存在的类，比如添加方法，而不需要你派生一个子类，也不需要知道这个类的具体实现细节。
当然，你可以对所有内置类添加方法。比如，我们要添加一个方法到`NSString`类中，用来判断内容是否是一个URL：

``` objective_c
#import <Cocoa/Cocoa.h>
@interface NSString  (Utilities)
-(BOOL) isURL;
@end
```
声明一个categories的方式与声明一个类十分相似，区别是没有基类列表，而且在括号中声明categories名。
下面是实现的代码，这里只是为了展示categories的用法，重点不是实现判断函数。

``` objective_c
#import "NSString-Utilities.h"
@implementation NSString (Utilities)
-(BOOL) isURL {
	if ( [self hasPrefix:@"http://"] )
		return YES;
	return NO;
}
```

现在我们可以对所有的NSString实例使用这个方法了：

``` objective_c
NSString* string1 = @"http://pixar.com/";
NSString* string2 = @"Pixar";
if ( [string1 isURL] )
	NSLog (@"string1 is a URL");
if ( [string2 isURL] )
	NSLog (@"string2 is a URL"); 
```

>注意，categories不能添加成员变量，但是可以覆盖已有的方法。
一旦你用categories改变了一个类，那么它会影响到整个应用程序中该类的实例。

**10. Self & Super**

`self` 是类的隐藏参数，指向当前调用方法的这个类的实例。而 `super` 是一个 `Magic Keyword`，它本质是一个编译器标示符，和 `self` 是指向的同一个消息接受者。在一个子类中不管调用`[self class]`还是`[super class]`，接受消息的对象都是子类对象。而不同的是，`super`是告诉编译器，调用 class 这个方法时，要去父类的方法，而不是本类里的。所以通常情况的`init`方法实现时，会先用`[super init]`，此时消息的接受者还是本类，只是`init`方法先调用父类的而已：

``` objective_c
-(id) initWithName : (NSString*) vName
			andAge : (int) vAge
	     andGender : (NSString*) vGender
{
	//复用父类已有的init方法，值还是赋给self的。
   	if(self = [super initWithName:vName andAge:vAge]) {
          self->Gender = vGender;
    }
    return self;
}
```
当使用 `self` 调用方法时，会从当前类的方法列表中开始找，如果没有，就从父类中再找；而当使用 `super` 时，则从父类的方法列表中开始找。然后调用父类的这个方法。

**11. 多态与动态绑定**

多态简单说就是对于不同对象响应同一个方法时做出不同的反应。在OC中动态类型`id`是实现多态的一种方式。动态类型使程序直到执行时才确定对象所属的类型，因而才可以确定实际调用的方法，即动态绑定。
动态类型识别方法：

``` objective_c
-(BOOL)isKindOfClass:classObj  //是否是classObj或者它的子类的实例
-(BOOL)isMemberOfClass:classObj  //是否是classObj的实例
-(BOOL)respondsToSelector:selector  //实例是否有这个方法
+(BOOL) instancesRespondToSelector:   //类是否有这个方法
NSClassFromString(NSString*); //由字符串得到类对象
NSStringFromClass([ClassName Class]); // 由类名得到字符串
Class rectClass= [Rectangle class]; //通过类名得到类对象
Class aClass =[anObject class]; //通过实例得到类对象
if([obj1 class]== [obj2 class]); //判断是不是相同类的实例
```

**12. 元类(Meta Class)**

我们从`id`的类型开始分析源码，在obj.h中，`id`的定义如下：
    
``` objective_c
/// A pointer to an instance of a class.
typedef struct objc_object *id;

/// Represents an instance of a class.
struct objc_object {
    Class isa;
};

/// An opaque type that represents an Objective-C class.
typedef struct objc_class *Class;
```

在runtime.h中 

``` objective_c
struct objc_class {
    Class isa  OBJC_ISA_AVAILABILITY;
    #if !__OBJC2__
    Class super_class                         OBJC2_UNAVAILABLE;
    const char *name                          OBJC2_UNAVAILABLE;
    long version                              OBJC2_UNAVAILABLE;
    long info                                 OBJC2_UNAVAILABLE;
    long instance_size                        OBJC2_UNAVAILABLE;
    struct objc_ivar_list *ivars              OBJC2_UNAVAILABLE;
    struct objc_method_list **methodLists     OBJC2_UNAVAILABLE;
    struct objc_cache *cache                  OBJC2_UNAVAILABLE;
    struct objc_protocol_list *protocols      OBJC2_UNAVAILABLE;
    #endif
} OBJC2_UNAVAILABLE;
```
该结构体中，`isa` 指向所属`Class`， super_class指向父类别。
在Objective-C的设计哲学中，一切都是对象。`Class`在设计中本身也是一个对象。而这个`Class`对象的对应的类，我们叫它 `Meta Class`，即`Class`结构体中的 `isa` 指向的就是它的` Meta Class`。我们可以把`Meta Class`理解为***一个Class对象的Class***。简单的说：

>* 当我们发送一个消息给一个NSObject对象时，这条消息会在对象的类的方法列表里查找
* 当我们发送一个消息给一个类时，这条消息会在类的Meta Class的方法列表里查找

而 `Meta Class`本身也是一个`Class`，它跟其他`Class`一样也有自己的`isa` 和 `super_class` 指针。

![Class&MetaClass](http://upload-images.jianshu.io/upload_images/1136939-897b71b8d64a3bc2.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

>* 每个Class都有一个isa指针指向一个唯一的Meta Class
* 每一个Meta Class的isa指针都指向最上层的Meta Class（图中的NSObject的Meta Class）
* 最上层的Meta Class的isa指针指向自己，形成一个回路
* 每一个Meta Class的super class指针指向它原本Class的 Super Class的Meta Class。但是最上层的Meta Class的 Super Class指向NSObject Class本身
* 最上层的NSObject Class的super class指向 nil

我们看isKindOfClass的源码：

``` objective_c
- (BOOL)isKindOf:aClass
{
    Class cls;
    for (cls = isa; cls; cls = cls->superclass) 
        if (cls == (Class)aClass)
            return YES;
    return NO;
}
```
isMemberOfClass 的源码是：

``` objective_c
- (BOOL)isMemberOf:aClass
{
    return isa == (Class)aClass;
}
```
结合上面讲的*isa*与MetaClass以及isKindOfClass、isMemberOfClass源码实现。可以知道下面习题的输出：

``` objective_c
@interface Sark : NSObject
@end

@implementation Sark
@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        BOOL res1 = [(id)[NSObject class] isKindOfClass:[NSObject class]];
        BOOL res2 = [(id)[NSObject class] isMemberOfClass:[NSObject class]];

        BOOL res3 = [(id)[Sark class] isKindOfClass:[Sark class]];
        BOOL res4 = [(id)[Sark class] isMemberOfClass:[Sark class]];

        NSLog(@"%d %d %d %d", res1, res2, res3, res4);
    }
    return 0;
}
```
输出：

```
1 0 0 0
```

**13. 选择器(Selector)**

相当于C语言的回调函数功能。

>SEL is a type that represents a selector in Objective-C. The @selector() keyword returns a SEL that you describe. It's not a function pointer and you can't pass it any objects or references of any kind. For each variable in the selector (method), you have to represent that in the call to @selector. 


``` objective_c
-(void)methodWithNoArguments;SEL noArgumentSelector = @selector(methodWithNoArguments);
-(void)methodWithOneArgument:(id)argument;SEL oneArgumentSelector = @selector(methodWithOneArgument:); // notice the colon here
-(void)methodWIthTwoArguments:(id)argumentOne and:(id)argumentTwo;SEL twoArgumentSelector = @selector(methodWithTwoArguments:and:); // notice the argument names are omitted
```
Selectors通常传递给delegate方法，然后在回调时指定执行哪个函数。
  
``` objective_c 
@implementation MyObject
-(void)myTimerCallback:(NSTimer*)timer 
{ 
  // do some computations 
  if( timerShouldEnd ) { 
    [timer invalidate]; 
  }
}
@end
// ...
int main(int argc, const char **argv) { 
  // do setup stuff
  MyObject* obj = [[MyObject alloc] init]; 
  SEL mySelector = @selector(myTimerCallback:); 
  [NSTimer scheduledTimerWithTimeInterval:30.0 target:obj     selector:mySelector userInfo:nil repeats:YES];
  // do some tear-down 
  return 0;
}
```

**14. KVC & KVO**

>KVC  - key value coding
KVO  - key value observing

在OC中的key是指一个字符串表示的对象的一个属性，与实例变量名以及访问方法同名。
KVC常用的四种方法是：

``` objective_c
- (id)valueForKey:(NSString *)key; 
- (void)setValue:(id)value forKey:(NSString *)key; 
- (id)valueForKeyPath:(NSString *)keyPath; 
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath;
```

效果与`setter/getter`方法一样，但是没有`setter/gtter`方法时也是可以通过这种方法获取/更新属性值的，而且支持多级属性的简便访问方法，即
上面的后两种方法的key路径。
key路径可以用点操作符同时遍历多级属性，比如：

>Department对象有manager属性，它是一个指向Employee对象的指针，而Employee对象有一个emergencyContact属性，它是一个指向Person对象的指针，Person对象有一个phoneNumber属性。

那么要了解销售部经理的紧急联系方式，可以这样用KVC:

``` objective_c
Department *sales = ...;
Employee *sickEmployee = [sales valueForKey:@"manager"];
Person *personToCall = [sickEmployee valueForKey:@"emergencyContact"];
NSString *numberToDial = [personToCall valueForKey:@"phoneNumber"];
```
有了key路径，我们可以简便方法：

``` objective_c
Department *sales = ...;
NSString *numerToDial = [sales valueForKeyPath:@"manager.emergencyContact.phoneNumber"];
```
也可以设置属性的值：

``` objective_c
Department *sales=...;
[sales setValue:@"1113332223" forKeyPath:@"manager.emergencyContact.phoneNumber"];
```
KVO提供了一种通知对象属性更新的机制。在OC中的MVC机制中扮演着Model与Controller之间的桥梁作用。
给一个对象属性设置观察者一般有4步：

* 1 明确是否需要设置KVO。比如一个对象的某个属性发生任意变化时，需要通知另外一个对象的时候。如下图，当BankObject的accountBalance发生任意变化时，PersonObject都需要感知到。
![kvo_objects](http://upload-images.jianshu.io/upload_images/1136939-ce1ce1713e613f21.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
* 2 PersonObeject必须注册为BankObject对象的accountBalance属性的一个观察者。

``` objective_c
[backInstance addObserver: personInstance
                 forKeyPath: @"accountBalance"
                    options: NSKeyValueObservingOptionNew
                    context: null]
```

![kvo_objects_connection](http://upload-images.jianshu.io/upload_images/1136939-196cedc7f29b5ce9.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

* 3 要响应更新通知，观察者必须实现 
observeValueForKeyPath:ofObject:change:context:方法。
![kvo_objects_implementation](http://upload-images.jianshu.io/upload_images/1136939-aae328982355965d.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

* 4 改变一个被观察的对象属性值时，
observeValueForKeyPath:ofObject:change:context:方法会自动被执行。
![kvo_objects_notification](http://upload-images.jianshu.io/upload_images/1136939-41a2986ee72bafaf.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

KVO的最重要的优势就是你不需要自己去实现通知机制。
 
