#import "TVFollowingViewController.h"
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVAPI.h"
#import "TVSession.h"
#import "TVStreamCell.h"
#import "TVChannelCell.h"
#import "TVCommonViews.h"
#import "TVChannelViewController.h"
#import "TVLoginViewController.h"

@interface TVFollowingViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TVLoadingOverlay *loadingOverlay;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray<TVUser *> *channels;
@property (nonatomic, strong) NSArray<TVUser *> *liveChannels;
@property (nonatomic, strong) NSArray<TVUser *> *offlineChannels;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL hasLoaded;

@end

@implementation TVFollowingViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Подписки";
        _channels = @[];
        _liveChannels = @[];
        _offlineChannels = @[];
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

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    TVStyleTableView(self.tableView);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 280.0;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 16.0, 0.0);
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[TVStreamCell class] forCellReuseIdentifier:@"stream"];
    [self.tableView registerClass:[TVChannelCell class] forCellReuseIdentifier:@"channel"];
    [self.view addSubview:self.tableView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = TVColorMuted();
    [self.refreshControl addTarget:self action:@selector(pulledToRefresh) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = self.refreshControl;

    self.loadingOverlay = [[TVLoadingOverlay alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingOverlay.textLabel.text = @"Загружаем подписки…";
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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionChanged:)
                                                 name:TVSessionDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(favoritesChanged:)
                                                 name:TVFavoritesDidChangeNotification
                                               object:nil];

    [self updateForSession];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateForSession];
    if ([TVSession shared].isLoggedIn && !self.hasLoaded && !self.loading) {
        [self loadContent];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.tableView.backgroundView) {
        self.tableView.backgroundView.frame = self.tableView.bounds;
    }
}

#pragma mark - Session

- (void)sessionChanged:(NSNotification *)notification {
    self.hasLoaded = NO;
    self.channels = @[];
    self.liveChannels = @[];
    self.offlineChannels = @[];
    [self.tableView reloadData];
    [self updateForSession];
    if ([TVSession shared].isLoggedIn) {
        [self loadContent];
    }
}

- (void)favoritesChanged:(NSNotification *)notification {
    [self.tableView reloadData];
}

- (void)updateForSession {
    if ([TVSession shared].isLoggedIn) {
        if (self.channels.count == 0 && !self.loading) {
            [self showLoadingStateIfNeeded];
        }
        return;
    }
    [self.loadingOverlay stop];
    [self.refreshControl endRefreshing];
    [self showEmptyStateWithTitle:@"Войдите в Twitch"
                         subtitle:@"Подписки, чат и избранное доступны после входа в аккаунт."
                      actionTitle:@"Войти"
                           action:^{
        [TVLoginViewController presentFromViewController:self];
    }];
}

- (void)showLoadingStateIfNeeded {
    if (self.channels.count == 0) {
        self.tableView.backgroundView = nil;
        [self.loadingOverlay start];
    }
}

#pragma mark - Data

- (void)refreshTapped {
    if (![TVSession shared].isLoggedIn) {
        [TVLoginViewController presentFromViewController:self];
        return;
    }
    [self loadContent];
}

- (void)pulledToRefresh {
    if (![TVSession shared].isLoggedIn) {
        [self.refreshControl endRefreshing];
        [TVLoginViewController presentFromViewController:self];
        return;
    }
    [self loadContent];
}

- (void)loadContent {
    if (self.loading || ![TVSession shared].isLoggedIn) {
        return;
    }
    self.loading = YES;
    if (self.channels.count == 0) {
        [self.loadingOverlay start];
    }
    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchFollowedChannelsWithCompletion:^(NSArray<TVUser *> *channels, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loading = NO;
        strongSelf.hasLoaded = YES;
        [strongSelf.refreshControl endRefreshing];
        [strongSelf.loadingOverlay stop];
        if (channels) {
            [strongSelf applyChannels:channels];
        } else {
            [strongSelf showError:error];
        }
    }];
}

- (void)applyChannels:(NSArray<TVUser *> *)channels {
    self.channels = channels ?: @[];
    NSMutableArray<TVUser *> *live = [NSMutableArray array];
    NSMutableArray<TVUser *> *offline = [NSMutableArray array];
    for (TVUser *user in self.channels) {
        if (user.isLive) {
            [live addObject:user];
        } else {
            [offline addObject:user];
        }
    }
    self.liveChannels = live;
    self.offlineChannels = offline;
    [self.tableView reloadData];

    if (self.channels.count == 0) {
        __weak typeof(self) weakSelf = self;
        [self showEmptyStateWithTitle:@"Пока нет подписок"
                             subtitle:@"Найдите каналы во вкладке «Поиск» и подпишитесь на них на Twitch."
                          actionTitle:@"Найти каналы"
                               action:^{
            __strong typeof(self) strongSelf = weakSelf;
            strongSelf.tabBarController.selectedIndex = 1;
        }];
    } else {
        self.tableView.backgroundView = nil;
    }
}

- (void)showError:(NSError *)error {
    NSString *message = error.localizedDescription ?: @"Не удалось загрузить подписки.";
    if (self.channels.count > 0) {
        TVShowAlert(self, @"Ошибка", message);
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self showEmptyStateWithTitle:@"Не удалось загрузить"
                         subtitle:message
                      actionTitle:@"Повторить"
                           action:^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf loadContent];
    }];
}

- (void)showEmptyStateWithTitle:(NSString *)title
                       subtitle:(NSString *)subtitle
                    actionTitle:(NSString *)actionTitle
                         action:(void (^)(void))action {
    TVEmptyStateView *empty = [[TVEmptyStateView alloc] initWithIcon:TVIconHeart
                                                              title:title
                                                           subtitle:subtitle
                                                        actionTitle:actionTitle];
    empty.actionBlock = action;
    self.tableView.backgroundView = empty;
}

#pragma mark - UITableView

- (BOOL)sectionIsLive:(NSInteger)section {
    if (self.liveChannels.count > 0) {
        return section == 0;
    }
    return NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (self.liveChannels.count > 0 ? 1 : 0) + (self.offlineChannels.count > 0 ? 1 : 0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self sectionIsLive:section] ? (NSInteger)self.liveChannels.count : (NSInteger)self.offlineChannels.count;
}

- (TVUser *)userAtIndexPath:(NSIndexPath *)indexPath {
    if ([self sectionIsLive:indexPath.section]) {
        return self.liveChannels[(NSUInteger)indexPath.row];
    }
    return self.offlineChannels[(NSUInteger)indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TVUser *user = [self userAtIndexPath:indexPath];
    if ([self sectionIsLive:indexPath.section]) {
        TVStreamCell *cell = [tableView dequeueReusableCellWithIdentifier:@"stream" forIndexPath:indexPath];
        [cell configureWithUser:user];
        __weak typeof(self) weakSelf = self;
        cell.onFavoriteTapped = ^{
            __strong typeof(self) strongSelf = weakSelf;
            [[TVSession shared] toggleFavorite:user.login];
            [strongSelf.tableView reloadData];
        };
        return cell;
    }
    TVChannelCell *cell = [tableView dequeueReusableCellWithIdentifier:@"channel" forIndexPath:indexPath];
    [cell configureWithUser:user showFavorite:YES];
    __weak typeof(self) weakSelf = self;
    cell.onFavoriteTapped = ^{
        __strong typeof(self) strongSelf = weakSelf;
        [[TVSession shared] toggleFavorite:user.login];
        [strongSelf.tableView reloadData];
    };
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self sectionIsLive:indexPath.section]) {
        return UITableViewAutomaticDimension;
    }
    return 74.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(tableView.bounds), 38.0)];
    header.backgroundColor = TVColorBackground();

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 12.0, CGRectGetWidth(tableView.bounds) - 32.0, 18.0)];
    label.textColor = TVColorMuted();
    label.font = TVFont(11.0, UIFontWeightBold);
    if ([self sectionIsLive:section]) {
        label.text = [NSString stringWithFormat:@"В ЭФИРЕ · %ld", (long)self.liveChannels.count];
    } else {
        label.text = [NSString stringWithFormat:@"НЕ В ЭФИРЕ · %ld", (long)self.offlineChannels.count];
    }
    [header addSubview:label];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 38.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TVUser *user = [self userAtIndexPath:indexPath];
    if (user.login.length == 0) {
        return;
    }
    TVChannelViewController *channel = [[TVChannelViewController alloc] initWithLogin:user.login];
    [self.navigationController pushViewController:channel animated:YES];
}

@end
