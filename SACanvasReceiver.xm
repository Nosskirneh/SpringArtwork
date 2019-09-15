#import "SACanvasReceiver.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "Common.h"
#import <notify.h>

#define kNotificationNameDidChangeDisplayStatus "com.apple.iokit.hid.displayStatus"


@implementation SACanvasReceiver {
    int _notifyTokenForDidChangeDisplayStatus;
    BOOL _manuallyPaused;
    BOOL _playing;
    UIImpactFeedbackGenerator *_hapticGenerator;
}

#pragma mark Public

- (void)setup {
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:SPBG_IDENTIFIER];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c registerForMessageName:kCanvasURLMessage target:self selector:@selector(_handleIncomingMessage:withUserInfo:)];

    [self _registerScreenEvent];
}

- (BOOL)isActive {
    return _canvasURL != nil;
}

- (void)loadHaptic {
    _hapticGenerator = [[%c(UIImpactFeedbackGenerator) alloc] initWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)togglePlayManually {
    if (![self isActive])
        return;

    [_hapticGenerator impactOccurred];
    [[NSNotificationCenter defaultCenter] postNotificationName:kTogglePlayPause
                                                        object:nil];
    if (_playing)
        _manuallyPaused = YES;

    _playing = !_playing;
}

#pragma mark Private

- (BOOL)_registerScreenEvent {
    __weak SACanvasReceiver *weakSelf = self;

    uint32_t result = notify_register_dispatch(kNotificationNameDidChangeDisplayStatus,
       &_notifyTokenForDidChangeDisplayStatus,
       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
       ^(int info) {
            __strong SACanvasReceiver *strongSelf = weakSelf;

            if (strongSelf) {
                // If the user manually paused the video, do not resume on screen turn on event
                if (!_playing && _manuallyPaused)
                    return;

                uint64_t state;
                notify_get_state(_notifyTokenForDidChangeDisplayStatus, &state);

                NSDictionary *info = @{
                    kPlayState : @((BOOL)state)
                };

                [[NSNotificationCenter defaultCenter] postNotificationName:kTogglePlayPause
                                                                    object:nil
                                                                  userInfo:info];
            }
       });
    return result == NOTIFY_STATUS_OK;
}

- (void)_handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    NSString *urlString = dict[kCanvasURL];
    if (![urlString isEqualToString:_canvasURL]) {
        _canvasURL = urlString;
        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateCanvas
                                                            object:nil
                                                          userInfo:dict];
        _manuallyPaused = NO;
        _playing = urlString != nil;
    }
}

@end
