#import "TVChatMessage.h"
#import "TVTheme.h"

static NSString *TVTagString(NSDictionary *tags, NSString *key) {
    id value = tags[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSRange TVRangeForCodePointRange(NSString *text, NSInteger start, NSInteger end) {
    if (text.length == 0 || start < 0 || end < start) {
        return NSMakeRange(NSNotFound, 0);
    }
    __block NSInteger codePoint = 0;
    __block NSInteger location = NSNotFound;
    __block NSInteger endLocation = NSNotFound;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        if (codePoint == start) {
            location = substringRange.location;
        }
        if (codePoint == end) {
            endLocation = NSMaxRange(substringRange);
            *stop = YES;
        }
        codePoint += 1;
    }];
    if (location != NSNotFound && endLocation != NSNotFound) {
        return NSMakeRange(location, endLocation - location);
    }
    return NSMakeRange(NSNotFound, 0);
}

static NSArray<TVEmote *> *TVParseEmotes(NSString *tag, NSString *text) {
    if (tag.length == 0 || text.length == 0) {
        return @[];
    }
    NSMutableArray<TVEmote *> *result = [NSMutableArray array];
    NSArray *groups = [tag componentsSeparatedByString:@"/"];
    for (NSString *group in groups) {
        NSArray *pieces = [group componentsSeparatedByString:@":"];
        if (pieces.count != 2) {
            continue;
        }
        NSString *emoteID = pieces[0];
        NSArray *ranges = [pieces[1] componentsSeparatedByString:@","];
        for (NSString *rangeText in ranges) {
            NSArray *bounds = [rangeText componentsSeparatedByString:@"-"];
            if (bounds.count != 2) {
                continue;
            }
            NSInteger start = [bounds[0] integerValue];
            NSInteger end = [bounds[1] integerValue];
            NSRange range = TVRangeForCodePointRange(text, start, end);
            if (range.location == NSNotFound || NSMaxRange(range) > text.length) {
                continue;
            }
            TVEmote *emote = [[TVEmote alloc] init];
            emote.emoteID = emoteID;
            emote.name = [text substringWithRange:range];
            emote.range = range;
            emote.imageURL = [NSString stringWithFormat:@"https://static-cdn.jtvnw.net/emoticons/v2/%@/default/dark/1.0", emoteID];
            [result addObject:emote];
        }
    }
    [result sortUsingComparator:^NSComparisonResult(TVEmote *a, TVEmote *b) {
        if (a.range.location == b.range.location) {
            return NSOrderedSame;
        }
        return a.range.location < b.range.location ? NSOrderedAscending : NSOrderedDescending;
    }];
    return result;
}

@implementation TVEmote
@end

@implementation TVChatMessage

+ (instancetype)systemMessage:(NSString *)text {
    TVChatMessage *message = [[TVChatMessage alloc] init];
    message.messageID = [[NSUUID UUID] UUIDString];
    message.login = @"twitch";
    message.displayName = @"Twitch";
    message.text = text ?: @"";
    message.systemText = text ?: @"";
    message.isSystem = YES;
    message.timestamp = [[NSDate date] timeIntervalSince1970];
    message.badges = @[];
    message.emotes = @[];
    return message;
}

+ (instancetype)messageWithTags:(NSDictionary *)tags
                         prefix:(NSString *)prefix
                        command:(NSString *)command
                         params:(NSArray<NSString *> *)params
                        channel:(NSString *)channel
                    currentUser:(NSString *)currentUser {
    TVChatMessage *message = [[TVChatMessage alloc] init];
    NSString *nick = TVTagString(tags, @"login");
    if (nick.length == 0 && prefix.length) {
        NSString *clean = [prefix hasPrefix:@":"] ? [prefix substringFromIndex:1] : prefix;
        NSRange bang = [clean rangeOfString:@"!"];
        nick = bang.location == NSNotFound ? clean : [clean substringToIndex:bang.location];
    }
    if (nick.length == 0) {
        nick = TVTagString(tags, @"display-name") ?: @"unknown";
    }
    message.login = nick;
    NSString *display = TVTagString(tags, @"display-name");
    message.displayName = display.length ? display : nick;
    message.messageID = TVTagString(tags, @"id") ?: [[NSUUID UUID] UUIDString];
    NSString *color = TVTagString(tags, @"color");
    message.colorHex = (color.length == 7 && [color hasPrefix:@"#"]) ? color : nil;
    message.timestamp = [TVTagString(tags, @"tmi-sent-ts") doubleValue] / 1000.0;
    if (message.timestamp <= 0) {
        message.timestamp = [[NSDate date] timeIntervalSince1970];
    }

    NSMutableArray<NSString *> *badges = [NSMutableArray array];
    NSString *badgeTag = TVTagString(tags, @"badges");
    if (badgeTag.length) {
        for (NSString *part in [badgeTag componentsSeparatedByString:@","]) {
            NSString *name = [[part componentsSeparatedByString:@"/"] firstObject];
            if (name.length && ![badges containsObject:name]) {
                [badges addObject:name];
            }
        }
    }
    if ([TVTagString(tags, @"mod") isEqualToString:@"1"] && ![badges containsObject:@"moderator"]) {
        [badges addObject:@"moderator"];
    }
    if ([TVTagString(tags, @"subscriber") isEqualToString:@"1"] && ![badges containsObject:@"subscriber"]) {
        [badges addObject:@"subscriber"];
    }
    if ([TVTagString(tags, @"vip") isEqualToString:@"1"] && ![badges containsObject:@"vip"]) {
        [badges addObject:@"vip"];
    }
    message.badges = badges;

    NSString *text = params.lastObject ?: @"";
    if ([text hasPrefix:@"\u0001ACTION "]) {
        message.isAction = YES;
        text = [text substringFromIndex:8];
        if ([text hasSuffix:@"\u0001"]) {
            text = [text substringToIndex:text.length - 1];
        }
    }
    message.text = text;
    message.emotes = TVParseEmotes(TVTagString(tags, @"emotes"), text);

    if (currentUser.length) {
        NSRange mention = [text rangeOfString:currentUser options:NSCaseInsensitiveSearch];
        message.isHighlighted = mention.location != NSNotFound;
    }
    return message;
}

@end
