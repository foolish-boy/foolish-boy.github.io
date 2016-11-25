---
title:  "property的copy修饰"
date:   2016-04-21 20:24:23
categories: [iOS]
tags: [iOS]
---
![objective c](http://upload-images.jianshu.io/upload_images/1136939-eb78fa28e1471928.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

经常会在property修饰中看到 copy和strong， 现在来个解释。

首先来看下面代码的输出：

``` objective_c
@interface Person : NSObject
@property (strong, nonatomic) NSArray *bookArray1;
@property (copy, nonatomic) NSArray *bookArray2;
@end

@implementation Person
//省略setter方法
@end

//Person调用
main(){
    NSMutableArray *books = [@[@"book1"] mutableCopy];
    Person *person = [[Person alloc] init];
    person.bookArray1 = books;
    person.bookArray2 = books;
    [books addObject:@"book2"];
    NSLog(@"bookArray1:%@",person.bookArray1);
    NSLog(@"bookArray2:%@",person.bookArray2);
}
```
可以看到此刻的`person.bookArray1`是`["book1","book2"]`，而`person.bookArray2`是`["book1"]`。

**原因**

>使用strong修饰符，person.bookArray1就指向books所指向的内存区域，所以与books同变化，而使用copy修饰符，那么person.bookArray2会先新建一个新的内存区域，并将books的数据拷贝过去，所以之后的books变化对person.bookArray2不影响。

**根因**

>1. strong 修饰的属性在setter 方法中，会首先对bookArray1 release，然后对books retain，最后再把books赋值给bookArray1。
2. copy修饰的属性在setter方法中，会首先对bookArray release，然后创建一块新内存拷贝books。(深拷贝)

**意义**

>如果property是NSString或者NSArray及其子类的时候，最好选择使用copy属性修饰。这是为了防止赋值给它的是可变的数据，如果可变的数据发生了变化，那么该property也会发生变化,这是不愿看到的。

这里是属性修饰符copy , 还有copy方法和mutableCopy方法，对应的浅拷贝与深拷贝问题可以看[这个介绍](http://www.cnblogs.com/chenyg32/p/5167194.html)
