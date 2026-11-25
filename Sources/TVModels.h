#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TVStream;

@interface TVUser : NSObject

@property (nonatomic, copy) NSString *userID;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarURL;
@property (nonatomic, copy) NSString *bannerURL;
@property (nonatomic, copy) NSString *bio;
@property (nonatomic, assign) NSInteger followerCount;
@property (nonatomic, assign) NSInteger followingCount;
@property (nonatomic, assign) BOOL partner;
@property (nonatomic, assign) BOOL affiliate;
@property (nonatomic, strong, nullable) TVStream *stream;

+ (nullable instancetype)userFromJSON:(NSDictionary *)json;
+ (instancetype)placeholderWithLogin:(NSString *)login;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)isLive;

@end

@interface TVStream : NSObject

@property (nonatomic, copy) NSString *streamID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSInteger viewers;
@property (nonatomic, copy) NSString *previewURL;
@property (nonatomic, copy) NSString *gameName;
@property (nonatomic, copy) NSString *gameID;
@property (nonatomic, strong, nullable) TVUser *broadcaster;

+ (nullable instancetype)streamFromJSON:(NSDictionary *)json;

@end

@interface TVGame : NSObject

@property (nonatomic, copy) NSString *gameID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *boxArtURL;
@property (nonatomic, assign) NSInteger viewers;

+ (nullable instancetype)gameFromJSON:(NSDictionary *)json;

@end

@interface TVSearchResults : NSObject

@property (nonatomic, strong) NSArray<TVUser *> *channels;
@property (nonatomic, strong) NSArray<TVGame *> *games;

@end

NS_ASSUME_NONNULL_END
