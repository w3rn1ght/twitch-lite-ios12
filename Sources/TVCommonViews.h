#import <UIKit/UIKit.h>
#import "TVIcons.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVAvatarView : UIView

@property (nonatomic, copy, nullable) NSString *urlString;
@property (nonatomic, copy, nullable) NSString *displayName;

- (void)setURLString:(nullable NSString *)urlString displayName:(nullable NSString *)displayName;

@end

@interface TVLiveBadgeView : UIView

@property (nonatomic, copy) NSString *text;

- (instancetype)initWithText:(NSString *)text;

@end

@interface TVPillView : UIView

@property (nonatomic, strong, readonly) UILabel *textLabel;
@property (nonatomic, strong, readonly) UIImageView *iconView;

- (instancetype)initWithIcon:(TVIconName)icon text:(NSString *)text;
- (void)setText:(NSString *)text;
- (void)setIcon:(TVIconName)icon;

@end

@interface TVEmptyStateView : UIView

@property (nonatomic, copy, nullable) void (^actionBlock)(void);
@property (nonatomic, strong, readonly) UIButton *actionButton;

- (instancetype)initWithIcon:(TVIconName)icon
                       title:(NSString *)title
                    subtitle:(nullable NSString *)subtitle
                 actionTitle:(nullable NSString *)actionTitle;

@end

@interface TVLoadingOverlay : UIView

@property (nonatomic, strong, readonly) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, readonly) UILabel *textLabel;

- (void)start;
- (void)stop;

@end

@interface TVGradientView : UIView

@property (nonatomic, copy) NSArray<UIColor *> *colors;

@end

@interface TVStatusDotView : UIView

@property (nonatomic, strong) UIColor *dotColor;

@end

NS_ASSUME_NONNULL_END
