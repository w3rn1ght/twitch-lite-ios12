#import "TVModels.h"

static NSString *TVStringValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return @"";
}

static NSInteger TVIntegerValue(id value) {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value integerValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [value integerValue];
    }
    return 0;
}

static NSDictionary *TVDictionaryValue(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

@implementation TVUser

+ (nullable instancetype)userFromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    TVUser *user = [[TVUser alloc] init];
    user.userID = TVStringValue(json[@"id"]);
    user.login = TVStringValue(json[@"login"]);
    user.displayName = TVStringValue(json[@"displayName"]);
    if (user.displayName.length == 0) {
        user.displayName = user.login;
    }
    user.avatarURL = TVStringValue(json[@"profileImageURL"]);
    user.bannerURL = TVStringValue(json[@"bannerImageURL"]);
    user.bio = TVStringValue(json[@"description"]);
    NSDictionary *followers = TVDictionaryValue(json[@"followers"]);
    user.followerCount = TVIntegerValue(followers[@"totalCount"]);
    NSDictionary *follows = TVDictionaryValue(json[@"follows"]);
    user.followingCount = TVIntegerValue(follows[@"totalCount"]);
    user.partner = [json[@"isPartner"] boolValue];
    user.affiliate = [json[@"isAffiliate"] boolValue];
    NSDictionary *streamJSON = TVDictionaryValue(json[@"stream"]);
    if (streamJSON) {
        user.stream = [TVStream streamFromJSON:streamJSON];
    }
    return user;
}

+ (instancetype)placeholderWithLogin:(NSString *)login {
    TVUser *user = [[TVUser alloc] init];
    user.login = login ?: @"";
    user.displayName = login ?: @"";
    return user;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.userID.length) dict[@"id"] = self.userID;
    if (self.login.length) dict[@"login"] = self.login;
    if (self.displayName.length) dict[@"displayName"] = self.displayName;
    if (self.avatarURL.length) dict[@"profileImageURL"] = self.avatarURL;
    if (self.bannerURL.length) dict[@"bannerImageURL"] = self.bannerURL;
    if (self.bio.length) dict[@"description"] = self.bio;
    dict[@"followers"] = @{@"totalCount": @(self.followerCount)};
    dict[@"follows"] = @{@"totalCount": @(self.followingCount)};
    dict[@"isPartner"] = @(self.partner);
    dict[@"isAffiliate"] = @(self.affiliate);
    return dict;
}

- (BOOL)isLive {
    return self.stream != nil;
}

@end

@implementation TVStream

+ (nullable instancetype)streamFromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    TVStream *stream = [[TVStream alloc] init];
    stream.streamID = TVStringValue(json[@"id"]);
    stream.title = TVStringValue(json[@"title"]);
    stream.viewers = TVIntegerValue(json[@"viewersCount"]);
    stream.previewURL = TVStringValue(json[@"previewImageURL"]);
    NSDictionary *game = TVDictionaryValue(json[@"game"]);
    stream.gameName = TVStringValue(game[@"name"]);
    stream.gameID = TVStringValue(game[@"id"]);
    NSDictionary *broadcaster = TVDictionaryValue(json[@"broadcaster"]);
    if (broadcaster) {
        stream.broadcaster = [TVUser userFromJSON:broadcaster];
    }
    return stream;
}

@end

@implementation TVGame

+ (nullable instancetype)gameFromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    TVGame *game = [[TVGame alloc] init];
    game.gameID = TVStringValue(json[@"id"]);
    game.name = TVStringValue(json[@"name"]);
    game.displayName = TVStringValue(json[@"displayName"]);
    if (game.displayName.length == 0) {
        game.displayName = game.name;
    }
    game.boxArtURL = TVStringValue(json[@"boxArtURL"]);
    game.viewers = TVIntegerValue(json[@"viewersCount"]);
    return game;
}

@end

@implementation TVSearchResults

- (instancetype)init {
    self = [super init];
    if (self) {
        _channels = @[];
        _games = @[];
    }
    return self;
}

@end
