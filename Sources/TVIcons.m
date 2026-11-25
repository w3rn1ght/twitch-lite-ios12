#import "TVIcons.h"

static UIBezierPath *TVStarPath(CGFloat cx, CGFloat cy, CGFloat outer, CGFloat inner) {
    UIBezierPath *path = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < 10; i++) {
        CGFloat angle = -M_PI_2 + (CGFloat)i * M_PI / 5.0;
        CGFloat radius = (i % 2 == 0) ? outer : inner;
        CGPoint point = CGPointMake(cx + cos(angle) * radius, cy + sin(angle) * radius);
        if (i == 0) {
            [path moveToPoint:point];
        } else {
            [path addLineToPoint:point];
        }
    }
    [path closePath];
    return path;
}

static UIBezierPath *TVHeartPath(void) {
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(12.0, 20.4)];
    [path addCurveToPoint:CGPointMake(3.2, 10.3)
            controlPoint1:CGPointMake(9.5, 18.1)
            controlPoint2:CGPointMake(3.2, 15.1)];
    [path addCurveToPoint:CGPointMake(8.2, 4.2)
            controlPoint1:CGPointMake(3.2, 5.7)
            controlPoint2:CGPointMake(5.7, 4.2)];
    [path addCurveToPoint:CGPointMake(12.0, 6.5)
            controlPoint1:CGPointMake(9.8, 4.2)
            controlPoint2:CGPointMake(11.1, 5.1)];
    [path addCurveToPoint:CGPointMake(15.8, 4.2)
            controlPoint1:CGPointMake(12.9, 5.1)
            controlPoint2:CGPointMake(14.2, 4.2)];
    [path addCurveToPoint:CGPointMake(20.8, 10.3)
            controlPoint1:CGPointMake(18.3, 4.2)
            controlPoint2:CGPointMake(20.8, 5.7)];
    [path addCurveToPoint:CGPointMake(12.0, 20.4)
            controlPoint1:CGPointMake(20.8, 15.1)
            controlPoint2:CGPointMake(14.5, 18.1)];
    [path closePath];
    return path;
}

@implementation TVIcons

+ (UIImage *)icon:(TVIconName)name size:(CGFloat)size color:(UIColor *)color {
    return [self icon:name size:size color:color weight:1.85];
}

+ (UIImage *)icon:(TVIconName)name size:(CGFloat)size color:(UIColor *)color weight:(CGFloat)weight {
    if (size <= 0.0) {
        size = 24.0;
    }
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat scale = size / 24.0;
    CGContextScaleCTM(context, scale, scale);
    CGContextSetShouldAntialias(context, true);
    [color setStroke];
    [color setFill];

    UIBezierPath *path = nil;
    switch (name) {
        case TVIconHeart:
        case TVIconHeartFilled: {
            path = TVHeartPath();
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            if (name == TVIconHeartFilled) {
                [path fill];
            } else {
                [path stroke];
            }
            break;
        }
        case TVIconSearch: {
            path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(10.5, 10.5)
                                                  radius:6.3
                                              startAngle:0.0
                                                endAngle:M_PI * 2.0
                                               clockwise:YES];
            path.lineWidth = weight;
            [path stroke];
            UIBezierPath *handle = [UIBezierPath bezierPath];
            [handle moveToPoint:CGPointMake(15.2, 15.2)];
            [handle addLineToPoint:CGPointMake(21.0, 21.0)];
            handle.lineWidth = weight;
            handle.lineCapStyle = kCGLineCapRound;
            [handle stroke];
            break;
        }
        case TVIconStar:
        case TVIconStarFilled: {
            path = TVStarPath(12.0, 12.4, 9.0, 4.1);
            path.lineWidth = weight;
            path.lineJoinStyle = kCGLineJoinRound;
            if (name == TVIconStarFilled) {
                [path fill];
            } else {
                [path stroke];
            }
            break;
        }
        case TVIconPerson: {
            UIBezierPath *head = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.0, 3.5, 8.0, 8.0)];
            head.lineWidth = weight;
            [head stroke];
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(4.2, 21.0)];
            [path addCurveToPoint:CGPointMake(19.8, 21.0)
                    controlPoint1:CGPointMake(4.2, 15.4)
                    controlPoint2:CGPointMake(19.8, 15.4)];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            break;
        }
        case TVIconBack: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(15.0, 4.5)];
            [path addLineToPoint:CGPointMake(8.0, 12.0)];
            [path addLineToPoint:CGPointMake(15.0, 19.5)];
            path.lineWidth = weight + 0.2;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconSend: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(3.2, 11.4)];
            [path addLineToPoint:CGPointMake(21.0, 3.4)];
            [path addLineToPoint:CGPointMake(14.1, 20.8)];
            [path addLineToPoint:CGPointMake(11.0, 13.3)];
            [path closePath];
            path.lineWidth = weight;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            UIBezierPath *line = [UIBezierPath bezierPath];
            [line moveToPoint:CGPointMake(11.0, 13.3)];
            [line addLineToPoint:CGPointMake(21.0, 3.4)];
            line.lineWidth = weight;
            line.lineCapStyle = kCGLineCapRound;
            [line stroke];
            break;
        }
        case TVIconEye: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(2.0, 12.0)];
            [path addCurveToPoint:CGPointMake(22.0, 12.0)
                    controlPoint1:CGPointMake(6.0, 5.0)
                    controlPoint2:CGPointMake(18.0, 5.0)];
            [path addCurveToPoint:CGPointMake(2.0, 12.0)
                    controlPoint1:CGPointMake(18.0, 19.0)
                    controlPoint2:CGPointMake(6.0, 19.0)];
            path.lineWidth = weight;
            [path stroke];
            UIBezierPath *pupil = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.2, 9.2, 5.6, 5.6)];
            [pupil fill];
            break;
        }
        case TVIconPlay: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(7.5, 4.5)];
            [path addLineToPoint:CGPointMake(20.0, 12.0)];
            [path addLineToPoint:CGPointMake(7.5, 19.5)];
            [path closePath];
            [path fill];
            break;
        }
        case TVIconPause: {
            UIBezierPath *left = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7.0, 5.0, 3.6, 14.0) cornerRadius:1.2];
            UIBezierPath *right = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(13.4, 5.0, 3.6, 14.0) cornerRadius:1.2];
            [left fill];
            [right fill];
            break;
        }
        case TVIconChat: {
            path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.5, 4.5, 17.0, 12.5) cornerRadius:2.5];
            [path moveToPoint:CGPointMake(9.0, 17.0)];
            [path addLineToPoint:CGPointMake(9.0, 21.0)];
            [path addLineToPoint:CGPointMake(13.8, 17.0)];
            path.lineWidth = weight;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconClose: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(5.0, 5.0)];
            [path addLineToPoint:CGPointMake(19.0, 19.0)];
            [path moveToPoint:CGPointMake(19.0, 5.0)];
            [path addLineToPoint:CGPointMake(5.0, 19.0)];
            path.lineWidth = weight + 0.1;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            break;
        }
        case TVIconShare: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(8.0, 10.0)];
            [path addLineToPoint:CGPointMake(5.0, 10.0)];
            [path addLineToPoint:CGPointMake(5.0, 20.0)];
            [path addLineToPoint:CGPointMake(19.0, 20.0)];
            [path addLineToPoint:CGPointMake(19.0, 10.0)];
            [path addLineToPoint:CGPointMake(16.0, 10.0)];
            path.lineWidth = weight;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            UIBezierPath *arrow = [UIBezierPath bezierPath];
            [arrow moveToPoint:CGPointMake(12.0, 3.0)];
            [arrow addLineToPoint:CGPointMake(12.0, 14.0)];
            [arrow moveToPoint:CGPointMake(8.0, 7.0)];
            [arrow addLineToPoint:CGPointMake(12.0, 3.0)];
            [arrow addLineToPoint:CGPointMake(16.0, 7.0)];
            arrow.lineWidth = weight;
            arrow.lineCapStyle = kCGLineCapRound;
            arrow.lineJoinStyle = kCGLineJoinRound;
            [arrow stroke];
            break;
        }
        case TVIconSettings: {
            for (NSInteger i = 0; i < 3; i++) {
                CGFloat y = 6.0 + i * 6.0;
                CGFloat knobX = (i == 0) ? 9.0 : ((i == 1) ? 15.0 : 7.0);
                UIBezierPath *line = [UIBezierPath bezierPath];
                [line moveToPoint:CGPointMake(3.5, y)];
                [line addLineToPoint:CGPointMake(20.5, y)];
                line.lineWidth = weight;
                line.lineCapStyle = kCGLineCapRound;
                [line stroke];
                UIBezierPath *knob = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(knobX - 2.2, y - 2.2, 4.4, 4.4)];
                [knob fill];
            }
            break;
        }
        case TVIconChevronRight: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(9.0, 5.0)];
            [path addLineToPoint:CGPointMake(16.0, 12.0)];
            [path addLineToPoint:CGPointMake(9.0, 19.0)];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconChevronDown: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(5.0, 9.0)];
            [path addLineToPoint:CGPointMake(12.0, 16.0)];
            [path addLineToPoint:CGPointMake(19.0, 9.0)];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconRefresh: {
            path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 12.0)
                                                  radius:7.5
                                              startAngle:-M_PI_4
                                                endAngle:M_PI * 1.45
                                               clockwise:YES];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            UIBezierPath *head = [UIBezierPath bezierPath];
            [head moveToPoint:CGPointMake(15.0, 2.6)];
            [head addLineToPoint:CGPointMake(19.8, 4.4)];
            [head addLineToPoint:CGPointMake(17.8, 9.0)];
            head.lineWidth = weight;
            head.lineCapStyle = kCGLineCapRound;
            head.lineJoinStyle = kCGLineJoinRound;
            [head stroke];
            break;
        }
        case TVIconMore: {
            for (NSInteger i = 0; i < 3; i++) {
                UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(4.0 + i * 6.5, 10.5, 3.0, 3.0)];
                [dot fill];
            }
            break;
        }
        case TVIconExternal: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(14.0, 4.0)];
            [path addLineToPoint:CGPointMake(20.0, 4.0)];
            [path addLineToPoint:CGPointMake(20.0, 10.0)];
            [path moveToPoint:CGPointMake(20.0, 4.0)];
            [path addLineToPoint:CGPointMake(11.0, 13.0)];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            UIBezierPath *box = [UIBezierPath bezierPath];
            [box moveToPoint:CGPointMake(18.0, 14.0)];
            [box addLineToPoint:CGPointMake(18.0, 20.0)];
            [box addLineToPoint:CGPointMake(4.0, 20.0)];
            [box addLineToPoint:CGPointMake(4.0, 6.0)];
            [box addLineToPoint:CGPointMake(10.0, 6.0)];
            box.lineWidth = weight;
            box.lineCapStyle = kCGLineCapRound;
            box.lineJoinStyle = kCGLineJoinRound;
            [box stroke];
            break;
        }
        case TVIconGrid: {
            NSArray *rects = @[
                [NSValue valueWithCGRect:CGRectMake(3.5, 3.5, 7.0, 7.0)],
                [NSValue valueWithCGRect:CGRectMake(13.5, 3.5, 7.0, 7.0)],
                [NSValue valueWithCGRect:CGRectMake(3.5, 13.5, 7.0, 7.0)],
                [NSValue valueWithCGRect:CGRectMake(13.5, 13.5, 7.0, 7.0)],
            ];
            for (NSValue *value in rects) {
                UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:value.CGRectValue cornerRadius:1.6];
                box.lineWidth = weight;
                [box stroke];
            }
            break;
        }
        case TVIconUsers: {
            UIBezierPath *head1 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(4.0, 4.5, 6.5, 6.5)];
            head1.lineWidth = weight;
            [head1 stroke];
            UIBezierPath *head2 = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(13.5, 5.5, 5.5, 5.5)];
            head2.lineWidth = weight;
            [head2 stroke];
            UIBezierPath *body1 = [UIBezierPath bezierPath];
            [body1 moveToPoint:CGPointMake(2.0, 20.0)];
            [body1 addCurveToPoint:CGPointMake(12.5, 20.0)
                     controlPoint1:CGPointMake(2.0, 14.5)
                     controlPoint2:CGPointMake(12.5, 14.5)];
            body1.lineWidth = weight;
            body1.lineCapStyle = kCGLineCapRound;
            [body1 stroke];
            UIBezierPath *body2 = [UIBezierPath bezierPath];
            [body2 moveToPoint:CGPointMake(14.5, 19.0)];
            [body2 addCurveToPoint:CGPointMake(22.0, 19.0)
                     controlPoint1:CGPointMake(14.5, 15.0)
                     controlPoint2:CGPointMake(22.0, 15.0)];
            body2.lineWidth = weight;
            body2.lineCapStyle = kCGLineCapRound;
            [body2 stroke];
            break;
        }
        case TVIconLock: {
            path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.0, 10.5, 14.0, 10.0) cornerRadius:2.0];
            path.lineWidth = weight;
            [path stroke];
            UIBezierPath *shackle = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 10.0)
                                                                   radius:4.0
                                                               startAngle:M_PI
                                                                 endAngle:0.0
                                                                clockwise:YES];
            shackle.lineWidth = weight;
            [shackle stroke];
            UIBezierPath *keyhole = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.8, 14.0, 2.4, 2.4)];
            [keyhole fill];
            break;
        }
        case TVIconCheck: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(4.5, 12.5)];
            [path addLineToPoint:CGPointMake(9.5, 17.5)];
            [path addLineToPoint:CGPointMake(19.5, 6.5)];
            path.lineWidth = weight + 0.3;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconFullscreen: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(4.0, 9.0)];
            [path addLineToPoint:CGPointMake(4.0, 4.0)];
            [path addLineToPoint:CGPointMake(9.0, 4.0)];
            [path moveToPoint:CGPointMake(15.0, 4.0)];
            [path addLineToPoint:CGPointMake(20.0, 4.0)];
            [path addLineToPoint:CGPointMake(20.0, 9.0)];
            [path moveToPoint:CGPointMake(20.0, 15.0)];
            [path addLineToPoint:CGPointMake(20.0, 20.0)];
            [path addLineToPoint:CGPointMake(15.0, 20.0)];
            [path moveToPoint:CGPointMake(9.0, 20.0)];
            [path addLineToPoint:CGPointMake(4.0, 20.0)];
            [path addLineToPoint:CGPointMake(4.0, 15.0)];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconVolume:
        case TVIconVolumeMuted: {
            UIBezierPath *speaker = [UIBezierPath bezierPath];
            [speaker moveToPoint:CGPointMake(3.5, 9.0)];
            [speaker addLineToPoint:CGPointMake(7.0, 9.0)];
            [speaker addLineToPoint:CGPointMake(12.0, 4.5)];
            [speaker addLineToPoint:CGPointMake(12.0, 19.5)];
            [speaker addLineToPoint:CGPointMake(7.0, 15.0)];
            [speaker addLineToPoint:CGPointMake(3.5, 15.0)];
            [speaker closePath];
            speaker.lineWidth = weight;
            speaker.lineJoinStyle = kCGLineJoinRound;
            [speaker stroke];
            if (name == TVIconVolume) {
                UIBezierPath *wave1 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.5, 12.0)
                                                                    radius:4.2
                                                                startAngle:-M_PI_4
                                                                  endAngle:M_PI_4
                                                                 clockwise:YES];
                wave1.lineWidth = weight;
                [wave1 stroke];
                UIBezierPath *wave2 = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.5, 12.0)
                                                                    radius:7.4
                                                                startAngle:-M_PI_4
                                                                  endAngle:M_PI_4
                                                                 clockwise:YES];
                wave2.lineWidth = weight;
                [wave2 stroke];
            } else {
                UIBezierPath *x = [UIBezierPath bezierPath];
                [x moveToPoint:CGPointMake(15.0, 9.0)];
                [x addLineToPoint:CGPointMake(20.5, 15.0)];
                [x moveToPoint:CGPointMake(20.5, 9.0)];
                [x addLineToPoint:CGPointMake(15.0, 15.0)];
                x.lineWidth = weight;
                x.lineCapStyle = kCGLineCapRound;
                [x stroke];
            }
            break;
        }
        case TVIconHome: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(3.5, 11.0)];
            [path addLineToPoint:CGPointMake(12.0, 3.5)];
            [path addLineToPoint:CGPointMake(20.5, 11.0)];
            [path moveToPoint:CGPointMake(5.5, 9.5)];
            [path addLineToPoint:CGPointMake(5.5, 20.0)];
            [path addLineToPoint:CGPointMake(18.5, 20.0)];
            [path addLineToPoint:CGPointMake(18.5, 9.5)];
            path.lineWidth = weight;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            break;
        }
        case TVIconPlus: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(12.0, 4.0)];
            [path addLineToPoint:CGPointMake(12.0, 20.0)];
            [path moveToPoint:CGPointMake(4.0, 12.0)];
            [path addLineToPoint:CGPointMake(20.0, 12.0)];
            path.lineWidth = weight + 0.2;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            break;
        }
        case TVIconTV: {
            path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.5, 4.5, 19.0, 14.0) cornerRadius:2.0];
            path.lineWidth = weight;
            [path stroke];
            UIBezierPath *play = [UIBezierPath bezierPath];
            [play moveToPoint:CGPointMake(10.0, 8.5)];
            [play addLineToPoint:CGPointMake(15.0, 11.5)];
            [play addLineToPoint:CGPointMake(10.0, 14.5)];
            [play closePath];
            [play fill];
            UIBezierPath *stand = [UIBezierPath bezierPath];
            [stand moveToPoint:CGPointMake(8.0, 21.0)];
            [stand addLineToPoint:CGPointMake(16.0, 21.0)];
            stand.lineWidth = weight;
            stand.lineCapStyle = kCGLineCapRound;
            [stand stroke];
            break;
        }
        case TVIconCompass: {
            path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 12.0) radius:9.0 startAngle:0.0 endAngle:M_PI * 2.0 clockwise:YES];
            path.lineWidth = weight;
            [path stroke];
            UIBezierPath *needle = [UIBezierPath bezierPath];
            [needle moveToPoint:CGPointMake(15.5, 8.5)];
            [needle addLineToPoint:CGPointMake(13.5, 13.5)];
            [needle addLineToPoint:CGPointMake(8.5, 15.5)];
            [needle addLineToPoint:CGPointMake(10.5, 10.5)];
            [needle closePath];
            [needle fill];
            break;
        }
        case TVIconBell: {
            path = [UIBezierPath bezierPath];
            [path moveToPoint:CGPointMake(5.5, 17.0)];
            [path addLineToPoint:CGPointMake(6.5, 15.5)];
            [path addLineToPoint:CGPointMake(6.5, 10.0)];
            [path addCurveToPoint:CGPointMake(17.5, 10.0)
                    controlPoint1:CGPointMake(6.5, 4.5)
                    controlPoint2:CGPointMake(17.5, 4.5)];
            [path addLineToPoint:CGPointMake(17.5, 15.5)];
            [path addLineToPoint:CGPointMake(18.5, 17.0)];
            [path closePath];
            path.lineWidth = weight;
            path.lineJoinStyle = kCGLineJoinRound;
            [path stroke];
            UIBezierPath *clapper = [UIBezierPath bezierPathWithArcCenter:CGPointMake(12.0, 17.5) radius:2.5 startAngle:0.0 endAngle:M_PI clockwise:YES];
            clapper.lineWidth = weight;
            [clapper stroke];
            break;
        }
        case TVIconCopy: {
            UIBezierPath *back = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(8.0, 3.5, 12.0, 12.0) cornerRadius:2.0];
            back.lineWidth = weight;
            [back stroke];
            UIBezierPath *front = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4.0, 8.0, 12.0, 12.0) cornerRadius:2.0];
            front.lineWidth = weight;
            [front stroke];
            break;
        }
        case TVIconLink: {
            UIBezierPath *left = [UIBezierPath bezierPath];
            [left moveToPoint:CGPointMake(9.5, 8.0)];
            [left addLineToPoint:CGPointMake(7.0, 8.0)];
            [left addCurveToPoint:CGPointMake(7.0, 16.0)
                  controlPoint1:CGPointMake(3.0, 8.0)
                  controlPoint2:CGPointMake(3.0, 16.0)];
            [left addLineToPoint:CGPointMake(9.5, 16.0)];
            left.lineWidth = weight;
            left.lineCapStyle = kCGLineCapRound;
            [left stroke];
            UIBezierPath *right = [UIBezierPath bezierPath];
            [right moveToPoint:CGPointMake(14.5, 8.0)];
            [right addLineToPoint:CGPointMake(17.0, 8.0)];
            [right addCurveToPoint:CGPointMake(17.0, 16.0)
                   controlPoint1:CGPointMake(21.0, 8.0)
                   controlPoint2:CGPointMake(21.0, 16.0)];
            [right addLineToPoint:CGPointMake(14.5, 16.0)];
            right.lineWidth = weight;
            right.lineCapStyle = kCGLineCapRound;
            [right stroke];
            UIBezierPath *middle = [UIBezierPath bezierPath];
            [middle moveToPoint:CGPointMake(8.5, 12.0)];
            [middle addLineToPoint:CGPointMake(15.5, 12.0)];
            middle.lineWidth = weight;
            middle.lineCapStyle = kCGLineCapRound;
            [middle stroke];
            break;
        }
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end
