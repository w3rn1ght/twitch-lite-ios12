#import "TVChatMessageCell.h"
#import "TVTheme.h"
#import "TVImageLoader.h"

static UIImage *TVBadgeImage(NSString *badgeName) {
    static NSCache<NSString *, UIImage *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
    });
    UIImage *cached = [cache objectForKey:badgeName];
    if (cached) {
        return cached;
    }

    NSString *text = nil;
    UIColor *color = TVColorMuted();
    if ([badgeName isEqualToString:@"broadcaster"] || [badgeName isEqualToString:@"staff"] || [badgeName isEqualToString:@"admin"]) {
        text = @"ST";
        color = TVColorLive();
    } else if ([badgeName isEqualToString:@"moderator"] || [badgeName isEqualToString:@"global_mod"]) {
        text = @"M";
        color = TVColorGreen();
    } else if ([badgeName isEqualToString:@"vip"]) {
        text = @"V";
        color = [UIColor colorWithRed:1.0 green:0.33 blue:0.62 alpha:1.0];
    } else if ([badgeName isEqualToString:@"subscriber"] || [badgeName isEqualToString:@"founder"]) {
        text = @"S";
        color = TVColorPurple();
    } else if ([badgeName isEqualToString:@"premium"] || [badgeName isEqualToString:@"prime"]) {
        text = @"P";
        color = [UIColor colorWithRed:0.22 green:0.52 blue:1.0 alpha:1.0];
    } else if ([badgeName isEqualToString:@"turbo"]) {
        text = @"T";
        color = TVColorPurpleBright();
    } else if ([badgeName isEqualToString:@"partner"] || [badgeName isEqualToString:@"verified"]) {
        text = @"✓";
        color = TVColorPurple();
    } else {
        return nil;
    }

    CGSize size = CGSizeMake(18.0, 18.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0, 0.0, size.width, size.height)
                                                   cornerRadius:4.0];
    [color setFill];
    [path fill];
    UIFont *font = [UIFont systemFontOfSize:([text isEqualToString:@"✓"] ? 12.0 : 9.0) weight:UIFontWeightBold];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor whiteColor],
    };
    CGSize textSize = [text sizeWithAttributes:attributes];
    [text drawAtPoint:CGPointMake((size.width - textSize.width) / 2.0,
                                  (size.height - textSize.height) / 2.0)
       withAttributes:attributes];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [cache setObject:image forKey:badgeName];
    return image;
}

@interface TVChatMessageCell ()
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) TVChatMessage *message;
@property (nonatomic, copy, nullable) NSString *currentUser;
@property (nonatomic, strong) NSMutableSet<NSString *> *loadingEmotes;
@end

@implementation TVChatMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _messageLabel.numberOfLines = 0;
        _messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _messageLabel.userInteractionEnabled = NO;
        [self.contentView addSubview:_messageLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_messageLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4.0],
            [_messageLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10.0],
            [_messageLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10.0],
            [_messageLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4.0],
        ]];
        _loadingEmotes = [NSMutableSet set];
    }
    return self;
}

- (void)configureWithMessage:(TVChatMessage *)message currentUser:(NSString *)currentUser {
    self.message = message;
    self.currentUser = currentUser;
    [self rebuild];
}

- (void)rebuild {
    TVChatMessage *message = self.message;
    if (!message) {
        return;
    }

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineSpacing = 1.0;
    NSDictionary *baseAttributes = @{
        NSFontAttributeName: TVFont(14.0, UIFontWeightRegular),
        NSForegroundColorAttributeName: TVColorText(),
        NSParagraphStyleAttributeName: paragraph,
    };
    NSDictionary *actionAttributes = @{
        NSFontAttributeName: [UIFont italicSystemFontOfSize:14.0],
        NSForegroundColorAttributeName: (TVColorFromHex(message.colorHex) ?: TVColorForName(message.displayName)),
        NSParagraphStyleAttributeName: paragraph,
    };

    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];

    for (NSString *badge in message.badges) {
        UIImage *image = TVBadgeImage(badge);
        if (!image) {
            continue;
        }
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = image;
        attachment.bounds = CGRectMake(0.0, -3.5, 18.0, 18.0);
        [result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:baseAttributes]];
    }

    UIColor *nameColor = TVColorFromHex(message.colorHex) ?: TVColorForName(message.displayName);
    NSDictionary *nameAttributes = @{
        NSFontAttributeName: TVFont(14.0, UIFontWeightSemibold),
        NSForegroundColorAttributeName: nameColor,
        NSParagraphStyleAttributeName: paragraph,
    };
    [result appendAttributedString:[[NSAttributedString alloc] initWithString:message.displayName attributes:nameAttributes]];
    if (message.isAction) {
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:baseAttributes]];
    } else {
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:@": " attributes:baseAttributes]];
    }

    NSDictionary *bodyAttributes = message.isAction ? actionAttributes : baseAttributes;
    NSString *text = message.text ?: @"";
    NSUInteger cursor = 0;
    for (TVEmote *emote in message.emotes) {
        if (emote.range.location == NSNotFound || emote.range.location < cursor || NSMaxRange(emote.range) > text.length) {
            continue;
        }
        if (emote.range.location > cursor) {
            NSString *segment = [text substringWithRange:NSMakeRange(cursor, emote.range.location - cursor)];
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:segment attributes:bodyAttributes]];
        }

        UIImage *emoteImage = [[TVImageLoader shared] cachedImageForURL:emote.imageURL];
        if (emoteImage) {
            NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
            attachment.image = emoteImage;
            attachment.bounds = CGRectMake(0.0, -7.0, 28.0, 28.0);
            [result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        } else {
            [result appendAttributedString:[[NSAttributedString alloc] initWithString:emote.name attributes:bodyAttributes]];
            if (![self.loadingEmotes containsObject:emote.imageURL]) {
                [self.loadingEmotes addObject:emote.imageURL];
                __weak typeof(self) weakSelf = self;
                TVChatMessage *loadingMessage = message;
                [[TVImageLoader shared] loadImageURL:emote.imageURL completion:^(UIImage *image) {
                    __strong typeof(self) strongSelf = weakSelf;
                    if (!strongSelf || strongSelf.message != loadingMessage || !image) {
                        return;
                    }
                    [strongSelf rebuild];
                    if (strongSelf.onNeedsReload) {
                        strongSelf.onNeedsReload();
                    }
                }];
            }
        }
        cursor = NSMaxRange(emote.range);
    }
    if (cursor < text.length) {
        NSString *segment = [text substringFromIndex:cursor];
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:segment attributes:bodyAttributes]];
    }

    self.messageLabel.attributedText = result;
    self.contentView.backgroundColor = message.isHighlighted
        ? [TVColorPurple() colorWithAlphaComponent:0.18]
        : [UIColor clearColor];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.message = nil;
    self.currentUser = nil;
    self.onNeedsReload = nil;
    self.messageLabel.attributedText = nil;
    self.contentView.backgroundColor = [UIColor clearColor];
    [self.loadingEmotes removeAllObjects];
}

@end

@interface TVSystemMessageCell ()
@property (nonatomic, strong) UILabel *messageLabel;
@end

@implementation TVSystemMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _messageLabel.textColor = TVColorMuted();
        _messageLabel.font = TVFont(11.0, UIFontWeightRegular);
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.numberOfLines = 0;
        [self.contentView addSubview:_messageLabel];
        [NSLayoutConstraint activateConstraints:@[
            [_messageLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:3.0],
            [_messageLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_messageLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
            [_messageLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-3.0],
        ]];
    }
    return self;
}

- (void)configureWithText:(NSString *)text {
    self.messageLabel.text = text;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.messageLabel.text = nil;
}

@end
