#import <Foundation/Foundation.h>
#import "TVModels.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^TVAPIDataCompletion)(id _Nullable data, NSError * _Nullable error);

@interface TVAPI : NSObject

+ (instancetype)shared;

- (void)graphQLQuery:(NSString *)query
           variables:(nullable NSDictionary *)variables
          completion:(TVAPIDataCompletion)completion;

- (void)fetchCurrentUserWithCompletion:(void (^)(TVUser * _Nullable user, NSError * _Nullable error))completion;
- (void)fetchFollowedChannelsWithCompletion:(void (^)(NSArray<TVUser *> * _Nullable channels, NSError * _Nullable error))completion;
- (void)fetchTopStreamsWithCompletion:(void (^)(NSArray<TVStream *> * _Nullable streams, NSError * _Nullable error))completion;
- (void)fetchPopularGamesWithCompletion:(void (^)(NSArray<TVGame *> * _Nullable games, NSError * _Nullable error))completion;
- (void)searchQuery:(NSString *)query completion:(void (^)(TVSearchResults * _Nullable results, NSError * _Nullable error))completion;
- (void)fetchChannelWithLogin:(NSString *)login completion:(void (^)(TVUser * _Nullable channel, NSError * _Nullable error))completion;
- (void)fetchUsersWithLogins:(NSArray<NSString *> *)logins completion:(void (^)(NSArray<TVUser *> * _Nullable users, NSError * _Nullable error))completion;
- (void)fetchGameStreamsWithName:(nullable NSString *)name
                          gameID:(nullable NSString *)gameID
                      completion:(void (^)(NSArray<TVStream *> * _Nullable streams, NSError * _Nullable error))completion;
- (void)fetchPlaybackURLForLogin:(NSString *)login completion:(void (^)(NSURL * _Nullable url, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
