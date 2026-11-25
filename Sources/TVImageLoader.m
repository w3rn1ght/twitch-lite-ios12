#import "TVImageLoader.h"
#import "TVTheme.h"

@interface TVImageLoader ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *cache;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *inFlight;
@end

@implementation TVImageLoader

+ (instancetype)shared {
    static TVImageLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[TVImageLoader alloc] init];
    });
    return loader;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 240;
        _inFlight = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = 6;
        configuration.timeoutIntervalForRequest = 30.0;
        configuration.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (UIImage *)cachedImageForURL:(NSString *)urlString {
    if (urlString.length == 0) {
        return nil;
    }
    return [self.cache objectForKey:urlString];
}

- (void)loadImageURL:(NSString *)urlString completion:(void (^)(UIImage * _Nullable image))completion {
    if (completion == nil) {
        return;
    }
    if (urlString.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    UIImage *cached = [self.cache objectForKey:urlString];
    if (cached) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(cached); });
        return;
    }

    void (^deliver)(UIImage *) = ^(UIImage *image) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
    };

    NSMutableArray *waiters = self.inFlight[urlString];
    if (waiters) {
        [waiters addObject:[deliver copy]];
        return;
    }

    waiters = [NSMutableArray arrayWithObject:[deliver copy]];
    self.inFlight[urlString] = waiters;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [self.inFlight removeObjectForKey:urlString];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 30.0;
    [request setValue:@"TwitchLite/1.0 (iPhone; iOS 12)" forHTTPHeaderField:@"User-Agent"];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = nil;
        if (data.length > 0 && error == nil) {
            image = [UIImage imageWithData:data];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *blocks = self.inFlight[urlString];
            [self.inFlight removeObjectForKey:urlString];
            if (image) {
                [self.cache setObject:image forKey:urlString cost:(NSUInteger)(image.size.width * image.size.height * 4.0)];
            }
            for (void (^block)(UIImage *) in blocks) {
                block(image);
            }
        });
    }];
    [task resume];
}

- (void)prefetchURLs:(NSArray<NSString *> *)urlStrings {
    for (NSString *urlString in urlStrings) {
        if (urlString.length && [self.cache objectForKey:urlString] == nil) {
            [self loadImageURL:urlString completion:^(UIImage *image) {}];
        }
    }
}

@end

@interface TVRemoteImageView ()
@property (nonatomic, assign) NSUInteger loadToken;
@end

@implementation TVRemoteImageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentMode = UIViewContentModeScaleAspectFill;
        self.clipsToBounds = YES;
        self.backgroundColor = TVColorSurfaceAlt();
    }
    return self;
}

- (void)setURLString:(NSString *)urlString {
    [self setURLString:urlString placeholderImage:self.placeholderImage];
}

- (void)setURLString:(nullable NSString *)urlString placeholderImage:(nullable UIImage *)placeholderImage {
    _urlString = [urlString copy];
    _placeholderImage = placeholderImage;
    self.loadToken += 1;
    NSUInteger token = self.loadToken;

    UIImage *cached = [[TVImageLoader shared] cachedImageForURL:urlString];
    if (cached) {
        self.image = cached;
        return;
    }
    self.image = placeholderImage;
    if (urlString.length == 0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TVImageLoader shared] loadImageURL:urlString completion:^(UIImage *image) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.loadToken != token) {
            return;
        }
        if (image) {
            strongSelf.image = image;
        }
    }];
}

@end
