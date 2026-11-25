#import "TVStreamCell.h"
#import <math.h>
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVCommonViews.h"
#import "TVImageLoader.h"
#import "TVSession.h"

@interface TVStreamCell ()
@property (nonatomic, strong) TVRemoteImageView *thumbnailView;
@property (nonatomic, strong) TVAvatarView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *gameLabel;
@property (nonatomic, strong) TVLiveBadgeView *liveBadge;
@property (nonatomic, strong) TVPillView *viewersPill;
@property (nonatomic, strong) TVPillView *offlinePill;
@property (nonatomic, strong) UIButton *starButton;
@property (nonatomic, strong) NSLayoutConstraint *thumbnailHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *thumbnailWidthConstraint;
@property (nonatomic, copy) NSString *login;
@end

@implementation TVStreamCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = TVColorBackground();
        self.contentView.backgroundColor = TVColorBackground();
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _thumbnailView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
        _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbnailView.layer.cornerRadius = 10.0;
        _thumbnailView.clipsToBounds = YES;
        _thumbnailView.backgroundColor = TVColorSurfaceAlt();
        [self.contentView addSubview:_thumbnailView];

        _liveBadge = [[TVLiveBadgeView alloc] initWithText:@"В ЭФИРЕ"];
        _liveBadge.translatesAutoresizingMaskIntoConstraints = NO;
        [_thumbnailView addSubview:_liveBadge];

        _viewersPill = [[TVPillView alloc] initWithIcon:TVIconEye text:@""];
        _viewersPill.translatesAutoresizingMaskIntoConstraints = NO;
        [_thumbnailView addSubview:_viewersPill];

        _offlinePill = [[TVPillView alloc] initWithIcon:(TVIconName)-1 text:@"НЕ В ЭФИРЕ"];
        _offlinePill.translatesAutoresizingMaskIntoConstraints = NO;
        [_thumbnailView addSubview:_offlinePill];

        _avatarView = [[TVAvatarView alloc] initWithFrame:CGRectZero];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.textColor = TVColorText();
        _nameLabel.font = TVFont(15.0, UIFontWeightSemibold);
        _nameLabel.numberOfLines = 1;
        [self.contentView addSubview:_nameLabel];

        _starButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _starButton.translatesAutoresizingMaskIntoConstraints = NO;
        _starButton.tintColor = TVColorMuted();
        [_starButton addTarget:self action:@selector(starTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_starButton];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.textColor = TVColorText();
        _titleLabel.font = TVFont(14.0, UIFontWeightRegular);
        _titleLabel.numberOfLines = 2;
        [self.contentView addSubview:_titleLabel];

        _gameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _gameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _gameLabel.textColor = TVColorMuted();
        _gameLabel.font = TVFont(12.0, UIFontWeightRegular);
        _gameLabel.numberOfLines = 1;
        [self.contentView addSubview:_gameLabel];

        _thumbnailHeightConstraint = [_thumbnailView.heightAnchor constraintEqualToAnchor:_thumbnailView.widthAnchor multiplier:9.0 / 16.0];
        _thumbnailWidthConstraint = [_thumbnailView.widthAnchor constraintEqualToConstant:300.0];
        [NSLayoutConstraint activateConstraints:@[
            [_thumbnailView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
            [_thumbnailView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            _thumbnailWidthConstraint,
            _thumbnailHeightConstraint,

            [_liveBadge.topAnchor constraintEqualToAnchor:_thumbnailView.topAnchor constant:8.0],
            [_liveBadge.leadingAnchor constraintEqualToAnchor:_thumbnailView.leadingAnchor constant:8.0],
            [_viewersPill.topAnchor constraintEqualToAnchor:_thumbnailView.topAnchor constant:8.0],
            [_viewersPill.trailingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor constant:-8.0],
            [_offlinePill.centerXAnchor constraintEqualToAnchor:_thumbnailView.centerXAnchor],
            [_offlinePill.centerYAnchor constraintEqualToAnchor:_thumbnailView.centerYAnchor],

            [_avatarView.topAnchor constraintEqualToAnchor:_thumbnailView.bottomAnchor constant:10.0],
            [_avatarView.leadingAnchor constraintEqualToAnchor:_thumbnailView.leadingAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:36.0],
            [_avatarView.heightAnchor constraintEqualToConstant:36.0],

            [_nameLabel.topAnchor constraintEqualToAnchor:_avatarView.topAnchor constant:1.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:9.0],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:_starButton.leadingAnchor constant:-8.0],

            [_starButton.centerYAnchor constraintEqualToAnchor:_nameLabel.centerYAnchor],
            [_starButton.trailingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor],
            [_starButton.widthAnchor constraintEqualToConstant:34.0],
            [_starButton.heightAnchor constraintEqualToConstant:34.0],

            [_titleLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor],

            [_gameLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4.0],
            [_gameLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_gameLabel.trailingAnchor constraintEqualToAnchor:_thumbnailView.trailingAnchor],
            [_gameLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12.0],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat available = CGRectGetWidth(self.contentView.bounds) - 24.0;
    CGFloat width = MIN(560.0, MAX(160.0, available));
    if (fabs(width - self.thumbnailWidthConstraint.constant) > 0.5) {
        self.thumbnailWidthConstraint.constant = width;
    }
}

- (void)configureWithUser:(TVUser *)user {
    self.login = user.login;
    TVStream *stream = user.stream;
    self.nameLabel.text = user.displayName.length ? user.displayName : user.login;
    [self.avatarView setURLString:user.avatarURL displayName:self.nameLabel.text];

    if (stream) {
        self.titleLabel.text = stream.title.length ? stream.title : @"Без названия";
        self.gameLabel.text = stream.gameName.length ? stream.gameName : @"Стрим";
        self.thumbnailView.alpha = 1.0;
        self.thumbnailView.urlString = stream.previewURL;
        self.liveBadge.hidden = NO;
        self.viewersPill.hidden = NO;
        self.offlinePill.hidden = YES;
        [self.viewersPill setText:TVFormatViewers(stream.viewers)];
    } else {
        self.titleLabel.text = @"Канал не в эфире";
        self.gameLabel.text = @"Офлайн";
        self.thumbnailView.alpha = 0.45;
        self.thumbnailView.urlString = nil;
        self.liveBadge.hidden = YES;
        self.viewersPill.hidden = YES;
        self.offlinePill.hidden = NO;
    }
    [self refreshFavoriteState];
}

- (void)configureWithStream:(TVStream *)stream {
    TVUser *broadcaster = stream.broadcaster;
    self.login = broadcaster.login;
    self.nameLabel.text = broadcaster.displayName.length ? broadcaster.displayName : broadcaster.login;
    [self.avatarView setURLString:broadcaster.avatarURL displayName:self.nameLabel.text];
    self.titleLabel.text = stream.title.length ? stream.title : @"Без названия";
    self.gameLabel.text = stream.gameName.length ? stream.gameName : @"Стрим";
    self.thumbnailView.alpha = 1.0;
    self.thumbnailView.urlString = stream.previewURL;
    self.liveBadge.hidden = NO;
    self.viewersPill.hidden = NO;
    self.offlinePill.hidden = YES;
    [self.viewersPill setText:TVFormatViewers(stream.viewers)];
    [self refreshFavoriteState];
}

- (void)refreshFavoriteState {
    BOOL favorite = [[TVSession shared] isFavorite:self.login];
    UIImage *image = [TVIcons icon:(favorite ? TVIconStarFilled : TVIconStar) size:22.0
                             color:(favorite ? TVColorPurpleBright() : TVColorMuted()) weight:1.8];
    [self.starButton setImage:image forState:UIControlStateNormal];
    self.starButton.accessibilityLabel = favorite ? @"Убрать из избранного" : @"Добавить в избранное";
}

- (void)starTapped {
    TVHapticLight();
    if (self.onFavoriteTapped) {
        self.onFavoriteTapped();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.thumbnailView.urlString = nil;
    [self.avatarView setURLString:nil displayName:nil];
    self.nameLabel.text = nil;
    self.titleLabel.text = nil;
    self.gameLabel.text = nil;
    self.onFavoriteTapped = nil;
}

@end
