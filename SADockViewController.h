#import "SAViewController.h"

@interface SAViewController (Private)
- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork
                            blurredImage:(UIImage *)blurredImage
                                   color:(UIColor *)color
                          changedContent:(BOOL)changedContent;
- (BOOL)_showArtworkViews;
- (BOOL)_hideArtworkViews;
- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                 changedContent:(BOOL)changedContent;
- (BOOL)_fadeCanvasLayerIn;
- (BOOL)_fadeCanvasLayerOut;
- (void)_performLayerOpacityAnimation:(CALayer *)layer
                                 show:(BOOL)show
                           completion:(void (^)(void))completion;
- (void)_replaceItemWithItem:(AVPlayerItem *)item player:(AVPlayer *)player;
@end

@interface SADockViewController : SAViewController
@end
