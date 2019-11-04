#import "SAViewController.h"
#import "SAManager.h"
#import "SpringBoard.h"
#import "Common.h"
#import <float.h>

static void setNoInterruptionMusic(AVPlayer *player) {
    AVAudioSessionMediaPlayerOnly *session = [player playerAVAudioSession];
    NSError *error = nil;
    [session setCategory:AVAudioSessionCategoryAmbient error:&error];
}

@implementation SAViewController {
    SAManager *_manager;
    BOOL _inCharge;

    UIImageView *_canvasContainerImageView;
    AVPlayerLayer *_canvasLayer;
    UIView *_artworkContainer;
    UIImageView *_artworkImageView;
    UIImageView *_backgroundArtworkImageView;

    BOOL _animating;
    void(^_completion)();
}

#pragma mark Public

- (id)initWithManager:(SAManager *)manager {
    if (self == [super init]) {
        _manager = manager;

        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        [player _setPreventsSleepDuringVideoPlayback:NO];
        setNoInterruptionMusic(player);

        _artworkContainer = [[UIView alloc] initWithFrame:self.view.frame];

        _backgroundArtworkImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _backgroundArtworkImageView.contentMode = UIViewContentModeScaleAspectFill;
        [_artworkContainer addSubview:_backgroundArtworkImageView];

        _artworkImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self updateArtworkWidthPercentage:manager.artworkWidthPercentage
                         yOffsetPercentage:manager.artworkYOffsetPercentage];
        _artworkImageView.contentMode = UIViewContentModeScaleAspectFit;
        [_artworkContainer addSubview:_artworkImageView];

        _canvasContainerImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _canvasContainerImageView.contentMode = UIViewContentModeScaleAspectFill;

        _canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        _canvasLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _canvasLayer.frame = self.view.frame;
        [_canvasContainerImageView.layer addSublayer:_canvasLayer];
        
        AVAsset *asset = manager.canvasAsset;
        if (asset)
            [self _canvasUpdatedWithAsset:asset isDirty:YES];

        [manager addNewViewController:self];
    }

    return self;
}

- (id)initWithTargetView:(UIView *)targetView manager:(SAManager *)manager {
    if (self == [self initWithManager:manager])
        [self setTargetView:targetView];
    return self;
}

- (id)initWithTargetView:(UIView *)targetView
                 manager:(SAManager *)manager
                inCharge:(BOOL)inCharge {
    if (self == [self initWithManager:manager]) {
        _inCharge = inCharge;
        if (inCharge)
            manager.inChargeController = self;

        [self setTargetView:targetView];
    }
    return self;
}

- (void)setTargetView:(UIView *)targetView {
    if (!targetView)
        return [self.view removeFromSuperview];

    self.view.frame = CGRectMake(0, 0,
                                 targetView.frame.size.width,
                                 targetView.frame.size.height);
    [targetView addSubview:self.view];
}

- (void)replayVideo {
    AVPlayer *player = _canvasLayer.player;
    [player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
        if (seeked)
            [player play];
    }];
}

- (void)togglePlayPauseWithState:(BOOL)playState {
    if ([_manager isCanvasActive]) {
        AVPlayer *player = _canvasLayer.player;
        playState ? [player play] : [player pause];
    } else if ([_manager hasAnimatingArtwork]) {
        playState ? [self _resumeArtworkAnimation] :
                    [self _pauseArtworkAnimation];
    }
}

- (void)togglePlayPause {
    if ([_manager isCanvasActive]) {
        AVPlayer *player = _canvasLayer.player;
        (player.rate == 0 || player.error) ? [player play] :
                                             [player pause];
    } else if ([_manager hasAnimatingArtwork]) {
        [self _togglePlayPauseArtworkAnimation];
    }
}

- (void)updateArtworkWidthPercentage:(int)percentage
                   yOffsetPercentage:(int)yOffsetPercentage {
    CGRect imageViewFrame = self.view.frame;
    if (percentage != 100) {
        float floatPercentage = 1 - (percentage / 100.0);
        float difference = imageViewFrame.size.width * floatPercentage;
        imageViewFrame.size.width -= difference;
        imageViewFrame.origin.x += difference / 2.0;
    }
    imageViewFrame.size.height = imageViewFrame.size.width;
    imageViewFrame.origin.y = self.view.frame.size.height / 2 -
                              imageViewFrame.size.height / 2;

    if (yOffsetPercentage != 0)
        imageViewFrame.origin.y += yOffsetPercentage / 100.0 *
                                   self.view.frame.size.height;
    _artworkImageView.frame = imageViewFrame;
}

- (void)artworkUpdated:(SAManager *)manager {
    if (manager) {
        BOOL changedContent = [manager changedContent];
        if (manager.canvasAsset) {
            void (^afterThumbnailCompletion)() = nil;

            if (changedContent)
                afterThumbnailCompletion = ^{
                    [self _artworkUpdatedWithImage:nil
                                      blurredImage:nil
                                             color:nil
                                    changedContent:changedContent];
                };

            [self _canvasUpdatedWithAsset:manager.canvasAsset
                                  isDirty:[manager isDirty]
                                thumbnail:manager.canvasThumbnail
                           afterThumbnail:afterThumbnailCompletion];
        } else if (manager.artworkImage) {
            [self _artworkUpdatedWithImage:manager.artworkImage
                              blurredImage:manager.blurredImage
                                     color:manager.useBackgroundColor ?
                                               manager.colorInfo.backgroundColor : nil
                            changedContent:changedContent];
            if (changedContent)
                [self _canvasUpdatedWithAsset:nil
                                      isDirty:NO
                                    thumbnail:nil
                               changedContent:changedContent];
        }
    } else {
        [self _noCheck_ArtworkUpdatedWithImage:nil
                                  blurredImage:nil
                                         color:nil
                                changedContent:NO];
        [self _canvasUpdatedWithAsset:nil isDirty:NO];
    }
}

#pragma mark Private

- (void)_artworkUpdatedWithImage:(UIImage *)artwork
                    blurredImage:(UIImage *)blurredImage
                           color:(UIColor *)color {
    [self _artworkUpdatedWithImage:artwork
                      blurredImage:blurredImage
                             color:color
                    changedContent:NO];
}

/* Check if this call came before the previous call.
   In that case, we're still animating and will place this operation in the queue. */
- (void)_artworkUpdatedWithImage:(UIImage *)artwork
                    blurredImage:(UIImage *)blurredImage
                           color:(UIColor *)color
                  changedContent:(BOOL)changedContent {
    if (_animating) {
        __weak typeof(self) weakSelf = self;
        _completion = ^{
            [weakSelf _noCheck_ArtworkUpdatedWithImage:artwork
                                          blurredImage:blurredImage
                                                 color:color
                                        changedContent:changedContent];
        };
    } else {
        [self _noCheck_ArtworkUpdatedWithImage:artwork
                                  blurredImage:blurredImage
                                         color:color
                                changedContent:changedContent];
    }
}

- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork
                            blurredImage:(UIImage *)blurredImage
                                   color:(UIColor *)color
                          changedContent:(BOOL)changedContent {
    if (!artwork) {
        [self _hideArtworkViews];
        return;
    }

    // Not already visible, so we don't need to animate the image change but only the layer
    if (changedContent || ![self _isShowingArtworkView]) {
        [self _setArtwork:artwork];
        [self _setBlurredImage:blurredImage color:color];
        [self _showArtworkViews];
    } else {
        [self _animateArtworkChange:artwork
                       blurredImage:blurredImage
                              color:color];
    }
}

- (void)_animateArtworkChange:(UIImage *)artwork
                 blurredImage:(UIImage *)blurredImage
                        color:(UIColor *)color {
    [UIView transitionWithView:_artworkImageView
                      duration:ANIMATION_DURATION
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self _setArtwork:artwork];
                    }
                    completion:nil];

    [UIView transitionWithView:_backgroundArtworkImageView
                      duration:ANIMATION_DURATION
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self _setBlurredImage:blurredImage color:color];
                    }
                    completion:nil];
}

- (void)_setBlurredImage:(UIImage *)blurredImage color:(UIColor *)color {
    if (blurredImage)
        _backgroundArtworkImageView.image = blurredImage;
    else if (color) {
        _backgroundArtworkImageView.image = nil;
        _backgroundArtworkImageView.backgroundColor = color;
    }
}

- (void)_setArtwork:(UIImage *)artwork {
    /* If call came from change of settings, it might be that the artwork is still the same.
       Hence, compare the image pointer before updating. */
    if (artwork == _artworkImageView.image)
        return;

    _artworkImageView.image = artwork;
    if ([_manager hasAnimatingArtwork])
        [self _addSpinArtwork];
}

- (void)_addSpinArtwork {
    _artworkImageView.layer.mask = [self _createLayerArtworkMask];
    [_artworkImageView.layer addSublayer:[self _createLayerArtworkOuterCD]];

    _artworkImageView.layer.cornerRadius = _artworkImageView.frame.size.width / 2;
    _artworkImageView.layer.borderColor = [UIColor.grayColor colorWithAlphaComponent:0.3].CGColor;
    _artworkImageView.layer.borderWidth = 1.0f;
    _artworkImageView.clipsToBounds = YES;

    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotation.fromValue = [NSNumber numberWithFloat:0];
    rotation.toValue = [NSNumber numberWithFloat:(2 * M_PI)];
    rotation.duration = 15.0;
    rotation.repeatCount = FLT_MAX;
    [_artworkImageView.layer addAnimation:rotation forKey:@"Spin"];
}

- (CALayer *)_createLayerArtworkOuterCD {
    CGFloat outerHoleWidth = 40.0f;
    CGRect outerHoleFrame = CGRectMake(_artworkImageView.frame.size.width / 2 - outerHoleWidth / 2,
                                       _artworkImageView.frame.size.height / 2 - outerHoleWidth / 2,
                                       outerHoleWidth, outerHoleWidth);
    UIBezierPath *beizerPath = [UIBezierPath bezierPathWithOvalInRect:outerHoleFrame];

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.fillColor = [UIColor.whiteColor colorWithAlphaComponent:0.5].CGColor;
    [layer setPath:[beizerPath CGPath]];
    return layer;
}

- (CALayer *)_createLayerArtworkMask {
    CGRect allFrame = CGRectMake(0, 0,
                                 _artworkImageView.frame.size.width,
                                 _artworkImageView.frame.size.height);
    UIBezierPath *beizerPath = [UIBezierPath bezierPathWithRect:allFrame];

    CGFloat innerHoleWidth = 20.0f;
    CGRect holeFrame = CGRectMake(_artworkImageView.frame.size.width / 2 - innerHoleWidth / 2,
                                  _artworkImageView.frame.size.height / 2 - innerHoleWidth / 2,
                                  innerHoleWidth, innerHoleWidth);
    [beizerPath appendPath:[[UIBezierPath bezierPathWithOvalInRect:holeFrame]
                            bezierPathByReversingPath]];

    CAShapeLayer *layer = [CAShapeLayer layer];
    [layer setPath:[beizerPath CGPath]];
    return layer;
}

- (void)_togglePlayPauseArtworkAnimation {
    CALayer *layer = _artworkImageView.layer;
    layer.speed == 0.0 ? [self _resumeArtworkAnimation:layer] :
                         [self _pauseArtworkAnimation:layer];
}

- (void)_pauseArtworkAnimation {
    [self _pauseArtworkAnimation:_artworkImageView.layer];
}

- (void)_resumeArtworkAnimation {
    [self _resumeArtworkAnimation:_artworkImageView.layer];
}

- (void)_pauseArtworkAnimation:(CALayer *)layer {
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

- (void)_resumeArtworkAnimation:(CALayer *)layer {
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

- (BOOL)_isShowingArtworkView {
    return _artworkContainer.superview;
}

- (BOOL)_showArtworkViews {
    if ([self _isShowingArtworkView])
        return NO;

    _animating = YES;
    [self.view addSubview:_artworkContainer];
    [self _performLayerOpacityAnimation:_artworkContainer.layer show:YES completion:^{
        _animating = NO;

        if (_completion) {
            _completion();
            _completion = nil;
        }
    }];
    return YES;
}

- (BOOL)_hideArtworkViews {
    if (![self _isShowingArtworkView])
        return NO;

    [self _performLayerOpacityAnimation:_artworkContainer.layer show:NO completion:^{
        [_artworkContainer removeFromSuperview];
    }];
    return YES;
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty {
    [self _canvasUpdatedWithAsset:asset
                          isDirty:isDirty
                        thumbnail:nil
                   changedContent:NO
                   afterThumbnail:nil];
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                 changedContent:(BOOL)changedContent {
    [self _canvasUpdatedWithAsset:asset
                          isDirty:isDirty
                        thumbnail:thumbnail
                   changedContent:changedContent
                   afterThumbnail:nil];
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                 afterThumbnail:(void (^)())afterThumbnailCompletion {
    [self _canvasUpdatedWithAsset:asset isDirty:isDirty
                        thumbnail:thumbnail
                   changedContent:NO
                   afterThumbnail:afterThumbnailCompletion];
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                 changedContent:(BOOL)changedContent
                 afterThumbnail:(void (^)())afterThumbnailCompletion {
    [self _preparePlayerForChange:_canvasLayer.player];

    if (asset) {
        [self _fadeCanvasLayerIn];
        [self _changeCanvasAsset:asset
                         isDirty:isDirty
                       thumbnail:thumbnail
                  afterThumbnail:afterThumbnailCompletion];
    } else {
        [self _fadeCanvasLayerOut];
    }
}

- (void)_preparePlayerForChange:(AVPlayer *)player {
    if (_inCharge && player.currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:_manager
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];
    }
}

- (void)_changeCanvasAsset:(AVAsset *)asset
                   isDirty:(BOOL)isDirty
                 thumbnail:(UIImage *)thumbnail
            afterThumbnail:(void (^)())afterThumbnailCompletion {
    if (isDirty || !thumbnail) {
        _canvasContainerImageView.image = nil;
        [self _replaceItemWithAsset:asset autoPlay:NO];
        if (afterThumbnailCompletion)
            afterThumbnailCompletion();
    } else {
        /* Create a thumbnail and add it as placeholder to the
           _canvasContainerImageView to prevent flash to background wallpaper */
        _canvasContainerImageView.image = thumbnail;

        if (afterThumbnailCompletion)
            afterThumbnailCompletion();

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

    if (_inCharge) {
        [[NSNotificationCenter defaultCenter] addObserver:_manager
                                                 selector:@selector(_videoEnded)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:item];
    }
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

    [self _showCanvasLayer:NO completion:^{
        [_canvasLayer.player pause];
        [_canvasContainerImageView removeFromSuperview];
    }];
    return YES;
}

- (void)_showCanvasLayer:(BOOL)show {
    [self _showCanvasLayer:show completion:nil];
}

- (void)_showCanvasLayer:(BOOL)show completion:(void (^)(void))completion {
    [self _performLayerOpacityAnimation:_canvasContainerImageView.layer
                                   show:show
                             completion:completion];
}

- (void)_performLayerOpacityAnimation:(CALayer *)layer
                                 show:(BOOL)show
                           completion:(void (^)(void))completion {
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
