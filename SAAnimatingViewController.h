#import "SAViewControllerManager.h"
#import <AVFoundation/AVFoundation.h>

@protocol SAViewControllerManager;

@protocol SAContentViewController
- (void)artworkUpdated:(id<SAViewControllerManager>)manager;
- (void)performLayerOpacityAnimation:(CALayer *)layer
                                show:(BOOL)show
                          completion:(void (^)(void))completion;
- (void)updateArtworkCornerRadius:(int)percentage;
- (void)updateBlurEffect:(BOOL)blur;
- (void)setArtwork:(UIImage *)artwork;
- (void)rotateToRadians:(float)rotation duration:(float)duration;
@end

@protocol SAAnimatingViewController
- (void)replayVideo;
- (void)togglePlayPauseWithState:(BOOL)playState;
- (void)togglePlayPause;
- (void)updateArtworkWidthPercentage:(int)percentage
                   yOffsetPercentage:(int)yOffsetPercentage;
- (void)addArtworkRotation;
- (void)removeArtworkRotation;
- (void)performWithoutAnimation:(void (^)(void))block;
- (void)updateRelevantStartTime;
- (void)updateCanvasStartTime;
- (void)updateAnimationStartTime;
- (CMTime)canvasCurrentTime;
- (NSNumber *)artworkAnimationTime;
@end
