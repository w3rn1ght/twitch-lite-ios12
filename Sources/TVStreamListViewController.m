#import "TVStreamListViewController.h"
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVAPI.h"
#import "TVSession.h"
#import "TVStreamCell.h"
#import "TVCommonViews.h"
#import "TVChannelViewController.h"

@interface TVStreamListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSString *listTitle;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) TVLoadingOverlay *loadingOverlay;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray<TVStream *> *streams;
@property (nonatomic, assign) BOOL loading;

@end

@implementation TVStreamListViewController

- (instancetype)initWithTitle:(NSString *)title streams:(NSArray<TVStream *> *)streams {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _listTitle = [title copy];
        _streams = streams ?: @[];
        self.title = title;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    TVStyleTableView(self.tableView);
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 300.0;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 16.0, 0.0);
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

    if (self.streams.count == 0) {
        [self refreshTapped];
    }
}

- (void)refreshTapped {
    if (self.loading) {
        return;
    }
    self.loading = YES;
    if (self.streams.count == 0) {
        [self.loadingOverlay start];
    }
    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchTopStreamsWithCompletion:^(NSArray<TVStream *> *streams, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loading = NO;
        [strongSelf.refreshControl endRefreshing];
        [strongSelf.loadingOverlay stop];
        if (streams) {
            strongSelf.streams = streams;
            [strongSelf.tableView reloadData];
        } else {
            TVShowAlert(strongSelf, @"Ошибка", error.localizedDescription ?: @"Не удалось загрузить стримы.");
        }
    }];
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
