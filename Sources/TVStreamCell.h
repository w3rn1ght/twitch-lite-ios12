#import <UIKit/UIKit.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVStreamCell : UITableViewCell

@property (nonatomic, copy, nullable) void (^onFavoriteTapped)(void);

- (void)configureWithUser:(TVUser *)user;
- (void)configureWithStream:(TVStream *)stream;
- (void)refreshFavoriteState;

@end

NS_ASSUME_NONNULL_END
