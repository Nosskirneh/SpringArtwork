#import "SAManager.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "Common.h"
#import <notify.h>
#import "SpringBoard.h"
#import "ApplicationProcesses.h"
#import <SpringBoard/SBMediaController.h>
#import <MediaRemote/MediaRemote.h>
#import "DockManagement.h"

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"
#define kSBApplicationProcessStateDidChange @"SBApplicationProcessStateDidChange"
#define kSBMediaNowPlayingAppChangedNotification @"SBMediaNowPlayingAppChangedNotification"


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
}

#pragma mark Public

- (void)setup {
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
}

- (BOOL)isCanvasActive {
    return _canvasURL != nil;
}

- (void)loadHaptic {
    _hapticGenerator = [[%c(UIImpactFeedbackGenerator) alloc] initWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)togglePlayManually {
    if (![self isCanvasActive])
        return;

    [_hapticGenerator impactOccurred];
    [[NSNotificationCenter defaultCenter] postNotificationName:kTogglePlayPause
                                                        object:nil];
    if (_playing)
        _manuallyPaused = YES;

    _playing = !_playing;
}

#pragma mark Private

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
                [self _sendCanvasPlayPauseNotificationWithState:_screenTurnedOn];
       });

    return result == NOTIFY_STATUS_OK;
}

- (void)_sendCanvasPlayPauseNotificationWithState:(BOOL)newState {
    if (_isDirty)
        _isDirty = NO;

    NSDictionary *info = @{
        kPlayState : @(newState)
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:kTogglePlayPause
                                                        object:nil
                                                      userInfo:info];
    _manuallyPaused = NO;
    _playing = _canvasURL != nil;
}

- (void)_sendCanvasUpdatedNotification {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    if (_canvasURL) {
        dict[kCanvasURL] = _canvasURL;
        if (_isDirty)
            dict[kIsDirty] = @YES;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                        object:nil
                                                      userInfo:dict];
}

- (void)_currentAppChanged:(NSNotification *)notification {
    SBApplication *app = notification.object;
    id<ProcessStateInfo> processState = [app respondsToSelector:@selector(internalProcessState)] ?
                                        app.internalProcessState : app.processState;
    _insideApp = processState.foreground && processState.visibility != ForegroundObscured;

    // If the user manually paused the video, do not resume when app enters background
    if (![self isCanvasActive] || (!_playing && _manuallyPaused))
        return;

    [self _sendCanvasPlayPauseNotificationWithState:!_insideApp];
}

- (void)_nowPlayingAppChanged:(NSNotification *)notification {
    SBMediaController *mediaController = notification.object;
    NSString *bundleID = mediaController.nowPlayingApplication.bundleIdentifier;
    HBLogDebug(@"bundleID: %@", bundleID);
    if (![bundleID isEqualToString:kSpotifyBundleID]) {
        _canvasURL = nil;

        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                            object:nil];
    }
}

- (void)_nowPlayingChanged:(NSNotification *)notification {
    if (_canvasURL)
        return;

    // HBLogDebug(@"notification: %@", notification);

    NSDictionary *userInfo = notification.userInfo;
    _MRNowPlayingClientProtobuf *processInfo = userInfo[@"kMRNowPlayingClientUserInfoKey"];
    NSString *bundleID = processInfo.bundleIdentifier;

    NSArray *contentItems = userInfo[@"kMRMediaRemoteUpdatedContentItemsUserInfoKey"];
    if (!contentItems && contentItems.count == 0)
        return [self _updateArtworkWithImage:nil];

    MRContentItem *contentItem = contentItems[0];
    NSDictionary *info = [contentItem dictionaryRepresentation];
    // HBLogDebug(@"info: %@", info);

    if ([self _isPlaceholderImageForBundleID:bundleID info:info]) {
        HBLogDebug(@"skipping placeholder...");
        return;
    }

    NSString *identifier = info[@"identifier"];
    NSDictionary *metadata = info[@"metadata"];
    if (!identifier || !metadata)
        return [self _updateArtworkWithImage:nil];

    NSString *artworkIdentifier = metadata[@"artworkIdentifier"];
    if ([_artworkIdentifier isEqualToString:artworkIdentifier])
        return;

    HBLogDebug(@"identifier: %@, artworkIdentifier: %@", identifier, artworkIdentifier);

    [[%c(MPCMediaRemoteController) controllerForPlayerPath:[%c(MPCPlayerPath) deviceActivePlayerPath]]
        onCompletion:^void(MPCMediaRemoteController *controller) {
            float width = [UIScreen mainScreen].nativeBounds.size.width;
            [[controller contentItemArtworkForContentItemIdentifier:identifier artworkIdentifier:artworkIdentifier size:CGSizeMake(width, width)]
                onCompletion:^void(UIImage *image) {
                    [self _updateArtworkWithImage:image];
                    _artworkIdentifier = artworkIdentifier;
                }
            ];
        }
    ];
}

/* Hopefully there are some pattern to recognize. We might have to analyze the image data god forbid :/ */
- (BOOL)_isPlaceholderImageForBundleID:(NSString *)bundleID info:(NSDictionary *)info {
    // return [bundleID isEqualToString:kSpotifyBundleID] && ...);
    return NO;
}

- (void)_updateArtworkWithImage:(UIImage *)image {
    if (_canvasURL) // Need to check again, since retrieving the image was done async
        return;
    _artworkImage = image;

    NSMutableDictionary *dict = nil;
    if (image) {
        dict = [NSMutableDictionary new];
        dict[kArtworkImage] = image;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            _colorInfo = [SAColorHelper colorsForImage:image];

            if (NO/*blurMode*/) // TODO: Add settings for this
                dict[kBlurredImage] = [self _blurredImage:image];
            else if (YES/*colorMode*/)
                dict[kColor] = _colorInfo.backgroundColor;

            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                                    object:nil
                                                                  userInfo:dict];
                [self _updateAppLabels];
            });
        });
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                        object:nil
                                                      userInfo:dict];
}

- (void)_updateAppLabels {
    SBIconViewMap *viewMap = ((SBIconController *)[%c(SBIconController) sharedInstance]).homescreenIconViewMap;
    [viewMap enumerateMappedIconViewsUsingBlock:^(SBIconView *iconView) {
        [iconView _updateLabel];
    }];
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
    if (![urlString isEqualToString:_canvasURL]) {
        _canvasURL = urlString;

        if (_insideApp || !_screenTurnedOn)
            _isDirty = YES;

        [self _sendCanvasUpdatedNotification];
    }
}

@end
