#import "SAViewController.h"
#import "Common.h"
#import "SpringBoard.h"
#import "CanvasReceiver.h"

#define ANIMATION_DURATION 0.75

extern CanvasReceiver *receiver;

static void setNoInterruptionMusic(AVPlayer *player) {
    AVAudioSessionMediaPlayerOnly *session = [player playerAVAudioSession];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryAmbient error:&error];
}

@implementation SAViewController

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
                                                 selector:@selector(canvasUpdated:)
                                                     name:kUpdateCanvas
                                                   object:nil];
        
        NSString *url = receiver.canvasURL;
        if (url)
            [self canvasUpdatedWithURLString:url];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(togglePlayPause)
                                                     name:kTogglePlayPause
                                                   object:nil];
    }
    return self;
}

- (void)hideDock:(BOOL)hide {
    // Only the homescreen controller is allowed to change the dock,
    // otherwise the two will do it simultaneously which obviously causes issues
    if (!_homescreen)
        return;

    SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
    SBDockView *dockView = [rootFolderController.contentView dockView];
    UIView *background = MSHookIvar<UIView *>(dockView, "_backgroundView");

    if (!hide)
        background.hidden = NO;

    [self performLayerOpacityAnimation:background.layer show:!hide completion:^() {
        if (hide)
            background.hidden = YES;
    }];
}

- (void)replayMovie:(NSNotification *)notification {
    [_canvasLayer.player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
        if (seeked)
            [_canvasLayer.player play];
    }];
}

- (void)canvasUpdated:(NSNotification *)notification {
    [self canvasUpdatedWithURLString:notification.userInfo[kCanvasURL]];
}

- (void)canvasUpdatedWithURLString:(NSString *)url {
    AVPlayer *player = _canvasLayer.player;
    if (player.currentItem)
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];

    if (url) {
        [self fadeCanvasLayerIn];
        [self changeCanvasURL:[NSURL URLWithString:url]];
    } else {
        [self fadeCanvasLayerOut];
    }
}

- (void)changeCanvasURL:(NSURL *)url {
    AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithURL:url];

    AVPlayer *player = _canvasLayer.player;
    [player replaceCurrentItemWithPlayerItem:newItem];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(replayMovie:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:player.currentItem];
    [player play];
}

- (void)fadeCanvasLayerIn {
    if (_canvasLayer.superlayer)
        return;

    [self.view.layer addSublayer:_canvasLayer];

    [self hideDock:YES];
    [self _showCanvasLayer:YES];
}

- (void)fadeCanvasLayerOut {
    if (!_canvasLayer.superlayer)
        return;

    [self hideDock:NO];
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
    [self performLayerOpacityAnimation:_canvasLayer show:show completion:completion];
}

- (void)performLayerOpacityAnimation:(CALayer *)layer show:(BOOL)show completion:(void (^)(void))completion {
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

- (void)togglePlayPause {
    AVPlayer *player = _canvasLayer.player;
    if (player.rate == 0 || player.error)
        [player play];
    else
        [player pause];
}

@end
