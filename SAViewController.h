#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@interface SAViewController : UIViewController
/* Public */
- (id)initWithManager:(id)manager;
- (id)initWithTargetView:(UIView *)targetView
				 manager:(id)manager;
- (id)initWithTargetView:(UIView *)targetView
				 manager:(id)manager
				inCharge:(BOOL)inCharge;
- (void)setTargetView:(UIView *)targetView;
- (void)replayVideo;
- (void)togglePlayPauseWithState:(BOOL)playState;
- (void)togglePlayPause;
- (void)artworkUpdated:(id)manager;
- (void)updateArtworkWidthPercentage:(int)percentage
				   yOffsetPercentage:(int)yOffsetPercentage;
- (void)addArtworkRotation;



/* Private (exposed to subclasses) */
- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork
                            blurredImage:(UIImage *)blurredImage
                                   color:(UIColor *)color
                          changedContent:(BOOL)changedContent;
- (BOOL)_showArtworkViews:(void (^)())completion;
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


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
- (void)_setPreventsSleepDuringVideoPlayback:(BOOL)preventSleep;
@end
