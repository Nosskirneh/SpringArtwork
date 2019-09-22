#import "SAViewController.h"

@interface SAViewController (Private)
- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color changeOfContent:(BOOL)changeOfContent;
- (BOOL)_showArtworkViews;
- (BOOL)_hideArtworkViews;
- (void)_canvasUpdatedWithURLString:(NSString *)url isDirty:(BOOL)isDirty changeOfContent:(BOOL)changeOfContent;
- (BOOL)_fadeCanvasLayerIn;
- (BOOL)_fadeCanvasLayerOut;
- (void)_performLayerOpacityAnimation:(CALayer *)layer show:(BOOL)show completion:(void (^)(void))completion;
@end

@interface SADockViewController : SAViewController
@end
