#import "SAManager.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "Common.h"
#import <notify.h>
#import "SpringBoard.h"
#import "ApplicationProcesses.h"
#import <SpringBoard/SBMediaController.h>
#import <MediaRemote/MediaRemote.h>

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"
#define kSBApplicationProcessStateDidChange @"SBApplicationProcessStateDidChange"
#define kSBMediaApplicationActivityDidEndNotification @"SBMediaApplicationActivityDidEndNotification"
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
    if ([bundleID isEqualToString:kSpotifyBundleID]) {
        if (!_canvasURL)
            [self _updateArtwork];
    } else {
        _canvasURL = nil;

        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                            object:nil];
    }
}

- (void)_nowPlayingChanged:(NSNotification *)notification {
    if (!_canvasURL)
        [self _updateArtwork];
}

- (void)_updateArtwork {
    [self _fetchArtwork:^(UIImage *image) {
        NSMutableDictionary *dict = nil;
        if (image) {
            dict = [NSMutableDictionary new];
            dict[kArtworkImage] = image;

            if (YES/*shouldBlur*/) // TODO: Add settings for this
                dict[kBlurredImage] = [self _blurredImage:image];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                            object:nil
                                                          userInfo:dict];
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

- (void)_fetchArtwork:(void (^)(UIImage *))completion {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        NSDictionary *dict = (__bridge NSDictionary *)information;
        if ([dict[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"] isEqualToString:_artworkIdentifier])
            return;

        NSData *imageData = dict[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
        if (!imageData) { 
            _artworkIdentifier = nil;
            return completion(nil);
        }

        _artworkIdentifier = dict[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];

        HBLogDebug(@"We got the information: %@ – %@", dict[@"kMRMediaRemoteNowPlayingInfoTitle"], dict[@"kMRMediaRemoteNowPlayingInfoArtist"]);
        completion([UIImage imageWithData:imageData]);
    });
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
