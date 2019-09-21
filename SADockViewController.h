#import "SAViewController.h"

@interface SAViewController (Private)
- (void)_artworkUpdatedWithImage:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color stillPlaying:(BOOL)stillPlaying;
- (BOOL)_showArtworkViews;
- (BOOL)_hideArtworkViews;
- (void)_canvasUpdatedWithURLString:(NSString *)url isDirty:(BOOL)isDirty stillPlaying:(BOOL)stillPlaying;
- (BOOL)_fadeCanvasLayerIn;
- (BOOL)_fadeCanvasLayerOut;
- (void)_performLayerOpacityAnimation:(CALayer *)layer show:(BOOL)show completion:(void (^)(void))completion;
@end

@interface SADockViewController : SAViewController
@end
