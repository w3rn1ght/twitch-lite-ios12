#import <UIKit/UIKit.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

// Large paging banner used at the top of the Home tab.
@interface TVHeroCarouselView : UIView

@property (nonatomic, copy, nullable) void (^onSelectStream)(TVStream *stream);

- (void)configureWithStreams:(NSArray<TVStream *> *)streams;
- (CGFloat)preferredHeightForWidth:(CGFloat)width;

@end

// Card used in the horizontal "live now" row.
@interface TVHomeStreamCard : UIControl

- (void)configureWithStream:(TVStream *)stream;
+ (CGFloat)heightForWidth:(CGFloat)width;

@end

// Box art card used in the horizontal "categories" row.
@interface TVHomeGameCard : UIControl

- (void)configureWithGame:(TVGame *)game;
+ (CGFloat)heightForWidth:(CGFloat)width;

@end

@interface TVSectionHeaderView : UIView

- (instancetype)initWithTitle:(NSString *)title;

@end

NS_ASSUME_NONNULL_END
