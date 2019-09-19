#import "SAViewController.h"
#import "SAManager.h"
#import "SpringBoard.h"
#import "Common.h"

#define ANIMATION_DURATION 0.75

extern SAManager *manager;

static void setNoInterruptionMusic(AVPlayer *player) {
    AVAudioSessionMediaPlayerOnly *session = [player playerAVAudioSession];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryAmbient error:&error];
}

@implementation SAViewController {
    AVPlayerLayer *_canvasLayer;
}

#pragma mark Public

- (id)initWithTargetView:(UIView *)targetView {
    if (self == [super init]) {
        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        setNoInterruptionMusic(player);

        self.view.frame = targetView.frame;
        [targetView addSubview:self.view];

        _canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        _canvasLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _canvasLayer.frame = CGRectMake(0, 0, targetView.frame.size.width, targetView.frame.size.height);

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_canvasUpdated:)
                                                     name:kUpdateArtwork
                                                   object:nil];
        
        NSString *url = manager.canvasURL;
        if (url)
            [self _canvasUpdatedWithURLString:url isDirty:YES];

        if (![(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication]) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(_togglePlayPause:)
                                                         name:kTogglePlayPause
                                                       object:nil];
        }
    }
    return self;
}

#pragma mark Private

- (void)_replayMovie:(NSNotification *)notification {
    [_canvasLayer.player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
        if (seeked)
            [_canvasLayer.player play];
    }];
}

- (void)_canvasUpdated:(NSNotification *)notification {
    HBLogDebug(@"_artworkUpdated: %@", notification);
    NSDictionary *userInfo = notification.userInfo;
    if (userInfo) {
        if (userInfo[kCanvasURL])
            [self _canvasUpdatedWithURLString:userInfo[kCanvasURL] isDirty:userInfo[kIsDirty] != nil];
    }
}

- (void)_canvasUpdatedWithURLString:(NSString *)url isDirty:(BOOL)isDirty {
    AVPlayer *player = _canvasLayer.player;
    if (player.currentItem)
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];

    if (url) {
        [self _fadeCanvasLayerIn];
        [self _changeCanvasURL:[NSURL URLWithString:url] isDirty:isDirty];
    } else {
        [self _fadeCanvasLayerOut];
    }
}

- (void)_changeCanvasURL:(NSURL *)url isDirty:(BOOL)isDirty {
    AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithURL:url];

    AVPlayer *player = _canvasLayer.player;
    [player replaceCurrentItemWithPlayerItem:newItem];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_replayMovie:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:player.currentItem];
    if (!isDirty)
        [player play];
}

- (void)_fadeCanvasLayerIn {
    if (_canvasLayer.superlayer)
        return;

    [self.view.layer addSublayer:_canvasLayer];
    [self _showCanvasLayer:YES];
}

- (void)_fadeCanvasLayerOut {
    if (!_canvasLayer.superlayer)
        return;

    [self _showCanvasLayer:NO completion:^() {
        AVPlayer *player = _canvasLayer.player;
        [player pause];
        [_canvasLayer removeFromSuperlayer];
    }];
}

- (void)_showCanvasLayer:(BOOL)show {
    [self _showCanvasLayer:show completion:nil];
}

- (void)_showCanvasLayer:(BOOL)show completion:(void (^)(void))completion {
    [self _performLayerOpacityAnimation:_canvasLayer show:show completion:completion];
}

- (void)_performLayerOpacityAnimation:(CALayer *)layer show:(BOOL)show completion:(void (^)(void))completion {
    float from;
    float to;
    if (show) {
        from = 0.0;
        to = 1.0;
    } else {
        from = 1.0;
        to = 0.0;
    }
    _canvasLayer.opacity = from;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.duration = ANIMATION_DURATION;
    animation.toValue = [NSNumber numberWithFloat:to];
    animation.fromValue = [NSNumber numberWithFloat:from];

    [CATransaction setCompletionBlock:completion];
    [layer addAnimation:animation forKey:@"timeViewFadeIn"];
    layer.opacity = to;
    [CATransaction commit];
}

- (void)_togglePlayPause:(NSNotification *)notification {
    AVPlayer *player = _canvasLayer.player;

    NSNumber *playState = notification.userInfo[kPlayState];
    if (playState) {
        [playState boolValue] ? [player play] : [player pause];
        return;
    }

    if (player.rate == 0 || player.error)
        [player play];
    else
        [player pause];
}

@end
