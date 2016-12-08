---
title:  "点击UITableViewCell发生了什么？"
date:   2016-12-08 10:10:23
categories: [iOS]
tags: [iOS]
---
今天遇到一个有关`UITableViewCell`的奇怪现象。

我的`UITableViewCell`上有一个`subview`，是用来显示未读数的。我给这个`subview`设置了一个红色背景，就像这样：

![未选择cell时](http://upload-images.jianshu.io/upload_images/1136939-4826b8680906a9a0.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


但是我选中这个cell时，发现未读数的背景色没有了，只有数字，就像这样：

![选择cell时](http://upload-images.jianshu.io/upload_images/1136939-b71965333e7b93a1.PNG?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

借此机会我了解到我们通常点击一个`UITableViewCell`时发生了哪些事，我按照调用方法的顺序绘制了一个简单的流程图：

![点击UITableViewCell的调用方法](http://upload-images.jianshu.io/upload_images/1136939-97de108b3881cbe0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


可以看到，手指按下的时候，Cell就进入`highlighted`状态。其实，Cell的`subview`也同时进入了`highlighted`状态。这个时候，Cell会把所有所有`subview`的背景色清空，以便设置统一的背景色。一般有如下几种选中模式：

> UITableViewCellSelectionStyleNone,
    UITableViewCellSelectionStyleBlue,
    UITableViewCellSelectionStyleGray,
    UITableViewCellSelectionStyleDefault

### 解决办法 ###
 我们可以选择UITableViewCellSelectionStyleNone，背景色就不会修改的。但是显然不能满足我们的应用场景。

正如Apple开发文档说的：

>A custom table cell may override this method to make any transitory appearance changes.

我们重载`(void)setSelected:(BOOL)selected animated:(BOOL)animated`和`(void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated`方法，在这里面我们来设置`subview`的背景色。

``` objective_c
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    
    [super setSelected:selected animated:animated];
    _unreadBadge.backgroundColor = [UIColor redColor];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    
    [super setHighlighted:highlighted animated:animated];
    _unreadBadge.backgroundColor = [UIColor redColor];
}
```
这样既可以按照系统的选择风格来，又可以自定义`subview`背景色，perfect！
