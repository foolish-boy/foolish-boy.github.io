---
title:  "SDWebImage源码解析（一）"
date:   2017-01-17 11:39:23
categories: [iOS]
tags: [iOS]
comments: true
---
[SDWebImage](https://github.com/rs/SDWebImage)是一个图片下载的开源项目，由于它提供了简介的接口以及异步下载与缓存的强大功能，深受“猿媛“的喜爱。截止到本篇文章开始，项目的star数已经超过1.6k了。今天我就对项目的源码做个阅读笔记，一方面归纳总结自己的心得，另一方面给准备阅读源码的童鞋做点铺垫工作。代码最新版本为3.8。

正如项目的第一句介绍一样：

>Asynchronous image downloader with cache support as a UIImageView category

`SDWebImage`是个支持异步下载与缓存的UIImageView扩展。项目主要提供了一下功能：

> * 扩展UIImageView, UIButton, MKAnnotationView，增加网络图片与缓存管理。
* 一个异步的图片加载器
* 一个异步的 内存 + 磁盘 图片缓存，拥有自动的缓存过期处理机制。
* 支持后台图片解压缩处理
* 确保同一个 URL 的图片不被多次下载
* 确保虚假的 URL 不会被反复加载
* 确保下载及缓存时，主线程不被阻塞
* 使用 GCD 与 ARC

项目支持的图片格式包括PNG,JEPG,GIF,WebP等等。

先看看`SDWebImage`的项目组织架构:

![SDWebImage组织架构.png](http://upload-images.jianshu.io/upload_images/1136939-dedbf4b5f8eaa701.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
 
>SDWebImageDownloader负责维持图片的下载队列；
SDWebImageDownloaderOperation负责真正的图片下载请求；
SDImageCache负责图片的缓存；
SDWebImageManager是总的管理类，维护了一个`SDWebImageDownloader`实例和一个`SDImageCache`实例，是下载与缓存的桥梁;
SDWebImageDecoder负责图片的解压缩；
SDWebImagePrefetcher负责图片的预取；
UIImageView+WebCache和其他的扩展都是与用户直接打交道的。

其中，最重要的三个类就是`SDWebImageDownloader`、`SDImageCache`、`SDWebImageManager`。接下来我们就分别详细地研究一下这些类各自具体做了哪些事，又是怎么做的。

为了便于大家从宏观上有个把握，我这里先给出项目的框架结构：

![Paste_Image.png](http://upload-images.jianshu.io/upload_images/1136939-6046837ca4d764b0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

`UIImageView+WebCache`和`UIButton+WebCache`直接为表层的 UIKit框架提供接口, 而 `SDWebImageManger`负责处理和协调`SDWebImageDownloader`和`SDWebImageCache`, 并与 UIKit层进行交互。`SDWebImageDownloaderOperation`真正执行下载请求；最底层的两个类为高层抽象提供支持。
我们按照从上到下执行的流程来研究各个类

### UIImageView+WebCache ###
这里，我们只用`UIImageView+WebCache`来举个例子，其他的扩展类似。
常用的场景是已知图片的url地址，来下载图片并设置到UIImageView上。`UIImageView+WebCache`提供了一系列的接口:

``` objective_c
- (void)setImageWithURL:(NSURL *)url;
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder;
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options;
- (void)setImageWithURL:(NSURL *)url completed:(SDWebImageCompletedBlock)completedBlock;
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder completed:(SDWebImageCompletedBlock)completedBlock;
- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options completed:(SDWebImageCompletedBlock)completedBlock;
```

这些接口最终会调用

``` objective_c 
- (void)sd_setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholder options:(SDWebImageOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletionBlock)completedBlock；
```
方法的第一行代码`[self sd_cancelCurrentImageLoad]`是取消UIImageView上当前正在进行的异步下载，确保每个 UIImageView 对象中永远只存在一个 operation，当前只允许一个图片网络请求，该 operation 负责从缓存中获取 image 或者是重新下载 image。具体执行代码是：

``` objective_c
// UIView+WebCacheOperation.m
// Cancel in progress downloader from queue
NSMutableDictionary *operationDictionary = [self operationDictionary];
id operations = [operationDictionary objectForKey:key];
if (operations) {
    if ([operations isKindOfClass:[NSArray class]]) {
        for (id <SDWebImageOperation> operation in operations) {
            if (operation) {
                [operation cancel];
            }
        }
    } else if ([operations conformsToProtocol:@protocol(SDWebImageOperation)]){
        [(id<SDWebImageOperation>) operations cancel];
    }
    [operationDictionary removeObjectForKey:key];
}
```
实际上，所有的操作都是由一个`operationDictionary `字典维护的,执行新的操作之前，先cancel所有的operation。这里的cancel是`SDWebImageOperation`协议里面定义的。

``` objective_c
//预览 占位图
    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            self.image = placeholder;
        });
    }
```
是一种占位图策略，作为图片下载完成之前的替代图片。`dispatch_main_async_safe`是一个宏，保证在主线程安全执行，最后再讲。
然后判断url，url为空就直接调用完成回调，报告错误信息；否则，用`SDWebImageManager`单例的

``` objective_c
- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(SDWebImageDownloaderProgressBlock)progressBlock
                                       completed:(SDWebImageCompletionWithFinishedBlock)completedBlock
```
方法下载图片。下载完成之后刷新UIImageView的图片。

``` objective_c
//图像的绘制只能在主线程完成
dispatch_main_sync_safe(^{
    if (!wself) return;
        if (image && (options & SDWebImageAvoidAutoSetImage) && completedBlock)
        {//延迟设置图片，手动处理
            completedBlock(image, error, cacheType, url);
            return;
        } else if (image) {
             //直接设置图片
             wself.image = image;
             [wself setNeedsLayout];
        } else {
            //image== nil,设置占位图
            if ((options & SDWebImageDelayPlaceholder)) {
                wself.image = placeholder;
                [wself setNeedsLayout];
            }
    }
    if (completedBlock && finished) {
        completedBlock(image, error, cacheType, url);
    }
});
```
最后，把返回的`id <SDWebImageOperation> operation`添加到`operationDictionary`中，方便后续的cancel。

### SDWebImageManager ###
在`SDWebImageManager.h`中是这样描述`SDWebImageManager`类的：

> The SDWebImageManager is the class behind the UIImageView+WebCache category and likes.It ties the asynchronous downloader (SDWebImageDownloader) with the image cache store (SDImageCache).You can use this class directly to benefit from web image downloading with caching in another context than a UIView.

即隐藏在`UIImageView+WebCache`背后，用于处理异步下载和图片缓存的类，当然你也可以直接使用 SDWebImageManager 的方法 `downloadImageWithURL:options:progress:completed:`来直接下载图片。

`SDWebImageManager.h`首先定义了一些枚举类型的`SDWebImageOptions`。关于这些Options的具体含义可以参考[叶孤城大神的解析](http://www.jianshu.com/p/6ae6f99b6c4c)

然后，声明了三个block：
  
``` objective_c
//操作完成的回调，被上层的扩展调用。
typedef void(^SDWebImageCompletionBlock)(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL);
//被SDWebImageManager调用。如果使用了SDWebImageProgressiveDownload标记，这个block可能会被重复调用，直到图片完全下载结束，finished=true,再最后调用一次这个block。
typedef void(^SDWebImageCompletionWithFinishedBlock)(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL);
//SDWebImageManager每次把URL转换为cache key的时候调用，可以删除一些image URL中的动态部分。
typedef NSString *(^SDWebImageCacheKeyFilterBlock)(NSURL *url);
```

定义了`SDWebImageManagerDelegate`协议：

``` objective_c
@protocol SDWebImageManagerDelegate <NSObject>

@optional

/**
 * Controls which image should be downloaded when the image is not found in the cache.
 *
 * @param imageManager The current `SDWebImageManager`
 * @param imageURL     The url of the image to be downloaded
 *
 * @return Return NO to prevent the downloading of the image on cache misses. If not implemented, YES is implied.
 * 控制在cache中没有找到image时 是否应该去下载。
 */
- (BOOL)imageManager:(SDWebImageManager *)imageManager shouldDownloadImageForURL:(NSURL *)imageURL;

/**
 * Allows to transform the image immediately after it has been downloaded and just before to cache it on disk and memory.
 * NOTE: This method is called from a global queue in order to not to block the main thread.
 *
 * @param imageManager The current `SDWebImageManager`
 * @param image        The image to transform
 * @param imageURL     The url of the image to transform
 *
 * @return The transformed image object.
 * 在下载之后，缓存之前转换图片。在全局队列中操作，不阻塞主线程
 */
- (UIImage *)imageManager:(SDWebImageManager *)imageManager transformDownloadedImage:(UIImage *)image withURL:(NSURL *)imageURL;

@end

```

`SDWebImageManager`是单例使用的，分别维护了一个`SDImageCache`实例和一个`SDWebImageDownloader`实例。   类方法分别是：

``` objective_c
//初始化SDWebImageManager单例，在init方法中已经初始化了cache单例和downloader单例。
- (instancetype)initWithCache:(SDImageCache *)cache downloader:(SDWebImageDownloader *)downloader;
//下载图片
- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(SDWebImageDownloaderProgressBlock)progressBlock
                                       completed:(SDWebImageCompletionWithFinishedBlock)completedBlock;
//缓存给定URL的图片
- (void)saveImageToCache:(UIImage *)image forURL:(NSURL *)url;
//取消当前所有的操作
- (void)cancelAll;
//监测当前是否有进行中的操作
- (BOOL)isRunning;
//监测图片是否在缓存中， 先在memory cache里面找  再到disk cache里面找
- (BOOL)cachedImageExistsForURL:(NSURL *)url;
//监测图片是否缓存在disk里
- (BOOL)diskImageExistsForURL:(NSURL *)url;
//监测图片是否在缓存中,监测结束后调用completionBlock
- (void)cachedImageExistsForURL:(NSURL *)url
                     completion:(SDWebImageCheckCacheCompletionBlock)completionBlock;
//监测图片是否缓存在disk里,监测结束后调用completionBlock
- (void)diskImageExistsForURL:(NSURL *)url
                   completion:(SDWebImageCheckCacheCompletionBlock)completionBlock;
//返回给定URL的cache key
- (NSString *)cacheKeyForURL:(NSURL *)url;
```

我们主要研究

``` objective_c
- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url
                                         options:(SDWebImageOptions)options
                                        progress:(SDWebImageDownloaderProgressBlock)progressBlock
                                       completed:(SDWebImageCompletionWithFinishedBlock)completedBlock
```

首先，监测url 的合法性：

``` objective_c
if ([url isKindOfClass:NSString.class]) {
    url = [NSURL URLWithString:(NSString *)url];
}
// Prevents app crashing on argument type error like sending NSNull instead of NSURL
if (![url isKindOfClass:NSURL.class]) {
    url = nil;
}
```
第一个判断条件是防止很多用户直接传递NSString作为NSURL导致的错误，第二个判断条件防止crash。

``` objective_c
if (url.absoluteString.length == 0 || (!(options & SDWebImageRetryFailed) && isFailedUrl)) {
        dispatch_main_sync_safe(^{
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
            completedBlock(nil, error, SDImageCacheTypeNone, YES, url);
        });
        return operation;
    }
```
集合`failedURLs`保存之前失败的urls，如果url为空或者url之前失败过且不采用重试策略，直接调用completedBlock返回错误。

``` objective_c
@synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
```
`runningOperations`是一个可变数组，保存所有的operation，主要用来监测是否有operation在执行，即判断running 状态。

`SDWebImageManager`会首先在memory以及disk的cache中查找是否下载过相同的照片，即调用***imageCache***的

``` objective_c
- (NSOperation *)queryDiskCacheForKey:(NSString *)key done:(SDWebImageQueryCompletedBlock)doneBlock 
```
方法。
 **如果在缓存中找到图片**，直接调用completedBlock，第一个参数是缓存的image。

``` objective_c
dispatch_main_sync_safe(^{
    __strong __typeof(weakOperation) strongOperation = weakOperation;
    if (strongOperation && !strongOperation.isCancelled) {//为啥这里用strongOperation TODO
        completedBlock(image, nil, cacheType, YES, url);
    }
});
```

**如果没有在缓存中找到图片**，或者不管是否找到图片，只要operation有`SDWebImageRefreshCached`标记，那么若`SDWebImageManagerDelegate`的`shouldDownloadImageForURL`方法返回true，即**允许下载**时，都使用 ***imageDownloader*** 的

``` objective_c
- (id <SDWebImageOperation>)downloadImageWithURL:(NSURL *)url options:(SDWebImageDownloaderOptions)options progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageDownloaderCompletedBlock)completedBlock
```
方法进行下载。如果下载有错误，直接调用completedBlock返回错误，并且视情况将url添加到failedURLs里面；

``` objective_c
dispatch_main_sync_safe(^{
    if (strongOperation && !strongOperation.isCancelled) {
        completedBlock(nil, error, SDImageCacheTypeNone, finished, url);
    }
});

if (error.code != NSURLErrorNotConnectedToInternet
 && error.code != NSURLErrorCancelled
 && error.code != NSURLErrorTimedOut
 && error.code != NSURLErrorInternationalRoamingOff
 && error.code != NSURLErrorDataNotAllowed
 && error.code != NSURLErrorCannotFindHost
 && error.code != NSURLErrorCannotConnectToHost) {
      @synchronized (self.failedURLs) {
          [self.failedURLs addObject:url];
      }
}
```
如果下载成功，若支持失败重试，将url从failURLs里删除：

``` objective_c
if ((options & SDWebImageRetryFailed)) {
    @synchronized (self.failedURLs) {
         [self.failedURLs removeObject:url];
    }
}
```
如果delegate实现了，`imageManager:transformDownloadedImage:withURL:`方法，图片在缓存之前，需要做转换（在全局队列中调用，不阻塞主线程）。转化成功切下载全部结束，图片存入缓存，调用completedBlock回调，第一个参数是转换后的image。

``` objective_c
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];

    if (transformedImage && finished) {
        BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
        //将图片缓存起来
        [self.imageCache storeImage:transformedImage recalculateFromImage:imageWasTransformed imageData:(imageWasTransformed ? nil : data) forKey:key toDisk:cacheOnDisk];
    }
    dispatch_main_sync_safe(^{
        if (strongOperation && !strongOperation.isCancelled) {
            completedBlock(transformedImage, nil, SDImageCacheTypeNone, finished, url);
        }
    });
});
```
否则，直接存入缓存，调用completedBlock回调，第一个参数是下载的原始image。

``` objective_c
if (downloadedImage && finished) {
    [self.imageCache storeImage:downloadedImage recalculateFromImage:NO imageData:data forKey:key toDisk:cacheOnDisk];
}

dispatch_main_sync_safe(^{
    if (strongOperation && !strongOperation.isCancelled) {
        completedBlock(downloadedImage, nil, SDImageCacheTypeNone, finished, url);
    }
});
```
存入缓存都是调用***imageCache***的

``` objective_c
- (void)storeImage:(UIImage *)image recalculateFromImage:(BOOL)recalculate imageData:(NSData *)imageData forKey:(NSString *)key toDisk:(BOOL)toDisk
```
方法。

**如果没有在缓存找到图片，且不允许下载，**直接调用completedBlock，第一个参数为nil。

``` objective_c
dispatch_main_sync_safe(^{
    __strong __typeof(weakOperation) strongOperation = weakOperation;
    if (strongOperation && !weakOperation.isCancelled) {//为啥这里用weakOperation TODO
        completedBlock(nil, nil, SDImageCacheTypeNone, YES, url);
    }
});
```

最后都要将这个operation从runningOperations里删除。

``` objective_c
@synchronized (self.runningOperations) {
    [self.runningOperations removeObject:operation];
 }
```

这里再说一下上面的operation，是一个`SDWebImageCombinedOperation `实例:

``` objective_c
@interface SDWebImageCombinedOperation : NSObject <SDWebImageOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (copy, nonatomic) SDWebImageNoParamsBlock cancelBlock;
@property (strong, nonatomic) NSOperation *cacheOperation;

@end
```
是一个遵循`SDWebImageOperation`协议的NSObject子类。

``` objective_c
@protocol SDWebImageOperation <NSObject>

- (void)cancel;

@end
```
在里面封装一个NSOperation，这么做的目的应该是为了使代码更简洁。因为下载操作需要查询缓存的operation和实际下载的operation，这个类的cancel方法可以同时cancel两个operation，同时还可以维护一个状态cancelled。
敬请期待后续更新！
