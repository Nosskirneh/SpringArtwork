#import "SAViewControllerManager.h"
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@protocol SAViewControllerManager;

@protocol SAContentViewController
- (void)artworkUpdated:(id<SAViewControllerManager>)manager;
- (void)performLayerOpacityAnimation:(CALayer *)layer
                                show:(BOOL)show
                          completion:(void (^)(void))completion;
- (void)updateArtworkCornerRadius:(int)percentage;
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
