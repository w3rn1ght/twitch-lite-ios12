#import "TVChatConnection.h"
#import "TVSession.h"
#import <stdlib.h>
#import <math.h>

static NSString *TVChatHTML(void) {
    return @"<!doctype html><html><head><meta charset=\"utf-8\"></head><body>"
           "<script>"
           "var ws=null;"
           "function post(o){try{window.webkit.messageHandlers.tv.postMessage(o);}catch(e){}}"
           "function connect(){"
           "try{ws=new WebSocket('wss://irc-ws.chat.twitch.tv:443');}catch(e){post({event:'error',message:String(e)});return;}"
           "ws.onopen=function(){post({event:'open'});};"
           "ws.onmessage=function(e){post({event:'message',data:String(e.data)});};"
           "ws.onerror=function(){post({event:'error',message:'WebSocket error'});};"
           "ws.onclose=function(e){post({event:'close',code:e.code,reason:String(e.reason||'')});};"
           "}"
           "function b64text(b64){var bin=atob(b64);var bytes=new Uint8Array(bin.length);for(var i=0;i<bin.length;i++){bytes[i]=bin.charCodeAt(i);}try{return new TextDecoder('utf-8').decode(bytes);}catch(e){return bin;}}"
           "function tvSend(b64){try{if(ws&&ws.readyState===1){ws.send(b64text(b64));}}catch(e){post({event:'error',message:String(e)});}}"
           "window.onload=connect;"
           "</script></body></html>";
}

static NSString *TVUnescapeTagValue(NSString *value) {
    if (value.length == 0) {
        return @"";
    }
    NSMutableString *result = [NSMutableString stringWithCapacity:value.length];
    for (NSUInteger i = 0; i < value.length; i++) {
        unichar c = [value characterAtIndex:i];
        if (c == '\\' && i + 1 < value.length) {
            unichar next = [value characterAtIndex:i + 1];
            if (next == 's') {
                [result appendString:@" "];
            } else if (next == ':') {
                [result appendString:@";"];
            } else if (next == '\\') {
                [result appendString:@"\\"];
            } else if (next == 'r') {
                [result appendString:@"\r"];
            } else if (next == 'n') {
                [result appendString:@"\n"];
            } else {
                [result appendFormat:@"%C", next];
            }
            i += 1;
        } else {
            [result appendFormat:@"%C", c];
        }
    }
    return result;
}

static NSDictionary<NSString *, NSString *> *TVParseTags(NSString *tagString) {
    NSMutableDictionary<NSString *, NSString *> *tags = [NSMutableDictionary dictionary];
    for (NSString *part in [tagString componentsSeparatedByString:@";"]) {
        NSRange equals = [part rangeOfString:@"="];
        if (equals.location == NSNotFound) {
            if (part.length) {
                tags[part] = @"1";
            }
        } else {
            NSString *key = [part substringToIndex:equals.location];
            NSString *value = [part substringFromIndex:equals.location + 1];
            if (key.length) {
                tags[key] = TVUnescapeTagValue(value);
            }
        }
    }
    return tags;
}

@interface TVWeakScriptMessageHandler : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> target;
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target;
@end

@implementation TVWeakScriptMessageHandler

- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target {
    self = [super init];
    if (self) {
        _target = target;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.target userContentController:userContentController didReceiveScriptMessage:message];
}

@end

@interface TVChatConnection () <WKScriptMessageHandler>
@property (nonatomic, weak) UIView *hostView;
@property (nonatomic, copy) NSString *channel;
@property (nonatomic, copy, nullable) NSString *token;
@property (nonatomic, copy, nullable) NSString *login;
@property (nonatomic, strong, nullable) WKWebView *webView;
@property (nonatomic, strong, nullable) TVWeakScriptMessageHandler *handlerProxy;
@property (nonatomic, strong) NSMutableString *lineBuffer;
@property (nonatomic, assign, readwrite) TVChatConnectionState state;
@property (nonatomic, assign) BOOL shouldReconnect;
@property (nonatomic, assign) BOOL useAnonymous;
@property (nonatomic, assign) NSInteger reconnectAttempts;
@end

@implementation TVChatConnection

- (instancetype)initWithHostView:(UIView *)hostView channel:(NSString *)channel {
    self = [super init];
    if (self) {
        _hostView = hostView;
        _channel = [channel copy];
        _lineBuffer = [NSMutableString string];
        _state = TVChatConnectionStateDisconnected;
        _shouldReconnect = NO;
        _useAnonymous = NO;
        _reconnectAttempts = 0;
    }
    return self;
}

- (void)dealloc {
    _shouldReconnect = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self cleanupWebView];
}

- (BOOL)isConnected {
    return self.state == TVChatConnectionStateConnected;
}

- (void)connectWithToken:(NSString *)token login:(NSString *)login {
    self.token = token.length ? token : nil;
    self.login = login.length ? login : nil;
    self.useAnonymous = (self.token == nil || self.login == nil);
    self.shouldReconnect = YES;
    self.reconnectAttempts = 0;
    [self startConnection];
}

- (void)disconnect {
    self.shouldReconnect = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self cleanupWebView];
    self.state = TVChatConnectionStateDisconnected;
    [self notifyState:TVChatConnectionStateDisconnected status:@"Чат отключён"];
}

- (void)sendMessage:(NSString *)message {
    if (!self.isConnected) {
        return;
    }
    NSString *clean = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    clean = [clean stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    clean = [clean stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    if (clean.length == 0) {
        return;
    }
    if (clean.length > 500) {
        clean = [clean substringToIndex:500];
    }
    [self sendRaw:[NSString stringWithFormat:@"PRIVMSG #%@ :%@", self.channel, clean]];
}

#pragma mark - WebSocket bridge

- (void)startConnection {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reconnectNow) object:nil];
    [self cleanupWebView];

    if (!self.hostView || self.channel.length == 0) {
        return;
    }

    self.state = TVChatConnectionStateConnecting;
    [self notifyState:self.state status:@"Подключение к чату…"];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    self.handlerProxy = [[TVWeakScriptMessageHandler alloc] initWithTarget:self];
    [controller addScriptMessageHandler:self.handlerProxy name:@"tv"];
    configuration.userContentController = controller;
    if (@available(iOS 10.0, *)) {
        configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }

    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1.0, 1.0) configuration:configuration];
    webView.opaque = NO;
    webView.backgroundColor = [UIColor clearColor];
    webView.scrollView.scrollEnabled = NO;
    webView.alpha = 0.01;
    webView.userInteractionEnabled = NO;
    self.webView = webView;
    [self.hostView addSubview:webView];
    [webView loadHTMLString:TVChatHTML() baseURL:[NSURL URLWithString:@"https://www.twitch.tv/"]];
}

- (void)cleanupWebView {
    if (self.webView) {
        [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"tv"];
        [self.webView stopLoading];
        [self.webView removeFromSuperview];
        self.webView = nil;
    }
    self.handlerProxy = nil;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"tv"] || ![message.body isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSDictionary *body = (NSDictionary *)message.body;
    NSString *event = body[@"event"];
    if ([event isEqualToString:@"open"]) {
        [self handleSocketOpen];
    } else if ([event isEqualToString:@"message"]) {
        NSString *data = body[@"data"];
        if ([data isKindOfClass:[NSString class]]) {
            [self consumeData:data];
        }
    } else if ([event isEqualToString:@"close"]) {
        [self handleSocketClose];
    } else if ([event isEqualToString:@"error"]) {
        NSLog(@"[TwitchLite] chat websocket error: %@", body[@"message"]);
    }
}

- (void)handleSocketOpen {
    if (self.useAnonymous || self.token.length == 0) {
        NSString *nick = [NSString stringWithFormat:@"justinfan%05d", (int)(10000 + arc4random_uniform(90000))];
        [self sendRaw:@"CAP REQ :twitch.tv/tags twitch.tv/commands"];
        [self sendRaw:[NSString stringWithFormat:@"NICK %@", nick]];
        [self sendRaw:@"CAP END"];
        [self sendRaw:[NSString stringWithFormat:@"JOIN #%@", self.channel]];
    } else {
        [self sendRaw:@"CAP REQ :twitch.tv/tags twitch.tv/commands"];
        [self sendRaw:[NSString stringWithFormat:@"PASS oauth:%@", self.token]];
        [self sendRaw:[NSString stringWithFormat:@"NICK %@", self.login]];
        [self sendRaw:@"CAP END"];
        [self sendRaw:[NSString stringWithFormat:@"JOIN #%@", self.channel]];
    }
    self.state = TVChatConnectionStateConnected;
    self.reconnectAttempts = 0;
    [self notifyState:self.state status:@"Чат подключён"];
}

- (void)handleSocketClose {
    if (!self.shouldReconnect) {
        self.state = TVChatConnectionStateDisconnected;
        [self notifyState:self.state status:@"Чат отключён"];
        return;
    }
    self.state = TVChatConnectionStateReconnecting;
    [self notifyState:self.state status:@"Соединение потеряно, переподключаемся…"];
    self.reconnectAttempts += 1;
    NSTimeInterval delay = MIN(30.0, pow(2.0, (double)self.reconnectAttempts));
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reconnectNow) object:nil];
    [self performSelector:@selector(reconnectNow) withObject:nil afterDelay:delay];
}

- (void)reconnectNow {
    if (!self.shouldReconnect) {
        return;
    }
    [self startConnection];
}

- (void)sendRaw:(NSString *)line {
    if (self.webView == nil || line.length == 0) {
        return;
    }
    NSString *payload = [line stringByAppendingString:@"\r\n"];
    NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    NSString *js = [NSString stringWithFormat:@"tvSend('%@')", base64];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

#pragma mark - IRC parsing

- (void)consumeData:(NSString *)data {
    [self.lineBuffer appendString:data];
    while (YES) {
        NSRange range = [self.lineBuffer rangeOfString:@"\r\n"];
        if (range.location == NSNotFound) {
            break;
        }
        NSString *line = [self.lineBuffer substringToIndex:range.location];
        [self.lineBuffer deleteCharactersInRange:NSMakeRange(0, NSMaxRange(range))];
        if (line.length) {
            [self processLine:line];
        }
    }
}

- (void)processLine:(NSString *)line {
    if ([line hasPrefix:@"PING"]) {
        [self sendRaw:@"PONG :tmi.twitch.tv"];
        return;
    }
    if ([line isEqualToString:@"RECONNECT"] || [line hasSuffix:@" RECONNECT"]) {
        // Twitch asks clients to reconnect. Rebuild the bridge shortly so we
        // are not tearing down the WKWebView from inside its own callback.
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reconnectNow) object:nil];
        [self performSelector:@selector(reconnectNow) withObject:nil afterDelay:0.5];
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *tags = [NSMutableDictionary dictionary];
    NSString *rest = line;
    if ([rest hasPrefix:@"@"]) {
        NSRange space = [rest rangeOfString:@" "];
        if (space.location != NSNotFound) {
            NSString *tagString = [rest substringWithRange:NSMakeRange(1, space.location - 1)];
            [tags addEntriesFromDictionary:TVParseTags(tagString)];
            rest = [rest substringFromIndex:space.location + 1];
        }
    }

    NSString *prefix = nil;
    if ([rest hasPrefix:@":"]) {
        NSRange space = [rest rangeOfString:@" "];
        if (space.location != NSNotFound) {
            prefix = [rest substringToIndex:space.location];
            rest = [rest substringFromIndex:space.location + 1];
        }
    }

    NSString *command = rest;
    NSArray<NSString *> *params = @[];
    NSRange space = [rest rangeOfString:@" "];
    if (space.location != NSNotFound) {
        command = [rest substringToIndex:space.location];
        NSString *tail = [rest substringFromIndex:space.location + 1];
        NSRange colon = [tail rangeOfString:@" :"];
        if (colon.location != NSNotFound) {
            NSString *before = [tail substringToIndex:colon.location];
            NSString *after = [tail substringFromIndex:colon.location + 2];
            NSMutableArray *parts = [NSMutableArray array];
            if (before.length) {
                [parts addObjectsFromArray:[before componentsSeparatedByString:@" "]];
            }
            [parts addObject:after];
            params = parts;
        } else {
            params = [tail componentsSeparatedByString:@" "];
        }
    }

    if ([command isEqualToString:@"PRIVMSG"]) {
        NSString *channel = params.firstObject ?: @"";
        NSString *currentUser = [TVSession shared].currentUser.login;
        TVChatMessage *message = [TVChatMessage messageWithTags:tags
                                                         prefix:prefix
                                                        command:command
                                                         params:params
                                                        channel:channel
                                                    currentUser:currentUser];
        if ([self.delegate respondsToSelector:@selector(chatConnection:didReceiveMessage:)]) {
            [self.delegate chatConnection:self didReceiveMessage:message];
        }
        return;
    }

    if ([command isEqualToString:@"NOTICE"]) {
        NSString *text = params.lastObject ?: @"";
        if ([text containsString:@"Login authentication failed"] ||
            [text containsString:@"Improperly formatted auth"] ||
            [text containsString:@"Login authentication"]) {
            if (!self.useAnonymous) {
                self.useAnonymous = YES;
                [self notifySystem:@"Токен чата не принят. Чат переключён в режим чтения."];
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reconnectNow) object:nil];
                [self performSelector:@selector(reconnectNow) withObject:nil afterDelay:0.5];
            }
        } else if (text.length) {
            [self notifySystem:text];
        }
        return;
    }

    if ([command isEqualToString:@"CLEARCHAT"]) {
        [self notifySystem:@"Модератор очистил чат."];
    } else if ([command isEqualToString:@"CLEARMSG"]) {
        // Individual message deletion is intentionally ignored.
    }
}

- (void)notifySystem:(NSString *)text {
    if ([self.delegate respondsToSelector:@selector(chatConnection:didReceiveSystemMessage:)]) {
        [self.delegate chatConnection:self didReceiveSystemMessage:text];
    }
}

- (void)notifyState:(TVChatConnectionState)state status:(NSString *)status {
    if ([self.delegate respondsToSelector:@selector(chatConnection:didChangeState:status:)]) {
        [self.delegate chatConnection:self didChangeState:state status:status];
    }
}

@end
