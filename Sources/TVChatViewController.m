#import "TVChatViewController.h"
#import "TVChatConnection.h"
#import "TVChatMessageCell.h"
#import "TVTheme.h"
#import "TVIcons.h"
#import "TVCommonViews.h"
#import "TVSession.h"
#import "TVLoginViewController.h"

@interface TVChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, TVChatConnectionDelegate>
@property (nonatomic, copy) NSString *channelLogin;
@property (nonatomic, strong, nullable) TVChatConnection *connection;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) TVStatusDotView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UIView *inputSeparator;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) UIButton *unreadButton;
@property (nonatomic, strong) NSMutableArray<TVChatMessage *> *messages;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, assign) TVChatConnectionState lastState;
@property (nonatomic, assign) BOOL hasConnectedOnce;
@property (nonatomic, assign) BOOL lastLoggedIn;
@property (nonatomic, assign) CGFloat keyboardOverlap;
@end

@implementation TVChatViewController

- (instancetype)initWithChannelLogin:(NSString *)login {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _channelLogin = [login copy];
        _messages = [NSMutableArray array];
        _lastState = (TVChatConnectionState)-1;
        _lastLoggedIn = [TVSession shared].isLoggedIn;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = TVColorBackground();
    self.view.clipsToBounds = YES;

    [self buildHeader];
    [self buildTable];
    [self buildInput];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionChanged:)
                                                 name:TVSessionDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    [self updateInputState];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.connection.delegate = nil;
    [self.connection disconnect];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.connection) {
        [self connectChat];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.messages.count) {
        [self scrollToBottomAnimated:NO];
    }
}

- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    [self.view setNeedsLayout];
}

#pragma mark - UI

- (void)buildHeader {
    self.headerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerView.backgroundColor = TVColorSurface();
    [self.view addSubview:self.headerView];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"ЧАТ";
    self.titleLabel.textColor = TVColorMuted();
    self.titleLabel.font = TVFont(11.0, UIFontWeightBold);
    [self.headerView addSubview:self.titleLabel];

    self.statusDot = [[TVStatusDotView alloc] initWithFrame:CGRectZero];
    self.statusDot.dotColor = TVColorMuted();
    [self.headerView addSubview:self.statusDot];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.text = @"Подключение…";
    self.statusLabel.textColor = TVColorMuted();
    self.statusLabel.font = TVFont(11.0, UIFontWeightRegular);
    [self.headerView addSubview:self.statusLabel];
}

- (void)buildTable {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.backgroundColor = TVColorBackground();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.allowsSelection = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 36.0;
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.contentInset = UIEdgeInsetsMake(4.0, 0.0, 8.0, 0.0);
    [self.tableView registerClass:[TVChatMessageCell class] forCellReuseIdentifier:@"message"];
    [self.tableView registerClass:[TVSystemMessageCell class] forCellReuseIdentifier:@"system"];
    [self.view addSubview:self.tableView];

    self.unreadButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.unreadButton.backgroundColor = TVColorPurple();
    [self.unreadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.unreadButton.titleLabel.font = TVFont(12.0, UIFontWeightSemibold);
    self.unreadButton.layer.cornerRadius = 16.0;
    self.unreadButton.hidden = YES;
    [self.unreadButton addTarget:self action:@selector(unreadTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.unreadButton];
}

- (void)buildInput {
    self.inputBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.inputBar.backgroundColor = TVColorSurface();
    [self.view addSubview:self.inputBar];

    self.inputSeparator = [[UIView alloc] initWithFrame:CGRectZero];
    self.inputSeparator.backgroundColor = TVColorBorder();
    [self.inputBar addSubview:self.inputSeparator];

    self.textField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.textField.backgroundColor = TVColorSurfaceAlt();
    self.textField.textColor = TVColorText();
    self.textField.tintColor = TVColorPurple();
    self.textField.font = TVFont(14.0, UIFontWeightRegular);
    self.textField.layer.cornerRadius = 19.0;
    self.textField.clipsToBounds = YES;
    self.textField.keyboardAppearance = UIKeyboardAppearanceDark;
    self.textField.returnKeyType = UIReturnKeySend;
    self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.textField.delegate = self;
    UIView *spacer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 12.0, 1.0)];
    self.textField.leftView = spacer;
    self.textField.leftViewMode = UITextFieldViewModeAlways;
    [self.inputBar addSubview:self.textField];

    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.backgroundColor = TVColorPurple();
    self.sendButton.layer.cornerRadius = 17.0;
    [self.sendButton setImage:[TVIcons icon:TVIconSend size:18.0 color:[UIColor whiteColor] weight:2.0]
                     forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.inputBar addSubview:self.sendButton];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(inputTapped)];
    tap.cancelsTouchesInView = NO;
    [self.inputBar addGestureRecognizer:tap];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);

    CGFloat bottomInset = 0.0;
    if (self.keyboardOverlap <= 0.5 && self.view.window) {
        CGRect windowRect = [self.view convertRect:self.view.bounds toView:nil];
        CGFloat windowHeight = CGRectGetHeight(self.view.window.bounds);
        if (CGRectGetMaxY(windowRect) >= windowHeight - 1.0) {
            bottomInset = self.view.safeAreaInsets.bottom;
        }
    }

    self.headerView.frame = CGRectMake(0.0, 0.0, width, 34.0);
    [self.titleLabel sizeToFit];
    self.titleLabel.frame = CGRectMake(12.0, (34.0 - CGRectGetHeight(self.titleLabel.bounds)) / 2.0,
                                       CGRectGetWidth(self.titleLabel.bounds), CGRectGetHeight(self.titleLabel.bounds));
    self.statusDot.frame = CGRectMake(CGRectGetMaxX(self.titleLabel.frame) + 9.0, (34.0 - 7.0) / 2.0, 7.0, 7.0);
    [self.statusLabel sizeToFit];
    self.statusLabel.frame = CGRectMake(CGRectGetMaxX(self.statusDot.frame) + 5.0,
                                        (34.0 - CGRectGetHeight(self.statusLabel.bounds)) / 2.0,
                                        CGRectGetWidth(self.statusLabel.bounds), CGRectGetHeight(self.statusLabel.bounds));

    CGFloat inputHeight = 52.0 + bottomInset;
    CGFloat inputY = height - inputHeight - self.keyboardOverlap;
    if (inputY < 34.0) {
        inputY = 34.0;
    }
    self.inputBar.frame = CGRectMake(0.0, inputY, width, inputHeight);
    self.inputSeparator.frame = CGRectMake(0.0, 0.0, width, 0.5);
    CGFloat fieldWidth = MAX(40.0, width - 66.0);
    self.textField.frame = CGRectMake(12.0, 7.0, fieldWidth, 38.0);
    self.sendButton.frame = CGRectMake(width - 46.0, 9.0, 34.0, 34.0);

    CGFloat tableHeight = MAX(0.0, CGRectGetMinY(self.inputBar.frame) - 34.0);
    self.tableView.frame = CGRectMake(0.0, 34.0, width, tableHeight);

    CGSize unreadSize = [self.unreadButton sizeThatFits:CGSizeMake(220.0, 32.0)];
    self.unreadButton.frame = CGRectMake((width - MAX(140.0, unreadSize.width)) / 2.0,
                                         CGRectGetMinY(self.inputBar.frame) - 42.0,
                                         MAX(140.0, unreadSize.width), 32.0);
    [self.view bringSubviewToFront:self.unreadButton];
}

#pragma mark - Keyboard

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    if (!self.view.window) {
        return;
    }
    CGRect endFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect localFrame = [self.view.window convertRect:endFrame toView:self.view];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(localFrame);
    if (overlap < 0.0) {
        overlap = 0.0;
    }
    self.keyboardOverlap = overlap;

    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:(UIViewAnimationOptions)(curve << 16)
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (overlap > 0.0) {
            [self scrollToBottomAnimated:NO];
        }
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (self.keyboardOverlap <= 0.0) {
        return;
    }
    self.keyboardOverlap = 0.0;
    NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = (UIViewAnimationCurve)[notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:(UIViewAnimationOptions)(curve << 16)
                     animations:^{
        [self.view layoutIfNeeded];
    } completion:nil];
}

#pragma mark - Session / connection

- (void)connectChat {
    if (self.connection) {
        self.connection.delegate = nil;
        [self.connection disconnect];
    }
    self.lastState = (TVChatConnectionState)-1;
    self.hasConnectedOnce = NO;
    self.connection = [[TVChatConnection alloc] initWithHostView:self.view channel:self.channelLogin];
    self.connection.delegate = self;
    TVSession *session = [TVSession shared];
    [self.connection connectWithToken:session.token login:session.currentUser.login];
    [self updateInputState];
}

- (void)updateInputState {
    BOOL loggedIn = [TVSession shared].isLoggedIn;
    self.textField.enabled = loggedIn;
    self.textField.textColor = loggedIn ? TVColorText() : TVColorMuted();
    self.textField.placeholder = loggedIn ? @"Написать сообщение" : @"Войдите, чтобы писать в чат";
    self.sendButton.hidden = !loggedIn;
}

- (void)sessionChanged:(NSNotification *)notification {
    BOOL loggedIn = [TVSession shared].isLoggedIn;
    BOOL changed = (loggedIn != self.lastLoggedIn);
    self.lastLoggedIn = loggedIn;
    [self updateInputState];
    if (changed) {
        [self connectChat];
    }
}

- (void)inputTapped {
    if (![TVSession shared].isLoggedIn) {
        [self presentLogin];
    } else {
        [self.textField becomeFirstResponder];
    }
}

- (void)presentLogin {
    UIViewController *presenter = self.parentViewController;
    if (!presenter) {
        presenter = self;
    }
    [TVLoginViewController presentFromViewController:presenter];
}

#pragma mark - Actions

- (void)sendTapped {
    if (![TVSession shared].isLoggedIn) {
        [self presentLogin];
        return;
    }
    NSString *text = [self.textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) {
        return;
    }
    if (!self.connection.isConnected) {
        [self appendSystem:@"Нет соединения с чатом. Подождите немного."];
        return;
    }
    [self.connection sendMessage:text];
    self.textField.text = @"";
    TVHapticLight();
    [self scrollToBottomAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendTapped];
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self scrollToBottomAnimated:YES];
}

- (void)unreadTapped {
    [self scrollToBottomAnimated:YES];
}

#pragma mark - Messages

- (BOOL)isNearBottom {
    if (self.tableView.contentSize.height <= CGRectGetHeight(self.tableView.bounds) + 1.0) {
        return YES;
    }
    CGFloat distance = self.tableView.contentSize.height - (self.tableView.contentOffset.y + CGRectGetHeight(self.tableView.bounds));
    return distance < 80.0;
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (self.messages.count == 0) {
        return;
    }
    [self.tableView layoutIfNeeded];
    NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    self.unreadCount = 0;
    self.unreadButton.hidden = YES;
}

- (void)appendMessage:(TVChatMessage *)message {
    BOOL nearBottom = [self isNearBottom] || self.messages.count == 0;
    [self.messages addObject:message];

    if (self.messages.count > 400) {
        [self.messages removeObjectsInRange:NSMakeRange(0, 100)];
        [self.tableView reloadData];
        [self scrollToBottomAnimated:NO];
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    [self.tableView endUpdates];

    if (nearBottom) {
        [self scrollToBottomAnimated:YES];
    } else {
        self.unreadCount += 1;
        [self.unreadButton setTitle:[NSString stringWithFormat:@"Новые сообщения (%ld)", (long)self.unreadCount]
                           forState:UIControlStateNormal];
        self.unreadButton.hidden = NO;
        [self.view bringSubviewToFront:self.unreadButton];
    }
}

- (void)appendSystem:(NSString *)text {
    [self appendMessage:[TVChatMessage systemMessage:text]];
}

- (void)reloadMessage:(TVChatMessage *)message {
    NSUInteger index = [self.messages indexOfObjectIdenticalTo:message];
    if (index == NSNotFound) {
        return;
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)index inSection:0];
    if ([[self.tableView indexPathsForVisibleRows] containsObject:indexPath]) {
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TVChatMessage *message = self.messages[(NSUInteger)indexPath.row];
    if (message.isSystem) {
        TVSystemMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"system" forIndexPath:indexPath];
        [cell configureWithText:message.text];
        return cell;
    }
    TVChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"message" forIndexPath:indexPath];
    [cell configureWithMessage:message currentUser:[TVSession shared].currentUser.login];
    __weak typeof(self) weakSelf = self;
    cell.onNeedsReload = ^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf reloadMessage:message];
    };
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([self isNearBottom] && !self.unreadButton.hidden) {
        self.unreadCount = 0;
        self.unreadButton.hidden = YES;
    }
}

#pragma mark - TVChatConnectionDelegate

- (void)chatConnection:(TVChatConnection *)connection didChangeState:(TVChatConnectionState)state status:(NSString *)status {
    self.statusLabel.text = status;
    [self.statusLabel sizeToFit];
    [self.view setNeedsLayout];

    switch (state) {
        case TVChatConnectionStateConnected:
            self.statusDot.dotColor = TVColorGreen();
            break;
        case TVChatConnectionStateConnecting:
        case TVChatConnectionStateReconnecting:
            self.statusDot.dotColor = [UIColor colorWithRed:1.0 green:0.72 blue:0.2 alpha:1.0];
            break;
        case TVChatConnectionStateDisconnected:
            self.statusDot.dotColor = TVColorRed();
            break;
    }

    if (state == TVChatConnectionStateConnected && !self.hasConnectedOnce) {
        self.hasConnectedOnce = YES;
        [self appendSystem:[TVSession shared].isLoggedIn
            ? [NSString stringWithFormat:@"Вы в чате #%@", self.channelLogin]
            : [NSString stringWithFormat:@"Чат #%@ подключён в режиме чтения", self.channelLogin]];
    } else if (state == TVChatConnectionStateReconnecting && self.lastState != TVChatConnectionStateReconnecting) {
        [self appendSystem:@"Соединение потеряно. Переподключаемся…"];
    } else if (state == TVChatConnectionStateDisconnected && self.lastState != TVChatConnectionStateDisconnected) {
        [self appendSystem:@"Чат отключён."];
    }
    self.lastState = state;
}

- (void)chatConnection:(TVChatConnection *)connection didReceiveMessage:(TVChatMessage *)message {
    [self appendMessage:message];
}

- (void)chatConnection:(TVChatConnection *)connection didReceiveSystemMessage:(NSString *)text {
    [self appendSystem:text];
}

@end
