#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TVEmote : NSObject

@property (nonatomic, copy) NSString *emoteID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, copy) NSString *imageURL;

@end

@interface TVChatMessage : NSObject

@property (nonatomic, copy) NSString *messageID;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) NSString *colorHex;
@property (nonatomic, copy) NSArray<NSString *> *badges;
@property (nonatomic, copy) NSArray<TVEmote *> *emotes;
@property (nonatomic, assign) BOOL isAction;
@property (nonatomic, assign) BOOL isHighlighted;
@property (nonatomic, assign) BOOL isSystem;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, copy, nullable) NSString *systemText;

+ (instancetype)systemMessage:(NSString *)text;
+ (instancetype)messageWithTags:(NSDictionary *)tags
                         prefix:(nullable NSString *)prefix
                        command:(NSString *)command
                         params:(NSArray<NSString *> *)params
                        channel:(nullable NSString *)channel
                    currentUser:(nullable NSString *)currentUser;

@end

NS_ASSUME_NONNULL_END
