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

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"
#define kSBApplicationProcessStateDidChange @"SBApplicationProcessStateDidChange"
#define kSBMediaNowPlayingAppChangedNotification @"SBMediaNowPlayingAppChangedNotification"
#define kSpringBoardFinishedStartup "com.apple.springboard.finishedstartup"


@interface NSValue (Missing)
+ (NSValue *)valueWithCMTime:(CMTime)time;
@end

@interface CPDistributedMessagingCenter (Missing)
- (void)unregisterForMessageName:(NSString *)name;
@end

extern SBDashBoardViewController *getDashBoardViewController();
extern _UILegibilitySettings *legibilitySettingsForDarkText(BOOL darkText);
extern SBWallpaperController *getWallpaperController();
extern SBIconController *getIconController();


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

    BOOL _insideApp;
    BOOL _screenTurnedOn;
    BOOL _mediaPlaying;
    BOOL _hasPendingArtworkChange;

    NSString *_canvasURL;

    /* The ones below exist because of Spotify Connect. If playing through
       Connect and then exiting the app, the now playing app will be removed.
       However, when opening the app again, it registers Spotify once again.
       It's just that there are no artwork or canvas events being fired by
       that point. */
    NSString *_bundleID;
    NSString *_previousSpotifyURL;
    AVAsset *_previousSpotifyAsset;
    UIImage *_previousSpotifyArtworkImage;
    // ---

    Mode _mode;
    Mode _previousMode;

    NSMutableArray *_viewControllers;
    UIImage *_placeholderImage;

    BOOL _tintFolderIcons;
    BOOL _artworkEnabled;
    ArtworkBackgroundMode _artworkBackgroundMode;
    UIColor *_staticColor;
    BOOL _canvasEnabled;
    BOOL _animateArtwork;
    BOOL _pauseContentWithMedia;

    /* Storing this as a ivar to prevent always having to traverse all the properties */
    SBLockScreenNowPlayingController *_nowPlayingController;
}

#pragma mark Public

- (void)setupWithPreferences:(NSDictionary *)preferences {
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

    /* This is called once when SpringBoard finished loading,
       thus traversing UI properties is possible here. */
    int springBoardLoadedToken;
    notify_register_dispatch(kSpringBoardFinishedStartup,
        &springBoardLoadedToken,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
        ^(int _) {
            SBDashBoardNotificationAdjunctListViewController *adjunctVC = getDashBoardViewController().
                                                                          mainPageContentViewController.
                                                                          combinedListViewController.
                                                                          adjunctListViewController;
            _nowPlayingController = MSHookIvar<SBLockScreenNowPlayingController *>(adjunctVC,
                                                                                   "_nowPlayingController");
            [_nowPlayingController setEnabled:YES];

            notify_cancel(springBoardLoadedToken);
        }
    );
}

- (BOOL)hasContent {
    return [self hasPlayableContent] || _artworkImage;
}

- (BOOL)hasPlayableContent {
    return [self isCanvasActive] || [self hasAnimatingArtwork];
}

- (BOOL)isCanvasActive {
    return _mode == Canvas;
}

- (BOOL)hasAnimatingArtwork {
    return _mode == Artwork && _animateArtwork && _artworkImage;
}

- (void)setupHaptic {
    _hapticGenerator = [[%c(UIImpactFeedbackGenerator) alloc] initWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)togglePlayManually {
    if (![self hasPlayableContent])
        return;

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

- (void)hide:(BOOL)animated {
    [self _setModeToNone];
    [self _updateOnMainQueueWithContent:NO];
}

// Destroy everything! MOHAHAHA! *evil laugh continues...*
- (void)setTrialEnded {
    _trialEnded = YES;

    [self _unsubscribeToArtworkChanges];
    [self _unregisterEventsForCanvasMode];
    [self _unregisterAutoPlayPauseEvents];
    notify_cancel(_notifyTokenForSettingsChanged);

    [self _setModeToNone];
    _folderColor = nil;
    _folderBackgroundColor = nil;
    _placeholderImage = nil;

    _previousSpotifyURL = nil;
    _previousSpotifyAsset = nil;

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
    return !_canvasURL && _artworkBackgroundMode != BlurredImage;
}

- (void)mediaWidgetDidActivate {
    if (_canvasURL || _artworkImage)
        [self _updateWithContent:YES];
}

#pragma mark Private

- (void)_videoEnded {
    for (SAViewController *vc in _viewControllers)
        [vc replayVideo];
}

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
        _artworkBackgroundMode = MatchingColor;
        _staticColor = nil;
    }

    current = preferences[kAnimateArtwork];
    _animateArtwork = current && [current boolValue];

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
            SBIconController *iconController = getIconController();
            [self _colorFolderIconsWithIconController:iconController
                                 rootFolderController:[iconController _rootFolderController]
                                               revert:!tintFolderIcons];
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

    current = preferences[kAnimateArtwork];
    BOOL animateArtwork = !current || ![current boolValue];
    current = preferences[kCanvasEnabled];
    BOOL canvasEnabled = !current || [current boolValue];

    if (current) {
        if (canvasEnabled != _canvasEnabled) {
            if (!canvasEnabled) {
                _previousSpotifyURL = _canvasURL;
                _previousSpotifyAsset = _canvasAsset;

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
                if (_previousSpotifyURL) {
                    _canvasURL = _previousSpotifyURL;
                    _canvasAsset = _previousSpotifyAsset;
                    _canvasArtworkImage = _artworkImage;

                    _mode = Canvas;
                    _previousMode = Artwork;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self _registerEventsForCanvasMode];
                });
            }
        }
    }

    if (_animateArtwork != animateArtwork) {
        if (animateArtwork)
            [self _registerAutoPlayPauseEvents];
        else if (!canvasEnabled)
            [self _unregisterAutoPlayPauseEvents];
    }

    current = preferences[kPauseContentWithMedia];
    if (current) {
        BOOL pauseContentWithMedia = [current boolValue];
        if (pauseContentWithMedia != _pauseContentWithMedia) {
            if (pauseContentWithMedia) {
                [self _subscribeToMediaPlayPause];
                [self _playPauseChanged:nil];
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

                if (artworkBackgroundMode == BlurredImage)
                    _blurredImage = [self _blurredImage:_artworkImage];
                else if (artworkBackgroundMode == StaticColor)
                    [self _updateStaticColor:preferences];

                // Updating these here as the updated values are required below
                _artworkBackgroundMode = artworkBackgroundMode;
                [self _getColorInfoWithStaticColorForImage:_artworkImage];
            }
        }
    }

    [self _fillPropertiesFromSettings:preferences];

    if (updateArtworkFrames)
        [self _updateArtworkFrames];

    if ([self _allowActivate])
        [self _updateOnMainQueueWithContent:YES];
}

- (void)_updateArtworkFrames {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc updateArtworkWidthPercentage:_artworkWidthPercentage
                           yOffsetPercentage:_artworkYOffsetPercentage];
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
    [_rbs_center registerForMessageName:kCanvasURLMessage
                                 target:self
                               selector:@selector(_handleIncomingMessage:withUserInfo:)];

    [self _registerAutoPlayPauseEvents];
}

- (void)_unregisterEventsForCanvasMode {
    [_rbs_center unregisterForMessageName:kCanvasURLMessage];
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

            if (![self hasPlayableContent])
                return;

            /* If the user manually paused the video,
               do not resume on screen turn on event */
            if (!_playing && _manuallyPaused)
                return;

            if (_pauseContentWithMedia && !_mediaPlaying)
                return;

            /* If animation needs to be added, do that instead of resuming nothing */
            if (_screenTurnedOn && !_insideApp && [self hasAnimatingArtwork]) {
                if (_hasPendingArtworkChange)
                    [self _updateOnMainQueueWithContent:YES];
                else if (_shouldAddRotation)
                    [self _addArtworkRotation];
            }

            if (!_insideApp)
                [self _setPlayPauseState:_screenTurnedOn];
        });

    return result == NOTIFY_STATUS_OK;
}

- (BOOL)_unregisterScreenEvent {
    return notify_cancel(_notifyTokenForDidChangeDisplayStatus) == NOTIFY_STATUS_OK;
}

- (void)_setPlayPauseState:(BOOL)newState {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (SAViewController *vc in _viewControllers)
            [vc togglePlayPauseWithState:newState];
    });

    _manuallyPaused = NO;
    _playing = _canvasURL != nil || _artworkImage != nil;
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

- (void)_updateWithContent:(BOOL)content {
    _hasPendingArtworkChange = NO;

    id object = nil;
    if (content) {
        object = self;
        [self _overrideLabels];
    } else {
        [self _revertLabels];
    }

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
    return _nowPlayingController.currentState != Inactive;
}

- (void)_currentAppChanged:(NSNotification *)notification {
    SBApplication *app = notification.object;
    id<ProcessStateInfo> processState = [app respondsToSelector:@selector(internalProcessState)] ?
                                        app.internalProcessState : app.processState;
    BOOL insideApp = processState.foreground && processState.visibility != ForegroundObscured;

    /* Don't update if nothing changed */
    if (_insideApp == insideApp)
        return;

    _insideApp = insideApp;

    if (![self hasPlayableContent])
        return;

    /* If the user manually paused the video,
       do not resume when app enters background */
    if (!_playing && _manuallyPaused)
        return;

    if (_pauseContentWithMedia && !_mediaPlaying)
        return;

    /* If animation needs to be added, do that instead of resuming nothing */
    if (!_insideApp && [self hasAnimatingArtwork]) {
        if (_hasPendingArtworkChange)
            [self _updateOnMainQueueWithContent:YES];
        else if (_shouldAddRotation)
            [self _addArtworkRotation];
    }

    [self _setPlayPauseState:!insideApp];
}

- (void)_addArtworkRotation {
    _shouldAddRotation = NO;
    for (SAViewController *vc in _viewControllers)
        [vc addArtworkRotation];
}

- (void)_checkForRestoreSpotifyConnectIssue {
    if (!_artworkImage && !_canvasURL &&
        (_previousSpotifyURL || _previousSpotifyArtworkImage)) {
        _canvasURL = _previousSpotifyURL;
        _canvasAsset = _previousSpotifyAsset;
        _artworkImage = _previousSpotifyArtworkImage;

        if ([self _allowActivate])
            [self _updateWithContent:YES];

        _previousSpotifyURL = nil;
        _previousSpotifyAsset = nil;
        _previousSpotifyArtworkImage = nil;
    }
}

- (void)_checkForStoreSpotifyConnectIssue:(NSString *)newBundleID {
    if (!newBundleID && [_bundleID isEqualToString:kSpotifyBundleID]) {
        _previousSpotifyURL = _canvasURL;
        _previousSpotifyAsset = _canvasAsset;
        _previousSpotifyArtworkImage = _artworkImage;
    }
}

- (void)_nowPlayingAppChanged:(NSNotification *)notification {
    SBMediaController *mediaController = notification.object;
    NSString *bundleID = mediaController.nowPlayingApplication.bundleIdentifier;

    if (!bundleID) {
        [self _checkForStoreSpotifyConnectIssue:bundleID];
        [self _setModeToNone];
        [self _updateOnMainQueueWithContent:NO];
    } else if ([_disabledApps containsObject:bundleID]) {
        [self _unsubscribeToArtworkChanges];
    } else {
        [self _subscribeToArtworkChanges];
        if ([bundleID isEqualToString:kSpotifyBundleID]) {
            _placeholderImage = [SAImageHelper stringToImage:SPOTIFY_PLACEHOLDER_BASE64];
            [self _checkForRestoreSpotifyConnectIssue];
        } else {
            [self _setModeToNone];
            [self _updateOnMainQueueWithContent:NO];

            if ([bundleID isEqualToString:kDeezerBundleID])
                _placeholderImage = [SAImageHelper stringToImage:DEEZER_PLACEHOLDER_BASE64];
            else
                _placeholderImage = nil;
        }
    }
    _bundleID = bundleID;
}

- (void)_setModeToNone {
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
}

- (void)_nowPlayingChanged:(NSNotification *)notification {
    // Reset these on track change
    _previousSpotifyURL = nil;
    _previousSpotifyAsset = nil;

    NSDictionary *userInfo = notification.userInfo;

    NSArray *contentItems = userInfo[@"kMRMediaRemoteUpdatedContentItemsUserInfoKey"];
    if (!contentItems || contentItems.count == 0)
        return;

    MRContentItem *contentItem = contentItems[0];
    NSDictionary *info = [contentItem dictionaryRepresentation];

    NSString *trackIdentifier = info[@"identifier"];
    NSDictionary *metadata = info[@"metadata"];
    if (!trackIdentifier || !metadata)
        return;

    NSString *artworkIdentifier = metadata[@"artworkIdentifier"];
    if (!artworkIdentifier || [_artworkIdentifier isEqualToString:artworkIdentifier])
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
            [request onCompletion:^(UIImage *image) {
                if (!image) {
                    #ifdef DEBUG
                    HBLogError(@"No artwork for this track!");
                    #endif
                    return;
                }

                // HBLogDebug(@"base64: %@, image: %@", [SAImageHelper imageToString:image], image);
                if ([self _candidatePlaceholderImage:image])
                    return;

                if (_canvasURL) {
                    _canvasArtworkImage = image;
                    return;
                }

                [self _updateModeToArtworkWithTrackIdentifier:trackIdentifier];

                _trackIdentifier = trackIdentifier;
                /* Skip showing artwork for canvas track when switching
                   (some weird bug that sends the old artwork when changing track) */
                if (_previousMode == Canvas && _canvasArtworkImage &&
                    [SAImageHelper compareImage:_canvasArtworkImage withImage:image]) {
                    _canvasArtworkImage = nil;
                    return;   
                }

                if (_artworkImage && [self _candidateSameAsPreviousArtwork:image]) {
                    if (![self changedContent])
                        [self _updateModeToArtworkWithTrackIdentifier:trackIdentifier];
                    return;
                }

                [self _updateArtworkWithImage:image];
                _artworkIdentifier = artworkIdentifier;
            }];
        }
    ];
}

- (void)_playPauseChanged:(NSNotification *)notification {
    NSString *key = CFBridgingRelease(kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey);
    _mediaPlaying = [notification.userInfo[key] boolValue];

    if (![self hasPlayableContent])
        return;

    if (_insideApp || !_screenTurnedOn)
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

    if (_placeholderImage)
        return [SAImageHelper compareImage:candidate withImage:_placeholderImage];
    return NO;
}

- (void)_getColorInfoWithStaticColorForImage:(UIImage *)image {
    UIColor *staticColor = _artworkBackgroundMode == StaticColor ?
                           _staticColor : nil;
    _colorInfo = [SAImageHelper colorsForImage:_artworkImage
                     withStaticBackgroundColor:staticColor];

    UIColor *toMixColor = [SAImageHelper colorIsLight:_colorInfo.backgroundColor] ?
                          UIColor.blackColor : UIColor.whiteColor;
    _blendedCDBackgroundColor = [[SAImageHelper blendColor:_colorInfo.backgroundColor
                                                 withColor:toMixColor
                                                percentage:0.5] colorWithAlphaComponent:0.8];
}

- (void)_updateArtworkWithImage:(UIImage *)image {
    UIImage *previousImage = _artworkImage;
    _artworkImage = image;

    if (image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self _getColorInfoWithStaticColorForImage:image];

            if (_artworkBackgroundMode == BlurredImage)
                _blurredImage = [self _blurredImage:image];

            if ([self _allowActivate]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    /* If this is the not first artwork that's being shown,
                       we need to wait with the change of artwork if animiating. */
                    if (previousImage &&
                        ![self changedContent] &&
                        [self hasAnimatingArtwork] &&
                        [self isDirty]) {
                        _hasPendingArtworkChange = YES;
                    } else {
                        [self _updateWithContent:YES];
                    }
                });
            }
        });
        return;
    }

    [self _updateOnMainQueueWithContent:NO];
}

- (void)_overrideLabels {
    if (!_colorInfo)
        return [self _revertLabels];

    _UILegibilitySettings *settings = legibilitySettingsForDarkText(_colorInfo.hasDarkTextColor);

    if (_enabledMode != LockscreenMode)
        [self _setAppLabelsLegibilitySettings:settings revert:NO];
    [self _overrideStatusBar:settings];
    if (_enabledMode != HomescreenMode)
        [self _updateLockscreenLabels];
}

- (void)_revertLabels {
    [self _setAppLabelsLegibilitySettings:[self _getOriginalHomescreenLegibilitySettings] revert:YES];
    [self _revertStatusBar];
    if (_enabledMode != HomescreenMode)
        [self _updateLockscreenLabels];
}

- (_UILegibilitySettings *)_getOriginalHomescreenLegibilitySettings {
    return [getWallpaperController() legibilitySettingsForVariant:1];
}

- (_UILegibilitySettings *)_getOriginalLockscreenLegibilitySettings {
    return [getDashBoardViewController().legibilityProvider currentLegibilitySettings];
}

- (void)_setAppLabelsLegibilitySettings:(_UILegibilitySettings *)settings
                                 revert:(BOOL)revert {
    _legibilitySettings = settings;
    SBIconController *iconController = getIconController();
    [iconController setLegibilitySettings:settings];

    SBRootFolderController *rootFolderController = [iconController _rootFolderController];
    [rootFolderController.contentView.pageControl setLegibilitySettings:settings];
    [self _colorFolderIconsWithIconController:iconController
                         rootFolderController:rootFolderController
                                       revert:revert];
}

- (void)_colorFolderIconsWithIconController:(SBIconController *)iconController
                       rootFolderController:(SBRootFolderController *)rootFolderController
                                     revert:(BOOL)revert {
    UIColor *color;
    if (!revert && (_canvasThumbnail || _artworkImage) && _tintFolderIcons) {
        color = _colorInfo.backgroundColor;
        if ([SAImageHelper colorIsLight:color])
            color = [SAImageHelper darkerColorForColor:color];
        else
            color = [SAImageHelper lighterColorForColor:color];
        _folderColor = [color colorWithAlphaComponent:0.8];
        _folderBackgroundColor = [color colorWithAlphaComponent:0.6];

        [self _colorizeFolderIcons:rootFolderController.iconListViews color:_folderColor animate:YES];
    } else if (!_folderColor) {
        return; // If we haven't already colorized, don't bother reverting it
    } else {
        _folderColor = nil;
        _folderBackgroundColor = nil;
        [[%c(_SBIconWallpaperBackgroundProvider) sharedInstance] _updateAllClients];
    }

    // If there is any open folder, colorize the background
    SBFolderController *openedFolder = [iconController _openFolderController];
    if (openedFolder) {
        SBFloatyFolderView *folderView = openedFolder.contentView;
        SBFloatyFolderBackgroundClipView *clipView = MSHookIvar<SBFloatyFolderBackgroundClipView *>(folderView,
                                                                                                    "_scrollClipView");
        [clipView nu_colorizeFolderBackground:_folderBackgroundColor];
    }
}

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

- (void)_overrideStatusBar:(_UILegibilitySettings *)settings {
    _UILegibilitySettings *homescreenSettings = nil;
    _UILegibilitySettings *lockscreenSettings = nil;
    if (_enabledMode == BothMode)
        lockscreenSettings = homescreenSettings = settings;
    else if (_enabledMode == LockscreenMode)
        lockscreenSettings = settings;
    else
        homescreenSettings = settings;

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
    [getDashBoardViewController() _updateActiveAppearanceForReason:nil];
}

- (UIImage *)_blurredImage:(UIImage *)image {
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [[CIImage alloc] initWithImage:image];

    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:5.0f] forKey:@"inputRadius"];

    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    CGImageRef cgImage = [context createCGImage:result fromRect:inputImage.extent];
    UIImage *blurredAndDarkenedImage = [UIImage imageWithCGImage:cgImage];

    CGImageRelease(cgImage);
    return blurredAndDarkenedImage;
}

/* This method must be called on the main thread! */
- (BOOL)isDirty {
    return !_screenTurnedOn ||
           [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
}

- (void)_handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    NSString *urlString = dict[kCanvasURL];
    if (!urlString) {
        _canvasURL = nil;
        _canvasAsset = nil;

        if ([_disabledApps containsObject:kSpotifyBundleID])
            [self _sendCanvasUpdatedEvent];
        return;
    } else {
        _artworkImage = nil;
        _trackIdentifier = nil;
        _artworkIdentifier = nil;
    }

    if (![urlString isEqualToString:_canvasURL]) {
        _canvasURL = urlString;
        _canvasAsset = [AVAsset assetWithURL:[NSURL URLWithString:urlString]];

        if (_mode == Canvas)
            _previousMode = None;
        else {
            if (_mode == Artwork)
                _previousMode = Artwork;
            _mode = Canvas;
        }

        [self _sendCanvasUpdatedEvent];
    }
}

@end
