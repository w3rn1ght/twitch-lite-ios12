#import "TVSession.h"
#import "TVAPI.h"
#import <Security/Security.h>
#import <WebKit/WebKit.h>

NSString *const TVSessionDidChangeNotification = @"TVSessionDidChangeNotification";
NSString *const TVFavoritesDidChangeNotification = @"TVFavoritesDidChangeNotification";

static NSString *const TVKeychainService = @"com.w3rn1ght.twitchlite";
static NSString *const TVKeychainAccount = @"oauth-token";
static NSString *const TVCurrentUserDefaultsKey = @"TVCurrentUser";
static NSString *const TVFavoritesDefaultsKey = @"TVFavoriteLogins";

@interface TVSession ()
@property (nonatomic, copy, readwrite, nullable) NSString *token;
@property (nonatomic, strong, readwrite, nullable) TVUser *currentUser;
@property (nonatomic, strong) NSMutableArray<NSString *> *favorites;
@end

@implementation TVSession

+ (instancetype)shared {
    static TVSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [[TVSession alloc] init];
    });
    return session;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:TVFavoritesDefaultsKey];
        _favorites = [NSMutableArray arrayWithArray:saved ?: @[]];
    }
    return self;
}

- (void)restore {
    self.token = [self keychainToken];
    NSDictionary *cached = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TVCurrentUserDefaultsKey];
    if ([cached isKindOfClass:[NSDictionary class]]) {
        self.currentUser = [TVUser userFromJSON:cached];
    }
}

- (BOOL)isLoggedIn {
    return self.token.length > 0 && self.currentUser != nil;
}

- (void)loginWithToken:(NSString *)token completion:(void (^)(BOOL, NSString * _Nullable))completion {
    NSString *clean = [self normalizedToken:token];
    if (clean.length < 20) {
        if (completion) {
            completion(NO, @"Токен выглядит слишком коротким.");
        }
        return;
    }

    self.token = clean;
    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchCurrentUserWithCompletion:^(TVUser *user, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (user) {
            strongSelf.currentUser = user;
            [strongSelf saveToken:clean];
            [strongSelf cacheCurrentUser];
            [[NSNotificationCenter defaultCenter] postNotificationName:TVSessionDidChangeNotification object:strongSelf];
            if (completion) {
                completion(YES, nil);
            }
        } else {
            strongSelf.token = nil;
            strongSelf.currentUser = nil;
            NSString *message = error.localizedDescription ?: @"Twitch не принял токен. Попробуйте войти заново.";
            if (completion) {
                completion(NO, message);
            }
        }
    }];
}

- (void)refreshCurrentUserWithCompletion:(void (^)(BOOL))completion {
    if (self.token.length == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchCurrentUserWithCompletion:^(TVUser *user, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (user) {
            strongSelf.currentUser = user;
            [strongSelf cacheCurrentUser];
            [[NSNotificationCenter defaultCenter] postNotificationName:TVSessionDidChangeNotification object:strongSelf];
            if (completion) {
                completion(YES);
            }
        } else if (error == nil) {
            // The token was accepted by the transport but Twitch returned no user.
            [strongSelf logout];
            if (completion) {
                completion(NO);
            }
        } else {
            if (completion) {
                completion(NO);
            }
        }
    }];
}

- (void)logout {
    self.token = nil;
    self.currentUser = nil;
    [self deleteToken];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TVCurrentUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (@available(iOS 11.0, *)) {
        NSSet<NSString *> *types = [NSSet setWithObject:WKWebsiteDataTypeCookies];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:types
                                                  modifiedSince:[NSDate distantPast]
                                              completionHandler:^{}];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:TVSessionDidChangeNotification object:self];
}

- (void)cacheCurrentUser {
    if (!self.currentUser) {
        return;
    }
    NSDictionary *dict = [self.currentUser dictionaryRepresentation];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:TVCurrentUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Favorites

- (NSArray<NSString *> *)favoriteLogins {
    return [self.favorites copy];
}

- (BOOL)isFavorite:(NSString *)login {
    NSString *key = [self normalizedLogin:login];
    if (key.length == 0) {
        return NO;
    }
    for (NSString *saved in self.favorites) {
        if ([[saved lowercaseString] isEqualToString:key]) {
            return YES;
        }
    }
    return NO;
}

- (void)toggleFavorite:(NSString *)login {
    if ([self isFavorite:login]) {
        [self removeFavorite:login];
    } else {
        [self addFavorite:login];
    }
}

- (void)addFavorite:(NSString *)login {
    NSString *key = [self normalizedLogin:login];
    if (key.length == 0 || [self isFavorite:key]) {
        return;
    }
    [self.favorites insertObject:key atIndex:0];
    [self saveFavorites];
}

- (void)removeFavorite:(NSString *)login {
    NSString *key = [self normalizedLogin:login];
    if (key.length == 0) {
        return;
    }
    NSUInteger index = NSNotFound;
    for (NSUInteger i = 0; i < self.favorites.count; i++) {
        if ([[self.favorites[i] lowercaseString] isEqualToString:key]) {
            index = i;
            break;
        }
    }
    if (index != NSNotFound) {
        [self.favorites removeObjectAtIndex:index];
        [self saveFavorites];
    }
}

- (void)saveFavorites {
    [[NSUserDefaults standardUserDefaults] setObject:self.favorites forKey:TVFavoritesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:TVFavoritesDidChangeNotification object:self];
    });
}

- (NSString *)normalizedLogin:(NSString *)login {
    if (![login isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [[login stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
}

#pragma mark - Token helpers

- (NSString *)normalizedToken:(NSString *)token {
    NSString *clean = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *prefixes = @[@"OAuth ", @"oauth:", @"OAuth:", @"oauth "];
    for (NSString *prefix in prefixes) {
        if ([clean hasPrefix:prefix]) {
            clean = [clean substringFromIndex:prefix.length];
            break;
        }
    }
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (nullable NSString *)keychainToken {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TVKeychainService,
        (__bridge id)kSecAttrAccount: TVKeychainAccount,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess && result) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void)saveToken:(NSString *)token {
    [self deleteToken];
    NSData *data = [token dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return;
    }
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TVKeychainService,
        (__bridge id)kSecAttrAccount: TVKeychainAccount,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecValueData: data,
    };
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

- (void)deleteToken {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: TVKeychainService,
        (__bridge id)kSecAttrAccount: TVKeychainAccount,
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@end
