---
title:  "如何优雅地动态插入数据到UITableView"
date:   2017-06-06 10:55:23
categories: [iOS]
tags: [iOS]
comments: true
---
TableView`中插入数据并刷新列表的时候，会发现列表是有抖动的。比如在微信聊天页面，你滑动到某一个位置保持住，然后收到一个或者若干人的微信(这几个人不在当前聊天列表中)。你会发现每收到一个人的信息，列表向下沉，就是有一个“抖动”的过程。当然，并不是说微信体验不好，只是抛砖引玉。

言归正传，我要讨论的场景如下：
> 当前列表展示了很多新闻，同时后台在加载第三方广告。广告加载完成后需要按照规定的位置顺序循环地插入到列表中，比如第5，12，19，26...，要求插入广告后当前展示的页面没有下沉抖动现象，避免刚刚看的新闻跳到不可知的位置去了。

由于这里广告不是直接附加在列表末尾，也不是一次性插入到相邻的位置，而是离散地分布在整个列表中，所以不好用`insertRowsAtIndexPaths:withRowAnimation:`或者
`reloadRowsAtIndexPaths:withRowAnimation:`局部刷新，必须对整个列表ReloadData。显然这会导致列表下沉抖动，最坏的情况是当前展示的整个页面下沉，这对于新闻客户端来说体验很不好。

首先，我会想到`scrollToRowAtIndexPath:atScrollPosition:animated:`这个方法。在我刷新完整个列表之后，再将`UITableView`滚动到之前记录的位置。大致思路看代码:

```objective_c
//刷新列表之前找到当前屏最顶部的新闻Id
- (NSString *)topNewsId {
    NSArray *visibleCells = [self.tableView visibleCells];
    
    UITableViewCell *cell = [visibleCells firstObject];
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    NewsModel *topNews = [self.dataArr objectAtIndex:indexPath.row];

    NSString *newsId = = topNews.newsId;
    return newsId;
}
//刷新之后再将之前顶部的新闻滚动到顶部 避免页面抖动
- (void)keepTopNews:(NSString *)topNewsId {
    int topNewsRow = 0;
    for (int i = 0; i <[self.dataArr count] ; i ++) {
        id data = [self.dataArr objectAtIndex:i];
        if ([data isKindOfClass:[NewsModel class]]) {
            NewsModel *model = data;
            if ([model.newsId isEqualToString:topNewsId]) {
                topNewsRow = i;
                break;
            }
        }
    }
    if (topNewsRow) {
        NSIndexPath *toIndex = [NSIndexPath indexPathForRow:topNewsRow inSection:0];
        [self.tableView scrollToRowAtIndexPath:toIndex atScrollPosition:UITableViewScrollPositionTop animated:NO];
    }
    
}
```

乍一看，这种方法挺优美的，也好像能达到我们的目的。但实际上还是有问题的，问题出在`visibleCells`这个方法。先来看看这个方法的定义：

> Returns an array of visible cells currently displayed by the collection view.

即返回当前展示的可见cell数组。
不过，这个方法并不是"眼见为实的"，有时候我们肉眼看不到的cell它却认为是可见的，或者只部分可见的它也会返回给我们的。比如图中网易新闻最上面的新闻 “...夫人镜头里的民国世相”就只见到一部分，如果用它来置顶也是会有下沉抖动问题的。

![网易新闻截图](http://upload-images.jianshu.io/upload_images/1136939-ebee2325b1d54e84.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

那么还有没有更优雅的方式呢？Absolutely!!!

既然用cell做单位来滚动太粗糙，我们可以用像素级别滚动来优雅地保持置顶新闻岿然不动。

首先我们要知道ReloadData的一个特性:

>When you call this method, the collection view discards any currently visible items and views and redisplays them. For efficiency, the collection view displays only the items and supplementary views that are visible after reloading the data. If the collection view’s size changes as a result of reloading the data, the collection view adjusts its scrolling offsets accordingly.

关于ContentOffset、ContentSize、ContentInset的区别这里就不赘述了，可以参考[这里](https://objccn.io/issue-3-2/)。

就是说ReloadData只刷新当前屏幕可见的哪些cell，只会对visibleCells调用
`tableView:cellForRowAtIndexPath:`。**contentOffset是保持不变的**，所以我们才看到了“抖动现象”，就像新闻被挤下去了。

![contentOffset模拟图](http://upload-images.jianshu.io/upload_images/1136939-94e4041267a4dd8e.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

图中灰色部分表示iPhone的屏幕，粉红色表示所有数据的布局大小，白色单元是隐藏在屏幕上方的数据，绿色表示目标广告单于格。

左图的当前屏幕最上面的新闻是news 11，UITableview的contentOffset是200，我们可以计算出news 11之前所有新闻单元格的高度总和得出现在news 11的偏移量preOffset。

右图是在第三个位置插入一个广告后的布局。UITableview的contentOffset还是200，但是news 11被“挤下去”了。我们同样可以计算news 11之前所有新闻单元格和广告单元格的高度总和得出现在news 11的偏移量afterOffset。

有了preOffset和afterOffset之后就可以知道news 11被“挤下去”多少距离

> deltaOffset = afterOffset - preOffset;

那么，为了保证news 11还是展示在当初的位置，我们只要手动更新ContentOffset的值就可以了，相当于将粉红色部分上移deltaOffset的距离。

看代码：

```objective_c
- (void)insertAds:(NSArray *)ads {
    NSString *topNewsId = [self topNewsId];
    
    CGFloat preOffset = [self offSetOfTopNews:topNewsId];
    
    /*
    插入广告...
    */
    
    [self.tableView reloadData];

    CGFloat afterOffset = [self offSetOfTopNews:topNewsId];
    
    CGFloat deltaOffset = afterOffset - preOffset;
    
    CGPoint contentOffet = [self.tableView contentOffset];
    contentOffet.y += deltaOffset;
    self.tableView .contentOffset = contentOffet;
}

//计算newsId对应新闻的偏移量
- (CGFloat)offSetOfTopNews:(NSString *)newsId {
    CGFloat offset = 0;
    for (int i = 0; i < [self.dataArr count]; i ++) {
        id data = [self.dataArr objectAtIndex:i];
        if ([data isKindOfClass:[NewsModel class]]) {
            NewsModel *model = data;
            if ([model.newsId isEqualToString:newsId]) {
                break;
            }
        }
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        CGFloat height = [self heightForRowAtIndexPath:indexPath];
        offset += height;
    }
    return offset;
}
```

如此，就可以真正做到当前屏幕一点都不下沉了。如果广告插在当前屏幕之外，用户是感觉不到的，等滑动列表才能在相应位置看到广告；如果插入到当前屏幕中，用户在课间区域看到插入一个新闻，但是置顶的新闻位置是保持不动的。

***尽享丝滑～***

最后稍微提一下计算偏移量中用到的一个小技巧。

如果所有的新闻和广告单元的高度是固定的，那么`heightForRowAtIndexPath:`是很方便计算的。如果是动态的，就需要用到一点技巧了。

比如广告的数据用`AdModel`表示。为了让广告单元的高度随广告内容动态调整，我们一般习惯在`AdModel`里用一个`cellHeight`字段。

```objective_c
@interface AdModel:NSObject

@property (nonatomic, assign) NSInteger adId;
...
@property (nonatomic, assign) CGFloat   cellHeight;

@end
```

在我们填充内容渲染广告位的时候算出高度再赋值给`cellHeight`。

在上面的场景下，前面虽然插入了广告，但是ReloadData的时候，UITableView并不会刷新不可见的广告位，因此`cellHeight`始终为0，这就导致`heightForRowAtIndexPath:`不能计算出正确的结果。

巧妙地，我们在广告插入`self.dataArr`的时候定义一个临时的广告单元变量`AdCell`，并主动调用渲染的接口来给`cellHeight`赋值。

```objective_c
AdCell *tmpCell = [AdCell new];
[tmpCell setAdsContent:model];//这里会渲染广告位并计算出cellHeight 
```

