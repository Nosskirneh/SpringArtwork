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
    __weak SAManager *_manager;
    BOOL _inCharge;
    BOOL _noAutomaticRotation;

    UIView *_targetView;
    UIImageView *_canvasContainerImageView;
    AVPlayerLayer *_canvasLayer;
    UIView *_artworkContainer;
    UIImageView *_artworkImageView;
    UIImageView *_backgroundArtworkImageView;
    CAShapeLayer *_outerCDLayer;
    UIVisualEffectView *_visualEffectView;
    NSLayoutConstraint *_artworkImageViewCenterYConstraint;

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

        // Artwork
        _artworkContainer = [[UIView alloc] initWithFrame:self.view.frame];
        _artworkContainer.translatesAutoresizingMaskIntoConstraints = NO;

        _backgroundArtworkImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _backgroundArtworkImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _backgroundArtworkImageView.contentMode = UIViewContentModeScaleAspectFill;
        if (manager.blurredImage)
            [self updateBlurEffect:YES];

        [_artworkContainer addSubview:_backgroundArtworkImageView];
        [NSLayoutConstraint activateConstraints:[self _constraintsForBackgroundArtworkImageView]];

        _artworkImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _artworkImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self updateArtworkWidthPercentage:manager.artworkWidthPercentage
                         yOffsetPercentage:manager.artworkYOffsetPercentage];
        _artworkImageView.contentMode = UIViewContentModeScaleAspectFit;

        // Canvas
        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        [player _setPreventsSleepDuringVideoPlayback:NO];
        setNoInterruptionMusic(player);

        CGSize mainBounds = [UIScreen mainScreen].bounds.size;
        CGRect canvasFrame = (CGRect) {
            .origin.x = 0.0,
            .origin.y = 0.0,
            .size.width = MIN(mainBounds.height, mainBounds.width),
            .size.height = MAX(mainBounds.height, mainBounds.width)
        };
        _canvasContainerImageView = [[UIImageView alloc] initWithFrame:canvasFrame];
        _canvasContainerImageView.translatesAutoresizingMaskIntoConstraints = YES;

        _canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        _canvasLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _canvasLayer.frame = canvasFrame;
        [_canvasContainerImageView.layer addSublayer:_canvasLayer];

        // Overall
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

- (id)initWithTargetView:(UIView *)targetView manager:(SAManager *)manager {
    if (self == [self initWithManager:manager])
        [self setTargetView:targetView];
    return self;
}

- (id)initWithTargetView:(UIView *)targetView
                 manager:(SAManager *)manager
                inCharge:(BOOL)inCharge {
    if (self == [self initWithTargetView:targetView manager:manager]) {
        _inCharge = inCharge;
        if (inCharge)
            manager.inChargeController = self;
    }
    return self;
}

- (id)initWithTargetView:(UIView *)targetView
                 manager:(SAManager *)manager
     noAutomaticRotation:(BOOL)noAutomaticRotation {
    if (self == [self initWithTargetView:targetView manager:manager]) {
        _noAutomaticRotation = noAutomaticRotation;
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

- (void)setTargetView:(UIView *)targetView {
    _targetView = targetView;
    if (!targetView)
        return [self.view removeFromSuperview];
    [targetView addSubview:self.view];

    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [self.view.widthAnchor constraintEqualToAnchor:targetView.widthAnchor],
        [self.view.heightAnchor constraintEqualToAnchor:targetView.heightAnchor]
    ]];

    // This is required for the camera transition view controller
    // that will receive its target view later than the others
    if ([self _isShowingArtworkView]) {
        [NSLayoutConstraint activateConstraints:[self _constraintsForArtworkContainer]];
        [NSLayoutConstraint activateConstraints:[self _constraintsForBackgroundArtworkImageView]];
    } else if ([self _isShowingCanvasView]) {
        [NSLayoutConstraint activateConstraints:[self _constraintsForCanvasContainerImageView]];
    }
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

- (CGFloat)_artworkImageViewCenterYConstant:(int)yOffsetPercentage {
    // The y offset should always use the current dimension's height
    CGFloat yConstant = 0.f;
    if (yOffsetPercentage != 0)
        yConstant = yOffsetPercentage / 100.0 * [UIScreen mainScreen].bounds.size.height;
    return yConstant;
}

- (void)updateArtworkWidthPercentage:(int)percentage
                   yOffsetPercentage:(int)yOffsetPercentage {
    // Always use the smallest width dimension for the width;
    // we don't want the size to change when rotating
    CGFloat width = [self _minScreenWidth];
    if (percentage != 100) {
        float floatPercentage = 1 - (percentage / 100.0);
        float difference = width * floatPercentage;
        width -= difference;
    }

    // Remove all previous constraints
    [_artworkImageView removeFromSuperview];
    [_artworkImageView removeConstraints:_artworkImageView.constraints];
    [_artworkContainer addSubview:_artworkImageView];

    _artworkImageViewCenterYConstraint = [_artworkImageView.centerYAnchor constraintEqualToAnchor:_artworkContainer.centerYAnchor
                                                                                         constant:[self _artworkImageViewCenterYConstant:yOffsetPercentage]];
    [NSLayoutConstraint activateConstraints:@[
        _artworkImageViewCenterYConstraint,
        [_artworkImageView.centerXAnchor constraintEqualToAnchor:_artworkContainer.centerXAnchor],
        [_artworkImageView.widthAnchor constraintEqualToConstant:width],
        [_artworkImageView.heightAnchor constraintEqualToConstant:width]
    ]];

    // Recreate the CD layer mask
    if ([_manager hasAnimatingArtwork]) {
        [self _destroySpinArtwork];
        [self _prepareSpinArtwork];
    }
    [self _updateArtworkCornerRadius:[_manager artworkCornerRadiusPercentage] width:width];
}

- (void)updateArtworkCornerRadius:(int)percentage {
    [self _updateArtworkCornerRadius:percentage width:[self _minScreenWidth]];
}

- (void)artworkUpdated:(id<SAViewControllerManager>)manager {
    BOOL changedContent = [manager changedContent];
    if (manager) {
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
        // In case hiding from one of the two, animate it
        [self _noCheck_ArtworkUpdatedWithImage:nil
                                  blurredImage:nil
                                         color:nil
                                changedContent:changedContent];
        [self _canvasUpdatedWithAsset:nil isDirty:NO changedContent:changedContent];
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

        // Force update blur
        [_visualEffectView _commonInit];
        [_visualEffectView _updateEffectsFromLegacyEffect];
    } else {
        _visualEffectView = [[UIVisualEffectView alloc] initWithEffect:_manager.blurEffect];

        [_backgroundArtworkImageView addSubview:_visualEffectView];
        _visualEffectView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [_visualEffectView.widthAnchor constraintEqualToAnchor:_backgroundArtworkImageView.widthAnchor],
            [_visualEffectView.heightAnchor constraintEqualToAnchor:_backgroundArtworkImageView.heightAnchor]
        ]];
    }
}

// Rotates the canvas container view the opposite of the SpringBoard
// rotation, allowing it to always appear in full screen.
// Also rotates the artwork container if the target view is not
// automatically rotating.
- (void)rotateToRadians:(float)rotation duration:(float)duration {
    [UIView animateWithDuration:duration animations:^(void) {
        if (_noAutomaticRotation) {
            // Rotate artwork view
            // This has to be done manually for the view controllers which
            // target view is not automatically rotated.
            _artworkContainer.transform = CGAffineTransformMakeRotation(-rotation);
            _visualEffectView.transform = CGAffineTransformMakeRotation(-rotation);
        } else {
            // Rotate canvas view
            // We need to counter-rotate the canvas views for the view controllers which
            // target view automatically rotate.
            _canvasContainerImageView.transform = CGAffineTransformMakeRotation(rotation);

            // We need to set the origin to (0, 0), otherwise it will be misplaced
            [self _resetCanvasOrigin];
        }

        _artworkImageViewCenterYConstraint.constant = [self _artworkImageViewCenterYConstant:_manager.artworkYOffsetPercentage];
    }];
}

#pragma mark Private

#pragma mark Artwork

- (CGFloat)_minScreenWidth {
    CGSize mainBounds = [UIScreen mainScreen].bounds.size;
    return MIN(mainBounds.height, mainBounds.width);
}

- (void)_updateArtworkCornerRadius:(int)percentage width:(CGFloat)width {
    _artworkImageView.clipsToBounds = percentage != 0;
    _artworkImageView.layer.cornerRadius = width / 2 * (percentage / 100.0);
}

- (NSArray *)_constraintsForArtworkContainer {
    return @[
        [_artworkContainer.widthAnchor constraintEqualToAnchor:self.view.widthAnchor],
        [_artworkContainer.heightAnchor constraintEqualToAnchor:self.view.heightAnchor]
    ];
}

- (NSArray *)_constraintsForBackgroundArtworkImageView {
    return @[
        [_backgroundArtworkImageView.widthAnchor constraintEqualToAnchor:_artworkContainer.widthAnchor],
        [_backgroundArtworkImageView.heightAnchor constraintEqualToAnchor:_artworkContainer.heightAnchor]
    ];
}

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

    [self.view addSubview:_artworkContainer];
    [NSLayoutConstraint activateConstraints:[self _constraintsForArtworkContainer]];

    /* Using snapshots here as well to avoid blur glitch */
    _artworkContainer.alpha = 1.0f;
    __block UIView *snapshot = [_artworkContainer snapshotViewAfterScreenUpdates:YES];
    [self.view insertSubview:snapshot aboveSubview:_artworkContainer];

    _artworkContainer.alpha = 0.0f;

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

- (UIView *)_currentReplicantView {
    for (UIView *subview in self.view.subviews) {
        if ([subview isKindOfClass:%c(_UIReplicantView)]) {
            return subview;
        }
    }
    return nil;
}

- (BOOL)_hideArtworkViews {
    if (![self _isShowingArtworkView])
        return NO;

    _animating = YES;
    [self performLayerOpacityAnimation:_artworkContainer.layer show:NO completion:^{
        _animating = NO;
        [_artworkContainer removeFromSuperview];
        _artworkImageView.image = nil;

        if (_nextArtworkChange) {
            _nextArtworkChange();
            _nextArtworkChange = nil;
        }
    }];

    // iOS creates this view which is visible when pulling down the lockscreen from within an app.
    // We need to remove it, otherwise it will look glitchy.
    UIView *replicantView = [self _currentReplicantView];
    [self performLayerOpacityAnimation:replicantView.layer show:NO completion:^{
        [replicantView removeFromSuperview];
    }];

    return YES;
}

#pragma mark Canvas

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                 changedContent:(BOOL)changedContent {
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
    if (_animating) {
        __weak typeof(self) weakSelf = self;
        _nextArtworkChange = ^{
            [weakSelf _noCheck_canvasUpdatedWithAsset:asset
                                              isDirty:isDirty
                                            thumbnail:thumbnail
                                       changedContent:changedContent
                                       afterThumbnail:afterThumbnailCompletion];
        };
    } else {
        [self _noCheck_canvasUpdatedWithAsset:asset
                                      isDirty:isDirty
                                    thumbnail:thumbnail
                               changedContent:changedContent
                               afterThumbnail:afterThumbnailCompletion];
    }
}

- (void)_noCheck_canvasUpdatedWithAsset:(AVAsset *)asset
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
    if ([self _isShowingCanvasView])
        return NO;

    [self.view addSubview:_canvasContainerImageView];
    [NSLayoutConstraint activateConstraints:[self _constraintsForCanvasContainerImageView]];

    [self _showCanvasLayer:YES];

    return YES;
}

- (NSArray *)_constraintsForCanvasContainerImageView {
    CGSize mainBounds = [UIScreen mainScreen].bounds.size;
    CGFloat width = MIN(mainBounds.height, mainBounds.width);
    CGFloat height = MAX(mainBounds.height, mainBounds.width);
    return @[
        [_canvasContainerImageView.widthAnchor constraintEqualToConstant:width],
        [_canvasContainerImageView.heightAnchor constraintEqualToConstant:height]
    ];
}

- (BOOL)_fadeCanvasLayerOut {
    if (![self _isShowingCanvasView])
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

        if (_nextArtworkChange) {
            _nextArtworkChange();
            _nextArtworkChange = nil;
        }
        return;
    }

    _animating = YES;
    [self performLayerOpacityAnimation:_canvasContainerImageView.layer
                                  show:show
                            completion:^{
        _animating = NO;

        if (completion)
            completion();

        if (_nextArtworkChange) {
            _nextArtworkChange();
            _nextArtworkChange = nil;
        }
    }];
}

- (BOOL)_isShowingCanvasView {
    return _canvasContainerImageView.superview;
}

- (void)_resetCanvasOrigin {
    CGRect frame = _canvasContainerImageView.frame;
    frame.origin = (CGPoint) {
        .x = 0.0,
        .y = 0.0
    };
    _canvasContainerImageView.frame = frame;
}

// Needed in order to show on iOS 13.3+ lockscreen
- (BOOL)_canShowWhileLocked {
    return YES;
}

@end
