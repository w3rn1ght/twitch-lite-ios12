#import "TVHomeViews.h"
#import <math.h>
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVCommonViews.h"
#import "TVImageLoader.h"

#pragma mark - Hero page

@interface TVHeroPageView : UIView

@property (nonatomic, strong) TVRemoteImageView *imageView;
@property (nonatomic, strong) TVGradientView *gradientView;
@property (nonatomic, strong) TVLiveBadgeView *liveBadge;
@property (nonatomic, strong) TVPillView *viewersPill;
@property (nonatomic, strong) TVAvatarView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@property (nonatomic, strong) UILabel *titleLabel;

- (void)configureWithStream:(TVStream *)stream;

@end

@implementation TVHeroPageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = TVColorSurface();
        self.clipsToBounds = YES;

        _imageView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];

        _gradientView = [[TVGradientView alloc] initWithFrame:CGRectZero];
        _gradientView.colors = @[[[UIColor blackColor] colorWithAlphaComponent:0.0],
                                 [[UIColor blackColor] colorWithAlphaComponent:0.86]];
        [self addSubview:_gradientView];

        _liveBadge = [[TVLiveBadgeView alloc] initWithText:@"В ЭФИРЕ"];
        [self addSubview:_liveBadge];

        _viewersPill = [[TVPillView alloc] initWithIcon:TVIconEye text:@""];
        [self addSubview:_viewersPill];

        _avatarView = [[TVAvatarView alloc] initWithFrame:CGRectZero];
        [self addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.font = TVFont(17.0, UIFontWeightBold);
        _nameLabel.numberOfLines = 1;
        [self addSubview:_nameLabel];

        _categoryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _categoryLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.82];
        _categoryLabel.font = TVFont(13.0, UIFontWeightMedium);
        _categoryLabel.numberOfLines = 1;
        [self addSubview:_categoryLabel];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92];
        _titleLabel.font = TVFont(13.0, UIFontWeightRegular);
        _titleLabel.numberOfLines = 1;
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)configureWithStream:(TVStream *)stream {
    TVUser *broadcaster = stream.broadcaster;
    NSString *name = broadcaster.displayName.length ? broadcaster.displayName : broadcaster.login;
    self.nameLabel.text = name;
    [self.avatarView setURLString:broadcaster.avatarURL displayName:name];
    self.imageView.urlString = stream.previewURL;
    self.categoryLabel.text = stream.gameName.length ? stream.gameName : @"Стрим";
    self.titleLabel.text = stream.title.length ? stream.title : @"Без названия";
    [self.viewersPill setText:TVFormatViewers(stream.viewers)];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);

    self.imageView.frame = self.bounds;
    self.gradientView.frame = CGRectMake(0.0, height * 0.42, width, height * 0.58);

    CGSize badgeSize = self.liveBadge.intrinsicContentSize;
    self.liveBadge.frame = CGRectMake(16.0, 16.0, badgeSize.width, badgeSize.height);

    CGSize pillSize = self.viewersPill.intrinsicContentSize;
    self.viewersPill.frame = CGRectMake(width - 16.0 - pillSize.width, 16.0, pillSize.width, pillSize.height);

    CGFloat titleHeight = 18.0;
    CGFloat categoryHeight = 18.0;
    CGFloat avatarSize = 40.0;
    CGFloat bottom = height - 16.0;

    self.titleLabel.frame = CGRectMake(16.0, bottom - titleHeight, width - 32.0, titleHeight);
    self.categoryLabel.frame = CGRectMake(16.0, CGRectGetMinY(self.titleLabel.frame) - categoryHeight - 2.0,
                                          width - 32.0, categoryHeight);
    CGFloat avatarY = CGRectGetMinY(self.categoryLabel.frame) - avatarSize - 10.0;
    self.avatarView.frame = CGRectMake(16.0, avatarY, avatarSize, avatarSize);
    self.nameLabel.frame = CGRectMake(CGRectGetMaxX(self.avatarView.frame) + 10.0,
                                      avatarY + (avatarSize - 22.0) / 2.0,
                                      width - CGRectGetMaxX(self.avatarView.frame) - 26.0,
                                      22.0);
}

@end

#pragma mark - Hero carousel

@interface TVHeroCarouselView () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIButton *leftButton;
@property (nonatomic, strong) UIButton *rightButton;
@property (nonatomic, strong) NSArray<TVStream *> *streams;
@property (nonatomic, strong) NSMutableArray<TVHeroPageView *> *pages;
@property (nonatomic, assign) NSInteger currentPage;
@end

@implementation TVHeroCarouselView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = TVColorSurface();
        self.clipsToBounds = YES;

        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.pagingEnabled = YES;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.delegate = self;
        _scrollView.backgroundColor = TVColorSurface();
        [self addSubview:_scrollView];

        _leftButton = [self arrowButtonFlipped:YES];
        _rightButton = [self arrowButtonFlipped:NO];
        [self addSubview:_leftButton];
        [self addSubview:_rightButton];

        _streams = @[];
        _pages = [NSMutableArray array];
    }
    return self;
}

- (UIButton *)arrowButtonFlipped:(BOOL)flipped {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *chevron = [TVIcons icon:TVIconChevronRight size:20.0 color:[UIColor whiteColor] weight:2.2];
    [button setImage:chevron forState:UIControlStateNormal];
    button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    button.layer.cornerRadius = 18.0;
    button.clipsToBounds = YES;
    button.alpha = 0.9;
    if (flipped) {
        button.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
    }
    [button addTarget:self
               action:(flipped ? @selector(goPrevious) : @selector(goNext))
     forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    return MIN(400.0, MAX(210.0, width * 0.48));
}

- (void)configureWithStreams:(NSArray<TVStream *> *)streams {
    for (TVHeroPageView *page in self.pages) {
        [page removeFromSuperview];
    }
    [self.pages removeAllObjects];
    self.streams = streams ?: @[];
    self.currentPage = 0;

    NSInteger index = 0;
    for (TVStream *stream in self.streams) {
        TVHeroPageView *page = [[TVHeroPageView alloc] initWithFrame:CGRectZero];
        [page configureWithStream:stream];
        page.tag = index;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pageTapped:)];
        [page addGestureRecognizer:tap];
        [self.scrollView addSubview:page];
        [self.pages addObject:page];
        index += 1;
    }
    self.leftButton.hidden = self.streams.count < 2;
    self.rightButton.hidden = self.streams.count < 2;
    [self setNeedsLayout];
}

- (void)pageTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag;
    if (index < 0 || index >= (NSInteger)self.streams.count) {
        return;
    }
    if (self.onSelectStream) {
        self.onSelectStream(self.streams[(NSUInteger)index]);
    }
}

- (void)goPrevious {
    [self scrollToPage:MAX(0, self.currentPage - 1)];
}

- (void)goNext {
    [self scrollToPage:MIN((NSInteger)self.streams.count - 1, self.currentPage + 1)];
}

- (void)scrollToPage:(NSInteger)page {
    if (page < 0 || page >= (NSInteger)self.streams.count) {
        return;
    }
    CGFloat width = CGRectGetWidth(self.scrollView.bounds);
    [self.scrollView setContentOffset:CGPointMake(width * page, 0.0) animated:YES];
    self.currentPage = page;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    self.scrollView.frame = self.bounds;
    self.scrollView.contentSize = CGSizeMake(width * self.pages.count, height);
    self.scrollView.contentInset = UIEdgeInsetsZero;

    NSInteger index = 0;
    for (TVHeroPageView *page in self.pages) {
        page.frame = CGRectMake(width * index, 0.0, width, height);
        index += 1;
    }

    CGFloat arrowSize = 36.0;
    self.leftButton.frame = CGRectMake(10.0, (height - arrowSize) / 2.0, arrowSize, arrowSize);
    self.rightButton.frame = CGRectMake(width - arrowSize - 10.0, (height - arrowSize) / 2.0, arrowSize, arrowSize);

    CGFloat offset = width * self.currentPage;
    if (self.scrollView.contentOffset.x != offset) {
        self.scrollView.contentOffset = CGPointMake(offset, 0.0);
    }
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat width = CGRectGetWidth(scrollView.bounds);
    if (width > 0.0) {
        self.currentPage = (NSInteger)lround(scrollView.contentOffset.x / width);
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    CGFloat width = CGRectGetWidth(scrollView.bounds);
    if (width > 0.0) {
        self.currentPage = (NSInteger)lround(scrollView.contentOffset.x / width);
    }
}

@end

#pragma mark - Stream card

@interface TVHomeStreamCard ()
@property (nonatomic, strong) TVRemoteImageView *thumbnailView;
@property (nonatomic, strong) TVLiveBadgeView *liveBadge;
@property (nonatomic, strong) TVPillView *viewersPill;
@property (nonatomic, strong) TVAvatarView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *categoryLabel;
@end

@implementation TVHomeStreamCard

+ (CGFloat)heightForWidth:(CGFloat)width {
    return floor(width * 9.0 / 16.0) + 104.0;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _thumbnailView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
        _thumbnailView.layer.cornerRadius = 10.0;
        _thumbnailView.clipsToBounds = YES;
        [self addSubview:_thumbnailView];

        _liveBadge = [[TVLiveBadgeView alloc] initWithText:@"В ЭФИРЕ"];
        [_thumbnailView addSubview:_liveBadge];

        _viewersPill = [[TVPillView alloc] initWithIcon:TVIconEye text:@""];
        [_thumbnailView addSubview:_viewersPill];

        _avatarView = [[TVAvatarView alloc] initWithFrame:CGRectZero];
        [self addSubview:_avatarView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.textColor = TVColorText();
        _nameLabel.font = TVFont(14.0, UIFontWeightSemibold);
        _nameLabel.numberOfLines = 1;
        [self addSubview:_nameLabel];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textColor = TVColorMuted();
        _titleLabel.font = TVFont(13.0, UIFontWeightRegular);
        _titleLabel.numberOfLines = 2;
        [self addSubview:_titleLabel];

        _categoryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _categoryLabel.textColor = TVColorMuted();
        _categoryLabel.font = TVFont(11.0, UIFontWeightMedium);
        _categoryLabel.numberOfLines = 1;
        [self addSubview:_categoryLabel];
    }
    return self;
}

- (void)configureWithStream:(TVStream *)stream {
    TVUser *broadcaster = stream.broadcaster;
    NSString *name = broadcaster.displayName.length ? broadcaster.displayName : broadcaster.login;
    self.nameLabel.text = name;
    [self.avatarView setURLString:broadcaster.avatarURL displayName:name];
    self.thumbnailView.urlString = stream.previewURL;
    self.titleLabel.text = stream.title.length ? stream.title : @"Без названия";
    self.categoryLabel.text = stream.gameName.length ? stream.gameName : @"Стрим";
    [self.viewersPill setText:TVFormatViewers(stream.viewers)];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.82 : 1.0;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat thumbHeight = floor(width * 9.0 / 16.0);

    self.thumbnailView.frame = CGRectMake(0.0, 0.0, width, thumbHeight);

    CGSize badgeSize = self.liveBadge.intrinsicContentSize;
    self.liveBadge.frame = CGRectMake(8.0, 8.0, badgeSize.width, badgeSize.height);

    CGSize pillSize = self.viewersPill.intrinsicContentSize;
    self.viewersPill.frame = CGRectMake(8.0, thumbHeight - pillSize.height - 8.0, pillSize.width, pillSize.height);

    CGFloat avatarSize = 34.0;
    self.avatarView.frame = CGRectMake(0.0, thumbHeight + 10.0, avatarSize, avatarSize);
    self.nameLabel.frame = CGRectMake(avatarSize + 9.0, thumbHeight + 10.0, width - avatarSize - 9.0, 18.0);
    self.titleLabel.frame = CGRectMake(0.0, thumbHeight + 46.0, width, 32.0);
    self.categoryLabel.frame = CGRectMake(0.0, thumbHeight + 80.0, width, 15.0);
}

@end

#pragma mark - Game card

@interface TVHomeGameCard ()
@property (nonatomic, strong) TVRemoteImageView *boxArtView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *viewersLabel;
@end

@implementation TVHomeGameCard

+ (CGFloat)heightForWidth:(CGFloat)width {
    return floor(width * 4.0 / 3.0) + 58.0;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _boxArtView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
        _boxArtView.layer.cornerRadius = 8.0;
        _boxArtView.clipsToBounds = YES;
        [self addSubview:_boxArtView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.textColor = TVColorText();
        _nameLabel.font = TVFont(12.0, UIFontWeightMedium);
        _nameLabel.numberOfLines = 2;
        [self addSubview:_nameLabel];

        _viewersLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _viewersLabel.textColor = TVColorMuted();
        _viewersLabel.font = TVFont(10.0, UIFontWeightRegular);
        _viewersLabel.numberOfLines = 1;
        [self addSubview:_viewersLabel];
    }
    return self;
}

- (void)configureWithGame:(TVGame *)game {
    self.boxArtView.urlString = game.boxArtURL;
    self.nameLabel.text = game.displayName.length ? game.displayName : game.name;
    self.viewersLabel.text = game.viewers > 0 ? [NSString stringWithFormat:@"%@ зрителей", TVFormatViewers(game.viewers)] : @"";
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.82 : 1.0;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat artHeight = floor(width * 4.0 / 3.0);
    self.boxArtView.frame = CGRectMake(0.0, 0.0, width, artHeight);
    self.nameLabel.frame = CGRectMake(0.0, artHeight + 6.0, width, 30.0);
    self.viewersLabel.frame = CGRectMake(0.0, artHeight + 38.0, width, 14.0);
}

@end

#pragma mark - Section header

@interface TVSectionHeaderView ()
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation TVSectionHeaderView

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.text = title;
        _titleLabel.textColor = TVColorPurpleBright();
        _titleLabel.font = TVFont(16.0, UIFontWeightBold);
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.titleLabel.frame = CGRectMake(16.0, 0.0, CGRectGetWidth(self.bounds) - 32.0, CGRectGetHeight(self.bounds));
}

@end
