---
title:  "遍历删除NSMutableArray的那些事"
date:   2017-03-23 20:13:23
categories: [iOS]
tags: [iOS]
comments: true
---
有点经验的老司机一看标题就应该知道我想说什么，并可能给出一个谜之鄙视的表情😒，所以你要是看完文章才知道这回事的话得回去补补数据结构了。

在学习数据结构的时候，我们就知道遍历链表同时删除元素的潜在隐患，只是长时间不去写这种代码可能会犯错误。

开门见山，现在有这样一个数组：
 
``` objective_c
NSMutableArray *mutArr = [[NSMutableArray alloc] initWithObjects:@1,@"a",@2,@"b",@3,@"c", nil];
```
如果让你删除其中的字符串，你会怎么做？

于是乎，我们咔咔就是写：

``` objective_c
for (id data in mutArr) {
  if ([data isKindOfClass:[NSString class]]) {
    [mutArr removeObject:data];
  }
}
```
想必也是极快的！然而 crash了！

![forin crash](http://upload-images.jianshu.io/upload_images/1136939-5d54c598cf5dbe1e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

就是因为你用forin在遍历的同时删除了元素，数组规定在forin遍历的时候不能修改数组元素。因为删除一个元素，没有遍历到的元素就会向前移动一位，那迭代器就不知道接下来要遍历当前删除位置的元素还是下一个位置的元素了。
但是有一种特殊情况，就是在删除数组最后一个元素的时候可以使用forin,因为到最后一个元素的时候forin枚举已经结束了，这时候删除元素不会影响到forin工作。

那么还有哪些方法可以正确做到遍历数组的同时删除元素呢？

## 1 用for循环 ##

``` objective_c
for (int i = 0; i < [mutArr count]; i ++) {
  id data = [mutArr objectAtIndex:i];
    if ([data isKindOfClass:[NSString class]]) {
      [mutArr removeObject:data];
    }
}
```
这样是没问题的，因为我们每次用index来取值，总是可以按照正确的顺序取到对应的值的。
这里要注意的是：for循环的条件是`i < [mutArr count]`， 而不能在for之前先计算好大小`cnt`再用`i < cnt`，这样也会crash的。每删除元素，数组都是变化的，其大小也是变化的。

## 2 用copy数组 ##
``` objective_c
NSMutableArray *copyArr = [mutArr mutableCopy];
for (id data in copyArr) {
  if ([data isKindOfClass:[NSString class]]) {
    [mutArr removeObject:data];
  }
}
```
用forin遍历copy出来的数组，在原来的数组做删除操作，是完全可以的。很明显，这种方式会有内存消耗。

## 3 反向迭代 ##
``` objective_c
NSEnumerator *enumerator = [mutArr reverseObjectEnumerator];
  for (id data in enumerator) {
    if ([data isKindOfClass:[NSString class]]) {
      [mutArr removeObject:data];
    }
}
```
前面说的是正向forin迭代遍历时会crash，但反向就没有问题。因为反向迭代时，没有遍历到的元素是不会移动位置的，所以迭代器仍然可以正常工作。

## 4 predicate ##

```objective_c
[mutArr filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
  NSLog(@"count == %ld",[mutArr count]);
  if ([evaluatedObject isKindOfClass:[NSString class]]) {
    return NO;
  }
  return YES;
}]];
```

这种方式也是可以过滤掉数据的。不过每次打印`[mutArr count]`值是不变的，所以其工作原理很可能是做了几次copy:

>1. NSPredicate复制原数组到一个新的集合，假定称为集合CopyA
2. 通过Block过滤器过滤出集合CopyA中的元素元素到另一个数组集合，假定这个集合为集合CopyB
3. 返回过滤数组集合CopyB，释放集合CopyA，完成赋值到初始集合

可见这种方式是很耗内存的，如果元素都是数据量比较大的如图片，就可能出现OOM。

## 5 用While ##

``` objective_c
int i = 0;
while ([mutArr count] > i) {
  id data = [mutArr objectAtIndex:i];
  if ([data isKindOfClass:[NSString class]]) {
    [mutArr removeObject:data];
    data = nil;//释放元素
  } else {
    i++;
  }
}
```
这种方式类似于第一种for循环，我们还可以及时释放删除的元素。

## 6 自定义Iterator ##
既然系统的迭代器有隐患，我们完全可以按照自己的想法来自定义一个迭代器。
具体demo可以参考[这里](https://my.oschina.net/ososchina/blog/648725)

当然，除了上面几种方法，还有其他的遍历方法可以做到，只是要注意特殊处理。关于数组的几种遍历方法，可以参考[这篇文章](http://darkdust.net/index.php/writings/objective-c/nsarray-enumeration-performance)，里面详细比较了几种遍历方法的性能，并给了统计图。先不论他的统计方法是否通用，我们还是可以从中大致了解各个遍历方法的性能。另外，文章还顺便分析了**并行遍历**和**数组分配**的性能问题，值得推荐！
