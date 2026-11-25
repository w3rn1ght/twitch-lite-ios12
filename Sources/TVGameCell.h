#import <UIKit/UIKit.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVGameCell : UICollectionViewCell

- (void)configureWithGame:(TVGame *)game;

@end

@interface TVGameRowCell : UITableViewCell

- (void)configureWithGame:(TVGame *)game;

@end

NS_ASSUME_NONNULL_END
