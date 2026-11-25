#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "TVChatMessage.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TVChatConnectionState) {
    TVChatConnectionStateDisconnected = 0,
    TVChatConnectionStateConnecting,
    TVChatConnectionStateConnected,
    TVChatConnectionStateReconnecting,
};

@class TVChatConnection;

@protocol TVChatConnectionDelegate <NSObject>
- (void)chatConnection:(TVChatConnection *)connection didChangeState:(TVChatConnectionState)state status:(NSString *)status;
- (void)chatConnection:(TVChatConnection *)connection didReceiveMessage:(TVChatMessage *)message;
@optional
- (void)chatConnection:(TVChatConnection *)connection didReceiveSystemMessage:(NSString *)text;
@end

@interface TVChatConnection : NSObject

@property (nonatomic, weak, nullable) id<TVChatConnectionDelegate> delegate;
@property (nonatomic, assign, readonly) TVChatConnectionState state;
@property (nonatomic, assign, readonly) BOOL isConnected;

- (instancetype)initWithHostView:(UIView *)hostView channel:(NSString *)channel;
- (void)connectWithToken:(nullable NSString *)token login:(nullable NSString *)login;
- (void)disconnect;
- (void)sendMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
