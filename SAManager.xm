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

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"
#define kSBApplicationProcessStateDidChange @"SBApplicationProcessStateDidChange"
#define kSBMediaNowPlayingAppChangedNotification @"SBMediaNowPlayingAppChangedNotification"

extern SBDashBoardViewController *getDashBoardViewController();
extern _UILegibilitySettings *legibilitySettingsForDarkText(BOOL darkText);

@implementation SAManager {
    int _notifyTokenForDidChangeDisplayStatus;
    BOOL _manuallyPaused;
    BOOL _playing;
    UIImpactFeedbackGenerator *_hapticGenerator;
    NSString *_artworkIdentifier;
    BOOL _insideApp;
    BOOL _screenTurnedOn;
    // isDirty marks that there has been a change of canvasURL,
    // but we're not updating it because once the event occurred
    // the device was either at sleep or some app was in the foreground.
    BOOL _isDirty;

    Mode _mode;
    Mode _previousMode;

    NSMutableArray *_viewControllers;
    SADockViewController *_dockViewController;
    UIImage *_placeholderImage;
}

#pragma mark Public

- (void)setup {
    _screenTurnedOn = YES;

    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:SA_IDENTIFIER];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c registerForMessageName:kCanvasURLMessage target:self selector:@selector(_handleIncomingMessage:withUserInfo:)];


    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_nowPlayingAppChanged:)
                                                 name:kSBMediaNowPlayingAppChangedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_nowPlayingChanged:)
                                                 name:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification
                                               object:nil];

    [self _registerEventsForCanvasMode];

    _viewControllers = [NSMutableArray new];

    _enabledMode = BothMode;
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

- (void)setDockViewController:(SADockViewController *)dockViewController {
    _dockViewController = dockViewController;
}

#pragma mark Private

- (void)_videoEnded {
    for (SAViewController *vc in _viewControllers)
        [vc replayVideo];
}

- (void)_registerEventsForCanvasMode {
    [self _registerScreenEvent];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_currentAppChanged:)
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

            if (!_insideApp) //|| [self  ])
                [self _setCanvasPlayPauseState:_screenTurnedOn];
       });

    return result == NOTIFY_STATUS_OK;
}

- (void)_setCanvasPlayPauseState:(BOOL)newState {
    if (_isDirty)
        _isDirty = NO;

    for (SAViewController *vc in _viewControllers)
        [vc togglePlayPauseWithState:newState];

    _manuallyPaused = NO;
    _playing = _canvasURL != nil;
}

- (void)_sendCanvasUpdatedNotification {
    NSMutableDictionary *userInfo = nil;
    if (_canvasURL) {
        userInfo = [NSMutableDictionary new];
        userInfo[kCanvasURL] = _canvasURL;
        userInfo[kChangeOfContent] = @(_previousMode != None && _mode != _previousMode);

        if (_isDirty)
            userInfo[kIsDirty] = @YES;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                        object:nil
                                                      userInfo:userInfo];
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

- (void)_nowPlayingAppChanged:(NSNotification *)notification {
    SBMediaController *mediaController = notification.object;
    NSString *bundleID = mediaController.nowPlayingApplication.bundleIdentifier;
    HBLogDebug(@"bundleID: %@", bundleID);
    if ([bundleID isEqualToString:kSpotifyBundleID]) {
        _placeholderImage = [SAImageHelper stringToImage:SPOTIFY_PLACEHOLDER_BASE64];
    } else {
        _canvasURL = nil;

        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                            object:nil];

        if ([bundleID isEqualToString:kDeezerBundleID])
            _placeholderImage = [SAImageHelper stringToImage:DEEZER_PLACEHOLDER_BASE64];
        else
            _placeholderImage = nil;
    }
}

- (void)_nowPlayingChanged:(NSNotification *)notification {
    if (_canvasURL)
        return;

    NSDictionary *userInfo = notification.userInfo;

    NSArray *contentItems = userInfo[@"kMRMediaRemoteUpdatedContentItemsUserInfoKey"];
    if (!contentItems && contentItems.count == 0)
        return;

    MRContentItem *contentItem = contentItems[0];
    NSDictionary *info = [contentItem dictionaryRepresentation];

    NSString *identifier = info[@"identifier"];
    NSDictionary *metadata = info[@"metadata"];
    if (!identifier || !metadata)
        return;

    NSString *artworkIdentifier = metadata[@"artworkIdentifier"];
    if ([_artworkIdentifier isEqualToString:artworkIdentifier])
        return;

    if (_mode == Artwork)
        _previousMode = None;
    else {
        if (_mode == Canvas)
            _previousMode = Canvas;
        _mode = Artwork;
    }

    HBLogDebug(@"identifier: %@, artworkIdentifier: %@", identifier, artworkIdentifier);

    [[%c(MPCMediaRemoteController) controllerForPlayerPath:[%c(MPCPlayerPath) deviceActivePlayerPath]]
        onCompletion:^void(MPCMediaRemoteController *controller) {
            float width = [UIScreen mainScreen].nativeBounds.size.width;
            MPCFuture *request;
            if ([controller respondsToSelector:@selector(contentItemArtworkForContentItemIdentifier:artworkIdentifier:size:)])
                request = [controller contentItemArtworkForContentItemIdentifier:identifier
                                                               artworkIdentifier:artworkIdentifier
                                                                            size:CGSizeMake(width, width)];
            else
                request = [controller contentItemArtworkForIdentifier:identifier
                                                                 size:CGSizeMake(width, width)];
            [request onCompletion:^void(UIImage *image) {
                // HBLogDebug(@"base64: %@, image: %@", [SAImageHelper imageToString:image], image);
                HBLogDebug(@"image: %@", image);

                if ([self _candidateSameAsPreviousArtwork:image])
                    return [self _updateArtworkWithImage:_artworkImage];

                if ([self _candidatePlaceholderImage:image])
                    return;

                [self _updateArtworkWithImage:image];
                _artworkIdentifier = artworkIdentifier;
            }];
        }
    ];
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

- (void)_updateArtworkWithImage:(UIImage *)image {
    if (_canvasURL) // Need to check again, since retrieving the image was done async
        return;
    _artworkImage = image;

    NSMutableDictionary *userInfo = nil;
    if (image) {
        userInfo = [NSMutableDictionary new];
        userInfo[kArtworkImage] = image;
        userInfo[kChangeOfContent] = @(_previousMode != None && _mode != _previousMode);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            _colorInfo = [SAImageHelper colorsForImage:image];

            if (NO/*blurMode*/) // TODO: Add settings for this
                userInfo[kBlurredImage] = [self _blurredImage:image];
            else if (YES/*colorMode*/)
                userInfo[kColor] = _colorInfo.backgroundColor;

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                                    object:nil
                                                                  userInfo:userInfo];
                [self _overrideLabels];
            });
        });
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                        object:nil
                                                      userInfo:userInfo];
}

- (void)_overrideLabels {
    _UILegibilitySettings *settings = legibilitySettingsForDarkText(_colorInfo.hasDarkTextColor);

    if (_enabledMode != LockscreenMode)
        [self _setAppLabelsLegibilitySettings:settings];
    [self _overrideStatusBar:settings];
    if (_enabledMode != HomescreenMode)
        [self _updateLockscreenLabels];
}

- (void)_revertLabels {
    [self _setAppLabelsLegibilitySettings:[self _getOriginalHomeScreenLegibilitySettings]];
    [self _revertStatusBar];
    if (_enabledMode != HomescreenMode)
        [self _updateLockscreenLabels];
}

- (_UILegibilitySettings *)_getOriginalHomeScreenLegibilitySettings {
    return ((SBIconController *)[%c(SBIconController) sharedInstance]).legibilitySettings;
}

- (_UILegibilitySettings *)_getOriginalLockScreenLegibilitySettings {
    return [getDashBoardViewController().legibilityProvider currentLegibilitySettings];
}

- (void)_setAppLabelsLegibilitySettings:(_UILegibilitySettings *)settings {
    SBIconViewMap *viewMap = ((SBIconController *)[%c(SBIconController) sharedInstance]).homescreenIconViewMap;
    viewMap.legibilitySettings = settings;
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
        originalLockscreenSettings = originalHomescreenSettings = [self _getOriginalHomeScreenLegibilitySettings];
    else if (_enabledMode == LockscreenMode)
        originalLockscreenSettings = [self _getOriginalLockScreenLegibilitySettings];
    else
        originalHomescreenSettings = [self _getOriginalHomeScreenLegibilitySettings];

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
        [assertionManager _enumerateAssertionsToLevel:HomescreenAssertionLevel withBlock:homescreenCompletion];
        [assertionManager _enumerateAssertionsToLevel:FullscreenAlertAnimationAssertionLevel withBlock:lockscreenCompletion];
    } else if (_enabledMode == LockscreenMode) {
        [assertionManager _enumerateAssertionsToLevel:FullscreenAlertAnimationAssertionLevel withBlock:lockscreenCompletion];
    } else {
        [assertionManager _enumerateAssertionsToLevel:HomescreenAssertionLevel withBlock:homescreenCompletion];
    }
}

- (void (^)(SBAppStatusBarSettingsAssertion *))_assertionCompletionWithSettings:(_UILegibilitySettings *)settings {
    return ^(SBAppStatusBarSettingsAssertion *assertion) {
        assertion.sa_legibilitySettings = settings;
        [assertion modifySettingsWithBlock:nil]; // This method is hooked in Tweak.xm and will change the color from there.
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

- (void)_handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    NSString *urlString = dict[kCanvasURL];
    if (!urlString) {
        _canvasURL = nil;
        return;
    }

    if (![urlString isEqualToString:_canvasURL]) {
        _canvasURL = urlString;
        _isDirty = _insideApp || !_screenTurnedOn;

        if (_mode == Canvas)
            _previousMode = None;
        else {
            if (_mode == Artwork)
                _previousMode = Artwork;
            _mode = Canvas;
        }

        [self _sendCanvasUpdatedNotification];
    }
}

@end
