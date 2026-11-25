#import "TVAppDelegate.h"
#import "TVMainViewController.h"
#import "TVLoginViewController.h"
#import "TVSession.h"
#import "TVTheme.h"

@interface TVAppDelegate ()

@property (nonatomic, assign) NSTimeInterval lastRefresh;

@end

@implementation TVAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    TVSession *session = [TVSession shared];
    [session restore];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = TVColorBackground();
    TVMainViewController *main = [[TVMainViewController alloc] init];
    self.window.rootViewController = main;
    [self.window makeKeyAndVisible];

    [self configureAppearance];

    if (session.isLoggedIn) {
        [self refreshSessionSilently];
    } else if (session.token.length > 0) {
        __weak typeof(self) weakSelf = self;
        [session refreshCurrentUserWithCompletion:^(BOOL success) {
            __strong typeof(self) strongSelf = weakSelf;
            if (success) {
                strongSelf.lastRefresh = [[NSDate date] timeIntervalSince1970];
            } else {
                [strongSelf presentLoginIfNeeded];
            }
        }];
    } else {
        [self presentLoginIfNeeded];
    }

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    TVSession *session = [TVSession shared];
    if (!session.isLoggedIn) {
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (self.lastRefresh > 0.0 && now - self.lastRefresh < 120.0) {
        return;
    }
    [self refreshSessionSilently];
}

- (void)configureAppearance {
    // The status bar style is defined in Info.plist (UIStatusBarStyle +
    // UIViewControllerBasedStatusBarAppearance = NO), so no runtime override
    // is needed here.
    [[UINavigationBar appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: TVColorText(),
        NSFontAttributeName: TVFont(17.0, UIFontWeightSemibold),
    }];
    [[UIBarButtonItem appearance] setTintColor:TVColorText()];
}

- (void)refreshSessionSilently {
    __weak typeof(self) weakSelf = self;
    [[TVSession shared] refreshCurrentUserWithCompletion:^(BOOL success) {
        __strong typeof(self) strongSelf = weakSelf;
        if (success) {
            strongSelf.lastRefresh = [[NSDate date] timeIntervalSince1970];
        }
    }];
}

- (void)presentLoginIfNeeded {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *root = self.window.rootViewController;
        if (!root || root.presentedViewController) {
            return;
        }
        [TVLoginViewController presentFromViewController:root];
    });
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
