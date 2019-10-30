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

    _viewControllers = [NSMutableArray new];

    notify_register_dispatch(kSettingsChanged,
        &_notifyTokenForSettingsChanged,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
        ^(int t) {
            [self _updateConfigurationWithDictionary:[NSDictionary dictionaryWithContentsOfFile:kPrefPath]];
        });
}

- (BOOL)isCanvasActive {
    return _mode == Canvas;
}

- (void)loadHaptic {
    _hapticGenerator = [[%c(UIImpactFeedbackGenerator) alloc] initWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)togglePlayManually {
    if (![self isCanvasActive])
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

- (void)mediaWidgetWillHide {
    [self _setModeToNone];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self _sendUpdateArtworkEvent:NO];
        [self _revertLabels];
    });
}

// Destroy everything! MOHAHAHA! *evil laugh continues...*
- (void)setTrialEnded {
    _trialEnded = YES;

    [self _unsubscribeToArtworkChanges];
    [self _unregisterEventsForCanvasMode];
    notify_cancel(_notifyTokenForSettingsChanged);

    [self _setModeToNone];
    _placeholderImage = nil;

    _previousSpotifyURL = nil;
    _previousSpotifyAsset = nil;

    _canvasThumbnail = nil;
    _canvasArtworkImage = nil;

    _artworkEnabled = NO;
    _canvasEnabled = NO;

    [self _sendUpdateArtworkEvent:NO];
    _viewControllers = nil;
    _inChargeController = nil;
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

    current = preferences[kCanvasEnabled];
    if (current) {
        BOOL canvasEnabled = [current boolValue];
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
            } else {
                if (_previousSpotifyURL) {
                    _canvasURL = _previousSpotifyURL;
                    _canvasAsset = _previousSpotifyAsset;
                    _canvasArtworkImage = _artworkImage;

                    _mode = Canvas;
                    _previousMode = Artwork;
                }
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self _registerEventsForCanvasMode];
                });
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
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self _sendUpdateArtworkEvent:YES];
        [self _overrideLabels];
    });
}

- (void)_updateArtworkFrames {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        for (SAViewController *vc in _viewControllers)
            [vc updateArtworkWidthPercentage:_artworkWidthPercentage
                           yOffsetPercentage:_artworkYOffsetPercentage];
    });
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

- (void)_registerEventsForCanvasMode {
    _rbs_center = [CPDistributedMessagingCenter centerNamed:SA_IDENTIFIER];
    rocketbootstrap_distributedmessagingcenter_apply(_rbs_center);
    [_rbs_center runServerOnCurrentThread];
    [_rbs_center registerForMessageName:kCanvasURLMessage
                                 target:self
                               selector:@selector(_handleIncomingMessage:withUserInfo:)];

    [self _registerScreenEvent];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_currentAppChanged:)
                                                 name:kSBApplicationProcessStateDidChange
                                               object:nil];
}

- (void)_unregisterEventsForCanvasMode {
    [_rbs_center unregisterForMessageName:kCanvasURLMessage];
    [_rbs_center stopServer];
    _rbs_center = nil;

    [self _unregisterScreenEvent];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSBApplicationProcessStateDidChange
                                                  object:nil];
}

- (BOOL)_registerScreenEvent {
    uint32_t result = notify_register_dispatch(kNotificationNameDidChangeDisplayStatus,
       &_notifyTokenForDidChangeDisplayStatus,
       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
       ^(int info) {
            uint64_t state;
            notify_get_state(_notifyTokenForDidChangeDisplayStatus, &state);
            _screenTurnedOn = BOOL(state);

            // If the user manually paused the video, do not resume on screen turn on event
            if (![self isCanvasActive] || (!_playing && _manuallyPaused))
                return;

            if (!_insideApp)
                [self _setCanvasPlayPauseState:_screenTurnedOn];
       });

    return result == NOTIFY_STATUS_OK;
}

- (BOOL)_unregisterScreenEvent {
    return notify_cancel(_notifyTokenForDidChangeDisplayStatus) == NOTIFY_STATUS_OK;
}

- (void)_setCanvasPlayPauseState:(BOOL)newState {
    for (SAViewController *vc in _viewControllers)
        [vc togglePlayPauseWithState:newState];

    _manuallyPaused = NO;
    _playing = _canvasURL != nil;
}

- (void)_sendCanvasUpdatedEvent {
    if (_canvasURL) {
        [self _thumbnailFromAsset:_canvasAsset withCompletion:^(UIImage *image) {
            _canvasThumbnail = image;
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self _sendUpdateArtworkEvent:YES];
            });

            if (!image)
                return;

            _colorInfo = [SAImageHelper colorsForImage:image];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self _overrideLabels];
            });
        }];
        return;
    } else {
        [self _sendUpdateArtworkEvent:NO];
        [self _revertLabels];
    }
}

- (void)_sendUpdateArtworkEvent:(BOOL)content {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        for (SAViewController *vc in _viewControllers)
            [vc artworkUpdated:content ? self : nil];
    });
}

- (void)_currentAppChanged:(NSNotification *)notification {
    SBApplication *app = notification.object;
    id<ProcessStateInfo> processState = [app respondsToSelector:@selector(internalProcessState)] ?
                                        app.internalProcessState : app.processState;
    _insideApp = processState.foreground && processState.visibility != ForegroundObscured;

    // If the user manually paused the video, do not resume when app enters background
    if (![self isCanvasActive] || (!_playing && _manuallyPaused))
        return;

    [self _setCanvasPlayPauseState:!_insideApp];
}

- (void)_checkForRestoreSpotifyConnectIssue {
    if (!_artworkImage && !_canvasURL && (_previousSpotifyURL || _previousSpotifyArtworkImage)) {
        _canvasURL = _previousSpotifyURL;
        _canvasAsset = _previousSpotifyAsset;
        _artworkImage = _previousSpotifyArtworkImage;

        [self _sendUpdateArtworkEvent:YES];
        [self _overrideLabels];

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
        [self _sendUpdateArtworkEvent:NO];
        [self _revertLabels];
    } else if ([_disabledApps containsObject:bundleID])
        [self _unsubscribeToArtworkChanges];
    else {
        [self _subscribeToArtworkChanges];
        if ([bundleID isEqualToString:kSpotifyBundleID]) {
            _placeholderImage = [SAImageHelper stringToImage:SPOTIFY_PLACEHOLDER_BASE64];
            [self _checkForRestoreSpotifyConnectIssue];
        } else {
            [self _setModeToNone];
            [self _sendUpdateArtworkEvent:NO];

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
        onCompletion:^void(MPCMediaRemoteController *controller) {
            float width = [UIScreen mainScreen].nativeBounds.size.width;
            MPCFuture *request;
            if ([controller respondsToSelector:@selector(contentItemArtworkForContentItemIdentifier:artworkIdentifier:size:)])
                request = [controller contentItemArtworkForContentItemIdentifier:trackIdentifier
                                                               artworkIdentifier:artworkIdentifier
                                                                            size:CGSizeMake(width, width)];
            else
                request = [controller contentItemArtworkForIdentifier:trackIdentifier
                                                                 size:CGSizeMake(width, width)];
            [request onCompletion:^void(UIImage *image) {
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
                    [SAImageHelper compareImage:_canvasArtworkImage withImage:image])
                    return;

                if ([self _candidateSameAsPreviousArtwork:image] && ![self changedContent]) {
                    [self _updateModeToArtworkWithTrackIdentifier:trackIdentifier];
                    return [self _updateArtworkWithImage:_artworkImage];
                }

                [self _updateArtworkWithImage:image];
                _artworkIdentifier = artworkIdentifier;
            }];
        }
    ];
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

- (BOOL)changedContent {
    return _previousMode != None && _mode != _previousMode;
}

- (BOOL)useBackgroundColor {
    return !_canvasURL && _artworkBackgroundMode != BlurredImage;
}

- (void)_getColorInfoWithStaticColorForImage:(UIImage *)image {
    UIColor *staticColor = _artworkBackgroundMode == StaticColor ?
                           _staticColor : nil;
    _colorInfo = [SAImageHelper colorsForImage:_artworkImage
                     withStaticBackgroundColor:staticColor];
}

- (void)_updateArtworkWithImage:(UIImage *)image {
    _artworkImage = image;

    if (image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self _getColorInfoWithStaticColorForImage:image];

            if (_artworkBackgroundMode == BlurredImage)
                _blurredImage = [self _blurredImage:image];

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self _sendUpdateArtworkEvent:YES];
                [self _overrideLabels];
            });
        });
        return;
    }

    [self _sendUpdateArtworkEvent:NO];
}

- (void)_overrideLabels {
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
        _folderColor = [color colorWithAlphaComponent:0.6];

        [self _colorizeFolderIcons:rootFolderController.iconListViews color:color animate:YES];
    } else if (!_folderColor) {
        return; // If we haven't already colorized, don't bother reverting it
    } else {
        _folderColor = nil;
        [[%c(_SBIconWallpaperBackgroundProvider) sharedInstance] _updateAllClients];
    }

    // If there is any open folder, colorize the background
    SBFolderController *openedFolder = [iconController _openFolderController];
    if (openedFolder) {
        SBFloatyFolderView *folderView = openedFolder.contentView;
        SBFloatyFolderBackgroundClipView *clipView = MSHookIvar<SBFloatyFolderBackgroundClipView *>(folderView, "_scrollClipView");
        [clipView nu_colorizeFolderBackground:_folderColor];
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

- (BOOL)isDirty {
    return !_screenTurnedOn || [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication];
}

- (void)_handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    NSString *urlString = dict[kCanvasURL];
    if (!urlString) {
        _canvasURL = nil;
        _canvasAsset = nil;
        _canvasArtworkImage = nil;

        if ([_disabledApps containsObject:kSpotifyBundleID])
            [self _sendCanvasUpdatedEvent];
        return;
    } else {
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
