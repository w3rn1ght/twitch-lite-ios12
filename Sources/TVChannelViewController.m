#import "TVChannelViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <math.h>
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVAPI.h"
#import "TVSession.h"
#import "TVCommonViews.h"
#import "TVImageLoader.h"
#import "TVChatViewController.h"

static void *TVPlayerItemStatusContext = &TVPlayerItemStatusContext;

@interface TVChannelViewController ()

@property (nonatomic, copy) NSString *login;
@property (nonatomic, strong, nullable) TVUser *user;

@property (nonatomic, strong) UIView *videoContainer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong, nullable) AVPlayerItem *playerItem;
@property (nonatomic, strong) TVLoadingOverlay *loadingOverlay;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) TVGradientView *controlsView;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *muteButton;
@property (nonatomic, strong) UIButton *fullscreenButton;
@property (nonatomic, strong) TVLiveBadgeView *liveBadge;
@property (nonatomic, strong) TVPillView *viewersPill;

@property (nonatomic, strong) UIView *infoView;
@property (nonatomic, strong) TVAvatarView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *gameLabel;
@property (nonatomic, strong) UIView *infoSeparator;

@property (nonatomic, strong) UIButton *favoriteButton;
@property (nonatomic, strong) UIButton *shareButton;

@property (nonatomic, strong) TVChatViewController *chatViewController;

@property (nonatomic, assign) BOOL loadingChannel;
@property (nonatomic, assign) BOOL startingPlayback;
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, assign) BOOL wantsPlaying;

@end

@implementation TVChannelViewController

- (instancetype)initWithLogin:(NSString *)login {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _login = [login copy];
        _controlsVisible = YES;
        self.title = login;
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    [self buildVideo];
    [self buildInfo];
    [self buildChat];
    [self buildNavigationItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.user && !self.loadingChannel) {
        [self loadChannel];
    } else if (self.user.isLive && !self.playerItem && !self.startingPlayback) {
        [self startPlayback];
    }
    [self updateFavoriteButton];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self showControls];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController) {
        [self.player pause];
        self.wantsPlaying = NO;
        [self removePlayerItemObserver];
        [[AVAudioSession sharedInstance] setActive:NO
                                       withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                             error:nil];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    BOOL landscape = width > height;

    if (landscape) {
        self.videoContainer.frame = self.view.bounds;
        self.infoView.hidden = YES;
        self.chatViewController.view.hidden = YES;
    } else {
        CGFloat videoHeight = floor(width * 9.0 / 16.0);
        self.videoContainer.frame = CGRectMake(0.0, 0.0, width, videoHeight);
        self.infoView.hidden = NO;
        self.infoView.frame = CGRectMake(0.0, videoHeight, width, 84.0);
        self.chatViewController.view.hidden = NO;
        self.chatViewController.view.frame = CGRectMake(0.0, videoHeight + 84.0,
                                                        width, MAX(0.0, height - videoHeight - 84.0));
    }

    self.playerLayer.frame = self.videoContainer.bounds;
    [self layoutVideoOverlays];
    [self layoutInfo];
}

- (void)dealloc {
    [self removePlayerItemObserver];
    [self.player pause];
    self.player = nil;
}

#pragma mark - Build UI

- (void)buildVideo {
    self.videoContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.videoContainer.backgroundColor = [UIColor blackColor];
    self.videoContainer.clipsToBounds = YES;
    [self.view addSubview:self.videoContainer];

    self.player = [[AVPlayer alloc] init];
    if (@available(iOS 10.0, *)) {
        self.player.automaticallyWaitsToMinimizeStalling = YES;
    }
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.videoContainer.layer addSublayer:self.playerLayer];

    self.loadingOverlay = [[TVLoadingOverlay alloc] initWithFrame:CGRectZero];
    self.loadingOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingOverlay.textLabel.text = @"Загружаем канал…";
    [self.videoContainer addSubview:self.loadingOverlay];

    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.textColor = TVColorText();
    self.errorLabel.font = TVFont(13.0, UIFontWeightMedium);
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 2;
    self.errorLabel.hidden = YES;
    [self.videoContainer addSubview:self.errorLabel];

    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.backgroundColor = TVColorPurple();
    self.retryButton.layer.cornerRadius = 8.0;
    self.retryButton.titleLabel.font = TVFont(13.0, UIFontWeightSemibold);
    [self.retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.retryButton setTitle:@"Повторить" forState:UIControlStateNormal];
    self.retryButton.hidden = YES;
    [self.retryButton addTarget:self action:@selector(retryTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.videoContainer addSubview:self.retryButton];

    self.controlsView = [[TVGradientView alloc] initWithFrame:CGRectZero];
    self.controlsView.colors = @[[[UIColor blackColor] colorWithAlphaComponent:0.0],
                                 [[UIColor blackColor] colorWithAlphaComponent:0.85]];
    [self.videoContainer addSubview:self.controlsView];

    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playButton.tintColor = [UIColor whiteColor];
    [self.playButton setImage:[TVIcons icon:TVIconPlay size:22.0 color:[UIColor whiteColor] weight:2.2]
                     forState:UIControlStateNormal];
    [self.playButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.controlsView addSubview:self.playButton];

    self.muteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.muteButton setImage:[TVIcons icon:TVIconVolume size:22.0 color:[UIColor whiteColor] weight:2.0]
                     forState:UIControlStateNormal];
    [self.muteButton addTarget:self action:@selector(muteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.controlsView addSubview:self.muteButton];

    self.fullscreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.fullscreenButton setImage:[TVIcons icon:TVIconFullscreen size:22.0 color:[UIColor whiteColor] weight:2.0]
                           forState:UIControlStateNormal];
    [self.fullscreenButton addTarget:self action:@selector(fullscreenTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.controlsView addSubview:self.fullscreenButton];

    self.liveBadge = [[TVLiveBadgeView alloc] initWithText:@"В ЭФИРЕ"];
    [self.videoContainer addSubview:self.liveBadge];

    self.viewersPill = [[TVPillView alloc] initWithIcon:TVIconEye text:@"0"];
    [self.videoContainer addSubview:self.viewersPill];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoTapped)];
    [self.videoContainer addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [self.loadingOverlay.topAnchor constraintEqualToAnchor:self.videoContainer.topAnchor],
        [self.loadingOverlay.leadingAnchor constraintEqualToAnchor:self.videoContainer.leadingAnchor],
        [self.loadingOverlay.trailingAnchor constraintEqualToAnchor:self.videoContainer.trailingAnchor],
        [self.loadingOverlay.bottomAnchor constraintEqualToAnchor:self.videoContainer.bottomAnchor],

        [self.errorLabel.centerXAnchor constraintEqualToAnchor:self.videoContainer.centerXAnchor],
        [self.errorLabel.centerYAnchor constraintEqualToAnchor:self.videoContainer.centerYAnchor constant:-14.0],
        [self.errorLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.videoContainer.leadingAnchor constant:24.0],
        [self.errorLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.videoContainer.trailingAnchor constant:-24.0],

        [self.retryButton.centerXAnchor constraintEqualToAnchor:self.videoContainer.centerXAnchor],
        [self.retryButton.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:12.0],
        [self.retryButton.widthAnchor constraintEqualToConstant:130.0],
        [self.retryButton.heightAnchor constraintEqualToConstant:36.0],
    ]];
}

- (void)buildInfo {
    self.infoView = [[UIView alloc] initWithFrame:CGRectZero];
    self.infoView.backgroundColor = TVColorSurface();
    [self.view addSubview:self.infoView];

    self.avatarView = [[TVAvatarView alloc] initWithFrame:CGRectZero];
    [self.infoView addSubview:self.avatarView];

    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.nameLabel.textColor = TVColorText();
    self.nameLabel.font = TVFont(16.0, UIFontWeightSemibold);
    [self.infoView addSubview:self.nameLabel];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.textColor = TVColorText();
    self.titleLabel.font = TVFont(13.0, UIFontWeightRegular);
    self.titleLabel.numberOfLines = 1;
    [self.infoView addSubview:self.titleLabel];

    self.gameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.gameLabel.textColor = TVColorMuted();
    self.gameLabel.font = TVFont(12.0, UIFontWeightRegular);
    self.gameLabel.numberOfLines = 1;
    [self.infoView addSubview:self.gameLabel];

    self.infoSeparator = [[UIView alloc] initWithFrame:CGRectZero];
    self.infoSeparator.backgroundColor = TVColorBorder();
    [self.infoView addSubview:self.infoSeparator];
}

- (void)buildChat {
    self.chatViewController = [[TVChatViewController alloc] initWithChannelLogin:self.login];
    [self addChildViewController:self.chatViewController];
    self.chatViewController.view.backgroundColor = TVColorBackground();
    [self.view addSubview:self.chatViewController.view];
    [self.chatViewController didMoveToParentViewController:self];
}

- (void)buildNavigationItems {
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.favoriteButton.frame = CGRectMake(0.0, 0.0, 34.0, 34.0);
    [self.favoriteButton addTarget:self action:@selector(favoriteTapped) forControlEvents:UIControlEventTouchUpInside];
    [self updateFavoriteButton];

    self.shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shareButton.frame = CGRectMake(0.0, 0.0, 34.0, 34.0);
    [self.shareButton setImage:[TVIcons icon:TVIconShare size:20.0 color:TVColorText() weight:2.0]
                      forState:UIControlStateNormal];
    [self.shareButton addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];

    UIBarButtonItem *favoriteItem = [[UIBarButtonItem alloc] initWithCustomView:self.favoriteButton];
    UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithCustomView:self.shareButton];
    self.navigationItem.rightBarButtonItems = @[shareItem, favoriteItem];
}

- (void)layoutVideoOverlays {
    CGFloat width = CGRectGetWidth(self.videoContainer.bounds);
    CGFloat height = CGRectGetHeight(self.videoContainer.bounds);

    CGSize liveSize = [self.liveBadge intrinsicContentSize];
    self.liveBadge.frame = CGRectMake(10.0, 10.0, liveSize.width, liveSize.height);

    CGSize pillSize = [self.viewersPill intrinsicContentSize];
    self.viewersPill.frame = CGRectMake(width - pillSize.width - 10.0, 10.0, pillSize.width, pillSize.height);

    CGFloat controlsHeight = 58.0;
    self.controlsView.frame = CGRectMake(0.0, height - controlsHeight, width, controlsHeight);
    self.playButton.frame = CGRectMake(10.0, controlsHeight - 42.0, 32.0, 32.0);
    self.muteButton.frame = CGRectMake(50.0, controlsHeight - 42.0, 32.0, 32.0);
    self.fullscreenButton.frame = CGRectMake(width - 42.0, controlsHeight - 42.0, 32.0, 32.0);
}

- (void)layoutInfo {
    CGFloat width = CGRectGetWidth(self.infoView.bounds);
    self.avatarView.frame = CGRectMake(12.0, 16.0, 44.0, 44.0);
    self.nameLabel.frame = CGRectMake(68.0, 13.0, width - 80.0, 20.0);
    self.titleLabel.frame = CGRectMake(68.0, 34.0, width - 80.0, 18.0);
    self.gameLabel.frame = CGRectMake(68.0, 53.0, width - 80.0, 17.0);
    self.infoSeparator.frame = CGRectMake(0.0, 83.5, width, 0.5);
}

#pragma mark - Channel data

- (void)loadChannel {
    if (self.loadingChannel) {
        return;
    }
    self.loadingChannel = YES;
    self.errorLabel.hidden = YES;
    self.retryButton.hidden = YES;
    [self.loadingOverlay start];
    self.loadingOverlay.textLabel.text = @"Загружаем канал…";

    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchChannelWithLogin:self.login completion:^(TVUser *channel, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.loadingChannel = NO;
        [strongSelf.loadingOverlay stop];
        if (!channel) {
            [strongSelf showChannelError:error];
            return;
        }
        strongSelf.user = channel;
        [strongSelf applyUser:channel];
        if (channel.isLive) {
            [strongSelf startPlayback];
        } else {
            [strongSelf showOffline];
        }
    }];
}

- (void)applyUser:(TVUser *)user {
    self.title = user.displayName.length ? user.displayName : user.login;
    self.nameLabel.text = user.displayName.length ? user.displayName : user.login;
    [self.avatarView setURLString:user.avatarURL displayName:self.nameLabel.text];
    self.errorLabel.hidden = YES;
    self.retryButton.hidden = YES;

    TVStream *stream = user.stream;
    if (stream) {
        self.titleLabel.text = stream.title.length ? stream.title : @"Без названия";
        NSString *game = stream.gameName.length ? stream.gameName : @"Стрим";
        self.gameLabel.text = [NSString stringWithFormat:@"%@ · %@ зрителей", game, TVFormatViewers(stream.viewers)];
        self.liveBadge.hidden = NO;
        self.viewersPill.hidden = NO;
        [self.viewersPill setText:TVFormatViewers(stream.viewers)];
    } else {
        self.titleLabel.text = @"Канал не в эфире";
        self.gameLabel.text = user.bio.length ? user.bio : @"Офлайн";
        self.liveBadge.hidden = YES;
        self.viewersPill.hidden = YES;
    }
    [self updateFavoriteButton];
    [self.view setNeedsLayout];
}

- (void)showOffline {
    [self.loadingOverlay stop];
    self.errorLabel.text = @"Канал сейчас не в эфире";
    self.errorLabel.hidden = NO;
    [self.retryButton setTitle:@"Обновить" forState:UIControlStateNormal];
    self.retryButton.hidden = NO;
    self.wantsPlaying = NO;
    [self updatePlayButton];
}

- (void)showChannelError:(NSError *)error {
    self.errorLabel.text = error.localizedDescription ?: @"Не удалось загрузить канал.";
    self.errorLabel.hidden = NO;
    [self.retryButton setTitle:@"Повторить" forState:UIControlStateNormal];
    self.retryButton.hidden = NO;
    self.wantsPlaying = NO;
    [self updatePlayButton];
}

#pragma mark - Playback

- (void)startPlayback {
    if (self.startingPlayback || !self.user.isLive) {
        return;
    }
    self.startingPlayback = YES;
    self.errorLabel.hidden = YES;
    self.retryButton.hidden = YES;
    [self.loadingOverlay start];
    self.loadingOverlay.textLabel.text = @"Загрузка потока…";

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    __weak typeof(self) weakSelf = self;
    [[TVAPI shared] fetchPlaybackURLForLogin:self.login completion:^(NSURL *url, NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf.startingPlayback = NO;
        if (!url) {
            [strongSelf showPlaybackError:error.localizedDescription ?: @"Не удалось получить ссылку на поток."];
            return;
        }
        [strongSelf playURL:url];
    }];
}

- (void)playURL:(NSURL *)url {
    [self removePlayerItemObserver];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    self.playerItem = item;
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:TVPlayerItemStatusContext];
    [self.player replaceCurrentItemWithPlayerItem:item];
    self.wantsPlaying = YES;
    [self.player play];
    [self updatePlayButton];
    [self showControls];
}

- (void)showPlaybackError:(NSString *)message {
    [self.loadingOverlay stop];
    self.errorLabel.text = message.length ? message : @"Не удалось воспроизвести поток.";
    self.errorLabel.hidden = NO;
    [self.retryButton setTitle:@"Повторить" forState:UIControlStateNormal];
    self.retryButton.hidden = NO;
    self.wantsPlaying = NO;
    [self.player pause];
    [self updatePlayButton];
    [self showControls];
}

- (void)removePlayerItemObserver {
    if (self.playerItem) {
        @try {
            [self.playerItem removeObserver:self forKeyPath:@"status" context:TVPlayerItemStatusContext];
        } @catch (NSException *exception) {
            (void)exception;
        }
        self.playerItem = nil;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (context == TVPlayerItemStatusContext) {
        AVPlayerItem *item = (AVPlayerItem *)object;
        if (item.status == AVPlayerItemStatusReadyToPlay) {
            [self.loadingOverlay stop];
            self.errorLabel.hidden = YES;
            self.retryButton.hidden = YES;
            self.wantsPlaying = YES;
            [self.player play];
            [self updatePlayButton];
            [self showControls];
        } else if (item.status == AVPlayerItemStatusFailed) {
            [self showPlaybackError:item.error.localizedDescription ?: @"Не удалось воспроизвести поток."];
        }
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)updatePlayButton {
    TVIconName icon = self.wantsPlaying ? TVIconPause : TVIconPlay;
    [self.playButton setImage:[TVIcons icon:icon size:22.0 color:[UIColor whiteColor] weight:2.2]
                     forState:UIControlStateNormal];
    [self.playButton setImage:[TVIcons icon:icon size:22.0 color:[UIColor whiteColor] weight:2.2]
                     forState:UIControlStateHighlighted];
}

- (void)updateMuteButton {
    TVIconName icon = self.player.muted ? TVIconVolumeMuted : TVIconVolume;
    [self.muteButton setImage:[TVIcons icon:icon size:22.0 color:[UIColor whiteColor] weight:2.0]
                     forState:UIControlStateNormal];
}

#pragma mark - Controls

- (void)showControls {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControlsNow) object:nil];
    self.controlsView.hidden = NO;
    self.controlsView.alpha = 1.0;
    self.controlsVisible = YES;
    [self scheduleHideControls];
}

- (void)scheduleHideControls {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideControlsNow) object:nil];
    if (!self.wantsPlaying || !self.errorLabel.hidden) {
        return;
    }
    [self performSelector:@selector(hideControlsNow) withObject:nil afterDelay:4.0];
}

- (void)hideControlsNow {
    if (!self.wantsPlaying || !self.errorLabel.hidden) {
        return;
    }
    self.controlsVisible = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.controlsView.alpha = 0.0;
    }];
}

- (void)videoTapped {
    if (self.controlsVisible) {
        [self hideControlsNow];
    } else {
        [self showControls];
    }
}

- (void)playPauseTapped {
    if (!self.playerItem) {
        if (self.user.isLive) {
            [self startPlayback];
        }
        return;
    }
    if (self.wantsPlaying) {
        self.wantsPlaying = NO;
        [self.player pause];
    } else {
        self.wantsPlaying = YES;
        [self.player play];
    }
    [self updatePlayButton];
    [self showControls];
}

- (void)muteTapped {
    self.player.muted = !self.player.muted;
    [self updateMuteButton];
    [self showControls];
}

- (void)fullscreenTapped {
    if (!self.player) {
        return;
    }
    AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
    controller.player = self.player;
    controller.showsPlaybackControls = YES;
    controller.videoGravity = AVLayerVideoGravityResizeAspect;
    controller.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:controller animated:YES completion:nil];
    [self showControls];
}

- (void)retryTapped {
    if (self.user.isLive) {
        [self startPlayback];
    } else {
        [self loadChannel];
    }
}

#pragma mark - Actions

- (void)favoriteTapped {
    if (self.login.length == 0) {
        return;
    }
    TVHapticLight();
    [[TVSession shared] toggleFavorite:self.login];
    [self updateFavoriteButton];
}

- (void)updateFavoriteButton {
    BOOL favorite = [[TVSession shared] isFavorite:self.login];
    UIImage *image = [TVIcons icon:(favorite ? TVIconStarFilled : TVIconStar)
                             size:22.0
                            color:(favorite ? TVColorPurpleBright() : TVColorText())
                           weight:1.9];
    [self.favoriteButton setImage:image forState:UIControlStateNormal];
    self.favoriteButton.accessibilityLabel = favorite ? @"Убрать из избранного" : @"Добавить в избранное";
}

- (void)shareTapped {
    if (self.login.length == 0) {
        return;
    }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.twitch.tv/%@", self.login]];
    if (!url) {
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                          applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.shareButton;
    activity.popoverPresentationController.sourceRect = self.shareButton.bounds;
    [self presentViewController:activity animated:YES completion:nil];
}

@end
