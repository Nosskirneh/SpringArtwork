#import "SAManager.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "Common.h"
#import <notify.h>
#import "SpringBoard.h"
#import "ApplicationProcesses.h"
#import <SpringBoard/SBMediaController.h>

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"
#define kSBApplicationProcessStateDidChange @"SBApplicationProcessStateDidChange"
#define kSBMediaApplicationActivityDidEndNotification @"SBMediaApplicationActivityDidEndNotification"
#define kSBMediaNowPlayingAppChangedNotification @"SBMediaNowPlayingAppChangedNotification"
#define kSBMediaNowPlayingChangedNotification @"SBMediaNowPlayingChangedNotification"


@implementation SAManager {
    int _notifyTokenForDidChangeDisplayStatus;
    BOOL _manuallyPaused;
    BOOL _playing;
    BOOL _subscribedToMediaInfo;
    UIImpactFeedbackGenerator *_hapticGenerator;
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
            // If the user manually paused the video, do not resume on screen turn on event
            if (![self isCanvasActive] || (!_playing && _manuallyPaused))
                return;

            uint64_t state;
            notify_get_state(_notifyTokenForDidChangeDisplayStatus, &state);
            [self _sendCanvasPlayPauseNotificationWithState:BOOL(state)];
       });

    return result == NOTIFY_STATUS_OK;
}

- (void)_unregisterEventsForCanvasMode {
    if (_notifyTokenForDidChangeDisplayStatus != 0)
        [self _unregisterScreenEvent];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSBApplicationProcessStateDidChange
                                                  object:nil];
}

- (BOOL)_unregisterScreenEvent {
    return notify_cancel(_notifyTokenForDidChangeDisplayStatus) == NOTIFY_STATUS_OK;
}

- (void)_subscribeToMediaInfo {
    if (_subscribedToMediaInfo)
        return;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_nowPlayingChanged:)
                                                 name:kSBMediaNowPlayingChangedNotification
                                               object:nil];
    _subscribedToMediaInfo = YES;
}

- (void)_unsubscribeToMediaInfo {
    if (!_subscribedToMediaInfo)
        return;

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSBMediaNowPlayingChangedNotification
                                                  object:nil];
    _subscribedToMediaInfo = NO;
}

- (void)_sendCanvasPlayPauseNotificationWithState:(BOOL)newState {
    NSDictionary *info = @{
        kPlayState : @(newState)
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:kTogglePlayPause
                                                        object:nil
                                                      userInfo:info];
}

- (void)_currentAppChanged:(NSNotification *)notification {    
    // If the user manually paused the video, do not resume when app enters background
    if (![self isCanvasActive] || (!_playing && _manuallyPaused))
        return;

    SBApplication *app = notification.object;
    BOOL foreground = [app respondsToSelector:@selector(internalProcessState)] ?
                       app.internalProcessState.foreground :
                       app.processState.foreground;
    [self _sendCanvasPlayPauseNotificationWithState:!foreground];
}

- (void)_nowPlayingAppChanged:(NSNotification *)notification {
    HBLogDebug(@"_nowPlayingAppChanged: %@", notification);

    SBMediaController *mediaController = notification.object;
    NSString *bundleID = mediaController.nowPlayingApplication.bundleIdentifier;
    HBLogDebug(@"bundleID: %@", bundleID);
    if ([bundleID isEqualToString:kSpotifyBundleID]) {
        [self _registerEventsForCanvasMode];
        [self _unsubscribeToMediaInfo];

        HBLogDebug(@"updating with URL: %@", _canvasURL);
        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                            object:nil];
    } else {
        [self _unregisterEventsForCanvasMode];
        if (bundleID) {
            HBLogDebug(@"adding again...");
            [self _subscribeToMediaInfo];
        }
    }
}

- (void)_nowPlayingChanged:(NSNotification *)notification {
    HBLogDebug(@"_nowPlayingChanged: %@", notification);
}

- (void)_handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    NSString *urlString = dict[kCanvasURL];
    if (![urlString isEqualToString:_canvasURL]) {
        _canvasURL = urlString;
        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateArtwork
                                                            object:nil
                                                          userInfo:dict];
        _manuallyPaused = NO;
        _playing = urlString != nil;
    }
}

@end
