#import <UIKit/UIKit.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVChannelCell : UITableViewCell

@property (nonatomic, copy, nullable) void (^onFavoriteTapped)(void);

- (void)configureWithUser:(TVUser *)user showFavorite:(BOOL)showFavorite;
- (void)refreshFavoriteState;

@end

NS_ASSUME_NONNULL_END
