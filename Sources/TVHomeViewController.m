#import "TVHomeViewController.h"
#import <math.h>
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVAPI.h"
#import "TVSession.h"
#import "TVCommonViews.h"
#import "TVHomeViews.h"
#import "TVChannelViewController.h"
#import "TVCategoryViewController.h"
#import "TVStreamListViewController.h"

@interface TVHomeViewController ()

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) TVLoadingOverlay *loadingOverlay;
@property (nonatomic, strong, nullable) TVEmptyStateView *emptyView;

@property (nonatomic, strong, nullable) TVHeroCarouselView *heroView;
@property (nonatomic, strong, nullable) UIScrollView *liveRow;
@property (nonatomic, strong, nullable) UIScrollView *gamesRow;
@property (nonatomic, strong, nullable) UIButton *moreButton;
@property (nonatomic, strong, nullable) NSLayoutConstraint *heroHeight;
@property (nonatomic, strong, nullable) NSLayoutConstraint *liveRowHeight;
@property (nonatomic, strong, nullable) NSLayoutConstraint *gamesRowHeight;

@property (nonatomic, strong) NSArray<TVStream *> *streams;
@property (nonatomic, strong) NSArray<TVGame *> *games;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL hasLoaded;
@property (nonatomic, assign) CGFloat laidOutWidth;

@end

@implementation TVHomeViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Главная";
        _streams = @[];
        _games = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = TVColorBackground();
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.contentInset = UIEdgeInsetsMake(8.0, 0.0, 28.0, 0.0);
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(8.0, 0.0, 28.0, 0.0);
    [self.view addSubview:self.scrollView];

    self.stackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.spacing = 24.0;
    [self.scrollView addSubview:self.stackView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = TVColorMuted();
    [self.refreshControl addTarget:self action:@selector(pulledToRefresh) forControlEvents:UIControlEventValueChanged];
    self.scrollView.refreshControl = self.refreshControl;

    self.loadingOverlay = [[TVLoadingOverlay alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingOverlay.textLabel.text = @"Загружаем Twitch…";
    [self.view addSubview:self.loadingOverlay];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.stackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.stackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],

        [self.loadingOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.loadingOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.loadingOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.loadingOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [self loadContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (fabs(width - self.laidOutWidth) > 0.5) {
        self.laidOutWidth = width;
        [self layoutDynamicSectionsForWidth:width];
    }
    if (self.emptyView) {
        self.emptyView.frame = self.view.bounds;
    }
}

#pragma mark - Data

- (void)pulledToRefresh {
    [self loadContent];
}

- (void)loadContent {
    if (self.loading) {
        return;
    }
    self.loading = YES;
    if (!self.hasLoaded) {
        [self.loadingOverlay start];
    }

    __block NSArray<TVStream *> *streams = nil;
    __block NSArray<TVGame *> *games = nil;
    __block NSError *streamsError = nil;
    __block NSError *gamesError = nil;

    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    [[TVAPI shared] fetchTopStreamsWithCompletion:^(NSArray<TVStream *> *result, NSError *error) {
        streams = result;
        streamsError = error;
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [[TVAPI shared] fetchPopularGamesWithCompletion:^(NSArray<TVGame *> *result, NSError *error) {
        games = result;
        gamesError = error;
        dispatch_group_leave(group);
    }];

    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loading = NO;
        strongSelf.hasLoaded = YES;
        [strongSelf.refreshControl endRefreshing];
        [strongSelf.loadingOverlay stop];

        if (streams) {
            strongSelf.streams = streams;
        }
        if (games) {
            strongSelf.games = games;
        }

        [strongSelf rebuildSections];
        [strongSelf updateEmptyStateWithError:streamsError ?: gamesError];
        [strongSelf.view setNeedsLayout];
    });
}

- (void)updateEmptyStateWithError:(NSError *)error {
    BOOL hasContent = self.streams.count > 0 || self.games.count > 0;
    if (hasContent) {
        [self.emptyView removeFromSuperview];
        self.emptyView = nil;
        return;
    }
    if (self.emptyView) {
        return;
    }
    TVEmptyStateView *empty = [[TVEmptyStateView alloc] initWithIcon:TVIconTV
                                                               title:@"Не удалось загрузить"
                                                            subtitle:error.localizedDescription ?: @"Проверьте подключение к интернету."
                                                         actionTitle:@"Повторить"];
    empty.frame = self.view.bounds;
    empty.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    __weak typeof(self) weakSelf = self;
    empty.actionBlock = ^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf loadContent];
    };
    [self.view addSubview:empty];
    self.emptyView = empty;
}

#pragma mark - Sections

- (void)rebuildSections {
    for (UIView *view in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    self.heroView = nil;
    self.liveRow = nil;
    self.gamesRow = nil;
    self.moreButton = nil;
    self.heroHeight = nil;
    self.liveRowHeight = nil;
    self.gamesRowHeight = nil;

    if (self.streams.count > 0) {
        TVHeroCarouselView *hero = [[TVHeroCarouselView alloc] initWithFrame:CGRectZero];
        hero.translatesAutoresizingMaskIntoConstraints = NO;
        [hero configureWithStreams:[self.streams subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)6, self.streams.count))]];
        __weak typeof(self) weakSelf = self;
        hero.onSelectStream = ^(TVStream *stream) {
            __strong typeof(self) strongSelf = weakSelf;
            [strongSelf openStream:stream];
        };
        [self.stackView addArrangedSubview:hero];
        self.heroView = hero;
        self.heroHeight = [hero.heightAnchor constraintEqualToConstant:240.0];
        self.heroHeight.active = YES;
    }

    if (self.streams.count > 0) {
        TVSectionHeaderView *header = [[TVSectionHeaderView alloc] initWithTitle:@"Прямая трансляция на Twitch"];
        [self addHeader:header];

        UIScrollView *row = [self makeLiveRow];
        [self.stackView addArrangedSubview:row];
        self.liveRow = row;
        self.liveRowHeight = [row.heightAnchor constraintEqualToConstant:280.0];
        self.liveRowHeight.active = YES;

        UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
        [more setTitle:@"Показать больше" forState:UIControlStateNormal];
        [more setTitleColor:TVColorPurpleBright() forState:UIControlStateNormal];
        more.titleLabel.font = TVFont(13.0, UIFontWeightSemibold);
        [more setImage:[TVIcons icon:TVIconChevronDown size:14.0 color:TVColorPurpleBright() weight:2.0]
              forState:UIControlStateNormal];
        more.tintColor = TVColorPurpleBright();
        more.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        more.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        more.imageEdgeInsets = UIEdgeInsetsMake(0.0, 6.0, 0.0, -6.0);
        [more.heightAnchor constraintEqualToConstant:34.0].active = YES;
        [more addTarget:self action:@selector(showMoreTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.stackView addArrangedSubview:more];
        self.moreButton = more;
        [self.stackView setCustomSpacing:8.0 afterView:row];
    }

    if (self.games.count > 0) {
        TVSectionHeaderView *header = [[TVSectionHeaderView alloc] initWithTitle:@"Категории, которые могут вам понравиться"];
        [self addHeader:header];

        UIScrollView *row = [self makeGamesRow];
        [self.stackView addArrangedSubview:row];
        self.gamesRow = row;
        self.gamesRowHeight = [row.heightAnchor constraintEqualToConstant:260.0];
        self.gamesRowHeight.active = YES;
        if (self.streams.count > 0 && self.moreButton) {
            [self.stackView setCustomSpacing:26.0 afterView:self.moreButton];
        }
    }

    [self layoutDynamicSectionsForWidth:CGRectGetWidth(self.view.bounds)];
}

- (void)addHeader:(TVSectionHeaderView *)header {
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [header.heightAnchor constraintEqualToConstant:26.0].active = YES;
    [self.stackView addArrangedSubview:header];
    UIView *last = self.stackView.arrangedSubviews[self.stackView.arrangedSubviews.count - 1];
    if (last) {
        [self.stackView setCustomSpacing:12.0 afterView:last];
    }
}

- (UIScrollView *)makeLiveRow {
    UIScrollView *row = [[UIScrollView alloc] initWithFrame:CGRectZero];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.showsHorizontalScrollIndicator = NO;
    row.showsVerticalScrollIndicator = NO;
    row.alwaysBounceHorizontal = YES;
    row.contentInset = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);

    NSInteger index = 0;
    for (TVStream *stream in self.streams) {
        TVHomeStreamCard *card = [[TVHomeStreamCard alloc] initWithFrame:CGRectZero];
        card.tag = index;
        [card configureWithStream:stream];
        [card addTarget:self action:@selector(streamCardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:card];
        index += 1;
    }
    return row;
}

- (UIScrollView *)makeGamesRow {
    UIScrollView *row = [[UIScrollView alloc] initWithFrame:CGRectZero];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.showsHorizontalScrollIndicator = NO;
    row.showsVerticalScrollIndicator = NO;
    row.alwaysBounceHorizontal = YES;
    row.contentInset = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);

    NSInteger index = 0;
    for (TVGame *game in self.games) {
        TVHomeGameCard *card = [[TVHomeGameCard alloc] initWithFrame:CGRectZero];
        card.tag = index;
        [card configureWithGame:game];
        [card addTarget:self action:@selector(gameCardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:card];
        index += 1;
    }
    return row;
}

- (void)layoutDynamicSectionsForWidth:(CGFloat)width {
    if (width <= 0.0) {
        return;
    }
    if (self.heroView && self.heroHeight) {
        self.heroHeight.constant = [self.heroView preferredHeightForWidth:width];
    }

    CGFloat streamCardWidth = width >= 700.0 ? 300.0 : MAX(210.0, MIN(280.0, width * 0.64));
    CGFloat streamCardHeight = [TVHomeStreamCard heightForWidth:streamCardWidth];
    CGFloat x = 0.0;
    for (UIView *card in self.liveRow.subviews) {
        card.frame = CGRectMake(x, 0.0, streamCardWidth, streamCardHeight);
        x += streamCardWidth + 12.0;
    }
    if (self.liveRow) {
        self.liveRow.contentSize = CGSizeMake(MAX(0.0, x - 12.0), streamCardHeight);
        self.liveRowHeight.constant = streamCardHeight;
    }

    CGFloat gameCardWidth = width >= 700.0 ? 148.0 : MAX(112.0, MIN(140.0, width * 0.32));
    CGFloat gameCardHeight = [TVHomeGameCard heightForWidth:gameCardWidth];
    x = 0.0;
    for (UIView *card in self.gamesRow.subviews) {
        card.frame = CGRectMake(x, 0.0, gameCardWidth, gameCardHeight);
        x += gameCardWidth + 12.0;
    }
    if (self.gamesRow) {
        self.gamesRow.contentSize = CGSizeMake(MAX(0.0, x - 12.0), gameCardHeight);
        self.gamesRowHeight.constant = gameCardHeight;
    }
}

#pragma mark - Actions

- (void)streamCardTapped:(TVHomeStreamCard *)card {
    NSInteger index = card.tag;
    if (index < 0 || index >= (NSInteger)self.streams.count) {
        return;
    }
    [self openStream:self.streams[(NSUInteger)index]];
}

- (void)gameCardTapped:(TVHomeGameCard *)card {
    NSInteger index = card.tag;
    if (index < 0 || index >= (NSInteger)self.games.count) {
        return;
    }
    TVGame *game = self.games[(NSUInteger)index];
    TVCategoryViewController *category = [[TVCategoryViewController alloc] initWithGame:game];
    [self.navigationController pushViewController:category animated:YES];
}

- (void)openStream:(TVStream *)stream {
    NSString *login = stream.broadcaster.login;
    if (login.length == 0) {
        return;
    }
    TVChannelViewController *channel = [[TVChannelViewController alloc] initWithLogin:login];
    [self.navigationController pushViewController:channel animated:YES];
}

- (void)showMoreTapped {
    TVStreamListViewController *list = [[TVStreamListViewController alloc] initWithTitle:@"Прямая трансляция"
                                                                                streams:self.streams];
    [self.navigationController pushViewController:list animated:YES];
}

@end
