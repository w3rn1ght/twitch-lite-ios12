#import "TVCommonViews.h"
#import "TVTheme.h"
#import "TVImageLoader.h"

@interface TVAvatarView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UILabel *initialsLabel;
@property (nonatomic, assign) NSUInteger loadToken;
@end

@implementation TVAvatarView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = TVColorSurfaceAlt();
        self.clipsToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = TVColorBorder().CGColor;

        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];

        _initialsLabel = [[UILabel alloc] initWithFrame:self.bounds];
        _initialsLabel.textAlignment = NSTextAlignmentCenter;
        _initialsLabel.textColor = [UIColor whiteColor];
        [self addSubview:_initialsLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.imageView.frame = self.bounds;
    self.initialsLabel.frame = self.bounds;
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2.0;
    self.initialsLabel.font = TVFont(MAX(10.0, CGRectGetWidth(self.bounds) * 0.4), UIFontWeightSemibold);
}

- (void)setURLString:(nullable NSString *)urlString displayName:(nullable NSString *)displayName {
    _urlString = [urlString copy];
    _displayName = [displayName copy];
    self.loadToken += 1;
    NSUInteger token = self.loadToken;

    NSString *name = displayName.length ? displayName : @"?";
    self.initialsLabel.text = [[name substringToIndex:1] uppercaseString];
    self.backgroundColor = TVColorForName(name);
    self.initialsLabel.hidden = NO;
    self.imageView.image = nil;

    UIImage *cached = [[TVImageLoader shared] cachedImageForURL:urlString];
    if (cached) {
        self.imageView.image = cached;
        self.initialsLabel.hidden = YES;
        return;
    }
    if (urlString.length == 0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[TVImageLoader shared] loadImageURL:urlString completion:^(UIImage *image) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.loadToken != token || !image) {
            return;
        }
        strongSelf.imageView.image = image;
        strongSelf.initialsLabel.hidden = YES;
    }];
}

@end

@interface TVLiveBadgeView ()
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UILabel *label;
@end

@implementation TVLiveBadgeView

- (instancetype)initWithText:(NSString *)text {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = TVColorLive();
        self.layer.cornerRadius = 4.0;
        self.clipsToBounds = YES;

        _dot = [[UIView alloc] initWithFrame:CGRectZero];
        _dot.backgroundColor = [UIColor whiteColor];
        _dot.layer.cornerRadius = 2.5;
        [self addSubview:_dot];

        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.textColor = [UIColor whiteColor];
        _label.font = TVFont(10.0, UIFontWeightBold);
        [self addSubview:_label];
        self.text = text ?: @"В ЭФИРЕ";
    }
    return self;
}

- (void)setText:(NSString *)text {
    _text = [text copy];
    self.label.text = [text uppercaseString];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (CGSize)intrinsicContentSize {
    CGSize size = [self.label sizeThatFits:CGSizeMake(CGFLOAT_MAX, 20.0)];
    return CGSizeMake(MAX(52.0, size.width + 26.0), 20.0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    self.dot.frame = CGRectMake(7.0, (height - 5.0) / 2.0, 5.0, 5.0);
    self.label.frame = CGRectMake(17.0, 0.0, width - 22.0, height);
}

@end

@interface TVPillView ()
@property (nonatomic, strong, readwrite) UILabel *textLabel;
@property (nonatomic, strong, readwrite) UIImageView *iconView;
@property (nonatomic, assign) TVIconName iconName;
@end

@implementation TVPillView

- (instancetype)initWithIcon:(TVIconName)icon text:(NSString *)text {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.72];
        self.layer.cornerRadius = 9.0;
        self.clipsToBounds = YES;
        _iconName = icon;

        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = [UIColor whiteColor];
        [self addSubview:_iconView];

        _textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _textLabel.textColor = [UIColor whiteColor];
        _textLabel.font = TVFont(11.0, UIFontWeightSemibold);
        [self addSubview:_textLabel];

        self.text = text ?: @"";
        [self setIcon:icon];
    }
    return self;
}

- (void)setText:(NSString *)text {
    self.textLabel.text = text ?: @"";
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (void)setIcon:(TVIconName)icon {
    _iconName = icon;
    if (icon == (TVIconName)-1) {
        self.iconView.image = nil;
        self.iconView.hidden = YES;
    } else {
        self.iconView.hidden = NO;
        self.iconView.image = [TVIcons icon:icon size:12.0 color:[UIColor whiteColor] weight:2.0];
    }
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (CGSize)intrinsicContentSize {
    CGSize textSize = [self.textLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 18.0)];
    CGFloat width = textSize.width + 16.0;
    if (!self.iconView.hidden) {
        width += 16.0;
    }
    return CGSizeMake(MAX(34.0, width), 20.0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if (!self.iconView.hidden) {
        self.iconView.frame = CGRectMake(7.0, (height - 12.0) / 2.0, 12.0, 12.0);
        self.textLabel.frame = CGRectMake(23.0, 0.0, width - 29.0, height);
    } else {
        self.textLabel.frame = CGRectMake(8.0, 0.0, width - 16.0, height);
    }
}

@end

@interface TVEmptyStateView ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong, readwrite) UIButton *actionButton;
@end

@implementation TVEmptyStateView

- (instancetype)initWithIcon:(TVIconName)icon
                       title:(NSString *)title
                    subtitle:(NSString *)subtitle
                 actionTitle:(NSString *)actionTitle {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.tintColor = TVColorMuted();
        _iconView.image = [TVIcons icon:icon size:52.0 color:TVColorMuted() weight:1.6];
        [_iconView.widthAnchor constraintEqualToConstant:56.0].active = YES;
        [_iconView.heightAnchor constraintEqualToConstant:56.0].active = YES;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.text = title;
        _titleLabel.textColor = TVColorText();
        _titleLabel.font = TVFont(18.0, UIFontWeightSemibold);
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 0;

        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subtitleLabel.text = subtitle;
        _subtitleLabel.textColor = TVColorMuted();
        _subtitleLabel.font = TVFont(13.0, UIFontWeightRegular);
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.hidden = subtitle.length == 0;

        _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_actionButton setTitle:actionTitle forState:UIControlStateNormal];
        [_actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _actionButton.titleLabel.font = TVFont(15.0, UIFontWeightSemibold);
        _actionButton.backgroundColor = TVColorPurple();
        _actionButton.layer.cornerRadius = 8.0;
        _actionButton.hidden = actionTitle.length == 0;
        [_actionButton.heightAnchor constraintEqualToConstant:44.0].active = YES;
        [_actionButton.widthAnchor constraintEqualToConstant:220.0].active = YES;
        [_actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];

        _stackView = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _titleLabel, _subtitleLabel, _actionButton]];
        _stackView.axis = UILayoutConstraintAxisVertical;
        _stackView.alignment = UIStackViewAlignmentCenter;
        _stackView.spacing = 10.0;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_stackView];
        [NSLayoutConstraint activateConstraints:@[
            [_stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:24.0],
            [_stackView.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-24.0],
            [_stackView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
    }
    return self;
}

- (void)actionTapped {
    TVHapticLight();
    if (self.actionBlock) {
        self.actionBlock();
    }
}

@end

@interface TVLoadingOverlay ()
@property (nonatomic, strong, readwrite) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, readwrite) UILabel *textLabel;
@end

@implementation TVLoadingOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.32];
        self.hidden = YES;

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_spinner];

        _textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _textLabel.text = @"Загрузка…";
        _textLabel.textColor = TVColorText();
        _textLabel.font = TVFont(13.0, UIFontWeightMedium);
        _textLabel.textAlignment = NSTextAlignmentCenter;
        _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_textLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_spinner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_spinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-12.0],
            [_textLabel.topAnchor constraintEqualToAnchor:_spinner.bottomAnchor constant:10.0],
            [_textLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16.0],
            [_textLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16.0],
        ]];
    }
    return self;
}

- (void)start {
    self.hidden = NO;
    [self.spinner startAnimating];
    [self.superview bringSubviewToFront:self];
}

- (void)stop {
    [self.spinner stopAnimating];
    self.hidden = YES;
}

@end

@implementation TVGradientView

+ (Class)layerClass {
    return [CAGradientLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CAGradientLayer *layer = (CAGradientLayer *)self.layer;
        layer.startPoint = CGPointMake(0.0, 0.0);
        layer.endPoint = CGPointMake(0.0, 1.0);
        self.colors = @[[[UIColor blackColor] colorWithAlphaComponent:0.0],
                        [[UIColor blackColor] colorWithAlphaComponent:0.75]];
    }
    return self;
}

- (void)setColors:(NSArray<UIColor *> *)colors {
    _colors = [colors copy];
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in colors) {
        [cgColors addObject:(__bridge id)color.CGColor];
    }
    ((CAGradientLayer *)self.layer).colors = cgColors;
}

@end

@implementation TVStatusDotView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = TVColorMuted();
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setDotColor:(UIColor *)dotColor {
    _dotColor = dotColor;
    self.backgroundColor = dotColor;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(8.0, 8.0);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2.0;
}

@end
