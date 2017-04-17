---
title:  "浅谈dispatch_semaphore_t"
date:   2017-04-11 15:14:23
categories: [iOS]
tags: [iOS]
comments: true
---

在UNIX环境下，多线程同步的技术有`mutex`、`condition variable`、`semaphore`、`RW Lock`、`spin Lock`等。在iOS平台上，可以使用`dispatch_semaphore_t`做线程同步。

`dispatch_semaphore_t`的原理类似于`semaphore`，与其相关的方法主要是:

``` objective_c
dispatch_semaphore_t dispatch_semaphore_create(long value);
long dispatch_semaphore_wait(dispatch_semaphore_t dsema, dispatch_time_t timeout);
long dispatch_semaphore_signal(dispatch_semaphore_t dsema);
```

####dispatch_semaphore_create####

创建一个新的信号量，参数value代表信号量资源池的初始数量。
>value < 0， 返回NULL
value = 0, 多线程在等待某个特定线程的结束。
value > 0, 资源数量，可以由多个线程使用。

####dispatch_semaphore_wait####
等待资源释放。如果传入的dsema大于0，就继续向下执行，并将信号量减1；如果dsema等于0，阻塞当前线程等待资源被dispatch_semaphore_signal释放。如果等到了信号量，继续向下执行并将信号量减1，如果一直没有等到信号量，就等到timeout再继续执行。dsema不能传入NULL。

timeout表示阻塞的时间长短，有两个常量：`DISPATCH_TIME_NOW`表示当前，`DISPATCH_TIME_FOREVER`表示永远。或者自己定义一个时间：

```objective_c
dispatch_time_t  t = dispatch_time(DISPATCH_TIME_NOW, 1*1000*1000*1000);
```

####dispatch_semaphore_signal####

释放一个资源。返回值为0表示没有线程等待这个信号量；返回值非0表示唤醒一个等待这个信号量的线程。如果线程有优先级，则按照优先级顺序唤醒线程，否则随机选择线程唤醒。

####应用场景####
dispatch_semaphore_t的应用场景很多，这里以一个异步网络请求为例。
在异步网络请求中，我们先发送网络请求，然后要等待网络结果返回再做其他事情。为了将这种异步请求改成同步的，我们可以使用dispatch_semaphore_t。

``` objective_c
static dispatch_semaphore_t match_sema;


- (void)asynNetWorkRequest {
    /*
    ...
    构造网络请求参数
    ...
    [[IosNet sharedInstance] asyncCall:method forParam:reqData forCallback:zuscallback forTimeout:timeoutValue];
    ...
    */
    
    //创建信号量，阻塞当前线程
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        match_sema = dispatch_semaphore_create(0);
    });
    dispatch_semaphore_wait(match_sema, DISPATCH_TIME_FOREVER);
}

//请求成功 释放信号量，继续当前线程
- (void)onCallSuccess:(NSData *)rspData ｛
    if (match_sema) {
        dispatch_semaphore_signal(match_sema);
    }
｝
//请求失败 释放信号量，继续当前线程
- (void)onCallFail:(NSError *)errorInfo {
    if (match_sema) {
        dispatch_semaphore_signal(match_sema);
    }
}
```



