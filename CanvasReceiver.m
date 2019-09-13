#import "CanvasReceiver.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import "Common.h"

@implementation CanvasReceiver

- (void)setup {
    CPDistributedMessagingCenter *c = [CPDistributedMessagingCenter centerNamed:SPBG_IDENTIFIER];
    rocketbootstrap_distributedmessagingcenter_apply(c);
    [c runServerOnCurrentThread];
    [c registerForMessageName:kCanvasURLMessage target:self selector:@selector(handleIncomingMessage:withUserInfo:)];
}

- (void)handleIncomingMessage:(NSString *)name withUserInfo:(NSDictionary *)dict {
    if (![dict[kCanvasURL] isEqualToString:_canvasURL]) {
        _canvasURL = dict[kCanvasURL];
        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateCanvas
                                                            object:nil];
    }
}

@end
