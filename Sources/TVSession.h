#import <Foundation/Foundation.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TVSessionDidChangeNotification;
extern NSString *const TVFavoritesDidChangeNotification;

@interface TVSession : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *token;
@property (nonatomic, strong, readonly, nullable) TVUser *currentUser;
@property (nonatomic, assign, readonly) BOOL isLoggedIn;
@property (nonatomic, copy, readonly) NSArray<NSString *> *favoriteLogins;

+ (instancetype)shared;

- (void)restore;
- (void)loginWithToken:(NSString *)token completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;
- (void)logout;
- (void)refreshCurrentUserWithCompletion:(void (^ _Nullable)(BOOL success))completion;

- (BOOL)isFavorite:(NSString *)login;
- (void)toggleFavorite:(NSString *)login;
- (void)addFavorite:(NSString *)login;
- (void)removeFavorite:(NSString *)login;

@end

NS_ASSUME_NONNULL_END
