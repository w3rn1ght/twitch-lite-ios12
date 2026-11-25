#import "TVCategoryViewController.h"
#import <math.h>
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVAPI.h"
#import "TVSession.h"
#import "TVStreamCell.h"
#import "TVCommonViews.h"
#import "TVImageLoader.h"
#import "TVChannelViewController.h"

@interface TVCategoryViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) TVGame *game;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TVLoadingOverlay *loadingOverlay;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) TVRemoteImageView *artView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) NSArray<TVStream *> *streams;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL hasLoaded;
@property (nonatomic, assign) CGFloat laidOutWidth;

@end

@implementation TVCategoryViewController

- (instancetype)initWithGame:(TVGame *)game {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _game = game;
        _streams = @[];
        self.title = game.displayName.length ? game.displayName : (game.name.length ? game.name : @"Категория");
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[[TVIcons icon:TVIconRefresh size:20.0 color:TVColorText() weight:2.0]
                                               imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(refreshTapped)];

    [self buildHeader];
    [self buildTable];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(favoritesChanged:)
                                                 name:TVFavoritesDidChangeNotification
                                               object:nil];

    [self loadStreams];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.hasLoaded && !self.loading) {
        [self loadStreams];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (fabs(width - self.laidOutWidth) > 0.5) {
        [self layoutHeaderForWidth:width];
        self.tableView.tableHeaderView = self.headerView;
    }
    if (self.tableView.backgroundView) {
        self.tableView.backgroundView.frame = self.tableView.bounds;
    }
}

#pragma mark - UI

- (void)buildHeader {
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 112.0)];
    self.headerView.backgroundColor = TVColorBackground();

    self.artView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
    self.artView.layer.cornerRadius = 6.0;
    self.artView.clipsToBounds = YES;
    [self.headerView addSubview:self.artView];

    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.nameLabel.textColor = TVColorText();
    self.nameLabel.font = TVFont(21.0, UIFontWeightBold);
    self.nameLabel.numberOfLines = 2;
    [self.headerView addSubview:self.nameLabel];

    self.metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.metaLabel.textColor = TVColorMuted();
    self.metaLabel.font = TVFont(13.0, UIFontWeightRegular);
    self.metaLabel.numberOfLines = 2;
    [self.headerView addSubview:self.metaLabel];

    self.artView.urlString = self.game.boxArtURL;
    self.nameLabel.text = self.game.displayName.length ? self.game.displayName : self.game.name;
    self.metaLabel.text = @"Загружаем стримы…";

    [self layoutHeaderForWidth:CGRectGetWidth(self.view.bounds)];
}

- (void)layoutHeaderForWidth:(CGFloat)width {
    self.laidOutWidth = width;
    self.headerView.frame = CGRectMake(0.0, 0.0, width, 112.0);
    self.artView.frame = CGRectMake(16.0, 12.0, 64.0, 86.0);
    self.nameLabel.frame = CGRectMake(92.0, 18.0, width - 108.0, 50.0);
    self.metaLabel.frame = CGRectMake(92.0, 72.0, width - 108.0, 34.0);
}

- (void)buildTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    TVStyleTableView(self.tableView);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 280.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0.0, 0.0, 16.0, 0.0);
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = self.headerView;
    [self.tableView registerClass:[TVStreamCell class] forCellReuseIdentifier:@"stream"];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = TVColorMuted();
    [self.refreshControl addTarget:self action:@selector(refreshTapped) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    self.loadingOverlay = [[TVLoadingOverlay alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingOverlay.textLabel.text = @"Загружаем стримы…";
    [self.view addSubview:self.loadingOverlay];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.loadingOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.loadingOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.loadingOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.loadingOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - Data

- (void)refreshTapped {
    [self loadStreams];
}

- (void)loadStreams {
    if (self.loading) {
        return;
    }
    if (self.game.gameID.length == 0 && self.game.name.length == 0) {
        [self showEmptyStateWithTitle:@"Категория недоступна"
                             subtitle:@"Не удалось определить категорию."
                          actionTitle:nil
                               action:nil];
        return;
    }
    self.loading = YES;
    if (self.streams.count == 0) {
        [self.loadingOverlay start];
    }
    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchGameStreamsWithName:self.game.name gameID:self.game.gameID completion:^(NSArray<TVStream *> *streams, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loading = NO;
        strongSelf.hasLoaded = YES;
        [strongSelf.refreshControl endRefreshing];
        [strongSelf.loadingOverlay stop];
        if (streams) {
            [strongSelf applyStreams:streams];
        } else {
            [strongSelf showError:error];
        }
    }];
}

- (void)applyStreams:(NSArray<TVStream *> *)streams {
    self.streams = streams ?: @[];
    NSInteger totalViewers = 0;
    for (TVStream *stream in self.streams) {
        totalViewers += stream.viewers;
    }
    if (self.streams.count > 0) {
        self.metaLabel.text = [NSString stringWithFormat:@"%ld стримов · %@ зрителей",
                               (long)self.streams.count, TVFormatViewers(totalViewers)];
    } else {
        self.metaLabel.text = @"Сейчас нет активных стримов";
    }
    [self.tableView reloadData];

    if (self.streams.count == 0) {
        __weak typeof(self) weakSelf = self;
        [self showEmptyStateWithTitle:@"В этой категории пусто"
                             subtitle:@"Сейчас никто не стримит в этой категории."
                          actionTitle:@"Обновить"
                               action:^{
            __strong typeof(self) strongSelf = weakSelf;
            [strongSelf loadStreams];
        }];
    } else {
        self.tableView.backgroundView = nil;
    }
}

- (void)showError:(NSError *)error {
    if (self.streams.count > 0) {
        TVShowAlert(self, @"Ошибка", error.localizedDescription ?: @"Не удалось загрузить стримы.");
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self showEmptyStateWithTitle:@"Не удалось загрузить"
                         subtitle:error.localizedDescription ?: @"Проверьте подключение к интернету."
                      actionTitle:@"Повторить"
                           action:^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf loadStreams];
    }];
}

- (void)showEmptyStateWithTitle:(NSString *)title
                       subtitle:(nullable NSString *)subtitle
                    actionTitle:(nullable NSString *)actionTitle
                         action:(void (^ _Nullable)(void))action {
    TVEmptyStateView *empty = [[TVEmptyStateView alloc] initWithIcon:TVIconGrid
                                                              title:title
                                                           subtitle:subtitle
                                                        actionTitle:actionTitle];
    empty.actionBlock = action;
    self.tableView.backgroundView = empty;
}

- (void)favoritesChanged:(NSNotification *)notification {
    [self.tableView reloadData];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.streams.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TVStream *stream = self.streams[(NSUInteger)indexPath.row];
    TVStreamCell *cell = [tableView dequeueReusableCellWithIdentifier:@"stream" forIndexPath:indexPath];
    [cell configureWithStream:stream];
    __weak typeof(self) weakSelf = self;
    cell.onFavoriteTapped = ^{
        __strong typeof(self) strongSelf = weakSelf;
        [[TVSession shared] toggleFavorite:stream.broadcaster.login];
        [strongSelf.tableView reloadData];
    };
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(tableView.bounds), 38.0)];
    header.backgroundColor = TVColorBackground();

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 12.0, CGRectGetWidth(tableView.bounds) - 32.0, 18.0)];
    label.textColor = TVColorMuted();
    label.font = TVFont(11.0, UIFontWeightBold);
    label.text = [NSString stringWithFormat:@"В ЭФИРЕ · %ld", (long)self.streams.count];
    [header addSubview:label];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 38.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TVStream *stream = self.streams[(NSUInteger)indexPath.row];
    NSString *login = stream.broadcaster.login;
    if (login.length == 0) {
        return;
    }
    TVChannelViewController *channel = [[TVChannelViewController alloc] initWithLogin:login];
    [self.navigationController pushViewController:channel animated:YES];
}

@end
