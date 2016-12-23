---
title:  "CoreData之Transformable属性"
date:   2016-12-23 11:39:23
categories: [iOS]
tags: [iOS]
comments: true
---
我们经常用到CoreData存储数据，但是CoreData能存储的基本都是一些标准的数据类型，当我们想存储`NSDictionary`、`NSArray`时，基本都是把它们转为 `NSData` 然后用 binary data 的类型写入到 Core Data，然后要用的时候再从 Core Data 中读出 NSData，再转回`NSDictionary`或者    `NSArray`。比如NSDictionary,我们可能用`NSJSONSerialization`的

``` objective_c
//NSData->NSDictionary
+ (nullable id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
//NSDictionary->NSData
+ (nullable NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;
```

这两个方法转换，对NSArray,我们可能用`NSKeyedArchiver`的

``` objective_c
//NSArray->NSData
+ (NSData *)archivedDataWithRootObject:(id)rootObject;
//NSData->NSArray
+ (nullable id)unarchiveObjectWithData:(NSData *)data;
```

这两个方法转换。显然每次这样做是挺麻烦的。再看看Core Data还支持哪些我们没用过的类型，于是乎就看到了`Transformable `。

![CoreData支持Transformable类型](http://upload-images.jianshu.io/upload_images/1136939-b221b8027c4996c5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


关于`Transformable`，苹果开发文档是这样说的:

>The idea behind transformable attributes is that you access an attribute as a non-standard type, but behind the scenes Core Data uses an instance of NSValueTransformer to convert the attribute to and from an instance of NSData. Core Data then stores the data instance to the persistent store.

意思就是用了transformable属性，CoreData在底层自动帮我们把非标准类型与NSData之间做了转换，这就节省了很多人力，而且减少了错误概率。这个转换过程依赖了一个`NSValueTransformer`实例。`NSValueTransformer`用于把一个值转换为另一个值。它指定了可以处理哪类输入，并且合适时甚至支持反向的转换。

它的主要方法有：

``` objective_c
+ (void)setValueTransformer:(nullable NSValueTransformer *)transformer forName:(NSValueTransformerName)name;
 // class of the "output" objects, as returned by transformedValue:
+ (Class)transformedValueClass;   
 // flag indicating whether transformation is read-only or not
+ (BOOL)allowsReverseTransformation;   
 // by default returns value
- (nullable id)transformedValue:(nullable id)value;         
// by default raises an exception if +allowsReverseTransformation returns NO and otherwise invokes transformedValue: 
- (nullable id)reverseTransformedValue:(nullable id)value;    
```

一个单例用一个名字来注册，其他几个方法定义了输入与输出的类型以及反向转换。

我们创建一个Students.xcdatamodel, 新建一个StudentEntity，有四个属性是`Tranformable`的，其中`courses`实际上是想存储NSArray类型，对应学生的课程表； `scores`实际上是想存储NSDictionary类型，对应学生的各科成绩；`contact`实际上是想存储自定义的Contact类型，对应学生的各种联系方式； `avatar`实际上是想存储UIImage类型，对应学生的头像。

![Students.xcdatamodel](http://upload-images.jianshu.io/upload_images/1136939-6b2e0204e6b28182.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

如果我们不指定NSValueTransformer的名字，Core Data 会默认使用
 NSKeyedUnarchiveFromDataTransformerName来注册一个transformer,它实际上用`archivedDataWithRootObject:`和`unarchiverObjectWithData:`方法来做类型转换。使用这个默认的transformer的非标准数据类型必须实现 NSCoding 协议，才能将其实例序列化为 NSData，并且进行存取。所以对于那些支持用`NSKeyedArchiver`转化并且实现了NSCoding协议的类型就可以直接使用默认的transformer了，比如NSDictionary、NSArrary等。
但是，对于一些不能直接用`NSKeyedArchiver`转换的非标准类型就不可以直接使用默认的transformer了，比如UIImage需要借助UIImagePNGRepresentation方法转换为NSData进行归档。此时，我们就需要自定义一个`NSValueTransformer`实例，并且重载几个关键的方法。

> If you specify a custom transformer, it must transform an instance of the non-standard data type into an instance of NSData and support reverse transformation.

首先，我们如上图所示，对`avatar`属性的Value Transformer取个名字，比如UIIMageToNSDataTransformer， 那在对应的studentEntity.h文件中，我们定义一个UIIMageToNSDataTransformer类继承自NSValueTransformer。

``` objective_c
// studentEntity.h
@interface StudentEntity : RHManagedObject
@property (nonatomic,strong) NSNumber *sid;
@property (nonatomic,strong) NSString *name;
@property (nonatomic,strong) NSNumber *age;
@property (nonatomic,strong) id       courses;//dictionary
@property (nonatomic,strong) id       scores;//array
@property (nonatomic,strong) id       avatar;//image;
@property (nonatomic,strong) id       contact;//custom class
@end

@interface UIIMageToNSDataTransformer: NSValueTransformer

@end
```

在studentEntity.m文件中重载几个方法：

``` objective_c
+ (Class)transformedValueClass {
    return [NSData class];
}
+ (BOOL)allowsReverseTransformation {
    return YES;
}
- (id)transformedValue:(id)value
{
    if (value == nil) {
        return nil;
    }
    if ([value isKindOfClass:[NSData class]]) {
        return value;
    }
    return UIImagePNGRepresentation((UIImage *)value);
}
- (id)reverseTransformedValue:(id)value
{
    return [UIImage imageWithData:(NSData *)value];
}
```
这样，就可以像NSDictionary一样简便地存取UIImage属性值了。

另外，对于我们自定义的Contact类型，要想使用这种转化，必须要实现NSCoding协议，既实现：

``` objective_c
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder; 
```
这两个方法。我们这样做：

``` objective_c
@interface Contact : NSObject <NSCoding>

@property (nonatomic, strong) NSString  *addr;
@property (nonatomic, strong) NSString  *phone;
@property (nonatomic, assign) NSInteger qq;

@end

@implementation Contact

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _addr   = [aDecoder decodeObjectForKey:@"addr"];
        _phone  = [aDecoder decodeObjectForKey:@"phone"];
        _qq     = [aDecoder decodeIntegerForKey:@"qq"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_addr forKey:@"addr"];
    [aCoder encodeObject:_phone forKey:@"phone"];
    [aCoder encodeInteger:_qq forKey:@"qq"];
}

@end
```
至此，我们就可以很方便地存取上面所有的数据了，而不用每次手动转化了。

``` objective_c
- (instancetype)initWithModel:(StudentModel *)model
{
    self = [super init];
    if (self) {
        self.sid    = model.sid;
        self.name   = model.name;
        self.age    = model.age;
        self.avatar = model.avatar;//直接赋值，不需转化
        self.courses = model.courses;//直接赋值，不需转化
        self.scores  = model.scores;//直接赋值，不需转化
        self.contact = model.contact;//直接赋值，不需转化
    }
    return self;
}

- (void)setModel:(StudentModel *)model {
    model.sid   = self.sid;
    model.name  = self.name;
    model.age   = self.age;
    model.avatar = self.avatar;//直接赋值，不需转化
    model.courses = self.courses;//直接赋值，不需转化
    model.scores  = self.scores;//直接赋值，不需转化
    model.contact = self.contact;//直接赋值，不需转化
}
```

我们先测试写入数据：

``` objective_c

StudentProfile *profile = [[StudentProfile alloc] init];
profile.sid     = @(1001);
profile.name    = @"小明";
profile.age     = @(12);
profile.courses = [NSMutableArray arrayWithObjects:kCourseYuwen,kCourseShuxu,kCourseYinyu, nil];
profile.avatar  = [UIImage imageNamed:@"default_avatar"];
profile.scores  = [NSMutableDictionary dictionary];
[profile.scores setObject:@(80) forKey:kCourseYuwen];
[profile.scores setObject:@(91) forKey:kCourseShuxu];
[profile.scores setObject:@(88) forKey:kCourseYinyu];
    
profile.contact = [Contact new];
profile.contact.addr = @"希望小学3年2班";
profile.contact.phone = @"188-1221-3309";
profile.contact.qq = 1033294537;
//save data
[[_Dao getStudentDao] saveStudentProfile:profile commit:YES];
```

然后读取数据：

``` objective_c
NSArray *students = [[_Dao getStudentDao] loadAll];
    
for (StudentProfile *student in students) {
    NSLog(@"==========ID  :%@==========",student.sid);
    NSLog(@"==========NAME:%@==========",student.name);
    NSLog(@"==========AGE :%@==========",student.age);
    for (id key in student.scores) {
        NSString *course = key;
        NSLog(@"==========%@ :%@分==========",course,[student.scores objectForKey:key]);
    }
    NSLog(@"==========ADDR :%@==========",student.contact.addr);
    NSLog(@"==========PHONE:%@==========",student.contact.phone);
    NSLog(@"==========QQ   :%ld==========",student.contact.qq);

    UIImage *avatar = student.avatar;
    NSLog(@"==========AVATAR :%@==========",avatar);
}
```

输入结果：

``` objective_c
==========ID  :1001==========
==========NAME:小明==========
==========AGE :12==========
==========语文 :80分==========
==========数学 :91分==========
==========英语 :88分==========
==========ADDR :希望小学3年2班==========
==========PHONE:188-1221-3309==========
 ==========QQ  :1033294537==========
==========AVATAR :<UIImage: 0x60000009cf20>, {60, 48}==========
```

如果我们不自定义UIIMageToNSDataTransformer的，avatar输出是NULL，既存取失败的。如果Contact不实现NSCoding协议，程序会crash的。

BTW：使用自定义的 transformer 还可以引申出另一个应用，就是可以用于对 entity 中某个 attribute 进行加密/解密，用自定义的加密/解密算法。单独对某个 attribute 进行加密/解密，可以避免对整个 entity 甚至是整个 database 进行加密/解密，提高了性能，降低了内存消耗。

更深入的学习可以参考 [TransformerKit库](https://github.com/mattt/TransformerKit/blob/master/TransformerKit/NSValueTransformer%2BTransformerKit.m#L36) 
