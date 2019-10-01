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
    UIImageView *_canvasContainerImageView;
    AVPlayerLayer *_canvasLayer;
    UIView *_artworkContainer;
    UIImageView *_artworkImageView;
    UIImageView *_backgroundArtworkImageView;

    BOOL _animating;
    void(^_completion)();
}

#pragma mark Public

- (id)initWithTargetView:(UIView *)targetView {
    if (self == [super init]) {
        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        [player _setPreventsSleepDuringVideoPlayback:NO];
        setNoInterruptionMusic(player);

        self.view.frame = CGRectMake(0, 0, targetView.frame.size.width, targetView.frame.size.height);
        [targetView addSubview:self.view];

        _artworkContainer = [[UIView alloc] initWithFrame:self.view.frame];

        CGRect imageViewFrame = self.view.frame;
        imageViewFrame.size.height = imageViewFrame.size.width;
        imageViewFrame.origin.y = self.view.frame.size.height / 2 - imageViewFrame.size.height / 2;
        _artworkImageView = [[UIImageView alloc] initWithFrame:imageViewFrame];
        _artworkImageView.contentMode = UIViewContentModeScaleAspectFit;
        [_artworkContainer addSubview:_artworkImageView];

        _backgroundArtworkImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _backgroundArtworkImageView.contentMode = UIViewContentModeScaleAspectFill;
        _backgroundArtworkImageView.layer.opacity = 0.0;
        [_artworkContainer addSubview:_backgroundArtworkImageView];

        _canvasContainerImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _canvasContainerImageView.contentMode = UIViewContentModeScaleAspectFill;

        _canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        _canvasLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _canvasLayer.frame = self.view.frame;
        [_canvasContainerImageView.layer addSublayer:_canvasLayer];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_artworkUpdated:)
                                                     name:kUpdateArtwork
                                                   object:nil];
        
        AVAsset *asset = manager.canvasAsset;
        if (asset)
            [self _canvasUpdatedWithAsset:asset isDirty:YES];

        [manager addNewViewController:self];

    }
    return self;
}

- (void)replayVideo {
    AVPlayer *player = _canvasLayer.player;
    [player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
        if (seeked)
            [player play];
    }];
}

- (void)togglePlayPauseWithState:(BOOL)playState {
    AVPlayer *player = _canvasLayer.player;
    playState ? [player play] : [player pause];
}

- (void)togglePlayPause {
    AVPlayer *player = _canvasLayer.player;
    if (player.rate == 0 || player.error)
        [player play];
    else
        [player pause];
}

#pragma mark Private

- (void)_artworkUpdated:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (userInfo) {
        BOOL changeOfContent = userInfo[kChangeOfContent] && [userInfo[kChangeOfContent] boolValue];
        if (userInfo[kCanvasAsset]) {
            if (changeOfContent)
                [self _artworkUpdatedWithImage:nil blurredImage:nil color:nil changeOfContent:changeOfContent];
            [self _canvasUpdatedWithAsset:userInfo[kCanvasAsset] isDirty:userInfo[kIsDirty] != nil thumbnail:userInfo[kCanvasThumbnail]];
        } else if (userInfo[kArtworkImage]) {
            if (changeOfContent)
                [self _canvasUpdatedWithAsset:nil isDirty:NO thumbnail:nil changeOfContent:changeOfContent];
            [self _artworkUpdatedWithImage:userInfo[kArtworkImage] blurredImage:userInfo[kBlurredImage] color:userInfo[kColor] changeOfContent:changeOfContent];
        }
    } else {
        [self _noCheck_ArtworkUpdatedWithImage:nil blurredImage:nil color:nil changeOfContent:NO];
        [self _canvasUpdatedWithAsset:nil isDirty:NO];
    }
}

- (void)_artworkUpdatedWithImage:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color {
    [self _artworkUpdatedWithImage:artwork blurredImage:blurredImage color:color changeOfContent:NO];
}

/* Check if this call came before the previous call.
   In that case, we're still animating and will place this operation in the queue. */
- (void)_artworkUpdatedWithImage:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color changeOfContent:(BOOL)changeOfContent {
    if (_animating) {
        __weak typeof(self) weakSelf = self;
        _completion = ^() {
            [weakSelf _noCheck_ArtworkUpdatedWithImage:artwork blurredImage:blurredImage color:color changeOfContent:changeOfContent];
        };
    } else {
        [self _noCheck_ArtworkUpdatedWithImage:artwork blurredImage:blurredImage color:color changeOfContent:changeOfContent];
    }
}

- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color changeOfContent:(BOOL)changeOfContent {
    if (!artwork) {
        [self _hideArtworkViews];
    } else if (changeOfContent || ![self _isShowingArtworkView]) { // Not already visible, so we don't need to animate the image change, just the layer
        [self _setArtwork:artwork blurredImage:blurredImage color:color];
        [self _showArtworkViews];
    } else {
        [self _animateArtworkChange:artwork blurredImage:blurredImage color:color];
    }
}

- (void)_animateArtworkChange:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color {
    [UIView transitionWithView:_artworkImageView duration:ANIMATION_DURATION options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self _setArtwork:artwork blurredImage:blurredImage color:color];
        }
        completion:nil
    ];
}

- (void)_setArtwork:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color {
    _artworkImageView.image = artwork;
    if (blurredImage)
        _backgroundArtworkImageView.image = blurredImage;
    else if (color)
        _artworkContainer.backgroundColor = color;
}

- (BOOL)_isShowingArtworkView {
    return _artworkContainer.superview;
}

- (BOOL)_showArtworkViews {
    if ([self _isShowingArtworkView])
        return NO;

    _animating = YES;
    [self.view addSubview:_artworkContainer];
    [self _performLayerOpacityAnimation:_artworkContainer.layer show:YES completion:^() {
        _animating = NO;

        if (_completion)
            _completion();
    }];
    return YES;
}

- (BOOL)_hideArtworkViews {
    if (![self _isShowingArtworkView])
        return NO;

    [self _performLayerOpacityAnimation:_artworkContainer.layer show:NO completion:^() {
        [_artworkContainer removeFromSuperview];
    }];
    return YES;
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty {
    [self _canvasUpdatedWithAsset:asset isDirty:isDirty thumbnail:nil changeOfContent:NO];
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail {
    [self _canvasUpdatedWithAsset:asset isDirty:isDirty thumbnail:thumbnail changeOfContent:NO];
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                changeOfContent:(BOOL)changeOfContent {
    [self _preparePlayerForChange:_canvasLayer.player];

    if (asset) {
        [self _fadeCanvasLayerIn];
        [self _changeCanvasAsset:asset isDirty:isDirty thumbnail:thumbnail];
    } else {
        [self _fadeCanvasLayerOut];
    }
}

- (void)_preparePlayerForChange:(AVPlayer *)player {
    return;
}

- (void)_changeCanvasAsset:(AVAsset *)asset isDirty:(BOOL)isDirty thumbnail:(UIImage *)thumbnail {
    if (isDirty) {
        _canvasContainerImageView.image = nil;
        [self _replaceItemWithAsset:asset autoPlay:NO];
    } else {
        /* Create a thumbnail and add it as placeholder to the
           _canvasContainerImageView to prevent flash to background wallpaper */
        _canvasContainerImageView.image = thumbnail;
        [self _replaceItemWithAsset:asset autoPlay:YES];
    }
}

- (void)_replaceItemWithAsset:(AVAsset *)asset autoPlay:(BOOL)autoPlay {
    AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithAsset:asset];

    AVPlayer *player = _canvasLayer.player;
    [self _replaceItemWithItem:newItem player:player];
    if (autoPlay)
        [player play];
}

- (void)_replaceItemWithItem:(AVPlayerItem *)item player:(AVPlayer *)player {
    [player replaceCurrentItemWithPlayerItem:item];
}

- (BOOL)_fadeCanvasLayerIn {
    if (_canvasContainerImageView.superview)
        return NO;

    [self.view addSubview:_canvasContainerImageView];
    [self _showCanvasLayer:YES];
    return YES;
}

- (BOOL)_fadeCanvasLayerOut {
    if (!_canvasContainerImageView.superview)
        return NO;

    [self _showCanvasLayer:NO completion:^() {
        [_canvasLayer.player pause];
        [_canvasContainerImageView removeFromSuperview];
    }];
    return YES;
}

- (void)_showCanvasLayer:(BOOL)show {
    [self _showCanvasLayer:show completion:nil];
}

- (void)_showCanvasLayer:(BOOL)show completion:(void (^)(void))completion {
    [self _performLayerOpacityAnimation:_canvasContainerImageView.layer show:show completion:completion];
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
    layer.opacity = from;

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

@end
