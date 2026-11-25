#import "TVLoginViewController.h"
#import <WebKit/WebKit.h>
#import "TVTheme.h"
#import "TVSession.h"
#import "TVCommonViews.h"

static NSString *const TVLoginURL = @"https://www.twitch.tv/login";
static NSString *const TVDesktopUserAgent =
    @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    @"(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

@interface TVLoginViewController () <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) TVLoadingOverlay *overlay;
@property (nonatomic, strong, nullable) NSTimer *cookieTimer;
@property (nonatomic, assign) BOOL authenticating;
@property (nonatomic, copy, nullable) NSString *lastAttemptedToken;
@property (nonatomic, assign) BOOL hasLoadedLoginPage;

@end

@implementation TVLoginViewController

+ (void)presentFromViewController:(UIViewController *)presenter {
    if (!presenter) {
        return;
    }
    UIViewController *top = presenter;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    if ([top isKindOfClass:[TVLoginViewController class]]) {
        return;
    }
    if ([top isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)top;
        if ([nav.viewControllers.firstObject isKindOfClass:[TVLoginViewController class]]) {
            return;
        }
    }

    TVLoginViewController *login = [[TVLoginViewController alloc] init];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:login];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    TVStyleNavigationBar(navigation.navigationBar);
    [top presentViewController:navigation animated:YES completion:nil];
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Вход в Twitch";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Отмена"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Токен"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(manualTokenTapped)];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progressTintColor = TVColorPurple();
    self.progressView.trackTintColor = TVColorSurfaceAlt();
    self.progressView.progress = 0.0;
    [self.view addSubview:self.progressView];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    if (@available(iOS 10.0, *)) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.navigationDelegate = self;
    self.webView.opaque = NO;
    self.webView.backgroundColor = TVColorBackground();
    self.webView.scrollView.backgroundColor = TVColorBackground();
    self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.customUserAgent = TVDesktopUserAgent;
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self.view addSubview:self.webView];

    self.overlay = [[TVLoadingOverlay alloc] initWithFrame:CGRectZero];
    self.overlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.overlay.textLabel.text = @"Проверяем аккаунт…";
    [self.view addSubview:self.overlay];

    [NSLayoutConstraint activateConstraints:@[
        [self.progressView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.progressView.heightAnchor constraintEqualToConstant:2.0],

        [self.webView.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasLoadedLoginPage) {
        self.hasLoadedLoginPage = YES;
        [self loadLoginPage];
    }
    [self startCookiePolling];
    [self checkCookies];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopCookiePolling];
}

- (void)dealloc {
    [self stopCookiePolling];
    self.webView.navigationDelegate = nil;
    @try {
        [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    } @catch (NSException *exception) {
        (void)exception;
    }
}

- (void)loadLoginPage {
    NSURL *url = [NSURL URLWithString:TVLoginURL];
    if (!url) {
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:30.0];
    [self.webView loadRequest:request];
}

#pragma mark - Cookie polling

- (void)startCookiePolling {
    [self stopCookiePolling];
    self.cookieTimer = [NSTimer scheduledTimerWithTimeInterval:0.9
                                                        target:self
                                                      selector:@selector(cookieTimerFired:)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopCookiePolling {
    [self.cookieTimer invalidate];
    self.cookieTimer = nil;
}

- (void)cookieTimerFired:(NSTimer *)timer {
    [self checkCookies];
}

- (void)checkCookies {
    if (self.authenticating) {
        return;
    }
    WKHTTPCookieStore *store = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
    __weak typeof(self) weakSelf = self;
    [store getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            NSHTTPCookie *best = nil;
            for (NSHTTPCookie *cookie in cookies) {
                if (![cookie.name isEqualToString:@"auth-token"] || cookie.value.length < 20) {
                    continue;
                }
                if (!best) {
                    best = cookie;
                } else if ([cookie.domain hasSuffix:@"twitch.tv"] && ![best.domain hasSuffix:@"twitch.tv"]) {
                    best = cookie;
                } else if (cookie.value.length > best.value.length) {
                    best = cookie;
                }
            }
            if (best) {
                [strongSelf handleToken:best.value];
            }
        });
    }];
}

#pragma mark - Authentication

- (void)handleToken:(NSString *)token {
    NSString *clean = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length < 20 || self.authenticating) {
        return;
    }
    if (self.lastAttemptedToken.length && [self.lastAttemptedToken isEqualToString:clean]) {
        return;
    }
    self.authenticating = YES;
    self.lastAttemptedToken = clean;
    [self stopCookiePolling];
    [self.overlay start];
    self.overlay.textLabel.text = @"Проверяем аккаунт…";

    __weak typeof(self) weakSelf = self;
    [[TVSession shared] loginWithToken:clean completion:^(BOOL success, NSString *errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            [strongSelf.overlay stop];
            strongSelf.authenticating = NO;
            if (success) {
                TVHapticMedium();
                UIViewController *presenting = strongSelf.presentingViewController;
                if (presenting) {
                    [presenting dismissViewControllerAnimated:YES completion:nil];
                } else {
                    [strongSelf.navigationController dismissViewControllerAnimated:YES completion:nil];
                }
            } else {
                [strongSelf startCookiePolling];
                NSString *message = errorMessage.length ? errorMessage : @"Twitch не принял токен. Попробуйте войти ещё раз.";
                TVShowAlert(strongSelf, @"Не удалось войти", message);
            }
        });
    }];
}

- (void)manualTokenTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Вход по токену"
                                                                   message:@"Вставьте OAuth-токен Twitch. Его можно получить из cookie auth-token после входа на twitch.tv."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"oauth:…";
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.returnKeyType = UIReturnKeyGo;
        textField.secureTextEntry = NO;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Войти" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(self) strongSelf = weakSelf;
        NSString *text = alert.textFields.firstObject.text;
        if (strongSelf && text.length) {
            [strongSelf handleToken:text];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.progressView.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.progressView.hidden = YES;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf checkCookies];
    });
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.progressView.hidden = YES;
    if (error.code == NSURLErrorCancelled) {
        return;
    }
    if (self.authenticating) {
        return;
    }
    TVShowAlert(self, @"Не удалось открыть страницу", error.localizedDescription ?: @"Проверьте подключение к интернету.");
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.progressView.hidden = YES;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (object == self.webView && [keyPath isEqualToString:@"estimatedProgress"]) {
        CGFloat progress = self.webView.estimatedProgress;
        [self.progressView setProgress:(float)progress animated:YES];
        self.progressView.hidden = progress >= 0.999;
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
