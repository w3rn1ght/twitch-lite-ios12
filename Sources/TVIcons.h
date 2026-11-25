#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TVIconName) {
    TVIconHeart,
    TVIconHeartFilled,
    TVIconSearch,
    TVIconStar,
    TVIconStarFilled,
    TVIconPerson,
    TVIconBack,
    TVIconSend,
    TVIconEye,
    TVIconPlay,
    TVIconPause,
    TVIconChat,
    TVIconClose,
    TVIconShare,
    TVIconSettings,
    TVIconChevronRight,
    TVIconChevronDown,
    TVIconRefresh,
    TVIconMore,
    TVIconExternal,
    TVIconGrid,
    TVIconUsers,
    TVIconLock,
    TVIconCheck,
    TVIconFullscreen,
    TVIconVolume,
    TVIconVolumeMuted,
    TVIconHome,
    TVIconPlus,
    TVIconTV,
    TVIconCompass,
    TVIconBell,
    TVIconCopy,
    TVIconLink,
};

@interface TVIcons : NSObject

+ (UIImage *)icon:(TVIconName)name size:(CGFloat)size color:(UIColor *)color;
+ (UIImage *)icon:(TVIconName)name size:(CGFloat)size color:(UIColor *)color weight:(CGFloat)weight;

@end

NS_ASSUME_NONNULL_END
