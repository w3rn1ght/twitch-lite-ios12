#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TVImageLoader : NSObject

+ (instancetype)shared;

- (nullable UIImage *)cachedImageForURL:(NSString *)urlString;
- (void)loadImageURL:(NSString *)urlString completion:(void (^)(UIImage * _Nullable image))completion;
- (void)prefetchURLs:(NSArray<NSString *> *)urlStrings;
- (void)clearCache;
- (void)probeURL:(NSString *)urlString completion:(void (^)(NSString *report))completion;

@end

@interface TVRemoteImageView : UIImageView

@property (nonatomic, copy, nullable) NSString *urlString;
@property (nonatomic, strong, nullable) UIImage *placeholderImage;

- (void)setURLString:(nullable NSString *)urlString placeholderImage:(nullable UIImage *)placeholderImage;

@end

NS_ASSUME_NONNULL_END
