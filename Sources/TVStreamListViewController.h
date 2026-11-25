#import <UIKit/UIKit.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVStreamListViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title streams:(NSArray<TVStream *> *)streams;

@end

NS_ASSUME_NONNULL_END
