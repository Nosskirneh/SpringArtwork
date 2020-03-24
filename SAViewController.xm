#import "SAViewController.h"
#import "SAManager.h"
#import "SpringBoard.h"
#import "Common.h"
#import "SABlurEffect.h"

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
    CAShapeLayer *_outerCDLayer;
    UIVisualEffectView *_visualEffectView;

    BOOL _skipAnimation;
    BOOL _animating;
    void(^_nextArtworkChange)();

    CMTime _canvasStartTime;
    NSNumber *_artworkAnimationStartTime;
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
        if (manager.blurredImage)
            [self updateBlurEffect:YES];

        [_artworkContainer addSubview:_backgroundArtworkImageView];

        _artworkImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self updateArtworkWidthPercentage:manager.artworkWidthPercentage
                         yOffsetPercentage:manager.artworkYOffsetPercentage];

        int cornerRadius = [manager artworkCornerRadiusPercentage];
        if (cornerRadius != 0)
            [self updateArtworkCornerRadius:cornerRadius];
        _artworkImageView.contentMode = UIViewContentModeScaleAspectFit;
        [_artworkContainer addSubview:_artworkImageView];

        _canvasContainerImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _canvasContainerImageView.contentMode = UIViewContentModeScaleAspectFill;

        _canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        _canvasLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _canvasLayer.frame = self.view.frame;
        [_canvasContainerImageView.layer addSublayer:_canvasLayer];

        if ([_manager hasContent]) {
            [self performWithoutAnimation:^{
                [self updateRelevantStartTime];
                [self artworkUpdated:_manager];
            }];
        }

        [manager addNewViewController:self];
    }

    return self;
}

- (void)performWithoutAnimation:(void (^)(void))block {
    _skipAnimation = YES;
    block();
    _skipAnimation = NO;
}

- (void)updateRelevantStartTime {
    if ([_manager isCanvasActive])
        [self updateCanvasStartTime];
    else if ([_manager hasAnimatingArtwork])
        [self updateAnimationStartTime];
}

- (void)updateCanvasStartTime {
    _canvasStartTime = [_manager canvasCurrentTime];
}

- (void)updateAnimationStartTime {
    _artworkAnimationStartTime = [_manager artworkAnimationTime];
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

    CGRect frame = targetView.frame;
    if (CGRectEqualToRect(frame, CGRectZero))
        frame = [UIScreen mainScreen].bounds;
    self.view.frame = frame;
    _visualEffectView.frame = frame;
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

    // Recreate the CD layer mask
    if ([_manager hasAnimatingArtwork]) {
        [self _destroySpinArtwork];
        [self _prepareSpinArtwork];
        [self updateArtworkCornerRadius:[_manager artworkCornerRadiusPercentage]];
    }
}

- (void)updateArtworkCornerRadius:(int)percentage {
    _artworkImageView.clipsToBounds = percentage != 0;
    _artworkImageView.layer.cornerRadius = _artworkImageView.frame.size.width / 2 *
                                           (percentage / 100.0);
}

- (void)artworkUpdated:(id<SAViewControllerManager>)manager {
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

- (void)addArtworkRotation {
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];

    if (_artworkAnimationStartTime) {
        rotation.fromValue = _artworkAnimationStartTime;
        rotation.toValue = @(2 * M_PI + [_artworkAnimationStartTime floatValue]);
        _artworkAnimationStartTime = nil;
    } else {
        rotation.fromValue = @(0);
        rotation.toValue = @(2 * M_PI);
    }

    rotation.duration = 15.0;
    rotation.repeatCount = INFINITY;
    [_artworkImageView.layer addAnimation:rotation forKey:@"transform.rotation"];
}

- (void)removeArtworkRotation {
    [_artworkImageView.layer removeAllAnimations];
    _artworkImageView.layer.transform = CATransform3DIdentity;
    [self _destroySpinArtwork];
}

- (CMTime)canvasCurrentTime {
    AVPlayerItem *item = _canvasLayer.player.currentItem;
    if (!item)
        return kCMTimeInvalid;
    return item.currentTime;
}

- (NSNumber *)artworkAnimationTime {
    return [_artworkImageView.layer.presentationLayer valueForKeyPath:@"transform.rotation"];
}

- (void)performLayerOpacityAnimation:(CALayer *)layer
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

    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];

        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        animation.duration = ANIMATION_DURATION;
        animation.toValue = @(to);
        animation.fromValue = @(from);

        [CATransaction setCompletionBlock:completion];
        [layer addAnimation:animation forKey:@"timeViewFadeIn"];
        layer.opacity = to;
        [CATransaction commit];
    });
}

- (void)setArtwork:(UIImage *)artwork {
    /* If call came from change of settings, it might be
       that the artwork is still the same. Hence, compare
       the image pointer before updating. */
    if (artwork == _artworkImageView.image)
        return;

    _artworkImageView.image = artwork;
}

- (void)updateBlurEffect:(BOOL)blur {
    if (!blur) {
        [_visualEffectView removeFromSuperview];
        _visualEffectView = nil;
        return;
    }

    if (_visualEffectView) {
        if (_visualEffectView.effect == _manager.blurEffect)
            return;

        [_visualEffectView setEffect:_manager.blurEffect];

        // Force update of blur
        [_visualEffectView _commonInit];
        [_visualEffectView _updateEffectsFromLegacyEffect];
    } else {
        _visualEffectView = [[UIVisualEffectView alloc] initWithEffect:_manager.blurEffect];
        [_visualEffectView setFrame:self.view.frame];
        [_backgroundArtworkImageView addSubview:_visualEffectView];
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
        _nextArtworkChange = ^{
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
        if ([_manager hasAnimatingArtwork])
            [self _pauseArtworkAnimation];

        [self _hideArtworkViews];
        return;
    }

    BOOL hasAnimatingArtwork = [_manager hasAnimatingArtwork];
    if (hasAnimatingArtwork)
        [self _prepareSpinArtwork];

    /* Not already visible, so we don't need to
       animate the image change but only the layer. */
    if (_skipAnimation || changedContent || ![self _isShowingArtworkView]) {
        if (!_manager.onlyBackground)
            [self setArtwork:artwork];
        [self _setBlurredImage:blurredImage color:color];

        /* Only wait with add of animation if changing content
           (otherwise view is not visible and animation will not start). */
        void (^completion)() = nil;
        if (hasAnimatingArtwork)
            completion = ^{
                [self _tryAddArtworkAnimation];
            };
        [self _showArtworkViews:completion];
    } else {
        [self _animateArtworkChange:artwork
                       blurredImage:blurredImage
                              color:color];
        if (hasAnimatingArtwork)
            [self _tryAddArtworkAnimation];
    }
}

- (void)_animateArtworkChange:(UIImage *)artwork
                 blurredImage:(UIImage *)blurredImage
                        color:(UIColor *)color {
    /* Animating change of an image when an UIVisualEffectView is placed
       above results in no animation. The solution is to take a snapshot,
       append it to the superview, hide the real view, change it without
       animation and then fade the real view in with animation.

       To avoid UI glitches with the blur, a snapshot on the resulting
       view is also taken which is then replaced with the real view. */
    __block UIView *oldSnapshot = [_backgroundArtworkImageView snapshotViewAfterScreenUpdates:NO];
    [_artworkContainer insertSubview:oldSnapshot aboveSubview:_backgroundArtworkImageView];

    [self _setBlurredImage:blurredImage color:color];
    __block UIView *newSnapshot = [_backgroundArtworkImageView snapshotViewAfterScreenUpdates:YES];
    _backgroundArtworkImageView.alpha = 0.0f;

    [_artworkContainer insertSubview:newSnapshot belowSubview:_artworkImageView];

    [UIView transitionWithView:_artworkContainer
                      duration:ANIMATION_DURATION
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        _backgroundArtworkImageView.alpha = 1.0f;

                        if (!_manager.onlyBackground)
                            [self setArtwork:artwork];
                    }
                    completion:^(BOOL _) {
                        [oldSnapshot removeFromSuperview];
                        oldSnapshot = nil;

                        [newSnapshot removeFromSuperview];
                        newSnapshot = nil;
                    }];
}

- (void)_setBlurredImage:(UIImage *)blurredImage color:(UIColor *)color {
    if (blurredImage) {
        _backgroundArtworkImageView.image = blurredImage;
        [self updateBlurEffect:YES];
    } else if (color) {
        _backgroundArtworkImageView.image = nil;
        _backgroundArtworkImageView.backgroundColor = color;
        [self updateBlurEffect:NO];
    }
}

- (void)_prepareSpinArtwork {
    if (!_outerCDLayer) {
        _artworkImageView.layer.mask = [self _createLayerArtworkMask];
        [_artworkImageView.layer addSublayer:[self _createLayerArtworkOuterCD]];

        _artworkImageView.layer.borderColor = [UIColor.grayColor colorWithAlphaComponent:0.3].CGColor;
        _artworkImageView.layer.borderWidth = 1.0f;
    }

    _outerCDLayer.fillColor = _manager.blendedCDBackgroundColor.CGColor;
}

- (void)_destroySpinArtwork {
    [_outerCDLayer removeFromSuperlayer];
    _outerCDLayer = nil;

    _artworkImageView.layer.mask = nil;
    _artworkImageView.layer.borderWidth = 0.0f;
}

- (void)_tryAddArtworkAnimation {
    if ([_manager isDirty]) {
        if (_inCharge)
            [_manager setShouldAddRotation];
    } else {
        [self addArtworkRotation];
    }
}

- (CALayer *)_createLayerArtworkOuterCD {
    CGFloat outerHoleWidth = _artworkImageView.frame.size.width * 0.20f;
    CGRect outerHoleFrame = CGRectMake(_artworkImageView.frame.size.width / 2 - outerHoleWidth / 2,
                                       _artworkImageView.frame.size.height / 2 - outerHoleWidth / 2,
                                       outerHoleWidth, outerHoleWidth);
    UIBezierPath *beizerPath = [UIBezierPath bezierPathWithOvalInRect:outerHoleFrame];

    _outerCDLayer = [CAShapeLayer layer];
    [_outerCDLayer setPath:[beizerPath CGPath]];
    return _outerCDLayer;
}

- (CALayer *)_createLayerArtworkMask {
    CGRect allFrame = CGRectMake(0, 0,
                                 _artworkImageView.frame.size.width,
                                 _artworkImageView.frame.size.height);
    UIBezierPath *beizerPath = [UIBezierPath bezierPathWithRect:allFrame];

    CGFloat innerHoleWidth = _artworkImageView.frame.size.width * 0.10f;
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

- (BOOL)_showArtworkViews:(void (^)())completion {
    if ([self _isShowingArtworkView]) {
        if (completion)
            completion();
        return NO;
    }

    /* Using snapshots here as well to avoid blur glitch */
    _artworkContainer.alpha = 1.0f;
    __block UIView *snapshot = [_artworkContainer snapshotViewAfterScreenUpdates:YES];
    [self.view insertSubview:snapshot aboveSubview:_artworkContainer];

    _artworkContainer.alpha = 0.0f;
    [self.view addSubview:_artworkContainer];

    if (_skipAnimation) {
        _artworkImageView.layer.opacity = 1.0;
        if (completion)
            completion();
        return YES;
    }

    _animating = YES;
    [self performLayerOpacityAnimation:snapshot.layer show:YES completion:^{
        _animating = NO;

         _artworkContainer.alpha = 1.0f;
        [snapshot removeFromSuperview];
        snapshot = nil;

        if (_nextArtworkChange) {
            _nextArtworkChange();
            _nextArtworkChange = nil;
        }

        if (completion)
            completion();
    }];
    return YES;
}

- (BOOL)_hideArtworkViews {
    if (![self _isShowingArtworkView])
        return NO;

    [self performLayerOpacityAnimation:_artworkContainer.layer show:NO completion:^{
        [_artworkContainer removeFromSuperview];
        _artworkImageView.image = nil;
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
    if (!thumbnail) {
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

        [self _replaceItemWithAsset:asset autoPlay:!isDirty];
    }
}

- (void)_replaceItemWithAsset:(AVAsset *)asset
                     autoPlay:(BOOL)autoPlay {
    AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithAsset:asset];

    AVPlayer *player = _canvasLayer.player;
    [self _player:player replaceItemWithItem:newItem];
    [self _player:player seekAndPlay:autoPlay];
}

- (void)_player:(AVPlayer *)player seekAndPlay:(BOOL)autoPlay {
    if (CMTIME_IS_VALID(_canvasStartTime)) {
        [player seekToTime:_canvasStartTime];
        _canvasStartTime = kCMTimeInvalid;
    }

    if (autoPlay)
        [player play];
}

- (void)_player:(AVPlayer *)player replaceItemWithItem:(AVPlayerItem *)item {
    [player replaceCurrentItemWithPlayerItem:item];

    if (_inCharge) {
        [[NSNotificationCenter defaultCenter] addObserver:_manager
                                                 selector:@selector(videoEnded)
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

- (void)_showCanvasLayer:(BOOL)show
              completion:(void (^)(void))completion {
    if (_skipAnimation) {
        _canvasContainerImageView.layer.opacity = show ? 1.0 : 0.0;
        if (completion)
            completion();
        return;
    }

    [self performLayerOpacityAnimation:_canvasContainerImageView.layer
                                   show:show
                             completion:completion];
}

// Needed in order to show on iOS 13.3+ lockscreen
- (BOOL)_canShowWhileLocked {
    return YES;
}

@end
