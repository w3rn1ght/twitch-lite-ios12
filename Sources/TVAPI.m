#import "TVAPI.h"
#import "TVSession.h"

static NSString *const TVGQLURL = @"https://gql.twitch.tv/gql";
static NSString *const TVTwitchClientID = @"kimne78kx3ncx6brgo4mv6wki5h1ko";
static NSString *const TVAPIErrorDomain = @"TVAPIErrorDomain";

static NSError *TVAPIError(NSString *message) {
    return [NSError errorWithDomain:TVAPIErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Ошибка Twitch API"}];
}

static NSArray *TVEdges(id connection) {
    if (![connection isKindOfClass:[NSDictionary class]]) {
        return @[];
    }
    id edges = connection[@"edges"];
    return [edges isKindOfClass:[NSArray class]] ? edges : @[];
}

static NSDictionary *TVNodeFromEdge(id edge) {
    if (![edge isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id node = edge[@"node"];
    if ([node isKindOfClass:[NSDictionary class]]) {
        return node;
    }
    id item = edge[@"item"];
    return [item isKindOfClass:[NSDictionary class]] ? item : nil;
}

static NSString *TVEncodeQueryValue(NSString *value) {
    NSMutableCharacterSet *allowed = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [allowed addCharactersInString:@"-._~"];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

@implementation TVAPI

+ (instancetype)shared {
    static TVAPI *api = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        api = [[TVAPI alloc] init];
    });
    return api;
}

- (void)graphQLQuery:(NSString *)query variables:(NSDictionary *)variables completion:(TVAPIDataCompletion)completion {
    if (completion == nil) {
        return;
    }
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    payload[@"query"] = query ?: @"";
    if (variables.count) {
        payload[@"variables"] = variables;
    }
    NSError *jsonError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!body) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, jsonError ?: TVAPIError(@"Не удалось собрать запрос.")); });
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:TVGQLURL]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    request.timeoutInterval = 25.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:TVTwitchClientID forHTTPHeaderField:@"Client-ID"];
    [request setValue:@"https://www.twitch.tv" forHTTPHeaderField:@"Origin"];
    [request setValue:@"https://www.twitch.tv/" forHTTPHeaderField:@"Referer"];
    [request setValue:@"TwitchLite/1.0 (iPhone; iOS 12)" forHTTPHeaderField:@"User-Agent"];

    NSString *token = [TVSession shared].token;
    if (token.length) {
        [request setValue:[NSString stringWithFormat:@"OAuth %@", token] forHTTPHeaderField:@"Authorization"];
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        if (http && (http.statusCode < 200 || http.statusCode >= 300)) {
            NSString *message = [NSString stringWithFormat:@"Twitch API вернул HTTP %ld.", (long)http.statusCode];
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, TVAPIError(message)); });
            return;
        }
        NSError *parseError = nil;
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, parseError ?: TVAPIError(@"Twitch API вернул пустой ответ."));
            });
            return;
        }
        NSDictionary *dict = (NSDictionary *)json;
        id dataObject = dict[@"data"];
        NSArray *errors = [dict[@"errors"] isKindOfClass:[NSArray class]] ? dict[@"errors"] : @[];
        if (dataObject && dataObject != [NSNull null]) {
            if (errors.count) {
                NSLog(@"[TwitchLite] GraphQL partial errors: %@", errors);
            }
            dispatch_async(dispatch_get_main_queue(), ^{ completion(dataObject, nil); });
            return;
        }
        NSString *message = @"Twitch API вернул ошибку.";
        if (errors.count) {
            NSDictionary *first = [errors.firstObject isKindOfClass:[NSDictionary class]] ? errors.firstObject : nil;
            NSString *remote = first[@"message"];
            if ([remote isKindOfClass:[NSString class]] && remote.length) {
                message = remote;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, TVAPIError(message)); });
    }];
    [task resume];
}

- (void)fetchCurrentUserWithCompletion:(void (^)(TVUser *, NSError *))completion {
    NSString *query =
        @"query CurrentUser {"
        @"  currentUser {"
        @"    id login displayName profileImageURL(width: 300) bannerImageURL description"
        @"    followers { totalCount } follows { totalCount } isPartner isAffiliate"
        @"  }"
        @"}";
    [self graphQLQuery:query variables:nil completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *current = data[@"currentUser"];
        if (![current isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, nil);
            return;
        }
        TVUser *user = [TVUser userFromJSON:current];
        if (completion) completion(user, nil);
    }];
}

- (void)fetchFollowedChannelsWithCompletion:(void (^)(NSArray<TVUser *> *, NSError *))completion {
    NSString *query =
        @"query FollowedChannels($limit: Int!) {"
        @"  currentUser {"
        @"    follows(first: $limit) {"
        @"      edges {"
        @"        node {"
        @"          id login displayName profileImageURL(width: 70)"
        @"          stream { id viewersCount title previewImageURL(width: 640, height: 360) game { id name } }"
        @"        }"
        @"      }"
        @"    }"
        @"  }"
        @"}";
    [self graphQLQuery:query variables:@{@"limit": @100} completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *current = data[@"currentUser"];
        if (![current isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, TVAPIError(@"Сессия Twitch истекла. Войдите заново."));
            return;
        }
        NSMutableArray<TVUser *> *channels = [NSMutableArray array];
        for (id edge in TVEdges(current[@"follows"])) {
            NSDictionary *node = TVNodeFromEdge(edge);
            TVUser *user = [TVUser userFromJSON:node];
            if (user.login.length) {
                [channels addObject:user];
            }
        }
        [channels sortUsingComparator:^NSComparisonResult(TVUser *a, TVUser *b) {
            BOOL aLive = a.stream != nil;
            BOOL bLive = b.stream != nil;
            if (aLive != bLive) {
                return aLive ? NSOrderedAscending : NSOrderedDescending;
            }
            if (aLive && a.stream.viewers != b.stream.viewers) {
                return a.stream.viewers > b.stream.viewers ? NSOrderedAscending : NSOrderedDescending;
            }
            return [a.displayName caseInsensitiveCompare:b.displayName];
        }];
        if (completion) completion(channels, nil);
    }];
}

- (void)fetchTopStreamsWithCompletion:(void (^)(NSArray<TVStream *> *, NSError *))completion {
    NSString *query =
        @"query TopStreams {"
        @"  streams(first: 24) {"
        @"    edges {"
        @"      node {"
        @"        id title viewersCount previewImageURL(width: 640, height: 360)"
        @"        broadcaster { id login displayName profileImageURL(width: 70) }"
        @"        game { id name }"
        @"      }"
        @"    }"
        @"  }"
        @"}";
    [self graphQLQuery:query variables:nil completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<TVStream *> *streams = [NSMutableArray array];
        for (id edge in TVEdges(data[@"streams"])) {
            TVStream *stream = [TVStream streamFromJSON:TVNodeFromEdge(edge)];
            if (stream.broadcaster.login.length) {
                [streams addObject:stream];
            }
        }
        if (completion) completion(streams, nil);
    }];
}

- (void)fetchPopularGamesWithCompletion:(void (^)(NSArray<TVGame *> *, NSError *))completion {
    NSString *query =
        @"query PopularGames {"
        @"  games(first: 24) {"
        @"    edges { node { id name displayName boxArtURL(width: 120, height: 160) viewersCount } }"
        @"  }"
        @"}";
    [self graphQLQuery:query variables:nil completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<TVGame *> *games = [NSMutableArray array];
        for (id edge in TVEdges(data[@"games"])) {
            TVGame *game = [TVGame gameFromJSON:TVNodeFromEdge(edge)];
            if (game.gameID.length) {
                [games addObject:game];
            }
        }
        if (completion) completion(games, nil);
    }];
}

- (void)searchQuery:(NSString *)query completion:(void (^)(TVSearchResults *, NSError *))completion {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        if (completion) completion([[TVSearchResults alloc] init], nil);
        return;
    }
    NSString *gql =
        @"query Search($query: String!) {"
        @"  searchFor(userQuery: $query, platform: \"web\") {"
        @"    channels { edges { item { ... on User { id login displayName profileImageURL(width: 70) stream { id viewersCount } } } } }"
        @"    games { edges { item { ... on Game { id name displayName boxArtURL(width: 120, height: 160) } } } }"
        @"  }"
        @"}";
    [self graphQLQuery:gql variables:@{@"query": trimmed} completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        TVSearchResults *results = [[TVSearchResults alloc] init];
        NSDictionary *search = data[@"searchFor"];
        NSMutableArray<TVUser *> *channels = [NSMutableArray array];
        for (id edge in TVEdges(search[@"channels"])) {
            TVUser *user = [TVUser userFromJSON:TVNodeFromEdge(edge)];
            if (user.login.length) {
                [channels addObject:user];
            }
        }
        NSMutableArray<TVGame *> *games = [NSMutableArray array];
        for (id edge in TVEdges(search[@"games"])) {
            TVGame *game = [TVGame gameFromJSON:TVNodeFromEdge(edge)];
            if (game.gameID.length) {
                [games addObject:game];
            }
        }
        results.channels = channels;
        results.games = games;
        if (completion) completion(results, nil);
    }];
}

- (void)fetchChannelWithLogin:(NSString *)login completion:(void (^)(TVUser *, NSError *))completion {
    NSString *gql =
        @"query Channel($login: String!) {"
        @"  user(login: $login) {"
        @"    id login displayName profileImageURL(width: 300) bannerImageURL description"
        @"    followers { totalCount } isPartner isAffiliate"
        @"    stream { id title viewersCount previewImageURL(width: 640, height: 360) game { id name } }"
        @"  }"
        @"}";
    [self graphQLQuery:gql variables:@{@"login": login ?: @""} completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *userJSON = data[@"user"];
        if (![userJSON isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, TVAPIError(@"Канал не найден."));
            return;
        }
        if (completion) completion([TVUser userFromJSON:userJSON], nil);
    }];
}

- (void)fetchUsersWithLogins:(NSArray<NSString *> *)logins completion:(void (^)(NSArray<TVUser *> *, NSError *))completion {
    if (logins.count == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    NSString *gql =
        @"query Users($logins: [String!]) {"
        @"  users(logins: $logins) {"
        @"    id login displayName profileImageURL(width: 70)"
        @"    stream { id viewersCount title previewImageURL(width: 640, height: 360) game { id name } }"
        @"  }"
        @"}";
    [self graphQLQuery:gql variables:@{@"logins": logins} completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSMutableArray<TVUser *> *users = [NSMutableArray array];
        id list = data[@"users"];
        if ([list isKindOfClass:[NSArray class]]) {
            for (id item in list) {
                TVUser *user = [TVUser userFromJSON:item];
                if (user.login.length) {
                    [users addObject:user];
                }
            }
        }
        if (completion) completion(users, nil);
    }];
}

- (void)fetchGameStreamsWithName:(NSString *)name gameID:(NSString *)gameID completion:(void (^)(NSArray<TVStream *> *, NSError *))completion {
    NSString *gql = nil;
    NSDictionary *variables = nil;
    if (gameID.length) {
        gql = @"query GameStreams($id: ID!) { game(id: $id) { id name displayName streams(first: 30) { edges { node { id title viewersCount previewImageURL(width: 640, height: 360) broadcaster { id login displayName profileImageURL(width: 70) } game { id name } } } } } }";
        variables = @{@"id": gameID};
    } else if (name.length) {
        gql = @"query GameStreams($name: String!) { game(name: $name) { id name displayName streams(first: 30) { edges { node { id title viewersCount previewImageURL(width: 640, height: 360) broadcaster { id login displayName profileImageURL(width: 70) } game { id name } } } } } }";
        variables = @{@"name": name};
    } else {
        if (completion) completion(nil, TVAPIError(@"Категория не указана."));
        return;
    }

    [self graphQLQuery:gql variables:variables completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *game = data[@"game"];
        NSMutableArray<TVStream *> *streams = [NSMutableArray array];
        for (id edge in TVEdges(game[@"streams"])) {
            TVStream *stream = [TVStream streamFromJSON:TVNodeFromEdge(edge)];
            if (stream.broadcaster.login.length) {
                [streams addObject:stream];
            }
        }
        if (completion) completion(streams, nil);
    }];
}

- (void)fetchPlaybackURLForLogin:(NSString *)login completion:(void (^)(NSURL *, NSError *))completion {
    NSString *gql =
        @"query PlaybackAccessToken($login: String!) {"
        @"  streamPlaybackAccessToken(channelName: $login, params: {platform: \"web\", playerBackend: \"mediaplayer\", playerType: \"site\"}) {"
        @"    value signature"
        @"  }"
        @"}";
    [self graphQLQuery:gql variables:@{@"login": login ?: @""} completion:^(id data, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *tokenJSON = data[@"streamPlaybackAccessToken"];
        NSString *value = tokenJSON[@"value"];
        NSString *signature = tokenJSON[@"signature"];
        if (![value isKindOfClass:[NSString class]] || ![signature isKindOfClass:[NSString class]] || value.length == 0) {
            if (completion) completion(nil, TVAPIError(@"Канал сейчас не в эфире."));
            return;
        }
        NSString *encodedToken = TVEncodeQueryValue(value);
        NSString *encodedSignature = TVEncodeQueryValue(signature);
        NSString *encodedLogin = TVEncodeQueryValue(login);
        NSString *urlString = [NSString stringWithFormat:
            @"https://usher.ttvnw.net/api/channel/hls/%@.m3u8?allow_source=true&allow_audio_only=true&p=1234567&player=twitchweb&segment_preference=4&sig=%@&token=%@&type=any",
            encodedLogin, encodedSignature, encodedToken];
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            if (completion) completion(nil, TVAPIError(@"Не удалось собрать ссылку на поток."));
            return;
        }
        if (completion) completion(url, nil);
    }];
}

@end
