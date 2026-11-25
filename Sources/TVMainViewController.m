#import "TVMainViewController.h"
#import "TVFollowingViewController.h"
#import "TVSearchViewController.h"
#import "TVFavoritesViewController.h"
#import "TVProfileViewController.h"
#import "TVTheme.h"
#import "TVIcons.h"

#pragma mark - Wordmark

@interface TVWordmarkView : UIView
@end

@implementation TVWordmarkView

- (CGSize)intrinsicContentSize {
    return CGSizeMake(96.0, 24.0);
}

- (void)drawRect:(CGRect)rect {
    CGFloat height = CGRectGetHeight(rect);
    CGFloat glyphHeight = 18.0;
    CGFloat glyphWidth = 22.0;
    CGRect bubble = CGRectMake(0.0, (height - glyphHeight) / 2.0, glyphWidth, glyphHeight);

    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:bubble cornerRadius:4.0];
    UIBezierPath *tail = [UIBezierPath bezierPath];
    [tail moveToPoint:CGPointMake(5.0, CGRectGetMaxY(bubble) - 1.0)];
    [tail addLineToPoint:CGPointMake(5.0, CGRectGetMaxY(bubble) + 4.0)];
    [tail addLineToPoint:CGPointMake(10.0, CGRectGetMaxY(bubble) - 1.0)];
    [tail closePath];
    [path appendPath:tail];

    [TVColorPurple() setFill];
    [path fill];

    [[UIColor whiteColor] setFill];
    UIBezierPath *leftEye = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(6.0, CGRectGetMinY(bubble) + 6.0, 3.0, 6.0)
                                                       cornerRadius:1.5];
    UIBezierPath *rightEye = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(13.0, CGRectGetMinY(bubble) + 6.0, 3.0, 6.0)
                                                        cornerRadius:1.5];
    [leftEye fill];
    [rightEye fill];

    NSDictionary *attributes = @{
        NSFontAttributeName: TVFont(20.0, UIFontWeightBold),
        NSForegroundColorAttributeName: TVColorPurple(),
    };
    [@"twitch" drawAtPoint:CGPointMake(28.0, (height - 24.0) / 2.0) withAttributes:attributes];
}

@end

#pragma mark - Main

@implementation TVMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();

    TVFollowingViewController *following = [[TVFollowingViewController alloc] init];
    TVSearchViewController *search = [[TVSearchViewController alloc] init];
    TVFavoritesViewController *favorites = [[TVFavoritesViewController alloc] init];
    TVProfileViewController *profile = [[TVProfileViewController alloc] init];

    UINavigationController *followingNav = [self navigationControllerWithRoot:following];
    UINavigationController *searchNav = [self navigationControllerWithRoot:search];
    UINavigationController *favoritesNav = [self navigationControllerWithRoot:favorites];
    UINavigationController *profileNav = [self navigationControllerWithRoot:profile];

    TVWordmarkView *wordmark = [[TVWordmarkView alloc] initWithFrame:CGRectMake(0.0, 0.0, 96.0, 24.0)];
    following.navigationItem.titleView = wordmark;

    followingNav.tabBarItem = [self tabBarItemWithTitle:@"Подписки" icon:TVIconHeart];
    searchNav.tabBarItem = [self tabBarItemWithTitle:@"Поиск" icon:TVIconSearch];
    favoritesNav.tabBarItem = [self tabBarItemWithTitle:@"Избранное" icon:TVIconStarFilled];
    profileNav.tabBarItem = [self tabBarItemWithTitle:@"Профиль" icon:TVIconPerson];

    self.viewControllers = @[followingNav, searchNav, favoritesNav, profileNav];
    self.selectedIndex = 0;

    TVStyleTabBar(self.tabBar);
    self.tabBar.translucent = NO;
}

- (UINavigationController *)navigationControllerWithRoot:(UIViewController *)root {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.navigationBar.translucent = NO;
    TVStyleNavigationBar(navigation.navigationBar);
    return navigation;
}

- (UITabBarItem *)tabBarItemWithTitle:(NSString *)title icon:(TVIconName)icon {
    UIImage *image = [[TVIcons icon:icon size:24.0 color:[UIColor whiteColor] weight:1.9]
        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:title image:image selectedImage:image];
    item.titlePositionAdjustment = UIOffsetMake(0.0, -1.0);
    return item;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end
