#import "TVTheme.h"

UIColor *TVColorBackground(void) {
    return [UIColor colorWithRed:0.055 green:0.055 blue:0.063 alpha:1.0]; // #0e0e10
}

UIColor *TVColorSurface(void) {
    return [UIColor colorWithRed:0.094 green:0.094 blue:0.106 alpha:1.0]; // #18181b
}

UIColor *TVColorSurfaceAlt(void) {
    return [UIColor colorWithRed:0.141 green:0.141 blue:0.161 alpha:1.0]; // #242428
}

UIColor *TVColorBorder(void) {
    return [UIColor colorWithRed:0.184 green:0.184 blue:0.208 alpha:1.0]; // #2f2f35
}

UIColor *TVColorPurple(void) {
    return [UIColor colorWithRed:0.569 green:0.278 blue:1.0 alpha:1.0]; // #9147ff
}

UIColor *TVColorPurpleBright(void) {
    return [UIColor colorWithRed:0.663 green:0.439 blue:1.0 alpha:1.0]; // #a970ff
}

UIColor *TVColorText(void) {
    return [UIColor colorWithRed:0.937 green:0.937 blue:0.945 alpha:1.0]; // #efeff1
}

UIColor *TVColorMuted(void) {
    return [UIColor colorWithRed:0.678 green:0.678 blue:0.722 alpha:1.0]; // #adadb8
}

UIColor *TVColorLive(void) {
    return [UIColor colorWithRed:0.922 green:0.016 blue:0.0 alpha:1.0]; // #eb0400
}

UIColor *TVColorGreen(void) {
    return [UIColor colorWithRed:0.0 green:0.78 blue:0.34 alpha:1.0];
}

UIColor *TVColorRed(void) {
    return [UIColor colorWithRed:0.95 green:0.22 blue:0.25 alpha:1.0];
}

UIFont *TVFont(CGFloat size, UIFontWeight weight) {
    return [UIFont systemFontOfSize:size weight:weight];
}

NSString *TVFormatCount(NSInteger count) {
    if (count < 0) {
        return @"0";
    }
    if (count < 1000) {
        return [NSString stringWithFormat:@"%ld", (long)count];
    }
    if (count < 1000000) {
        double value = count / 1000.0;
        NSString *text = (value < 10.0)
            ? [NSString stringWithFormat:@"%.1f", value]
            : [NSString stringWithFormat:@"%.0f", value];
        return [[text stringByReplacingOccurrencesOfString:@"." withString:@","] stringByAppendingString:@" тыс."];
    }
    double value = count / 1000000.0;
    NSString *text = (value < 10.0)
        ? [NSString stringWithFormat:@"%.1f", value]
        : [NSString stringWithFormat:@"%.0f", value];
    return [[text stringByReplacingOccurrencesOfString:@"." withString:@","] stringByAppendingString:@" млн"];
}

NSString *TVFormatViewers(NSInteger count) {
    return TVFormatCount(count);
}

NSString *TVRelativeTime(NSTimeInterval timestamp) {
    if (timestamp <= 0) {
        return @"";
    }
    NSTimeInterval delta = [[NSDate date] timeIntervalSince1970] - timestamp;
    if (delta < 60) {
        return @"только что";
    }
    if (delta < 3600) {
        return [NSString stringWithFormat:@"%ld мин назад", (long)(delta / 60)];
    }
    if (delta < 86400) {
        return [NSString stringWithFormat:@"%ld ч назад", (long)(delta / 3600)];
    }
    return [NSString stringWithFormat:@"%ld дн назад", (long)(delta / 86400)];
}

UIColor * _Nullable TVColorFromHex(NSString * _Nullable hex) {
    if (![hex isKindOfClass:[NSString class]] || hex.length < 4) {
        return nil;
    }
    NSString *value = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (value.length == 3) {
        NSString *r = [value substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [value substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [value substringWithRange:NSMakeRange(2, 1)];
        value = [NSString stringWithFormat:@"%@%@%@%@%@%@", r, r, g, g, b, b];
    }
    if (value.length != 6) {
        return nil;
    }
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:value];
    if (![scanner scanHexInt:&rgb]) {
        return nil;
    }
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

UIColor *TVColorForName(NSString *name) {
    static NSArray<UIColor *> *colors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors = @[
            [UIColor colorWithRed:1.00 green:0.33 blue:0.33 alpha:1.0],
            [UIColor colorWithRed:1.00 green:0.50 blue:0.20 alpha:1.0],
            [UIColor colorWithRed:0.95 green:0.78 blue:0.20 alpha:1.0],
            [UIColor colorWithRed:0.35 green:0.85 blue:0.45 alpha:1.0],
            [UIColor colorWithRed:0.30 green:0.75 blue:0.95 alpha:1.0],
            [UIColor colorWithRed:0.45 green:0.55 blue:1.00 alpha:1.0],
            [UIColor colorWithRed:0.75 green:0.45 blue:1.00 alpha:1.0],
            [UIColor colorWithRed:1.00 green:0.45 blue:0.75 alpha:1.0],
        ];
    });
    NSUInteger hash = [name.lowercaseString hash];
    return colors[hash % colors.count];
}

UIImage *TVSolidImage(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0, 1.0), NO, 0.0);
    [color setFill];
    UIRectFill(CGRectMake(0.0, 0.0, 1.0, 1.0));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsZero];
}

UIImage *TVRoundedImage(UIColor *color, CGFloat cornerRadius, CGSize size) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0, 0.0, size.width, size.height)
                                                   cornerRadius:cornerRadius];
    [color setFill];
    [path fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGFloat cap = MAX(cornerRadius, 1.0);
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(cap, cap, cap, cap)];
}

UIImage * _Nullable TVGradientImage(NSArray<UIColor *> *colors, CGSize size) {
    if (colors.count == 0 || size.width <= 0 || size.height <= 0) {
        return nil;
    }
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in colors) {
        [cgColors addObject:(__bridge id)color.CGColor];
    }
    CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace(colors.firstObject.CGColor),
                                                        (__bridge CFArrayRef)cgColors, NULL);
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(0.0, 0.0),
                                CGPointMake(0.0, size.height),
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

void TVStyleNavigationBar(UINavigationBar *bar) {
    bar.translucent = NO;
    bar.barStyle = UIBarStyleBlack;
    bar.barTintColor = TVColorBackground();
    bar.tintColor = TVColorText();
    bar.titleTextAttributes = @{
        NSForegroundColorAttributeName: TVColorText(),
        NSFontAttributeName: TVFont(17.0, UIFontWeightSemibold),
    };
    [bar setBackgroundImage:TVSolidImage(TVColorBackground()) forBarMetrics:UIBarMetricsDefault];
    bar.shadowImage = TVSolidImage(TVColorBorder());
    if (@available(iOS 11.0, *)) {
        bar.prefersLargeTitles = NO;
    }
}

void TVStyleTabBar(UITabBar *tabBar) {
    tabBar.translucent = NO;
    tabBar.barStyle = UIBarStyleBlack;
    tabBar.barTintColor = TVColorSurface();
    tabBar.backgroundColor = TVColorSurface();
    tabBar.tintColor = TVColorPurple();
    tabBar.backgroundImage = TVSolidImage(TVColorSurface());
    tabBar.shadowImage = TVSolidImage(TVColorBorder());
    if (@available(iOS 10.0, *)) {
        tabBar.unselectedItemTintColor = TVColorMuted();
    }
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: TVColorMuted(),
        NSFontAttributeName: TVFont(10.0, UIFontWeightMedium),
    } forState:UIControlStateNormal];
    [[UITabBarItem appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: TVColorPurpleBright(),
        NSFontAttributeName: TVFont(10.0, UIFontWeightSemibold),
    } forState:UIControlStateSelected];
}

void TVStyleTableView(UITableView *tableView) {
    tableView.backgroundColor = TVColorBackground();
    tableView.separatorColor = TVColorBorder();
    tableView.separatorInset = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    tableView.rowHeight = UITableViewAutomaticDimension;
    tableView.estimatedRowHeight = 120.0;
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    if (@available(iOS 11.0, *)) {
        tableView.insetsContentViewsToSafeArea = YES;
    }
}

static UIViewController *TVTopViewController(UIViewController *controller) {
    if (controller.presentedViewController) {
        return TVTopViewController(controller.presentedViewController);
    }
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)controller;
        return TVTopViewController(nav.visibleViewController ?: nav);
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabs = (UITabBarController *)controller;
        return TVTopViewController(tabs.selectedViewController ?: tabs);
    }
    return controller;
}

void TVShowAlert(UIViewController *controller, NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = TVTopViewController(controller);
        if (top.presentedViewController) {
            top = TVTopViewController(top.presentedViewController);
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

void TVHapticLight(void) {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [generator prepare];
        [generator impactOccurred];
    }
}

void TVHapticMedium(void) {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator prepare];
        [generator impactOccurred];
    }
}
