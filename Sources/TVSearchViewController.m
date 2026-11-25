#import "TVSearchViewController.h"
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVAPI.h"
#import "TVSession.h"
#import "TVStreamCell.h"
#import "TVChannelCell.h"
#import "TVGameCell.h"
#import "TVCommonViews.h"
#import "TVChannelViewController.h"
#import "TVCategoryViewController.h"

typedef NS_ENUM(NSInteger, TVSearchSectionType) {
    TVSearchSectionTypeChannels = 0,
    TVSearchSectionTypeGames,
    TVSearchSectionTypeStreams,
};

@interface TVSearchViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UIView *searchContainer;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIView *searchSeparator;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TVLoadingOverlay *loadingOverlay;
@property (nonatomic, strong, nullable) UIActivityIndicatorView *spinner;
@property (nonatomic, strong, nullable) TVSearchResults *results;
@property (nonatomic, strong) NSArray<TVGame *> *popularGames;
@property (nonatomic, strong) NSArray<TVStream *> *popularStreams;
@property (nonatomic, assign) BOOL loadingPopular;
@property (nonatomic, assign) BOOL hasLoadedPopular;
@property (nonatomic, assign) NSInteger searchGeneration;
@property (nonatomic, assign) BOOL hasFocusedSearch;

@end

@implementation TVSearchViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"Поиск";
        _popularGames = @[];
        _popularStreams = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    [self buildSearchBar];
    [self buildTable];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(favoritesChanged:)
                                                 name:TVFavoritesDidChangeNotification
                                               object:nil];

    [self loadPopular];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.hasLoadedPopular && !self.loadingPopular && [self trimmedQuery].length == 0) {
        [self loadPopular];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasFocusedSearch) {
        self.hasFocusedSearch = YES;
        [self.searchField becomeFirstResponder];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.tableView.backgroundView) {
        self.tableView.backgroundView.frame = self.tableView.bounds;
    }
}

#pragma mark - UI

- (void)buildSearchBar {
    self.searchContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchContainer.backgroundColor = TVColorBackground();
    [self.view addSubview:self.searchContainer];

    self.searchField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.searchField.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchField.backgroundColor = TVColorSurfaceAlt();
    self.searchField.textColor = TVColorText();
    self.searchField.tintColor = TVColorPurple();
    self.searchField.font = TVFont(15.0, UIFontWeightRegular);
    self.searchField.layer.cornerRadius = 20.0;
    self.searchField.clipsToBounds = YES;
    self.searchField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Поиск каналов и категорий"
            attributes:@{NSForegroundColorAttributeName: TVColorMuted()}];
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.returnKeyType = UIReturnKeySearch;
    self.searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchField.delegate = self;
    [self.searchField addTarget:self action:@selector(searchFieldChanged) forControlEvents:UIControlEventEditingChanged];

    UIView *iconContainer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 38.0, 22.0)];
    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(13.0, 2.0, 18.0, 18.0)];
    iconView.image = [TVIcons icon:TVIconSearch size:18.0 color:TVColorMuted() weight:2.0];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    [iconContainer addSubview:iconView];
    self.searchField.leftView = iconContainer;
    self.searchField.leftViewMode = UITextFieldViewModeAlways;
    [self.searchContainer addSubview:self.searchField];

    self.searchSeparator = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchSeparator.backgroundColor = TVColorBorder();
    [self.searchContainer addSubview:self.searchSeparator];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.searchContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.searchContainer.heightAnchor constraintEqualToConstant:58.0],

        [self.searchField.topAnchor constraintEqualToAnchor:self.searchContainer.topAnchor constant:8.0],
        [self.searchField.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor constant:12.0],
        [self.searchField.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor constant:-12.0],
        [self.searchField.heightAnchor constraintEqualToConstant:40.0],

        [self.searchSeparator.leadingAnchor constraintEqualToAnchor:self.searchContainer.leadingAnchor],
        [self.searchSeparator.trailingAnchor constraintEqualToAnchor:self.searchContainer.trailingAnchor],
        [self.searchSeparator.bottomAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor],
        [self.searchSeparator.heightAnchor constraintEqualToConstant:0.5],
    ]];
}

- (void)buildTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    TVStyleTableView(self.tableView);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100.0;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 16.0, 0.0);
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[TVStreamCell class] forCellReuseIdentifier:@"stream"];
    [self.tableView registerClass:[TVChannelCell class] forCellReuseIdentifier:@"channel"];
    [self.tableView registerClass:[TVGameRowCell class] forCellReuseIdentifier:@"game"];
    [self.view addSubview:self.tableView];

    self.loadingOverlay = [[TVLoadingOverlay alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingOverlay.textLabel.text = @"Загружаем Twitch…";
    [self.view addSubview:self.loadingOverlay];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchContainer.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.loadingOverlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.loadingOverlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.loadingOverlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.loadingOverlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (NSString *)trimmedQuery {
    return [self.searchField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (BOOL)isSearchMode {
    return [self trimmedQuery].length > 0;
}

#pragma mark - Popular

- (void)loadPopular {
    if (self.loadingPopular) {
        return;
    }
    if (self.hasLoadedPopular && (self.popularGames.count > 0 || self.popularStreams.count > 0)) {
        return;
    }
    self.loadingPopular = YES;
    if (self.popularGames.count == 0 && self.popularStreams.count == 0 && ![self isSearchMode]) {
        [self.loadingOverlay start];
    }

    __weak typeof(self) weakSelf = self;
    dispatch_group_t group = dispatch_group_create();
    __block NSArray<TVGame *> *games = nil;
    __block NSArray<TVStream *> *streams = nil;
    __block NSError *firstError = nil;

    dispatch_group_enter(group);
    [[TVAPI shared] fetchPopularGamesWithCompletion:^(NSArray<TVGame *> *result, NSError *error) {
        if (result) {
            games = result;
        } else if (error && !firstError) {
            firstError = error;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [[TVAPI shared] fetchTopStreamsWithCompletion:^(NSArray<TVStream *> *result, NSError *error) {
        if (result) {
            streams = result;
        } else if (error && !firstError) {
            firstError = error;
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loadingPopular = NO;
        strongSelf.hasLoadedPopular = YES;
        [strongSelf.loadingOverlay stop];
        if (games) {
            strongSelf.popularGames = games;
        }
        if (streams) {
            strongSelf.popularStreams = streams;
        }
        [strongSelf.tableView reloadData];

        if (![strongSelf isSearchMode] && strongSelf.popularGames.count == 0 && strongSelf.popularStreams.count == 0) {
            [strongSelf showPopularError:firstError];
        } else {
            strongSelf.tableView.backgroundView = nil;
        }
    });
}

- (void)showPopularError:(NSError *)error {
    __weak typeof(self) weakSelf = self;
    TVEmptyStateView *empty = [[TVEmptyStateView alloc] initWithIcon:TVIconCompass
                                                              title:@"Не удалось загрузить Twitch"
                                                           subtitle:error.localizedDescription ?: @"Проверьте подключение к интернету."
                                                        actionTitle:@"Повторить"];
    empty.actionBlock = ^{
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.hasLoadedPopular = NO;
        [strongSelf loadPopular];
    };
    self.tableView.backgroundView = empty;
}

#pragma mark - Search

- (void)searchFieldChanged {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runSearch) object:nil];
    self.searchGeneration += 1;

    if (![self isSearchMode]) {
        self.results = nil;
        [self stopSpinner];
        [self.tableView reloadData];
        [self loadPopular];
        return;
    }
    [self performSelector:@selector(runSearch) withObject:nil afterDelay:0.35];
}

- (void)runSearch {
    NSString *query = [self trimmedQuery];
    if (query.length == 0) {
        return;
    }
    NSInteger generation = self.searchGeneration;
    [self startSpinner];

    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] searchQuery:query completion:^(TVSearchResults *results, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf || generation != strongSelf.searchGeneration) {
            return;
        }
        [strongSelf stopSpinner];
        if (!results) {
            [strongSelf showSearchError:error];
            return;
        }
        strongSelf.results = results;
        [strongSelf.tableView reloadData];
        if (results.channels.count == 0 && results.games.count == 0) {
            [strongSelf showNoResults];
        } else {
            strongSelf.tableView.backgroundView = nil;
        }
    }];
}

- (void)showNoResults {
    TVEmptyStateView *empty = [[TVEmptyStateView alloc] initWithIcon:TVIconSearch
                                                              title:@"Ничего не найдено"
                                                           subtitle:@"Попробуйте изменить запрос."
                                                        actionTitle:nil];
    self.tableView.backgroundView = empty;
}

- (void)showSearchError:(NSError *)error {
    TVEmptyStateView *empty = [[TVEmptyStateView alloc] initWithIcon:TVIconSearch
                                                              title:@"Ошибка поиска"
                                                           subtitle:error.localizedDescription ?: @"Не удалось выполнить запрос."
                                                        actionTitle:nil];
    self.tableView.backgroundView = empty;
}

- (void)startSpinner {
    if (self.spinner) {
        [self.spinner startAnimating];
        return;
    }
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    spinner.hidesWhenStopped = YES;
    [spinner startAnimating];
    self.spinner = spinner;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
}

- (void)stopSpinner {
    [self.spinner stopAnimating];
    self.spinner = nil;
    self.navigationItem.rightBarButtonItem = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runSearch) object:nil];
    self.searchGeneration += 1;
    [self runSearch];
    return NO;
}

- (void)favoritesChanged:(NSNotification *)notification {
    [self.tableView reloadData];
}

#pragma mark - Sections

- (NSArray<NSNumber *> *)sectionTypes {
    NSMutableArray<NSNumber *> *types = [NSMutableArray array];
    if ([self isSearchMode]) {
        if (self.results.channels.count > 0) {
            [types addObject:@(TVSearchSectionTypeChannels)];
        }
        if (self.results.games.count > 0) {
            [types addObject:@(TVSearchSectionTypeGames)];
        }
    } else {
        if (self.popularGames.count > 0) {
            [types addObject:@(TVSearchSectionTypeGames)];
        }
        if (self.popularStreams.count > 0) {
            [types addObject:@(TVSearchSectionTypeStreams)];
        }
    }
    return types;
}

- (TVSearchSectionType)sectionType:(NSInteger)section {
    NSArray<NSNumber *> *types = [self sectionTypes];
    if (section < 0 || section >= (NSInteger)types.count) {
        return TVSearchSectionTypeChannels;
    }
    return (TVSearchSectionType)[types[(NSUInteger)section] integerValue];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)[self sectionTypes].count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self sectionType:section]) {
        case TVSearchSectionTypeChannels:
            return (NSInteger)self.results.channels.count;
        case TVSearchSectionTypeGames:
            return [self isSearchMode] ? (NSInteger)self.results.games.count : (NSInteger)self.popularGames.count;
        case TVSearchSectionTypeStreams:
            return (NSInteger)self.popularStreams.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TVSearchSectionType type = [self sectionType:indexPath.section];
    if (type == TVSearchSectionTypeChannels) {
        TVUser *user = self.results.channels[(NSUInteger)indexPath.row];
        TVChannelCell *cell = [tableView dequeueReusableCellWithIdentifier:@"channel" forIndexPath:indexPath];
        [cell configureWithUser:user showFavorite:YES];
        cell.onFavoriteTapped = ^{
            [[TVSession shared] toggleFavorite:user.login];
        };
        return cell;
    }
    if (type == TVSearchSectionTypeGames) {
        TVGame *game = [self isSearchMode] ? self.results.games[(NSUInteger)indexPath.row]
                                          : self.popularGames[(NSUInteger)indexPath.row];
        TVGameRowCell *cell = [tableView dequeueReusableCellWithIdentifier:@"game" forIndexPath:indexPath];
        [cell configureWithGame:game];
        return cell;
    }
    TVStream *stream = self.popularStreams[(NSUInteger)indexPath.row];
    TVStreamCell *cell = [tableView dequeueReusableCellWithIdentifier:@"stream" forIndexPath:indexPath];
    [cell configureWithStream:stream];
    cell.onFavoriteTapped = ^{
        [[TVSession shared] toggleFavorite:stream.broadcaster.login];
    };
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch ([self sectionType:indexPath.section]) {
        case TVSearchSectionTypeChannels:
            return 74.0;
        case TVSearchSectionTypeGames:
            return 76.0;
        case TVSearchSectionTypeStreams:
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
    switch ([self sectionType:section]) {
        case TVSearchSectionTypeChannels:
            label.text = [NSString stringWithFormat:@"КАНАЛЫ · %ld", (long)self.results.channels.count];
            break;
        case TVSearchSectionTypeGames:
            label.text = [self isSearchMode]
                ? [NSString stringWithFormat:@"КАТЕГОРИИ · %ld", (long)self.results.games.count]
                : [NSString stringWithFormat:@"ПОПУЛЯРНЫЕ КАТЕГОРИИ · %ld", (long)self.popularGames.count];
            break;
        case TVSearchSectionTypeStreams:
            label.text = [NSString stringWithFormat:@"ПОПУЛЯРНЫЕ СТРИМЫ · %ld", (long)self.popularStreams.count];
            break;
    }
    [header addSubview:label];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 38.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TVSearchSectionType type = [self sectionType:indexPath.section];
    if (type == TVSearchSectionTypeChannels) {
        TVUser *user = self.results.channels[(NSUInteger)indexPath.row];
        [self openChannel:user.login];
        return;
    }
    if (type == TVSearchSectionTypeGames) {
        TVGame *game = [self isSearchMode] ? self.results.games[(NSUInteger)indexPath.row]
                                          : self.popularGames[(NSUInteger)indexPath.row];
        TVCategoryViewController *category = [[TVCategoryViewController alloc] initWithGame:game];
        [self.navigationController pushViewController:category animated:YES];
        return;
    }
    TVStream *stream = self.popularStreams[(NSUInteger)indexPath.row];
    [self openChannel:stream.broadcaster.login];
}

- (void)openChannel:(NSString *)login {
    if (login.length == 0) {
        return;
    }
    TVChannelViewController *channel = [[TVChannelViewController alloc] initWithLogin:login];
    [self.navigationController pushViewController:channel animated:YES];
}

@end
