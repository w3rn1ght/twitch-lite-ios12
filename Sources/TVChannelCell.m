#import "TVChannelCell.h"
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVCommonViews.h"
#import "TVSession.h"

@interface TVChannelCell ()
@property (nonatomic, strong) TVAvatarView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) TVStatusDotView *liveDot;
@property (nonatomic, strong) UIButton *starButton;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView *separatorView;
@property (nonatomic, copy) NSString *login;
@property (nonatomic, assign) BOOL showFavorite;
@end

@implementation TVChannelCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = TVColorBackground();
        self.contentView.backgroundColor = TVColorBackground();
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _avatarView = [[TVAvatarView alloc] initWithFrame:CGRectZero];
        _avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.textColor = TVColorText();
        _nameLabel.font = TVFont(15.0, UIFontWeightSemibold);
        [self.contentView addSubview:_nameLabel];

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.textColor = TVColorMuted();
        _subtitleLabel.font = TVFont(12.0, UIFontWeightRegular);
        [self.contentView addSubview:_subtitleLabel];

        _liveDot = [[TVStatusDotView alloc] initWithFrame:CGRectZero];
        _liveDot.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_liveDot];

        _starButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _starButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_starButton addTarget:self action:@selector(starTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_starButton];

        _chevronView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.image = [TVIcons icon:TVIconChevronRight size:16.0 color:TVColorMuted() weight:2.0];
        [self.contentView addSubview:_chevronView];

        _separatorView = [[UIView alloc] initWithFrame:CGRectZero];
        _separatorView.translatesAutoresizingMaskIntoConstraints = NO;
        _separatorView.backgroundColor = TVColorBorder();
        [self.contentView addSubview:_separatorView];

        [NSLayoutConstraint activateConstraints:@[
            [_avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_avatarView.widthAnchor constraintEqualToConstant:48.0],
            [_avatarView.heightAnchor constraintEqualToConstant:48.0],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:13.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_avatarView.trailingAnchor constant:12.0],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_starButton.leadingAnchor constant:-8.0],

            [_subtitleLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3.0],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_starButton.leadingAnchor constant:-8.0],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-13.0],

            [_liveDot.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_liveDot.centerYAnchor constraintEqualToAnchor:_subtitleLabel.centerYAnchor],
            [_liveDot.widthAnchor constraintEqualToConstant:7.0],
            [_liveDot.heightAnchor constraintEqualToConstant:7.0],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_liveDot.trailingAnchor constant:5.0],

            [_starButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-10.0],
            [_starButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_starButton.widthAnchor constraintEqualToConstant:36.0],
            [_starButton.heightAnchor constraintEqualToConstant:36.0],

            [_chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:16.0],
            [_chevronView.heightAnchor constraintEqualToConstant:16.0],

            [_separatorView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:76.0],
            [_separatorView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_separatorView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_separatorView.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }
    return self;
}

- (void)configureWithUser:(TVUser *)user showFavorite:(BOOL)showFavorite {
    self.login = user.login;
    self.showFavorite = showFavorite;
    self.nameLabel.text = user.displayName.length ? user.displayName : user.login;
    [self.avatarView setURLString:user.avatarURL displayName:self.nameLabel.text];

    TVStream *stream = user.stream;
    if (stream) {
        self.liveDot.dotColor = TVColorLive();
        self.subtitleLabel.text = [NSString stringWithFormat:@"В эфире · %@ зрителей", TVFormatViewers(stream.viewers)];
        self.subtitleLabel.textColor = TVColorMuted();
        self.liveDot.hidden = NO;
    } else {
        self.liveDot.dotColor = TVColorMuted();
        self.subtitleLabel.text = @"Не в эфире";
        self.subtitleLabel.textColor = TVColorMuted();
        self.liveDot.hidden = NO;
    }

    self.starButton.hidden = !showFavorite;
    self.chevronView.hidden = showFavorite;
    [self refreshFavoriteState];
}

- (void)refreshFavoriteState {
    BOOL favorite = [[TVSession shared] isFavorite:self.login];
    UIImage *image = [TVIcons icon:(favorite ? TVIconStarFilled : TVIconStar) size:22.0
                             color:(favorite ? TVColorPurpleBright() : TVColorMuted()) weight:1.8];
    [self.starButton setImage:image forState:UIControlStateNormal];
}

- (void)starTapped {
    TVHapticLight();
    if (self.onFavoriteTapped) {
        self.onFavoriteTapped();
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.avatarView setURLString:nil displayName:nil];
    self.nameLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.onFavoriteTapped = nil;
}

@end
