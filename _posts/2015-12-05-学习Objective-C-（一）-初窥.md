---
title:  "学习Objective-C-（一）-初窥"
date:   2015-12-05 21:24:23
categories: [iOS]
tags: [iOS]
---
![objective-c](http://upload-images.jianshu.io/upload_images/1136939-2cc1acf1a97ed073.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

学习ios首先就是要学习object-c(以下简称OC)，虽然现在有了更方便的Swift，但是万变不离其宗嘛～，就像我们有了更高级的C++、Java等面向对象语言的时候，我们还是喜欢去研究一下他们的实现原理，就是为了更好滴把控他。要知道，只有随心所欲滴掌控一样东西，才可以真正做到为我所用，任我所用！此乃为内功也！

我刚开始学习，花了一个星期时间看了这本[Objective-C 编程](http://book.douban.com/subject/19962787/),每天晚上花个两个小时左右时间，国外原版太贵也不好搞，只好用翻译的了。 由于之前学习过C语言，所以前面两部分工12章几乎一带而过。这本书写的的确不错，难易有当，适合所有初学者看，而且要在实际开发中不断滴看。当时看完这本书，还给几个小伙伴做了简单的分享，写了个很粗糙的[PPT](http://pan.baidu.com/disk/home#path=%252F%25E6%2588%2591%25E7%259A%2584%25E6%2596%2587%25E6%25A1%25A3)

我觉得大部分内容都是比较简单的，有C语言基础的人，看起来应该好不费事。不过我是一个foolish boy嘛，所以还是有一些不懂的地方。在此把我不太懂的地方，也可能是大家比较关注的几个问题列出来，并结合网上资料和自己的理解给个参考答案，欢迎大家指正。

1. ***#include  / #import  /  #@import***

      OC里面包含头文件的方式有了`import`这种方式，那么它到底什么来头？

      我们知道在C、C++等其他编程语言中，为了防止某一个头文件被多次包含，我们会使用`#ifndef #define`的方式，在OC中`import`就自动解决这种问题了，所以推荐用`import`(实际上几乎所有的ios程序都使用`import`)。有了`#import`，怎么还有一个`@import`呢？这又是神马东东。 这就要提到一个新的特性，叫做`Modules`，最基本的作用就是为了加速编译阶段。 `#import`只是简单地做代码替换，这将无疑增加程序的大小和编译时间，例如一个UIKit框架的代码就有11000行。`@import`会在编译的预处理阶段预先计算和缓存需要的代码，借此提高代码的编译速度。此外，它还简化了我们的添加框架的操作。每个程序至少会用到几个基本的框架，我们需要手动去添加这些框架，万一忘记了添加某个框架，就会链接失败，我们就需要再去添加框架重新编译。有了`@import`,它会自动帮我们做这些事，是不是方便又快捷。

2. ***+ function / - function***

    第一次看到OC的函数前的`+/-` 符号的时候我以为是编译器自带的代码隐藏于显示的功能，后来发现我是图样啊。原来，`＋`代表函数是个静态方法，即可以通过类名直接访问；`－`代表时成员方法，需要实例化对象才能访问。类似于C++中的static。

3. ***MRC / ARC / AutoReleasepool***

    OC的内存管理不像Java那么方便，但是比C++要方便点。C++需要自己申请(new/malloc)和释放(delete/free)资源，一不小心就会造成内存泄漏，Java有自己的内存回收机制，无需程序员手动执行。OC刚好在两者之间，它既是自动回收的，也需要程序员的命令。
当一个对象的拥有方或者说引用计数为0时，会释放这个对象资源。
在早期，OC时需要程序员使用手动引用计数`(MRC, Manual Refrence Counting)`的，维护一个retain计数，程序要显示地向对象发送retain消息，例如：

    >[anObject release]; // anObject失去一个拥有方
   [anObject retain];     // anObject得到一个拥有方

    这种方式带来的问题是容易忘记发送release消息，导致内存泄漏。特别是大规模项目中，这种问题尤为复杂。Apple为了结束这种“内存管理黑暗时代”，开发类一款名为[Clang](http://baike.baidu.com/link?url=VZ9hd8zuMcv-x8q6sZohcfqBdY3PY-z5aY_ju0CVrafommTBcetpKyAr03_NEQc5bHCOYpj2nUAHIOjCvM2ina)的静态分析器，可以找到程序中的内存泄漏点。后来，基于此诞生了`ARC(Automatic Refrence Counting)`,顾名思义，就是自动帮你做引用计数管理了。

    >Automatic Reference Counting (ARC) is a compiler feature that provides automatic memory management of Objective-C objects. ARC works by adding code at compile time to ensure that objects live as long as necessary, but no longer. Conceptually, it follows the same memory management conventions as manual reference counting by adding the appropriate memory management calls for you.

    自动释放池是NSAutoreleasePool的实例。其中包含了收到autorelease消息的对象。当一个自动释放池自身被销毁（dealloc）时，它会给池中每一个对象发送一个release消息（如果你给一个对象多次发送autorelease消息，那么当自动释放池销毁时，这个对象也会收到同样数目的release消息）。这是一种延迟释放的机制，等到释放池被销毁的时候释放所有的对象。虽然它表现的好像很自动，但是我们不知道它保留的对象真正在什么时候释放，而且这种延迟释放在临时对象很多的时候也是造成很多内存的浪费。

     那么问题来了，既然有了ARC，干嘛还要用autoreleasepool。前者频繁释放没有什么不好啊，反而后者一起释放会占用内存。是的，但是前者是在编译阶段干好的时，当我们遇到一些运行时需要解决的问题，比如一个变量横跨几个作用域的时候，或者在多线程编程的时候。我还没用到过，暂且这么记着吧。
   
4. ***强引用 / 弱引用***

    OC中大量使用指针，就是说一个对象是被另外一个对象指向的，术语叫做“拥有”，如果A对象拥有B对象，同时B对象也拥有A对象，那么就造成一种强引用循环。这样导致两个对象都不能被释放，从而造成内存泄漏。于是乎，弱引用横空出世了。借用书中的说法是:
    >强引用会保留对象的拥有方，使其不被释放；弱引用不会保留对象拥有方。标记为弱引用的实例变量或者属性指向的对象可能会消失，此时这个实例变量或属性被置为nil。

    用weak属性可以标记弱引用，如：

``` objective_c 
@property (nonatomic, weak) BNREmployee *holder;
__weak BNRPerson *parent;
```

待补充......
