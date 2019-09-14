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
	NSString *urlString = dict[kCanvasURL];
    if (![urlString isEqualToString:_canvasURL]) {
    	_canvasURL = urlString;
        [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateCanvas
                                                            object:nil
                                                          userInfo:dict];
    }
}

@end