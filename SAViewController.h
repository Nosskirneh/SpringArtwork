#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@interface SAViewController : UIViewController
- (id)initWithManager:(id)manager;
- (id)initWithTargetView:(UIView *)targetView manager:(id)manager;
- (id)initWithTargetView:(UIView *)targetView manager:(id)manager inCharge:(BOOL)inCharge;
- (void)setTargetView:(UIView *)targetView;
- (void)replayVideo;
- (void)togglePlayPauseWithState:(BOOL)playState;
- (void)togglePlayPause;
- (void)artworkUpdated:(id)manager;
- (void)updateArtworkWidthPercentage:(int)percentage;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
- (void)_setPreventsSleepDuringVideoPlayback:(BOOL)preventSleep;
@end
