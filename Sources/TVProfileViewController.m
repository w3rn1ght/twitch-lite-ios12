#import "TVProfileViewController.h"
#import <SafariServices/SafariServices.h>
#import <math.h>
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVSession.h"
#import "TVCommonViews.h"
#import "TVImageLoader.h"
#import "TVLoginViewController.h"

@interface TVProfileViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) TVRemoteImageView *bannerView;
@property (nonatomic, strong) TVGradientView *bannerGradient;
@property (nonatomic, strong) TVAvatarView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *loginLabel;
@property (nonatomic, strong) UILabel *bioLabel;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) NSArray<NSArray<NSDictionary<NSString *, id> *> *> *sections;
@property (nonatomic, strong, nullable) UIActivityIndicatorView *refreshSpinner;
@property (nonatomic, assign) NSTimeInterval lastRefresh;
@property (nonatomic, assign) BOOL refreshing;
@property (nonatomic, assign) CGFloat laidOutWidth;

@end

@implementation TVProfileViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Профиль";
        _sections = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    [self buildHeader];
    [self buildTable];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionChanged:)
                                                 name:TVSessionDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(favoritesChanged:)
                                                 name:TVFavoritesDidChangeNotification
                                               object:nil];

    [self updateUI];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateUI];
    [self refreshIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (fabs(width - self.laidOutWidth) > 0.5) {
        [self layoutHeaderForWidth:width];
        self.tableView.tableHeaderView = self.headerView;
    }
}

#pragma mark - UI

- (void)buildHeader {
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 300.0)];
    self.headerView.backgroundColor = TVColorBackground();
    self.headerView.clipsToBounds = YES;

    self.bannerView = [[TVRemoteImageView alloc] initWithFrame:CGRectZero];
    self.bannerView.placeholderImage = TVGradientImage(@[[TVColorPurple() colorWithAlphaComponent:0.65],
                                                         [TVColorBackground() colorWithAlphaComponent:1.0]],
                                                       CGSizeMake(8.0, 120.0));
    [self.headerView addSubview:self.bannerView];

    self.bannerGradient = [[TVGradientView alloc] initWithFrame:CGRectZero];
    self.bannerGradient.colors = @[[[UIColor blackColor] colorWithAlphaComponent:0.0],
                                   [TVColorBackground() colorWithAlphaComponent:0.92]];
    [self.headerView addSubview:self.bannerGradient];

    self.avatarView = [[TVAvatarView alloc] initWithFrame:CGRectZero];
    self.avatarView.layer.borderWidth = 3.0;
    self.avatarView.layer.borderColor = TVColorBackground().CGColor;
    [self.headerView addSubview:self.avatarView];

    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.nameLabel.textColor = TVColorText();
    self.nameLabel.font = TVFont(22.0, UIFontWeightBold);
    self.nameLabel.numberOfLines = 1;
    [self.headerView addSubview:self.nameLabel];

    self.loginLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.loginLabel.textColor = TVColorMuted();
    self.loginLabel.font = TVFont(13.0, UIFontWeightRegular);
    self.loginLabel.numberOfLines = 1;
    [self.headerView addSubview:self.loginLabel];

    self.bioLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bioLabel.textColor = TVColorMuted();
    self.bioLabel.font = TVFont(13.0, UIFontWeightRegular);
    self.bioLabel.numberOfLines = 2;
    [self.headerView addSubview:self.bioLabel];

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statsLabel.textColor = TVColorText();
    self.statsLabel.font = TVFont(12.0, UIFontWeightMedium);
    [self.headerView addSubview:self.statsLabel];

    self.actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.actionButton.titleLabel.font = TVFont(15.0, UIFontWeightSemibold);
    self.actionButton.layer.cornerRadius = 8.0;
    self.actionButton.layer.borderWidth = 1.0;
    [self.actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.actionButton];

    [self layoutHeaderForWidth:CGRectGetWidth(self.view.bounds)];
}

- (void)layoutHeaderForWidth:(CGFloat)width {
    self.laidOutWidth = width;
    self.headerView.frame = CGRectMake(0.0, 0.0, width, 300.0);
    self.bannerView.frame = CGRectMake(0.0, 0.0, width, 120.0);
    self.bannerGradient.frame = CGRectMake(0.0, 0.0, width, 120.0);
    self.avatarView.frame = CGRectMake(16.0, 82.0, 76.0, 76.0);
    self.nameLabel.frame = CGRectMake(104.0, 86.0, width - 120.0, 27.0);
    self.loginLabel.frame = CGRectMake(104.0, 116.0, width - 120.0, 18.0);
    self.bioLabel.frame = CGRectMake(16.0, 172.0, width - 32.0, 40.0);
    self.statsLabel.frame = CGRectMake(16.0, 218.0, width - 32.0, 18.0);
    self.actionButton.frame = CGRectMake(16.0, 248.0, width - 32.0, 40.0);
}

- (void)buildTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = TVColorBackground();
    self.tableView.separatorColor = TVColorBorder();
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 16.0, 0.0, 16.0);
    self.tableView.rowHeight = 48.0;
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = self.headerView;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1.0, 1.0)];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[[TVIcons icon:TVIconRefresh size:20.0 color:TVColorText() weight:2.0]
                                               imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(refreshTapped)];
}

#pragma mark - State

- (void)sessionChanged:(NSNotification *)notification {
    [self updateUI];
}

- (void)favoritesChanged:(NSNotification *)notification {
    [self updateUI];
}

- (void)updateUI {
    TVSession *session = [TVSession shared];
    TVUser *user = session.currentUser;
    BOOL loggedIn = session.isLoggedIn;

    if (loggedIn && user) {
        self.bannerView.urlString = user.bannerURL;
        [self.avatarView setURLString:user.avatarURL displayName:user.displayName];
        self.nameLabel.text = user.displayName.length ? user.displayName : user.login;
        self.loginLabel.text = [NSString stringWithFormat:@"@%@", user.login];
        self.bioLabel.text = user.bio.length ? user.bio : @"Описание не указано.";
        NSString *following = user.followingCount > 0 ? TVFormatCount(user.followingCount) : @"—";
        self.statsLabel.text = [NSString stringWithFormat:@"%@ подписчиков · %@ подписок",
                                TVFormatCount(user.followerCount), following];
        [self.actionButton setTitle:@"Выйти" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:TVColorRed() forState:UIControlStateNormal];
        self.actionButton.backgroundColor = TVColorSurfaceAlt();
        self.actionButton.layer.borderColor = TVColorRed().CGColor;
    } else {
        self.bannerView.urlString = nil;
        [self.avatarView setURLString:nil displayName:@"?"];
        self.nameLabel.text = @"Гость";
        self.loginLabel.text = @"Вы не вошли в аккаунт";
        self.bioLabel.text = @"Войдите, чтобы видеть подписки, писать в чат и сохранять избранное.";
        self.statsLabel.text = @"";
        [self.actionButton setTitle:@"Войти в Twitch" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.actionButton.backgroundColor = TVColorPurple();
        self.actionButton.layer.borderColor = [UIColor clearColor].CGColor;
    }

    [self updateSections];
    [self.tableView reloadData];
}

- (void)updateSections {
    TVSession *session = [TVSession shared];
    TVUser *user = session.currentUser;
    NSMutableArray<NSArray<NSDictionary<NSString *, id> *> *> *sections = [NSMutableArray array];

    if (session.isLoggedIn && user) {
        [sections addObject:@[
            @{@"title": @"Логин", @"detail": user.login.length ? user.login : @"—"},
            @{@"title": @"ID", @"detail": user.userID.length ? user.userID : @"—"},
            @{@"title": @"Избранное", @"detail": [NSString stringWithFormat:@"%ld", (long)session.favoriteLogins.count], @"action": @"favorites"},
            @{@"title": @"Подписки", @"detail": user.followingCount > 0 ? TVFormatCount(user.followingCount) : @"—"},
        ]];
    }

    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (version.length == 0) {
        version = @"1.0.0";
    }
    [sections addObject:@[
        @{@"title": @"Версия", @"detail": version},
        @{@"title": @"Открыть twitch.tv", @"action": @"safari"},
        @{@"title": @"О приложении", @"action": @"about"},
    ]];

    self.sections = sections;
}

#pragma mark - Actions

- (void)actionTapped {
    if ([TVSession shared].isLoggedIn) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Выйти из аккаунта?"
                                                                       message:@"Токен будет удалён с устройства."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(self) weakSelf = self;
        [alert addAction:[UIAlertAction actionWithTitle:@"Выйти" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            __strong typeof(self) strongSelf = weakSelf;
            [[TVSession shared] logout];
            [strongSelf updateUI];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [TVLoginViewController presentFromViewController:self];
    }
}

- (void)refreshTapped {
    if (![TVSession shared].isLoggedIn) {
        [TVLoginViewController presentFromViewController:self];
        return;
    }
    [self refreshCurrentUserSilently:NO];
}

- (void)refreshIfNeeded {
    if (![TVSession shared].isLoggedIn) {
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (self.lastRefresh > 0.0 && now - self.lastRefresh < 60.0) {
        return;
    }
    [self refreshCurrentUserSilently:YES];
}

- (void)refreshCurrentUserSilently:(BOOL)silent {
    if (self.refreshing) {
        return;
    }
    self.refreshing = YES;
    if (!silent) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        spinner.hidesWhenStopped = YES;
        [spinner startAnimating];
        self.refreshSpinner = spinner;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
    }

    __weak typeof(self) weakSelf = self;
    [[TVSession shared] refreshCurrentUserWithCompletion:^(BOOL success) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.refreshing = NO;
        if (strongSelf.refreshSpinner) {
            [strongSelf.refreshSpinner stopAnimating];
            strongSelf.refreshSpinner = nil;
            strongSelf.navigationItem.rightBarButtonItem =
                [[UIBarButtonItem alloc] initWithImage:[[TVIcons icon:TVIconRefresh size:20.0 color:TVColorText() weight:2.0]
                                                       imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                 style:UIBarButtonItemStylePlain
                                                target:strongSelf
                                                action:@selector(refreshTapped)];
        }
        if (success) {
            strongSelf.lastRefresh = [[NSDate date] timeIntervalSince1970];
            [strongSelf updateUI];
        } else if (!silent) {
            TVShowAlert(strongSelf, @"Не удалось обновить профиль", @"Проверьте подключение к интернету и попробуйте снова.");
        }
    }];
}

- (void)openSafari {
    NSURL *url = [NSURL URLWithString:@"https://www.twitch.tv/"];
    if (!url) {
        return;
    }
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
    safari.preferredBarTintColor = TVColorSurface();
    safari.preferredControlTintColor = TVColorPurpleBright();
    [self presentViewController:safari animated:YES completion:nil];
}

- (void)showAbout {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
    NSString *message = [NSString stringWithFormat:
        @"Twitch Lite %@\n\nНативный клиент Twitch для jailbroken iOS 12.\n\n"
        @"Вход через Twitch, подписки, поиск, избранное, чат и HLS-воспроизведение.",
        version];
    TVShowAlert(self, @"О приложении", message);
}

#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.sections[(NSUInteger)section].count;
}

- (NSDictionary<NSString *, id> *)rowAtIndexPath:(NSIndexPath *)indexPath {
    return self.sections[(NSUInteger)indexPath.section][(NSUInteger)indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"profile-row";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.backgroundColor = TVColorSurface();
        cell.textLabel.textColor = TVColorText();
        cell.textLabel.font = TVFont(15.0, UIFontWeightRegular);
        cell.detailTextLabel.textColor = TVColorMuted();
        cell.detailTextLabel.font = TVFont(14.0, UIFontWeightRegular);
        UIView *selected = [[UIView alloc] initWithFrame:CGRectZero];
        selected.backgroundColor = TVColorSurfaceAlt();
        cell.selectedBackgroundView = selected;
    }
    NSDictionary<NSString *, id> *row = [self rowAtIndexPath:indexPath];
    cell.textLabel.text = row[@"title"];
    cell.detailTextLabel.text = row[@"detail"];
    cell.accessoryType = row[@"action"] ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(tableView.bounds), 36.0)];
    header.backgroundColor = TVColorBackground();

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 14.0, CGRectGetWidth(tableView.bounds) - 32.0, 16.0)];
    label.textColor = TVColorMuted();
    label.font = TVFont(11.0, UIFontWeightBold);
    label.text = (section == 0 && [TVSession shared].isLoggedIn) ? @"АККАУНТ" : @"ПРИЛОЖЕНИЕ";
    [header addSubview:label];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 36.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 8.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, id> *row = [self rowAtIndexPath:indexPath];
    NSString *action = row[@"action"];
    if ([action isEqualToString:@"favorites"]) {
        self.tabBarController.selectedIndex = 2;
    } else if ([action isEqualToString:@"safari"]) {
        [self openSafari];
    } else if ([action isEqualToString:@"about"]) {
        [self showAbout];
    }
}

@end
