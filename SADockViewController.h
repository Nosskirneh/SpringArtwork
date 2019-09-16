#import "SAViewController.h"

@interface SAViewController (Private)
- (void)_fadeCanvasLayerIn;
- (void)_fadeCanvasLayerOut;
- (void)_performLayerOpacityAnimation:(CALayer *)layer show:(BOOL)show completion:(void (^)(void))completion;
@end

@interface SADockViewController : SAViewController
@end
