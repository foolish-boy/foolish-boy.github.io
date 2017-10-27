---
title:  "聊聊ALAssetsLibrary 与 Photos" 
date:   2017-10-25 10:24:23
categories: [iOS]
tags: [iOS]
comments: true
---

# 聊聊ALAssetsLibrary 与 Photos 

`ALAssetsLibrary`和`Photos`都是Apple提供访问系统相册资源的两个标准库，前者在iOS9之后已经被弃用，后者在iOS8上开始支持。可想而知，`Photos`库提供了更全面更友好的接口。

本文通过对比两者的用法来系统地学习一下“iOS访问系统相册资源”的知识点。重点会放在新的`Photos`库。

首先来看看旧的`ALAssetsLibrary`库。

### ALAssetsLibrary

>An instance of ALAssetsLibrary provides access to the videos and photos that are under the control of the Photos application.

`ALAssetsLibrary`相对来说是简洁一些的，只有5个类:

* ALAsset                   表示一个照片／视频资源实体
* ALAssetRepresentation     表示一个资源的详细信息
* ALAssetsFilter            设置拉取条件（图片？视频？全部？）
* ALAssetsGroup             表示一个相册（照片组）
* ALAssetsLibrary           对相册的实际操作接口

创建一个`ALAssetsLibrary`:

``` objective_c
ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
```

这里要注意：**“AssetsLibrary 实例需要强引用”** ，引用官方文档：
>The lifetimes of objects you get back from a library instance are tied to the lifetime of the library instance.

可以如下测试：

``` objective_c
- (void)viewDidLoad {
    [super viewDidLoad];
    _photos = [NSMutableArray new];

    ALAssetsLibrary *al = [[ALAssetsLibrary alloc] init];
    [al enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (group) {
            [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (result) {
                    [_photos addObject:result];
                }
            }];
            *stop = YES;
        }
    } failureBlock:^(NSError *error) {
        
    }];
    //由于ALAssetsLibrary的所有操作都是异步的，这里要在主线程
    //延迟访问_photos
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processResAssets];
    });
}

- (void)processResAssets {
    for (ALAsset *asset  in _photos) {
        CGImageRef *imgRef = asset.thumbnail;
        UIImage *img = [UIImage imageWithCGImage:imgRef];
        NSLog(@"%@",img);
    }
}

```

上面代码中的`ALAssetsLibrary`实例是局部变量，在`processResAssets`方法中访问_photos时，由于_photos存储的只是代表资源文件的指针信息，真正保存资源文件的AssetsLibrary已经被释放了，所以取出来的资源都是nil的。

所以我们要**确保ALAssetsLibrary实例是strong类型的属性或者是单例的**。

`ALAssetsLibrary`类定义了一些Block，其中

```objective-c
typedef void (^ALAssetsLibraryGroupsEnumerationResultsBlock)(ALAssetsGroup *group, BOOL *stop) 
```

**可以设置stop为true来终止block, 而不能像普通的block一样通过return来终止**，其他类似的block都是这个用法。

用`ALAssetLibrary`还有一个要注意的**写入优先原则**，就是说在利用 AssetsLibrary 读取资源的过程中，有任何其它的进程（不一定是同一个 App）在保存资源时，就会收到 ALAssetsLibraryChangedNotification，让用户自行中断读取操作。最常见的就是读取 fullResolutionImage 时，有进程在写入，由于读取 fullResolutionImage 耗时较长，很容易就会 exception。


`ALAssetsLibrary`提供的接口主要是两大类：

**增**

``` objective_c
- (void)writeImageToSavedPhotosAlbum:(CGImageRef)imageRef orientation:(ALAssetOrientation)orientation completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
- (void)writeImageToSavedPhotosAlbum:(CGImageRef)imageRef metadata:(NSDictionary *)metadata completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
- (void)writeImageDataToSavedPhotosAlbum:(NSData *)imageData metadata:(NSDictionary *)metadata completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
- (void)writeVideoAtPathToSavedPhotosAlbum:(NSURL *)videoPathURL completionBlock:(ALAssetsLibraryWriteVideoCompletionBlock)completionBlock
```

**查**

``` objective_c
- (void)enumerateGroupsWithTypes:(ALAssetsGroupType)types usingBlock:(ALAssetsLibraryGroupsEnumerationResultsBlock)enumerationBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock
- (void)assetForURL:(NSURL *)assetURL resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock 
- (void)groupForURL:(NSURL *)groupURL resultBlock:(ALAssetsLibraryGroupResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock 
```

可以看到，`ALAssetsLibrary`并没有提供**删**和**改**的接口。

**ALAssetsLibrary在第一次增、查的时候会提示用户打开访问相册的权限**，这帮开发者省略了自己写权限判断的逻辑。当然，前提是在项目的info.plist中定义了`Privacy - Photo Library Usage Description`这个key，否则会crash。

**ALAsset**定义了很多资源的属性，比如`ALAssetPropertyLocation`、`ALAssetPropertyDuration`、`ALAssetPropertyOrientation`等等，可以通过`- (id)valueForProperty:(NSString *)property`方法来获取值。

可以通过`thumbnail`和`aspectRatioThumbnail`属性获取资源的缩略图。

虽然`ALAssetsLibrary`没有直接提供更新资源的接口，但是`ALAsset`自己提供了。`ALAsset`不仅可以更新资源数据，还可以选择直接覆盖当前资源还是生成一个新的资源。**更新的前提是editable属性为true。**

``` objective_c
//把当前ALAsset更新之后的数据写到新的ALAsset对象中去
- (void)writeModifiedImageDataToSavedPhotosAlbum:(NSData *)imageData metadata:(NSDictionary *)metadata completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock 
- (void)writeModifiedVideoAtPathToSavedPhotosAlbum:(NSURL *)videoPathURL completionBlock:(ALAssetsLibraryWriteVideoCompletionBlock)completionBlock
//直接将更新后的资源数据覆盖原来的资源上，AssetURL不变
- (void)setImageData:(NSData *)imageData metadata:(NSDictionary *)metadata completionBlock:(ALAssetsLibraryWriteImageCompletionBlock)completionBlock
- (void)setVideoAtPath:(NSURL *)videoPathURL completionBlock:(ALAssetsLibraryWriteVideoCompletionBlock)completionBlock
```

如果资源被更新了还想看原来的资源怎么办，Apple已经帮我们想到这个问题了，**originalAsset**就是原始的资源。遗憾的是，如果我们更新了资源却没有存储，那就没办法找到原来的资源了。

**ALAssetRepresentation**是对 ALAsset 的封装，可以更方便地获取 ALAsset 中的资源信息，比如url、filename、scale等等。每个 ALAsset 都有至少有一个 ALAssetRepresentation 对象，可以通过 defaultRepresentation 获取。而例如使用系统相机应用拍摄的 RAW + JPEG 照片，则会有两个 ALAssetRepresentation，一个封装了照片的 RAW 信息，另一个则封装了照片的 JPEG 信息

其中`fullScreenImage`比较常用，就是返回一个屏幕大小的缩略图，比thumbnail大一些，但仍然是分辨率比较低的图片。但是这个很有用，因为它既满足了预览的清晰度要求，也加快了加载速度。

与之对应的是`fullResolutionImage`，它表示原分辨率的图片，当然是最清晰的版本，也是最大的，所以加载速度很慢。很少用到。

**ALAssetsGroup**就是相册，其顺序就是系统相册看到的顺序。
手机的每个相册都有一个预览图，是由`posterImage`属性指定的。

同样地，`ALAssetsGroup`也提供了**增**、**查**的接口。

``` objective_c
//增
// Returns YES if the asset was added successfully.  Returns NO if the group is not editable, or if the asset was not able to be added to the group.
- (BOOL)addAsset:(ALAsset *)asset;

//查
- (void)enumerateAssetsUsingBlock:(ALAssetsGroupEnumerationResultsBlock)enumerationBlock
- (void)enumerateAssetsWithOptions:(NSEnumerationOptions)options usingBlock:(ALAssetsGroupEnumerationResultsBlock)enumerationBlock
- (void)enumerateAssetsAtIndexes:(NSIndexSet *)indexSet options:(NSEnumerationOptions)options usingBlock:(ALAssetsGroupEnumerationResultsBlock)enumerationBlock
```

其中，`enumerateAssetsWithOptions:usingBlock:`可以通过指定`NSEnumerationReverse`选项来倒序遍历相册。
在`ALAssetsGroupEnumerationResultsBlock`处理资源，同上，可以指定stop=true来终止遍历。


### Photos

> The shared PHPhotoLibrary object represents the entire set of assets and collections managed by the Photos app, including both assets stored on the local device and (if enabled) those stored in iCloud Photos

官方建议，iOS8之后开始用`Photos`库来替代`ALAssetLibrary`库。`Photos`提供了额外的关于用户资源的元数据，而这些数据在以前使用 ALAssetsLibrary 框架中是没有办法访问，或者很难访问到。这点可以从`PhotosTypes.h`中看出来，比如可以验证资源库中的图像在捕捉时是否开启了 HDR；拍摄时是否使用了相机应用的全景模式；是否被用户标记为收藏或被隐藏等等信息。

`Photos`淡化照片库中 URL 的概念，改之使用一个标志符来唯一代表一个资源，即**localIdentifier**。其带来的最大好处是PHObject类实现了 NSCopying 协议，可以直接使用localIdentifier属性对PHObject及其子类对象进行对比是否同一个对象。

`Photos`提供了更全面的接口，涵盖了**增**、**删**、**改**、**查**的所有方面。可以参考[官方文档](https://developer.apple.com/documentation/photos/phphotolibrary)。这些操作都是基于相应的变更请求类`PHAssetChangeRequest`, `PHAssetCollectionChangeRequest`和`PHCollectionListChangeRequest`，都在`PhotoLibrary`的`performChanges:completionHandler:`或者`performChangesAndWait:error:`的`changeBlock`中执行。

**增**
每个`change request`的类中都提供了一个新增资源的方法：

``` objective_c
//PHAssetChangeRequest
+ (instancetype)creationRequestForAssetFromImage:(UIImage *)image;
+ (nullable instancetype)creationRequestForAssetFromImageAtFileURL:(NSURL *)fileURL;
+ (nullable instancetype)creationRequestForAssetFromVideoAtFileURL:(NSURL *)fileURL;

//PHAssetCollectionChangeRequest
+ (instancetype)creationRequestForAssetCollectionWithTitle:(NSString *)title;

//PHCollectionListChangeRequest
+ (instancetype)creationRequestForCollectionListWithTitle:(NSString *)title;
```


**删**
每个`change request`的类中都提供了一个删除资源的方法：

``` objective_c
//PHAssetChangeRequest
+ (void)deleteAssets:(id<NSFastEnumeration>)assets;

//PHAssetCollectionChangeRequest
+ (void)deleteAssetCollections:(id<NSFastEnumeration>)assetCollections;

//PHCollectionListChangeRequest
+ (void)deleteCollectionLists:(id<NSFastEnumeration>)collectionLists;
```

**改**
创建`change request`之后，可以使用属性或者实例化方法来修改它代表的asset或者collection的相应特性。比如`changeRequestForAsset:` 方法可以根据目标asset创建一个 `change request`，然后可以修改favorite属性.

``` objective_c
//PHAssetChangeRequest
+ (instancetype)changeRequestForAsset:(PHAsset *)asset;

//PHAssetCollectionChangeRequest
+ (nullable instancetype)changeRequestForAssetCollection:(PHAssetCollection *)assetCollection;
+ (nullable instancetype)changeRequestForAssetCollection:(PHAssetCollection *)assetCollection assets:(PHFetchResult<PHAsset *> *)assets;

//PHCollectionListChangeRequest
+ (nullable instancetype)changeRequestForCollectionList:(PHCollectionList *)collectionList;
+ (nullable instancetype)changeRequestForCollectionList:(PHCollectionList *)collectionList childCollections:(PHFetchResult<__kindof PHCollection *> *)childCollections;
```

官方文档给了一个创建asset添加到album的例子：

``` objective_c
- (void)addNewAssetWithImage:(UIImage *)image toAlbum:(PHAssetCollection *)album {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
        PHObjectPlaceholder *assetPlaceholder = [createAssetRequest placeholderForCreatedAsset];        [albumChangeRequest addAssets:@[ assetPlaceholder ]];
     } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
    }];
}
```

每个`change request`都有一个PHObjectPlaceholder类型的属性，其作用是给新创建的asset或者collection占位，可以在`change block`完成之后直接获取到新创建的资源。你也可以直接在`change block`里直接添加到`change request`中去。

每次在调用`performChanges:completionHandler:`或者 `performChangesAndWait:error:`方法时，Photos都可能尝试提醒用户访问相册权限。

你可以在一个`change block`合并提交多个`change request`。

**查**
`Photos`中有两种资源可供获取：PHAsset 和 PHCollection。PHCollection有PHAssetCollection和PHCollectionList两个子类。获取资源的过程类似于Core Data:

``` objective_c
/*PHAsset*/
+ (PHFetchResult<PHAsset *> *)fetchAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(nullable PHFetchOptions *)options; // includes hidden assets by default
+ (nullable PHFetchResult<PHAsset *> *)fetchKeyAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithBurstIdentifier:(NSString *)burstIdentifier options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithOptions:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithMediaType:(PHAssetMediaType)mediaType options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithALAssetURLs:(NSArray<NSURL *> *)assetURLs options:(nullable PHFetchOptions *)options


/*PHAssetCollection*/
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithType:(PHAssetCollectionType)type subtype:(PHAssetCollectionSubtype)subtype options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsContainingAsset:(PHAsset *)asset withType:(PHAssetCollectionType)type options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithALAssetGroupURLs:(NSArray<NSURL *> *)assetGroupURLs options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchMomentsInMomentList:(PHCollectionList *)momentList options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchMomentsWithOptions:(nullable PHFetchOptions *)options;

/*PHCollectionList*/
+ (PHFetchResult<PHCollectionList *> *)fetchCollectionListsContainingCollection:(PHCollection *)collection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHCollectionList *> *)fetchCollectionListsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHCollectionList *> *)fetchCollectionListsWithType:(PHCollectionListType)collectionListType subtype:(PHCollectionListSubtype)subtype options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHCollectionList *> *)fetchMomentListsWithSubtype:(PHCollectionListSubtype)momentListSubtype containingMoment:(PHAssetCollection *)moment options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHCollectionList *> *)fetchMomentListsWithSubtype:(PHCollectionListSubtype)momentListSubtype options:(nullable PHFetchOptions *)options;
```

获取的结果`PHAsset`、`PHAssetCollection`和`PHCollectionList` 都是轻量级的不可变对象，使用这些类时并没有将其代表的图像或视频或是集合载入内存中，要使用其代表的图像或视频，需要通过`PHImageManager`类来请求。

``` objective_c

#pragma mark - Image
- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options resultHandler:(void (^)(UIImage *__nullable result, NSDictionary *__nullable info))resultHandler;
- (PHImageRequestID)requestImageDataForAsset:(PHAsset *)asset options:(nullable PHImageRequestOptions *)options resultHandler:(void(^)(NSData *__nullable imageData, NSString *__nullable dataUTI, UIImageOrientation orientation, NSDictionary *__nullable info))resultHandler;

#pragma mark - Live Photo
- (PHImageRequestID)requestLivePhotoForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHLivePhotoRequestOptions *)options resultHandler:(void (^)(PHLivePhoto *__nullable livePhoto, NSDictionary *__nullable info))resultHandler PHOTOS_AVAILABLE_IOS_TVOS(9_1, 10_0);


#pragma mark - Video
- (PHImageRequestID)requestPlayerItemForVideo:(PHAsset *)asset options:(nullable PHVideoRequestOptions *)options resultHandler:(void (^)(AVPlayerItem *__nullable playerItem, NSDictionary *__nullable info))resultHandler;
- (PHImageRequestID)requestExportSessionForVideo:(PHAsset *)asset options:(nullable PHVideoRequestOptions *)options exportPreset:(NSString *)exportPreset resultHandler:(void (^)(AVAssetExportSession *__nullable exportSession, NSDictionary *__nullable info))resultHandler;
- (PHImageRequestID)requestAVAssetForVideo:(PHAsset *)asset options:(nullable PHVideoRequestOptions *)options resultHandler:(void (^)(AVAsset *__nullable asset, AVAudioMix *__nullable audioMix, NSDictionary *__nullable info))resultHandler;
```

iOS11的系统相册支持了GIF，这个时候或取GIF就要用`requestImageDataForAsset`了，否则是一张静图。

`targetSize`指定了图片的目标大小，但是结果不一定就是这个大小，还要以来后面options的设置； `contentMode`类似于UIView的contentMode属性，决定了照片应该以按比例缩放还是按比例填充的方式放到目标大小内。如果不对照片大小进行修改或裁剪，那么方法参数是 PHImageManagerMaximumSize 和 PHImageContentMode.Default。

**PHImageRequestOptions**提供了设置图片的其他一些属性。

`deliveryMode`指定了图片递送进度的策略：

* PHImageRequestOptionsDeliveryModeOpportunistic 默认行为，同步获取时返回一个结果；异步获取时会返回多个结果，从低质量版本到高质量版本。
* PHImageRequestOptionsDeliveryModeHighQualityFormat 只返回一次高质量的结果，可以接受长时间的加载。在同步模式下，默认直接采用这个策略。
* PHImageRequestOptionsDeliveryModeFastFormat 只返回一次结果，但质量稍微差一点点，是前面两种策略的结合。

`resizeMode`指定了重新设置图片大小的方式：

* PHImageRequestOptionsResizeModeNone 不用重新设置
* PHImageRequestOptionsResizeModeExact 返回图像与targetSize一样，如果指定了normalizedCropRect，则必须设置为这个模式。
* PHImageRequestOptionsResizeModeFast 已targetSize为参考，优化解码方式，效率更好一些，但结果可能比targetSize大。

`normalizedCropRect`原始图片的单元坐标上的裁剪矩形。只在 resizeMode 为 Exact 时有效。

`networkAccessAllowed`是否下载iCloud上的照片。

`progressHandler`下载iCloud照片的进度处理器。

`version`针对编辑过的照片决定哪个版本的图像资源应该通过 result handler 被递送。

* PHImageRequestOptionsVersionCurrent 会递送包含所有调整和修改的图像。
* PHImageRequestOptionsVersionUnadjusted 会递送未被施加任何修改的图像。
* PHImageRequestOptionsVersionOriginal 会递送原始的、最高质量的格式的图像 (例如 RAW 格式的数据。而当将属性设置为 .Unadjusted 时，会递送一个 JPEG

当你需要加载许多资源时，可以使用**PHCachingImageManager**。比如当要在一组滚动的 collection 视图上展示大量的资源图像的缩略图时，预先将一些图像加载到内存中有时是非常有用的。

在缓存的时候，只是照片资源被缓存，此时还没有裁剪和大小设置；
如果同时对一个asset有多个不同options或targetSize的缓存请求时，采取FIFO的原则。

``` objective_c
- (void)startCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options;
- (void)stopCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options;
- (void)stopCachingImagesForAllAssets;
```
