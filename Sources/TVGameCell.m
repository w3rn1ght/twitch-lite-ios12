#import "TVGameCell.h"
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVImageLoader.h"

@interface TVGameCell ()
@property (nonatomic, strong) TVRemoteImageView *boxArtView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *viewersLabel;
@end

@implementation TVGameCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = TVColorBackground();

        _boxArtView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
        _boxArtView.translatesAutoresizingMaskIntoConstraints = NO;
        _boxArtView.layer.cornerRadius = 6.0;
        _boxArtView.clipsToBounds = YES;
        [self.contentView addSubview:_boxArtView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.textColor = TVColorText();
        _nameLabel.font = TVFont(12.0, UIFontWeightMedium);
        _nameLabel.numberOfLines = 2;
        [self.contentView addSubview:_nameLabel];

        _viewersLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _viewersLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _viewersLabel.textColor = TVColorMuted();
        _viewersLabel.font = TVFont(10.0, UIFontWeightRegular);
        [self.contentView addSubview:_viewersLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_boxArtView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_boxArtView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_boxArtView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_boxArtView.heightAnchor constraintEqualToAnchor:_boxArtView.widthAnchor multiplier:4.0 / 3.0],

            [_nameLabel.topAnchor constraintEqualToAnchor:_boxArtView.bottomAnchor constant:6.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],

            [_viewersLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2.0],
            [_viewersLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_viewersLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_viewersLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor],
        ]];
    }
    return self;
}

- (void)configureWithGame:(TVGame *)game {
    self.boxArtView.urlString = game.boxArtURL;
    self.nameLabel.text = game.displayName.length ? game.displayName : game.name;
    self.viewersLabel.text = game.viewers > 0 ? [NSString stringWithFormat:@"%@ зрителей", TVFormatViewers(game.viewers)] : @"";
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.boxArtView.urlString = nil;
    self.nameLabel.text = nil;
    self.viewersLabel.text = nil;
}

@end

@interface TVGameRowCell ()
@property (nonatomic, strong) TVRemoteImageView *boxArtView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView *separatorView;
@end

@implementation TVGameRowCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = TVColorBackground();
        self.contentView.backgroundColor = TVColorBackground();
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _boxArtView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
        _boxArtView.translatesAutoresizingMaskIntoConstraints = NO;
        _boxArtView.layer.cornerRadius = 5.0;
        _boxArtView.clipsToBounds = YES;
        [self.contentView addSubview:_boxArtView];

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

        _chevronView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _chevronView.translatesAutoresizingMaskIntoConstraints = NO;
        _chevronView.image = [TVIcons icon:TVIconChevronRight size:16.0 color:TVColorMuted() weight:2.0];
        [self.contentView addSubview:_chevronView];

        _separatorView = [[UIView alloc] initWithFrame:CGRectZero];
        _separatorView.translatesAutoresizingMaskIntoConstraints = NO;
        _separatorView.backgroundColor = TVColorBorder();
        [self.contentView addSubview:_separatorView];

        [NSLayoutConstraint activateConstraints:@[
            [_boxArtView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
            [_boxArtView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_boxArtView.widthAnchor constraintEqualToConstant:52.0],
            [_boxArtView.heightAnchor constraintEqualToConstant:69.0],

            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:14.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_boxArtView.trailingAnchor constant:12.0],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-8.0],

            [_subtitleLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:3.0],
            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-8.0],
            [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14.0],

            [_chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
            [_chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevronView.widthAnchor constraintEqualToConstant:16.0],
            [_chevronView.heightAnchor constraintEqualToConstant:16.0],

            [_separatorView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:80.0],
            [_separatorView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_separatorView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
            [_separatorView.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }
    return self;
}

- (void)configureWithGame:(TVGame *)game {
    self.boxArtView.urlString = game.boxArtURL;
    self.nameLabel.text = game.displayName.length ? game.displayName : game.name;
    self.subtitleLabel.text = game.viewers > 0 ? [NSString stringWithFormat:@"%@ зрителей", TVFormatViewers(game.viewers)] : @"Категория";
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.boxArtView.urlString = nil;
    self.nameLabel.text = nil;
    self.subtitleLabel.text = nil;
}

@end
