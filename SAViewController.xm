#import "SAViewController.h"
#import "SACanvasReceiver.h"
#import "SpringBoard.h"
#import "Common.h"

#define ANIMATION_DURATION 0.75

extern SACanvasReceiver *receiver;

static void setNoInterruptionMusic(AVPlayer *player) {
    AVAudioSessionMediaPlayerOnly *session = [player playerAVAudioSession];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryAmbient error:&error];
}

@implementation SAViewController {
    BOOL _homescreen;
}

#pragma mark Public

- (id)initWithTargetView:(UIView *)targetView homescreen:(BOOL)homescreen {
    if (self == [super init]) {
        _homescreen = homescreen;

        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        setNoInterruptionMusic(player);

        self.view.frame = targetView.frame;
        [targetView addSubview:self.view];

        _canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        _canvasLayer.frame = CGRectMake(0, 0, targetView.frame.size.width, targetView.frame.size.height);

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_canvasUpdated:)
                                                     name:kUpdateCanvas
                                                   object:nil];
        
        NSString *url = receiver.canvasURL;
        if (url)
            [self _canvasUpdatedWithURLString:url];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_togglePlayPause:)
                                                     name:kTogglePlayPause
                                                   object:nil];
    }
    return self;
}

#pragma mark Private

- (void)_hideDock:(BOOL)hide {
    // Only the homescreen controller is allowed to change the dock,
    // otherwise the two will do it simultaneously which obviously causes issues
    if (!_homescreen)
        return;

    SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
    SBDockView *dockView = [rootFolderController.contentView dockView];
    UIView *background = MSHookIvar<UIView *>(dockView, "_backgroundView");

    if (!hide)
        background.hidden = NO;

    [self _performLayerOpacityAnimation:background.layer show:!hide completion:^() {
        if (hide)
            background.hidden = YES;
    }];
}

- (void)_replayMovie:(NSNotification *)notification {
    [_canvasLayer.player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
        if (seeked)
            [_canvasLayer.player play];
    }];
}

- (void)_canvasUpdated:(NSNotification *)notification {
    [self _canvasUpdatedWithURLString:notification.userInfo[kCanvasURL]];
}

- (void)_canvasUpdatedWithURLString:(NSString *)url {
    AVPlayer *player = _canvasLayer.player;
    if (player.currentItem)
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];

    if (url) {
        [self _fadeCanvasLayerIn];
        [self _changeCanvasURL:[NSURL URLWithString:url]];
    } else {
        [self _fadeCanvasLayerOut];
    }
}

- (void)_changeCanvasURL:(NSURL *)url {
    AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithURL:url];

    AVPlayer *player = _canvasLayer.player;
    [player replaceCurrentItemWithPlayerItem:newItem];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_replayMovie:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:player.currentItem];
    [player play];
}

- (void)_fadeCanvasLayerIn {
    if (_canvasLayer.superlayer)
        return;

    [self.view.layer addSublayer:_canvasLayer];

    [self _hideDock:YES];
    [self _showCanvasLayer:YES];
}

- (void)_fadeCanvasLayerOut {
    if (!_canvasLayer.superlayer)
        return;

    [self _hideDock:NO];
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
