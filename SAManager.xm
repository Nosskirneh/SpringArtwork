#import "SAManager.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "Common.h"
#import <notify.h>
#import "SpringBoard.h"
#import "ApplicationProcesses.h"
#import <SpringBoard/SBMediaController.h>
#import <MediaRemote/MediaRemote.h>
#import "Artwork.h"
#import "PlaceholderImages.h"
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVAssetImageGenerator.h>
#import <libcolorpicker.h>
#import "ColorFlow.h"

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"
#define kSBApplicationProcessStateDidChange @"SBApplicationProcessStateDidChange"
#define kSBMediaNowPlayingAppChangedNotification @"SBMediaNowPlayingAppChangedNotification"


@interface NSValue (Missing)
+ (NSValue *)valueWithCMTime:(CMTime)time;
@end

@interface CPDistributedMessagingCenter (Missing)
- (void)unregisterForMessageName:(NSString *)name;
@end

extern UIViewController<CoverSheetViewController> *getCoverSheetViewController();
extern SBWallpaperController *getWallpaperController();
extern SBIconController *getIconController();
extern SBCoverSheetPrimarySlidingViewController *getSlidingViewController();


@implementation SAManager {
    CPDistributedMessagingCenter *_rbs_center;
    int _notifyTokenForDidChangeDisplayStatus;
    int _notifyTokenForSettingsChanged;

    BOOL _registeredAutoPlayPauseEvents;
    BOOL _subscribedToArtwork;
    NSSet *_disabledApps;

    BOOL _manuallyPaused;
    BOOL _playing;
    UIImpactFeedbackGenerator *_hapticGenerator;

    NSString *_trackIdentifier;
    NSString *_artworkIdentifier;

    UIImage *_canvasArtworkImage;
    BOOL _useCanvasArtworkTimer;
    NSTimer *_canvasArtworkTimer;

    BOOL _didInit;
    BOOL _dockHidden;
    BOOL _screenTurnedOn;
    BOOL _mediaPlaying;
    BOOL _mediaWidgetActive;

    BOOL _colorFlowEnabled;

    /* This is used when using artwork animations.
       It isn't possible to change the artwork in
       the background when there are animations present.
       The solution is to mark the change as pending
       and check on every unlock, app exit. */
    BOOL _hasPendingArtworkChange;
    BOOL _shouldAddRotation;
    BOOL _shouldRemoveRotation;

    NSString *_canvasURL;

    /* The ones below exist because of Spotify Connect. If playing through
       Connect and then exiting the app, the now playing app will be removed.
       However, when opening the app again, it registers Spotify once again.
       It's just that there are no artwork or canvas events being fired by
       that point. */
    NSString *_bundleID;
    NSString *_previousCanvasURL;
    AVAsset *_previousCanvasAsset;
    // ---

    Mode _mode;
    Mode _previousMode;

    NSMutableArray *_viewControllers;

    NSArray<UIImage *> *_ignoredImages;
    NSTimer *_placeholderArtworkTimer;

    BOOL _tintFolderIcons;
    BOOL _artworkEnabled;
    ArtworkBackgroundMode _artworkBackgroundMode;
    UIColor *_staticColor;
    BlurColoringMode _blurColoringMode;

    BOOL _animateArtwork;
    NSNumber *_blurRadius;
    int _artworkCornerRadiusPercentage;
    BOOL _canvasEnabled;
    BOOL _pauseContentWithMedia;
}

#pragma mark Public

- (void)setupWithPreferences:(NSDictionary *)preferences {
    _didInit = YES;
    _screenTurnedOn = YES;

    [self _fillPropertiesFromSettings:preferences];

    if (_canvasEnabled)
        [self _registerEventsForCanvasMode];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_nowPlayingAppChanged:)
                                                 name:kSBMediaNowPlayingAppChangedNotification
                                               object:nil];

    [self _subscribeToArtworkChanges];

    if (_pauseContentWithMedia)
        [self _subscribeToMediaPlayPause];

    _viewControllers = [NSMutableArray new];

    notify_register_dispatch(kSettingsChanged,
        &_notifyTokenForSettingsChanged,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
        ^(int _) {
            [self _updateConfigurationWithDictionary:[NSDictionary dictionaryWithContentsOfFile:kPrefPath]];
        }
    );

    _colorFlowEnabled = %c(CFWPrefsManager) &&
                        ((CFWPrefsManager *)[%c(CFWPrefsManager) sharedInstance]).lockScreenEnabled;
}

- (BOOL)hasContent {
    return [self isCanvasActive] || _artworkImage;
}

- (BOOL)hasPlayableContent {
    return [self isCanvasActive] || [self hasAnimatingArtwork];
}

- (BOOL)isCanvasActive {
    return _canvasURL != nil;
}

- (BOOL)hasAnimatingArtwork {
    return _mode == Artwork && _animateArtwork && !_onlyBackground && _artworkImage;
}

- (BOOL)isDirty {
    return !_screenTurnedOn ||
           (_insideApp && !_lockscreenPulledDownInApp);
}

- (void)setupHaptic {
    _hapticGenerator = [[%c(UIImpactFeedbackGenerator) alloc] initWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)togglePlayManually {
    /* If animation was previously manually paused, we need
       to add it again if the artwork image changed. */
    if (_manuallyPaused && _shouldAddRotation)
        [self _addArtworkRotation];

    [_hapticGenerator impactOccurred];
    for (SAViewController *vc in _viewControllers)
        [vc togglePlayPause];

    if (_playing)
        _manuallyPaused = YES;

    _playing = !_playing;
}

- (void)addNewViewController:(SAViewController *)viewController {
    [_viewControllers addObject:viewController];
}

- (void)removeViewController:(SAViewController *)viewController {
    [_viewControllers removeObject:viewController];
}

- (void)updateInControlViewControllerVisibility {
    if (_enabledMode == HomescreenMode)
        _inChargeController.view.hidden = NO;
    else if (_enabledMode == LockscreenMode)
        _inChargeController.view.hidden = YES;
}

- (void)hide {
    [self _setModeToNone];
    [self _updateOnMainQueueWithContent:NO];
}

// Destroy everything! MOHAHAHA! *evil laugh continues...*
- (void)setTrialEnded {
    _trialEnded = YES;

    /* Used to guard against uninitialized tweak due to trial invalidity */
    if (!_didInit)
        return;

    [self _unsubscribeToArtworkChanges];
    [self _unregisterEventsForCanvasMode];
    [self _unregisterAutoPlayPauseEvents];
    notify_cancel(_notifyTokenForSettingsChanged);

    [self _setModeToNone];
    _ignoredImages = nil;

    _previousCanvasURL = nil;
    _previousCanvasAsset = nil;

    _canvasThumbnail = nil;
    _canvasArtworkImage = nil;

    _artworkEnabled = NO;
    _canvasEnabled = NO;

    [self _updateWithContent:NO];
    _viewControllers = nil;
    _inChargeController = nil;
}

- (BOOL)changedContent {
    return _previousMode != None && _mode != _previousMode;
}

- (BOOL)useBackgroundColor {
    return ![self isCanvasActive] &&
           _artworkBackgroundMode != BlurredImage;
}

- (void)mediaWidgetDidActivate:(BOOL)activate {
    _mediaWidgetActive = activate;

    if ([self hasContent] || _previousCanvasURL) {
        BOOL isSpotify = [_bundleID isEqualToString:kSpotifyBundleID];
        if (activate) {
            /* Restore canvas if any */
            if (isSpotify && _previousCanvasURL) {
                _canvasURL = _previousCanvasURL;
                _canvasAsset = _previousCanvasAsset;
            }
            [self _updateWithContent:YES];
        } else {
            /* Store canvas if any */
            if (isSpotify) {
                _previousCanvasURL = _canvasURL;
                _previousCanvasAsset = _canvasAsset;
            }

            [self hide];
        }
    }
}

- (void)setLockscreenPulledDownInApp:(BOOL)down {
    _lockscreenPulledDownInApp = down;
    if (_playing != down) {
        if ([self _canAutoPlayPause]) {
            if (_hasPendingArtworkChange)
                [self _updateOnMainQueueWithContent:YES];
            else if (_shouldAddRotation)
                [self _addArtworkRotation];

            [self _setPlayPauseState:down];
        } else if (_shouldRemoveRotation) {
            [self _removeArtworkRotation];
        }
    }
}

- (CMTime)canvasCurrentTime {
    return [_inChargeController canvasCurrentTime];
}

- (NSNumber *)artworkAnimationTime {
    return [_inChargeController artworkAnimationTime];
}

- (void)videoEnded {
    for (SAViewController *vc in _viewControllers)
        [vc replayVideo];
}

- (int)artworkCornerRadiusPercentage {
    return _animateArtwork ? 100 : _artworkCornerRadiusPercentage;
}

- (void)setShouldAddRotation {
    _shouldAddRotation = YES;
}

#pragma mark Private

- (void)_fillPropertiesFromSettings:(NSDictionary *)preferences {
    id current = preferences[kEnabledMode];
    _enabledMode = current ? (EnabledMode)[current intValue] : BothMode;

    current = preferences[kTintFolderIcons];
    _tintFolderIcons = !current || [current boolValue];

    current = preferences[kArtworkEnabled];
    _artworkEnabled = !current || [current boolValue];

    current = preferences[kDisabledApps];
    NSArray *disabledAppsList = current ? current : @[];
    _disabledApps = [NSSet setWithArray:disabledAppsList];

    current = preferences[kArtworkBackgroundMode];
    if (current) {
        _artworkBackgroundMode = (ArtworkBackgroundMode)[current intValue];
        if (_artworkBackgroundMode == StaticColor)
            [self _updateStaticColor:preferences];
        else
            _staticColor = nil;
    } else {
        _artworkBackgroundMode = BlurredImage;
        _staticColor = nil;
    }

    current = preferences[kOnlyBackground];
    _onlyBackground = current && [current boolValue];

    current = preferences[kBlurColoringMode];
    _blurColoringMode = current ? (BlurColoringMode)[current intValue] :
                                     BasedOnArtwork;

    current = preferences[kBlurRadius];
    _blurRadius = current ? current : @(22.0f);

    current = preferences[kAnimateArtwork];
    _animateArtwork = current && [current boolValue];

    current = preferences[kArtworkCornerRadiusPercentage];
    _artworkCornerRadiusPercentage = current ? [current intValue] : 10;

    current = preferences[kArtworkWidthPercentage];
    _artworkWidthPercentage = current ? [current intValue] : 70;

    current = preferences[kArtworkYOffsetPercentage];
    _artworkYOffsetPercentage = current ? [current intValue] : 0;

    current = preferences[kCanvasEnabled];
    _canvasEnabled = !current || [current boolValue];

    current = preferences[kShakeToPause];
    _shakeToPause = !current || [current boolValue];

    current = preferences[kHideDockBackground];
    _hideDockBackground = !current || [current boolValue];

    current = preferences[kPauseContentWithMedia];
    _pauseContentWithMedia = !current || [current boolValue];
}

- (void)_updateStaticColor:(NSDictionary *)preferences {
    NSString *current = preferences[kStaticColor];
    _staticColor = current ? LCPParseColorString(current, nil) : UIColor.blackColor;
}

- (void)_updateConfigurationWithDictionary:(NSDictionary *)preferences {
    NSNumber *current = preferences[kTintFolderIcons];
    if (current) {
        BOOL tintFolderIcons = [current boolValue];
        if (tintFolderIcons != _tintFolderIcons) {
            _tintFolderIcons = tintFolderIcons;

            dispatch_async(dispatch_get_main_queue(), ^{
                SBIconController *iconController = getIconController();
                [self _colorFolderIconsWithIconController:iconController
                                     rootFolderController:[iconController _rootFolderController]
                                                   revert:!tintFolderIcons];
            });
        }
    }

    current = preferences[kArtworkEnabled];
    if (current) {
        BOOL artworkEnabled = [current boolValue];
        if (artworkEnabled != _artworkEnabled) {
            if (!artworkEnabled) {
                _artworkIdentifier = nil;
                _artworkImage = nil;
                [self _unsubscribeToArtworkChanges];
            } else {
                [self _subscribeToArtworkChanges];
            }
        }
    }

    current = preferences[kOnlyBackground];
    if (current) {
        BOOL onlyBackground = current && [current boolValue];
        if (onlyBackground != _onlyBackground)
            [self _updateArtworkImage:onlyBackground];
    }

    current = preferences[kArtworkCornerRadiusPercentage];
    if (current) {
        int artworkCornerRadiusPercentage = [current intValue];
        if (artworkCornerRadiusPercentage != _artworkCornerRadiusPercentage) {
            _artworkCornerRadiusPercentage = artworkCornerRadiusPercentage;
            [self _updateArtworkCornerRadius];
        }
    }

    current = preferences[kAnimateArtwork];
    BOOL animateArtwork = current && [current boolValue];
    current = preferences[kCanvasEnabled];
    BOOL canvasEnabled = !current || [current boolValue];

    if (current && canvasEnabled != _canvasEnabled) {
        if (!canvasEnabled) {
            _previousCanvasURL = _canvasURL;
            _previousCanvasAsset = _canvasAsset;

            _artworkImage = _canvasArtworkImage;
            _canvasURL = nil;
            _canvasAsset = nil;
            _canvasThumbnail = nil;
            _canvasArtworkImage = nil;
            [self _getColorInfoWithStaticColorForImage:_artworkImage];

            if (_mode == Canvas) {
                _mode = Artwork;
                _previousMode = Canvas;
            }
            [self _unregisterEventsForCanvasMode];

            /* Don't disable auto play pause events
               if artwork animation is enabled. */
            if (!animateArtwork)
                [self _unregisterAutoPlayPauseEvents];
        } else {
            if (_previousCanvasURL) {
                _canvasURL = _previousCanvasURL;
                _canvasAsset = _previousCanvasAsset;
                _canvasArtworkImage = _artworkImage;

                _mode = Canvas;
                _previousMode = Artwork;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _registerEventsForCanvasMode];
            });
        }
    }

    if (_animateArtwork != animateArtwork) {
        _animateArtwork = animateArtwork;
        [self _updateArtworkCornerRadius];

        if (animateArtwork) {
            [self _registerAutoPlayPauseEvents];
        } else {
            // Restore views from previous animation
            _shouldRemoveRotation = YES;

            if (!canvasEnabled)
                [self _unregisterAutoPlayPauseEvents];
        }
    }

    current = preferences[kPauseContentWithMedia];
    if (current) {
        BOOL pauseContentWithMedia = [current boolValue];
        if (pauseContentWithMedia != _pauseContentWithMedia) {
            if (pauseContentWithMedia) {
                [self _subscribeToMediaPlayPause];
                if (![self isDirty])
                    [self _setPlayPauseState:[[%c(SBMediaController) sharedInstance] isPlaying]];
            } else {
                [self _unsubscribeToMediaPlayPause];
            }
        }
    }

    BOOL updateArtworkFrames;
    current = preferences[kArtworkWidthPercentage];
    if (current) {
        int artworkWidthPercentage = [current intValue];
        updateArtworkFrames = artworkWidthPercentage != _artworkWidthPercentage;
    }

    current = preferences[kArtworkYOffsetPercentage];
    if (current) {
        int artworkYOffsetPercentage = [current intValue];
        if (!updateArtworkFrames)
            updateArtworkFrames = artworkYOffsetPercentage != _artworkWidthPercentage;
    }

    current = preferences[kArtworkBackgroundMode];
    if (current) {
        ArtworkBackgroundMode artworkBackgroundMode = (ArtworkBackgroundMode)[current intValue];
        if (artworkBackgroundMode != _artworkBackgroundMode) {
            if (_artworkImage && !_canvasURL) {
                _blurredImage = nil;
                _colorInfo = nil;

                if (artworkBackgroundMode == StaticColor)
                    [self _updateStaticColor:preferences];

                // Updating these here as the updated values are required below
                _artworkBackgroundMode = artworkBackgroundMode;
                [self _getColorInfoWithStaticColorForImage:_artworkImage];

                // This requires the _colorInfo to be updated
                if (artworkBackgroundMode == BlurredImage)
                    [self _updateBlurEffect];
            }
        } else if (_artworkBackgroundMode == StaticColor) {
            // Static color might have changed, we have to read it to check
            UIColor *previousStaticColor = _staticColor;
            [self _updateStaticColor:preferences];
            if (![previousStaticColor isEqual:_staticColor])
                [self _getColorInfoWithStaticColorForImage:_artworkImage];
        }
    }

    if (_artworkBackgroundMode == BlurredImage) {
        current = preferences[kBlurRadius];
        BOOL shouldUpdateBlur = NO;
        if (current && ![current isEqualToNumber:_blurRadius] && _artworkImage) {
            _blurRadius = current;
            shouldUpdateBlur = YES;
        } else {
            current = preferences[kBlurColoringMode];
            if (current) {
                BlurColoringMode blurColoringMode = (BlurColoringMode)[current intValue];
                if (blurColoringMode != _blurColoringMode) {
                    _blurColoringMode = blurColoringMode;
                    shouldUpdateBlur = YES;
                }
            }
        }

        if (shouldUpdateBlur) {
            [self _updateBlurEffect];
            [self _updateBlur];
        }
    }

    [self _fillPropertiesFromSettings:preferences];

    if (updateArtworkFrames)
        [self _updateArtworkFrames];

    if ([self _allowActivate])
        [self _updateOnMainQueueWithContent:[self hasContent]];
}

- (void)_updateBlur {
    BOOL blur = ![_blurRadius isEqualToNumber:@0];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc updateBlurEffect:blur];
    });
}

- (void)_updateArtworkCornerRadius {
    int cornerRadiusPercentage = [self artworkCornerRadiusPercentage];
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc updateArtworkCornerRadius:cornerRadiusPercentage];
    });
}

- (void)_updateArtworkFrames {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc updateArtworkWidthPercentage:_artworkWidthPercentage
                           yOffsetPercentage:_artworkYOffsetPercentage];
    });
}

- (void)_updateArtworkImage:(BOOL)onlyBackground {
    UIImage *artwork = onlyBackground ? nil : _artworkImage;

    if (_animateArtwork) {
        if (onlyBackground) {
            _shouldAddRotation = NO;
            _shouldRemoveRotation = YES;
        }
        else {
            _shouldRemoveRotation = NO;
            _shouldAddRotation = YES;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc setArtwork:artwork];
    });
}

- (void)_subscribeToMediaPlayPause {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_playPauseChanged:)
                                                 name:(__bridge NSString *)kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification
                                               object:nil];
}

- (void)_unsubscribeToMediaPlayPause {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:(__bridge NSString *)kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification
                                                  object:nil];
}

- (void)_subscribeToArtworkChanges {
    if (_subscribedToArtwork)
        return;

    _subscribedToArtwork = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_nowPlayingChanged:)
                                                 name:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification
                                               object:nil];
}

- (void)_unsubscribeToArtworkChanges {
    if (!_subscribedToArtwork)
        return;

    _subscribedToArtwork = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification
                                                  object:nil];
}

- (void)_registerAutoPlayPauseEvents {
    if (_registeredAutoPlayPauseEvents)
        return;
    _registeredAutoPlayPauseEvents = YES;

    [self _registerScreenEvent];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_currentAppChanged:)
                                                 name:kSBApplicationProcessStateDidChange
                                               object:nil];
}

- (void)_unregisterAutoPlayPauseEvents {
    if (!_registeredAutoPlayPauseEvents)
        return;
    _registeredAutoPlayPauseEvents = NO;

    [self _unregisterScreenEvent];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSBApplicationProcessStateDidChange
                                                  object:nil];
}

- (void)_registerEventsForCanvasMode {
    _rbs_center = [CPDistributedMessagingCenter centerNamed:SA_IDENTIFIER];
    rocketbootstrap_distributedmessagingcenter_apply(_rbs_center);
    [_rbs_center runServerOnCurrentThread];
    [_rbs_center registerForMessageName:kSpotifyMessage
                                 target:self
                               selector:@selector(_handleIncomingMessage:withUserInfo:)];

    [self _registerAutoPlayPauseEvents];
}

- (void)_unregisterEventsForCanvasMode {
    [_rbs_center unregisterForMessageName:kSpotifyMessage];
    [_rbs_center stopServer];
    _rbs_center = nil;
}

- (BOOL)_registerScreenEvent {
    uint32_t result = notify_register_dispatch(kNotificationNameDidChangeDisplayStatus,
        &_notifyTokenForDidChangeDisplayStatus,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
        ^(int _) {
            uint64_t state;
            notify_get_state(_notifyTokenForDidChangeDisplayStatus, &state);
            _screenTurnedOn = BOOL(state);

            BOOL contentVisible = _screenTurnedOn && !_insideApp;

            if (![self _canAutoPlayPause]) {
                // Check pending animation removal
                if (_shouldRemoveRotation && contentVisible)
                    [self _removeArtworkRotation];
                return;
            }

            /* If animation needs to be added, do that instead of resuming nothing */
            if (contentVisible && [self hasAnimatingArtwork]) {
                if (_hasPendingArtworkChange)
                    [self _updateOnMainQueueWithContent:YES];
                // Check pending animation addition
                else if (_shouldAddRotation)
                    [self _addArtworkRotation];
            }

            if (!_insideApp && [self hasContent])
                [self _setPlayPauseState:_screenTurnedOn];
        });

    return result == NOTIFY_STATUS_OK;
}

- (BOOL)_unregisterScreenEvent {
    return notify_cancel(_notifyTokenForDidChangeDisplayStatus) == NOTIFY_STATUS_OK;
}

- (void)_setPlayPauseState:(BOOL)newState {
    if (_playing == newState)
        return;

    _manuallyPaused = NO;
    _playing = newState;

    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc togglePlayPauseWithState:newState];
    });
}

- (void)_sendCanvasUpdatedEvent {
    if (_canvasURL) {
        [self _thumbnailFromAsset:_canvasAsset withCompletion:^(UIImage *image) {
            _canvasThumbnail = image;

            if (![self _allowActivate]) {
                if (image)
                    _colorInfo = [SAImageHelper colorsForImage:image];
            } else {
                _colorInfo = image ? [SAImageHelper colorsForImage:image] : nil;
                [self _updateOnMainQueueWithContent:YES];
            }
        }];
        return;
    } else {
        [self _updateWithContent:NO];
    }
}

- (void)_tryHideDock:(BOOL)hide {
    if (hide == _dockHidden)
        return;

    [self _hideDock:hide];
}

- (void)_hideDock:(BOOL)hide {
    _dockHidden = hide;

    SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
    SBDockView *dockView = [rootFolderController.contentView dockView];
    if (!dockView)
        return;

    UIView *background = MSHookIvar<UIView *>(dockView, "_backgroundView");

    if (!hide)
        background.hidden = NO;

    [_inChargeController performLayerOpacityAnimation:background.layer
                                                 show:!hide
                                           completion:^{
        if (hide)
            background.hidden = YES;
    }];
}

- (void)_updateWithContent:(BOOL)content {
    _hasPendingArtworkChange = NO;

    id object = nil;
    if (content) {
        object = self;
        [self _overrideLabels];
    } else {
        [self _revertLabels];
    }

    SBCoverSheetPrimarySlidingViewController *slidingViewController = getSlidingViewController();
    // This method is only initiated on some firmwares
    if (_enabledMode != HomescreenMode &&
        [slidingViewController respondsToSelector:@selector(sa_hideWallpaperView)])
        [slidingViewController sa_hideWallpaperView:content];

    if (_hideDockBackground)
        [self _tryHideDock:content];

    for (SAViewController *vc in _viewControllers)
        [vc artworkUpdated:object];
}

- (void)_updateOnMainQueueWithContent:(BOOL)content {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _updateWithContent:content];
    });
}

/* Only allow activate when the media widget is showing */
- (BOOL)_allowActivate {
    return _mediaWidgetActive;
}

- (BOOL)_canAutoPlayPause {
    if (![self hasPlayableContent])
        return NO;

    /* If the user manually paused the video,
       do not resume on screen turn on event */
    if (!_playing && _manuallyPaused)
        return NO;

    if (_pauseContentWithMedia && !_mediaPlaying)
        return NO;

    if (![self _allowActivate])
        return NO;

    return YES;
}

- (void)_currentAppChanged:(NSNotification *)notification {
    SBApplication *app = notification.object;
    if ([app.bundleIdentifier isEqualToString:@"com.apple.MusicUIService"])
        return;

    id<ProcessStateInfo> processState = [app respondsToSelector:@selector(internalProcessState)] ?
                                        app.internalProcessState : app.processState;
    BOOL insideApp = processState.foreground && processState.visibility != ForegroundObscured;

    /* Don't update if nothing changed */
    if (_insideApp == insideApp)
        return;
    _insideApp = insideApp;

    BOOL contentVisible = !_insideApp && ![self _isDeviceLocked];

    if (![self _canAutoPlayPause]) {
        if (_shouldRemoveRotation)
            [self _removeArtworkRotation];
        return;
    }

    /* If animation needs to be added, do that instead of resuming nothing */
    if (contentVisible && [self hasAnimatingArtwork]) {
        if (_hasPendingArtworkChange)
            [self _updateOnMainQueueWithContent:YES];
        else if (_shouldAddRotation)
            [self _addArtworkRotation];
    }

    [self _setPlayPauseState:!insideApp];
}

- (void)_addArtworkRotation {
    _shouldAddRotation = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc addArtworkRotation];
    });
}

- (void)_removeArtworkRotation {
    _shouldRemoveRotation = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc removeArtworkRotation];
    });
}

- (BOOL)_isDeviceLocked {
    SpringBoard *springBoard = (SpringBoard *)[%c(SpringBoard) sharedApplication];
    return [[springBoard pluginUserAgent] deviceIsLocked];
}

- (void)_nowPlayingAppChanged:(NSNotification *)notification {
    SBMediaController *mediaController = notification.object;
    _bundleID = mediaController.nowPlayingApplication.bundleIdentifier;

    if (!_bundleID) {
        [self _setModeToNone];
        [self _updateOnMainQueueWithContent:NO];
    } else if ([_disabledApps containsObject:_bundleID] || [_bundleID isEqualToString:kSpotifyBundleID]) {
        [self _unsubscribeToArtworkChanges];
        _ignoredImages = nil;
    } else {
        [self _subscribeToArtworkChanges];

        if ([_bundleID isEqualToString:kDeezerBundleID])
            _ignoredImages = @[[SAImageHelper stringToImage:DEEZER_PLACEHOLDER_BASE64],
                               [SAImageHelper stringToImage:DEEZER_PLACEHOLDER_iOS13_BASE64]];
        else
            _ignoredImages = nil;
    }
}

- (void)_setModeToNone {
    [self _setPlayPauseState:NO];

    _mode = None;
    _previousMode = None;

    _canvasURL = nil;
    _canvasAsset = nil;

    _colorInfo = nil;
    _blendedCDBackgroundColor = nil;
    _legibilitySettings = nil;

    _artworkImage = nil;
    _blurredImage = nil;

    _artworkIdentifier = nil;
    _trackIdentifier = nil;
    _ignoredImages = nil;
}

/* Backup mechanism to get the artwork data */
- (void)_getArtworkFromMediaRemote {
    [self _fetchArtwork:^(UIImage *image, NSString *trackIdentifier, NSString *artworkIdentifier) {
        if (![_artworkIdentifier isEqualToString:artworkIdentifier])
            [self _processImageCompletion:trackIdentifier artworkIdentifier:artworkIdentifier](image);
    }];
}

- (void)_fetchArtwork:(void (^)(UIImage *, NSString *, NSString *))completion {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        NSDictionary *dict = (__bridge NSDictionary *)information;

        NSData *imageData = dict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
        if (!imageData)
            return completion(nil, nil, nil);

        // HBLogDebug(@"We got the information: %@ – %@",
        //            dict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTitle],
        //            dict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtist]);

        completion([UIImage imageWithData:imageData],
                   dict[kMRMediaRemoteNowPlayingInfoContentItemIdentifier],
                   dict[kMRMediaRemoteNowPlayingInfoArtworkIdentifier]);
    });
}

- (void (^)(UIImage *))_processImageCompletion:(NSString *)trackIdentifier
                             artworkIdentifier:(NSString *)artworkIdentifier {
    return ^(UIImage *image) {
        // HBLogDebug(@"base64: %@, image: %@", [SAImageHelper imageToString:image], image);
        if (!image || [self _candidatePlaceholderImage:image]) {
            // In case listening to an item without artwork, there no real
            // artwork will follow the default placeholder. To solve that,
            // we need to start a timer here and if some other call was
            // received after that, cancel it. Otherwise hide all views.
            if ([self hasContent]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_placeholderArtworkTimer invalidate];
                    _placeholderArtworkTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                                target:self
                                                                              selector:@selector(hide)
                                                                              userInfo:nil
                                                                               repeats:NO];
                });
            }
            return;
        } else if (_placeholderArtworkTimer) {
            [_placeholderArtworkTimer invalidate];
            _placeholderArtworkTimer = nil;
        }

        if (_canvasURL) {
            _canvasArtworkImage = image;
            return;
        }

        [self _updateModeToArtworkWithTrackIdentifier:trackIdentifier];

        _trackIdentifier = trackIdentifier;
        /* Skip showing artwork for canvas track when switching
           (some weird bug that sends the old artwork when changing track) */

        // In case the previous canvas track has the same artwork as the next
        // non-canvas track, we need to hide the canvas stuff here. But we cannot do
        // that since we don't know if it is the bug, where the artwork for the
        // previous canvas track is sent, or not.

        // Solution:
        // The "real" artwork is sent very quickly after the "incorrect" one.
        // If we didn't receive a new (read: "real") artwork during some time period,
        // consider the first and only received artwork as real.
        // However, if another artwork (that's not same on the pixels) does come within
        // that time, discard the first artwork (read: "incorrect") and stop the timer.

        // The timer should only be used when changed content from canvas to artwork
        // (_canvasURL = nil => useTimer).
        if (_previousMode == Canvas && _canvasArtworkImage &&
            [SAImageHelper compareImage:_canvasArtworkImage withImage:image]) {

            if (_useCanvasArtworkTimer) {
                _useCanvasArtworkTimer = NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 0.5f was not enough
                    _canvasArtworkTimer = [NSTimer scheduledTimerWithTimeInterval:1.2f
                                                                           target:self
                                                                         selector:@selector(_canvasArtworkTimerFired:)
                                                                         userInfo:nil
                                                                          repeats:NO];
                });
            } else {
                _canvasArtworkImage = nil;
            }
            return;
        } else if (_canvasArtworkTimer) {
            // If a second new artwork event occurred before
            // the timer fired, cancel the timer.
            [_canvasArtworkTimer invalidate];
        }

        [self _secondPartForImage:image
                artworkIdentifier:artworkIdentifier];
    };
}

- (void)_nowPlayingChanged:(NSNotification *)notification {
    // Reset these on track change
    _previousCanvasURL = nil;
    _previousCanvasAsset = nil;

    NSDictionary *userInfo = notification.userInfo;
    NSArray *contentItems = userInfo[@"kMRMediaRemoteUpdatedContentItemsUserInfoKey"];

    /* It seems that in the case of no contentItems available,
       invoking the media remote request down below once results
       in the next notification calls have provides them.
       This seems to happen on some 3rd party media clients on
       iOS 13. */
    if (!contentItems || contentItems.count == 0)
        return [self _getArtworkFromMediaRemote];

    MRContentItem *contentItem = contentItems[0];
    NSDictionary *info = [contentItem dictionaryRepresentation];

    NSString *trackIdentifier = info[@"identifier"];
    NSDictionary *metadata = info[@"metadata"];

    if (!trackIdentifier || !metadata)
        return;

    /* Apple changed the structure in the iOS 13 Music app;
       the artworkIdentifier is not always included anymore.
       For some reason, if not always using the MediaRemote
       approach, concurrent calls occur despite comparing
       the _artworkImage, which result in no animation. */
    NSString *artworkIdentifier = metadata[@"artworkIdentifier"];
    if (!artworkIdentifier ||
        [_bundleID isEqualToString:kMusicBundleID])
        return [self _getArtworkFromMediaRemote];
    else if ([_artworkIdentifier isEqualToString:artworkIdentifier])
        return;

    [[%c(MPCMediaRemoteController) controllerForPlayerPath:[%c(MPCPlayerPath) deviceActivePlayerPath]]
        onCompletion:^(MPCMediaRemoteController *controller) {
            float width = [UIScreen mainScreen].nativeBounds.size.width;
            MPCFuture *request;
            if ([controller respondsToSelector:@selector(contentItemArtworkForContentItemIdentifier:artworkIdentifier:size:)])
                request = [controller contentItemArtworkForContentItemIdentifier:trackIdentifier
                                                               artworkIdentifier:artworkIdentifier
                                                                            size:CGSizeMake(width, width)];
            else
                request = [controller contentItemArtworkForIdentifier:trackIdentifier
                                                                 size:CGSizeMake(width, width)];
            [request onCompletion:[self _processImageCompletion:trackIdentifier
                                              artworkIdentifier:artworkIdentifier]];
        }
    ];
}

- (void)_secondPartForImage:(UIImage *)image
          artworkIdentifier:(NSString *)artworkIdentifier {
    if (_artworkImage && [self _candidateSameAsPreviousArtwork:image]) {
        if (![self changedContent])
            [self _updateModeToArtworkWithTrackIdentifier:_trackIdentifier];
        return;
    }

    [self _updateArtworkWithImage:image];
    _artworkIdentifier = artworkIdentifier;
}

- (void)_canvasArtworkTimerFired:(NSTimer *)timer {
    NSString *artworkIdentifier = timer.userInfo[@"artworkIdentifier"];
    [self _secondPartForImage:_canvasArtworkImage
            artworkIdentifier:artworkIdentifier];
    _canvasArtworkImage = nil;
    timer = nil;
}

- (void)_playPauseChanged:(NSNotification *)notification {
    NSString *key = CFBridgingRelease(kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey);
    _mediaPlaying = [notification.userInfo[key] boolValue];

    if (![self hasPlayableContent])
        return;

    if ([self isDirty])
        return;

    /* If the user manually paused the video,
       do not resume on media playback state change */
    if (!_playing && _manuallyPaused)
        return;

    [self _setPlayPauseState:_mediaPlaying];
}

- (void)_updateModeToArtworkWithTrackIdentifier:(NSString *)trackIdentifier {
    if (_mode == Artwork && ![_trackIdentifier isEqualToString:trackIdentifier])
        _previousMode = None;
    else {
        if (_mode == Canvas)
            _previousMode = Canvas;
        _mode = Artwork;
    }
}

- (void)_thumbnailFromAsset:(AVAsset *)asset withCompletion:(void(^)(UIImage *))completion {
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];

    [imageGenerator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:kCMTimeZero]]
                                         completionHandler:^(CMTime requestedTime,
                                                             CGImageRef cgImage,
                                                             CMTime actualTime,
                                                             AVAssetImageGeneratorResult result,
                                                             NSError *error) {
        if (result == AVAssetImageGeneratorSucceeded) {
            completion([UIImage imageWithCGImage:cgImage]);
        } else {
            #ifdef DEBUG
            HBLogError(@"Error retrieving video placeholder: %@", error.localizedDescription);
            #endif
            completion(nil);
        }
    }];
}

- (BOOL)_candidateSameAsPreviousArtwork:(UIImage *)candidate {
    return [UIImagePNGRepresentation(_artworkImage) isEqualToData:UIImagePNGRepresentation(candidate)];
}

- (BOOL)_candidatePlaceholderImage:(UIImage *)candidate {
    // All placeholder images are squared
    if (candidate.size.width != candidate.size.height)
        return NO;

    if (_ignoredImages) {
        for (UIImage *ignoredImage in _ignoredImages)
            if ([SAImageHelper compareImage:candidate withImage:ignoredImage])
                return YES;
    }
    return NO;
}

- (UIColor *)_getColorFlowBackgroundColor:(UIImage *)image {
    if (![%c(CFWColorInfo) respondsToSelector:@selector(colorInfoWithAnalyzedInfo:)] ||
        ![%c(CFWBucket) respondsToSelector:@selector(analyzeImage:resize:)]) {
        return nil;
    }

    AnalyzedInfo info = [%c(CFWBucket) analyzeImage:image resize:YES];
    CFWColorInfo *colorInfo = [%c(CFWColorInfo) colorInfoWithAnalyzedInfo:info];
    return colorInfo.backgroundColor;
} 

- (void)_getColorInfoWithStaticColorForImage:(UIImage *)image {
    UIColor *customColor = nil;
    if (_artworkBackgroundMode == StaticColor)
        customColor = _staticColor;
    else if (_artworkBackgroundMode == MatchingColor && _colorFlowEnabled)
        customColor = [self _getColorFlowBackgroundColor:image];

    _colorInfo = [SAImageHelper colorsForImage:_artworkImage
                     withStaticBackgroundColor:customColor];

    UIColor *toMixColor = [SAImageHelper colorIsLight:_colorInfo.backgroundColor] ?
                          UIColor.blackColor : UIColor.whiteColor;
    _blendedCDBackgroundColor = [[SAImageHelper blendColor:_colorInfo.backgroundColor
                                                 withColor:toMixColor
                                                percentage:0.5] colorWithAlphaComponent:0.8];
}

- (void)_updateArtworkWithImage:(UIImage *)image {
    BOOL coldArtworkStart = _artworkImage = nil;
    _artworkImage = image;

    if (image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self _getColorInfoWithStaticColorForImage:image];

            if (_artworkBackgroundMode == BlurredImage)
                [self _updateBlurEffect];

            if ([self _allowActivate]) {
                /* If this is the not first artwork that's being shown,
                   we need to wait with the change of artwork if animiating. */
                if (!coldArtworkStart &&
                    ![self changedContent] &&
                    [self hasAnimatingArtwork] &&
                    [self isDirty]) {
                    _hasPendingArtworkChange = YES;
                } else {
                    [self _updateOnMainQueueWithContent:YES];
                }
            }
        });
        return;
    }

    [self _updateOnMainQueueWithContent:NO];
}

- (void)_updateLegibilitySettings {
    _legibilitySettings = [self _createLegibilitySettings];
}

- (BOOL)_shouldUseDarkText {
    switch (_blurColoringMode) {
        case BasedOnDarkMode:
            if (@available(iOS 13, *)) {
                return [UIScreen mainScreen].traitCollection.userInterfaceStyle != UIUserInterfaceStyleDark;
                break;
            }

        case BasedOnArtwork:
            return _colorInfo.hasDarkTextColor;

        case LightBlurBlackText:
            return YES;

        case DarkBlurWhiteText:
        default:
            return NO;
    }
}

- (_UILegibilitySettings *)_createLegibilitySettings {
    if (_artworkBackgroundMode == BlurredImage)
        return [self _legibilitySettingsForDarkText:[self _shouldUseDarkText]];

    SAColorInfo *info = _colorInfo;
    return info ? [self _legibilitySettingsForDarkText:info.hasDarkTextColor] : nil;
}

- (_UILegibilitySettings *)_legibilitySettingsForDarkText:(BOOL)darkText {
    return [_UILegibilitySettings sharedInstanceForStyle:darkText ? 2 : 1];
}

- (void)_overrideLabels {
    if (!_colorInfo)
        return [self _revertLabels];

    [self _updateLegibilitySettings];

    if (_enabledMode != LockscreenMode)
        [self _setAppLabelsLegibilitySettingsAndRevert:NO];

    [self _overrideStatusBar];

    if (_enabledMode != HomescreenMode)
        [self _updateLockscreenLabels];
}

- (void)_revertLabels {
    _legibilitySettings = nil;

    if (_enabledMode != LockscreenMode)
        [self _setAppLabelsLegibilitySettingsAndRevert:YES];

    [self _revertStatusBar];

    if (_enabledMode != HomescreenMode)
        [self _updateLockscreenLabels];
}

- (_UILegibilitySettings *)_getOriginalHomescreenLegibilitySettings {
    return [getWallpaperController() legibilitySettingsForVariant:1];
}

- (_UILegibilitySettings *)_getOriginalLockscreenLegibilitySettings {
    return [getCoverSheetViewController().legibilityProvider currentLegibilitySettings];
}

- (void)_setAppLabelsLegibilitySettingsAndRevert:(BOOL)revert {
    SBIconController *iconController = getIconController();
    _UILegibilitySettings *legibilitySettings = revert ?
                                                [self _getOriginalHomescreenLegibilitySettings] :
                                                _legibilitySettings;

    [iconController setLegibilitySettings:legibilitySettings];

    SBRootFolderController *rootFolderController = [iconController _rootFolderController];
    [rootFolderController.contentView.pageControl setLegibilitySettings:legibilitySettings];
    [self _colorFolderIconsWithIconController:iconController
                         rootFolderController:rootFolderController
                                       revert:revert];
}

- (void)_colorFolderIconsWithIconController:(SBIconController *)iconController
                       rootFolderController:(SBRootFolderController *)rootFolderController
                                     revert:(BOOL)revert {
    if (!revert && (_canvasThumbnail || _artworkImage) && _tintFolderIcons) {
        UIColor *color = _colorInfo.backgroundColor;
        if ([SAImageHelper colorIsLight:color])
            color = [SAImageHelper darkerColorForColor:color];
        else
            color = [SAImageHelper lighterColorForColor:color];
        _folderColor = [color colorWithAlphaComponent:0.8];
        _folderBackgroundColor = [color colorWithAlphaComponent:0.6];
    } else if (!_folderColor) {
        return; // If we haven't already colorized, don't bother reverting it
    } else {
        _folderColor = nil;
        _folderBackgroundColor = nil;
        if (%c(_SBIconWallpaperBackgroundProvider))
            [[%c(_SBIconWallpaperBackgroundProvider) sharedInstance] _updateAllClients];
    }

    if ([%c(SBFolderIconImageView) instancesRespondToSelector:@selector(sa_colorizeFolderBackground:)])
        [self _colorizeVisibleFolderIcons:rootFolderController.currentIconListView
                                    color:_folderColor
                                  animate:YES];
    else
        [self _colorizeFolderIcons:rootFolderController.iconListViews
                             color:_folderColor
                           animate:YES];

    // If there is any open folder, colorize the background
    SBFolderController *openedFolder = [iconController _openFolderController];
    if (openedFolder) {
        SBFloatyFolderView *folderView = openedFolder.contentView;
        SBFloatyFolderBackgroundClipView *clipView = MSHookIvar<SBFloatyFolderBackgroundClipView *>(folderView,
                                                                                                    "_scrollClipView");
        [clipView nu_colorizeFolderBackground:_folderBackgroundColor];
    }
}

// iOS 13
- (void)_colorizeVisibleFolderIcons:(SBIconListView *)listView
                              color:(UIColor *)color
                            animate:(BOOL)animate {
    [listView enumerateIconsUsingBlock:^(SBIcon *icon) {
        if (![icon isKindOfClass:%c(SBFolderIcon)])
            return;

        SBIconView *iconView = [listView iconViewForIcon:icon];
        SBFolderIconImageView *folderIconImageView = [iconView _folderIconImageView];
        if (![folderIconImageView respondsToSelector:@selector(sa_colorizeFolderBackground:)]) {
            HBLogError(@"%@ (supposed to be %@) does not respond to sa_colorizeFolderBackground:",
                       folderIconImageView, %c(SBFolderIconImageView));
            return;
        }

        if (animate) {
            [UIView transitionWithView:iconView.folderIconBackgroundView
                              duration:ANIMATION_DURATION
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                [folderIconImageView sa_colorizeFolderBackground:color];
                            }
                            completion:nil];
        } else {
            [folderIconImageView sa_colorizeFolderBackground:color];
        }
    }];
}

// iOS 12
- (void)_colorizeFolderIcons:(NSArray<SBRootIconListView *> *)iconListViews
                       color:(UIColor *)color
                     animate:(BOOL)animate {
    for (SBRootIconListView *listView in iconListViews) {
        SBIconViewMap *viewMap = listView.viewMap;
        SBIconListModel *listModel = listView.model;

        [listModel enumerateFolderIconsUsingBlock:^(SBFolderIcon *folderIcon) {
            SBFolderIconView *iconView = (SBFolderIconView *)[viewMap mappedIconViewForIcon:folderIcon];
            SBFolderIconBackgroundView *backgroundView = [iconView iconBackgroundView];

            if (animate) {
                [UIView transitionWithView:backgroundView
                                  duration:ANIMATION_DURATION
                                   options:UIViewAnimationOptionTransitionCrossDissolve
                                animations:^{
                                    [iconView sa_colorizeFolderBackground:backgroundView color:color];
                                }
                                completion:nil];
            } else {
                [iconView sa_colorizeFolderBackground:backgroundView color:color];
            }
        }];
    }
}

- (void)_overrideStatusBar {
    _UILegibilitySettings *homescreenSettings = nil;
    _UILegibilitySettings *lockscreenSettings = nil;
    if (_enabledMode == BothMode)
        lockscreenSettings = homescreenSettings = _legibilitySettings;
    else if (_enabledMode == LockscreenMode)
        lockscreenSettings = _legibilitySettings;
    else
        homescreenSettings = _legibilitySettings;

    [self _setStatusBarHomescreenSettings:homescreenSettings lockscreenSettings:lockscreenSettings];
}

- (void)_revertStatusBar {
    _UILegibilitySettings *originalHomescreenSettings = nil;
    _UILegibilitySettings *originalLockscreenSettings = nil;

    if (_enabledMode == BothMode)
        originalLockscreenSettings = originalHomescreenSettings = [self _getOriginalHomescreenLegibilitySettings];
    else if (_enabledMode == LockscreenMode)
        originalLockscreenSettings = [self _getOriginalLockscreenLegibilitySettings];
    else
        originalHomescreenSettings = [self _getOriginalHomescreenLegibilitySettings];

    [self _setStatusBarHomescreenSettings:originalHomescreenSettings lockscreenSettings:originalLockscreenSettings];
}

- (void)_setStatusBarHomescreenSettings:(_UILegibilitySettings *)homescreenSettings
                     lockscreenSettings:(_UILegibilitySettings *)lockscreenSettings {
    SBAppStatusBarAssertionManager *assertionManager = [%c(SBAppStatusBarAssertionManager) sharedInstance];

    void (^homescreenCompletion)(SBAppStatusBarSettingsAssertion *) = nil;
    void (^lockscreenCompletion)(SBAppStatusBarSettingsAssertion *) = nil;

    if (homescreenSettings)
         homescreenCompletion = [self _assertionCompletionWithSettings:homescreenSettings];

    if (homescreenSettings == lockscreenSettings)
        lockscreenCompletion = homescreenCompletion;
    else if (lockscreenSettings)
        lockscreenCompletion = [self _assertionCompletionWithSettings:lockscreenSettings];

    if (_enabledMode == BothMode) {
        [assertionManager _enumerateAssertionsToLevel:HomescreenAssertionLevel
                                            withBlock:homescreenCompletion];
        [assertionManager _enumerateAssertionsToLevel:FullscreenAlertAnimationAssertionLevel
                                            withBlock:lockscreenCompletion];
    } else if (_enabledMode == LockscreenMode) {
        [assertionManager _enumerateAssertionsToLevel:FullscreenAlertAnimationAssertionLevel
                                            withBlock:lockscreenCompletion];
    } else {
        [assertionManager _enumerateAssertionsToLevel:HomescreenAssertionLevel
                                            withBlock:homescreenCompletion];
    }
}

- (void (^)(SBAppStatusBarSettingsAssertion *))_assertionCompletionWithSettings:(_UILegibilitySettings *)settings {
    return ^(SBAppStatusBarSettingsAssertion *assertion) {
        assertion.sa_legibilitySettings = settings;
        // This method is hooked in Tweak.xm and will change the color from there.
        [assertion modifySettingsWithBlock:nil];
    };
}

- (void)_updateLockscreenLabels {
    [getCoverSheetViewController() _updateActiveAppearanceForReason:nil];
}

- (UIBlurEffectStyle)_getBlurStyle {
    if (_artworkBackgroundMode == BlurredImage)
        return [self _shouldUseDarkText] ?
               UIBlurEffectStyleLight : UIBlurEffectStyleDark;

    return [SAImageHelper colorIsLight:_colorInfo.backgroundColor] ?
           UIBlurEffectStyleLight : UIBlurEffectStyleDark;
}

- (void)_updateBlurEffect {
    _blurredImage = _artworkImage;

    UIBlurEffectStyle style = [self _getBlurStyle];

    // Only update blur effect if a change was detected
    if (_blurEffect._style != style || ![_blurRadius isEqualToNumber:_blurEffect.blurRadius])
        _blurEffect = [SABlurEffect effectWithStyle:style blurRadius:_blurRadius];
}

- (void)_changeModeToCanvas {
    if (_mode == Canvas)
        _previousMode = None;
    else {
        if (_mode == Artwork)
            _previousMode = Artwork;
        _mode = Canvas;
    }
}

- (void)_handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    NSString *urlString = dict[kCanvasURL];
    if (!urlString) {
        _useCanvasArtworkTimer = YES;
        _canvasURL = nil;
        _canvasAsset = nil;

        if ([_disabledApps containsObject:kSpotifyBundleID])
            [self _sendCanvasUpdatedEvent];
        else if (dict[kArtwork]) {
            [self _updateModeToArtworkWithTrackIdentifier:dict[kTrackIdentifier]];
            [self _updateArtworkWithImage:[UIImage imageWithData:dict[kArtwork]]];
            return;
        }
    } else {
        if (_placeholderArtworkTimer) {
            [_placeholderArtworkTimer invalidate];
            _placeholderArtworkTimer = nil;
        }

        _useCanvasArtworkTimer = NO;
        if (_canvasArtworkTimer) {
            [_canvasArtworkTimer invalidate];
            _canvasArtworkTimer = nil;
        }

        _artworkImage = nil;
        _trackIdentifier = nil;
        _artworkIdentifier = nil;
    }

    if (![urlString isEqualToString:_canvasURL]) {
        _canvasURL = urlString;
        _canvasAsset = [AVAsset assetWithURL:[NSURL URLWithString:urlString]];

        [self _changeModeToCanvas];
        [self _sendCanvasUpdatedEvent];
    }
}

@end
