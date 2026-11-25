#import "TVImageLoader.h"
#import "TVTheme.h"
#import <WebKit/WebKit.h>

static NSString *const TVImageUserAgent =
    @"Mozilla/5.0 (iPad; CPU OS 12_4 like Mac OS X) AppleWebKit/605.1.15 "
    @"(KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1";

#pragma mark - WebKit fallback

// Some networks/jailbreak setups refuse plain NSURLSession requests to the
// Twitch image CDN while WebKit loads them fine. This fallback fetches the
// bytes inside a hidden WKWebView and hands the decoded image back.
@interface TVImageWebFallback : NSObject <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong, nullable) WKWebView *webView;
@property (nonatomic, assign) BOOL pageReady;
@property (nonatomic, assign) BOOL pageLoading;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *queue;
@property (nonatomic, copy, nullable) NSString *activeURL;
@property (nonatomic, copy, nullable) void (^activeCompletion)(UIImage * _Nullable image);
+ (instancetype)shared;
- (void)loadURL:(NSString *)urlString completion:(void (^)(UIImage * _Nullable image))completion;
- (void)pump;
- (void)ensureWebView;
- (void)finishWithImage:(nullable UIImage *)image;
@end

@implementation TVImageWebFallback

+ (instancetype)shared {
    static TVImageWebFallback *fallback = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fallback = [[TVImageWebFallback alloc] init];
    });
    return fallback;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSMutableArray array];
    }
    return self;
}

- (void)loadURL:(NSString *)urlString completion:(void (^)(UIImage *))completion {
    if (urlString.length == 0 || completion == nil) {
        if (completion) {
            completion(nil);
        }
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.queue addObject:@{@"url": urlString, @"completion": [completion copy]}];
        [self pump];
    });
}

- (void)ensureWebView {
    if (self.webView) {
        return;
    }
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    [configuration.userContentController addScriptMessageHandler:self name:@"tvimg"];
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(-200.0, -200.0, 2.0, 2.0)
                                                  configuration:configuration];
    webView.userInteractionEnabled = NO;
    webView.navigationDelegate = self;
    self.webView = webView;

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        window = [UIApplication sharedApplication].windows.firstObject;
    }
    [window addSubview:webView];

    NSString *html =
        @"<!doctype html><html><head><meta charset=\"utf-8\"></head><body><script>"
        @"window.grab=function(u){"
        @"fetch(u,{credentials:'omit',cache:'no-store'}).then(function(r){"
        @"if(!r.ok){throw new Error('HTTP '+r.status);}return r.blob();"
        @"}).then(function(b){var fr=new FileReader();"
        @"fr.onload=function(){window.webkit.messageHandlers.tvimg.postMessage({url:u,data:String(fr.result)});};"
        @"fr.onerror=function(){window.webkit.messageHandlers.tvimg.postMessage({url:u,error:'read error'});};"
        @"fr.readAsDataURL(b);"
        @"}).catch(function(e){window.webkit.messageHandlers.tvimg.postMessage({url:u,error:String(e)});});"
        @"};"
        @"</script></body></html>";
    self.pageLoading = YES;
    [webView loadHTMLString:html baseURL:[NSURL URLWithString:@"https://www.twitch.tv/"]];
}

- (void)pump {
    if (self.activeURL.length > 0 || self.queue.count == 0) {
        return;
    }
    [self ensureWebView];
    if (!self.pageReady) {
        return;
    }
    NSDictionary *item = self.queue.firstObject;
    [self.queue removeObjectAtIndex:0];
    NSString *urlString = item[@"url"];
    self.activeURL = urlString;
    self.activeCompletion = item[@"completion"];

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:urlString options:0 error:&jsonError];
    NSString *jsonURL = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : nil;
    if (!jsonURL) {
        [self finishWithImage:nil];
        return;
    }
    NSString *script = [NSString stringWithFormat:@"window.grab(%@);", jsonURL];
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (error) {
            NSLog(@"[TwitchLite] image fallback js error: %@", error.localizedDescription);
            [strongSelf finishWithImage:nil];
        }
    }];

    NSString *expected = urlString;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf && [strongSelf.activeURL isEqualToString:expected]) {
            NSLog(@"[TwitchLite] image fallback timeout for %@", expected);
            [strongSelf finishWithImage:nil];
        }
    });
}

- (void)finishWithImage:(UIImage *)image {
    void (^completion)(UIImage *) = self.activeCompletion;
    self.activeURL = nil;
    self.activeCompletion = nil;
    if (completion) {
        completion(image);
    }
    [self pump];
}

#pragma mark WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.pageReady = YES;
    self.pageLoading = NO;
    [self pump];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.pageLoading = NO;
    NSLog(@"[TwitchLite] image fallback page failed: %@", error.localizedDescription);
}

#pragma mark WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSDictionary *body = message.body;
    NSString *urlString = body[@"url"];
    if (![urlString isKindOfClass:[NSString class]] || ![urlString isEqualToString:self.activeURL]) {
        return;
    }
    NSString *dataString = body[@"data"];
    UIImage *image = nil;
    if ([dataString isKindOfClass:[NSString class]] && dataString.length > 0) {
        NSRange comma = [dataString rangeOfString:@","];
        if (comma.location != NSNotFound) {
            NSString *base64 = [dataString substringFromIndex:comma.location + 1];
            NSData *data = [[NSData alloc] initWithBase64EncodedString:base64
                                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (data.length > 0) {
                image = [UIImage imageWithData:data];
            }
        }
    }
    if (!image) {
        NSLog(@"[TwitchLite] image fallback failed for %@ (%@)", urlString, body[@"error"] ?: @"decode");
    }
    [self finishWithImage:image];
}

@end

#pragma mark - Loader

@interface TVImageLoader ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *cache;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *inFlight;
- (void)deliverImage:(nullable UIImage *)image forURL:(NSString *)urlString;
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
        // The API requests already work through the shared session, so reuse the
        // exact same networking stack for images instead of a custom session.
        _session = [NSURLSession sharedSession];
    }
    return self;
}

- (void)clearCache {
    [self.cache removeAllObjects];
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
    request.timeoutInterval = 20.0;
    [request setValue:TVImageUserAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"https://www.twitch.tv/" forHTTPHeaderField:@"Referer"];
    [request setValue:@"https://www.twitch.tv" forHTTPHeaderField:@"Origin"];
    [request setValue:@"image/jpeg,image/png,image/*;q=0.8" forHTTPHeaderField:@"Accept"];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        UIImage *image = nil;
        if (data.length > 0 && error == nil && (http == nil || (http.statusCode >= 200 && http.statusCode < 300))) {
            image = [UIImage imageWithData:data];
        }
        if (image) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self deliverImage:image forURL:urlString];
            });
            return;
        }
        NSLog(@"[TwitchLite] image load failed %@ (http %ld, %lu bytes, %@); trying WebKit",
              urlString, (long)http.statusCode, (unsigned long)data.length,
              error.localizedDescription ?: @"no error");
        [[TVImageWebFallback shared] loadURL:urlString completion:^(UIImage *fallbackImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self deliverImage:fallbackImage forURL:urlString];
            });
        }];
    }];
    [task resume];
}

- (void)deliverImage:(UIImage *)image forURL:(NSString *)urlString {
    NSMutableArray *blocks = self.inFlight[urlString];
    [self.inFlight removeObjectForKey:urlString];
    if (image) {
        [self.cache setObject:image forKey:urlString cost:(NSUInteger)(image.size.width * image.size.height * 4.0)];
    }
    for (void (^block)(UIImage *) in blocks) {
        block(image);
    }
}

- (void)probeURL:(NSString *)urlString completion:(void (^)(NSString *))completion {
    if (completion == nil) {
        return;
    }
    if (urlString.length == 0) {
        completion(@"URL не задан");
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.timeoutInterval = 20.0;
    [request setValue:TVImageUserAgent forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"https://www.twitch.tv/" forHTTPHeaderField:@"Referer"];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
        NSString *report = nil;
        if (error) {
            report = [NSString stringWithFormat:@"ошибка: %@", error.localizedDescription];
        } else if (http && (http.statusCode < 200 || http.statusCode >= 300)) {
            report = [NSString stringWithFormat:@"HTTP %ld", (long)http.statusCode];
        } else if (!image) {
            report = [NSString stringWithFormat:@"не декодируется (%lu байт)", (unsigned long)data.length];
        } else {
            report = [NSString stringWithFormat:@"HTTP %ld · %lu байт · %.0f×%.0f",
                      (long)http.statusCode, (unsigned long)data.length, image.size.width, image.size.height];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(report);
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

#pragma mark - Remote image view

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
