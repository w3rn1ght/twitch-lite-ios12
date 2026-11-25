#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Twitch-inspired palette.
UIColor *TVColorBackground(void);
UIColor *TVColorSurface(void);
UIColor *TVColorSurfaceAlt(void);
UIColor *TVColorBorder(void);
UIColor *TVColorPurple(void);
UIColor *TVColorPurpleBright(void);
UIColor *TVColorText(void);
UIColor *TVColorMuted(void);
UIColor *TVColorLive(void);
UIColor *TVColorGreen(void);
UIColor *TVColorRed(void);

UIFont *TVFont(CGFloat size, UIFontWeight weight);
NSString *TVFormatCount(NSInteger count);
NSString *TVFormatViewers(NSInteger count);
NSString *TVRelativeTime(NSTimeInterval timestamp);
UIColor * _Nullable TVColorFromHex(NSString * _Nullable hex);
UIColor *TVColorForName(NSString * _Nullable name);
UIImage *TVSolidImage(UIColor *color);
UIImage *TVRoundedImage(UIColor *color, CGFloat cornerRadius, CGSize size);
UIImage * _Nullable TVGradientImage(NSArray<UIColor *> *colors, CGSize size);

void TVStyleNavigationBar(UINavigationBar *bar);
void TVStyleTabBar(UITabBar *bar);
void TVStyleTableView(UITableView *tableView);
void TVShowAlert(UIViewController *controller, NSString *title, NSString *message);
void TVHapticLight(void);
void TVHapticMedium(void);

NS_ASSUME_NONNULL_END
