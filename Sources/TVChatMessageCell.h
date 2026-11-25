#import <UIKit/UIKit.h>
#import "TVChatMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVChatMessageCell : UITableViewCell

@property (nonatomic, copy, nullable) void (^onNeedsReload)(void);

- (void)configureWithMessage:(TVChatMessage *)message currentUser:(nullable NSString *)currentUser;

@end

@interface TVSystemMessageCell : UITableViewCell

- (void)configureWithText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
