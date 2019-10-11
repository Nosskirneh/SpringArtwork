#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@interface SAViewController : UIViewController
- (id)initWithTargetView:(UIView *)view manager:(id)manager;
- (id)initWithManager:(id)manager;
- (void)setTargetView:(UIView *)targetView;
- (void)replayVideo;
- (void)togglePlayPauseWithState:(BOOL)playState;
- (void)togglePlayPause;
- (void)artworkUpdated:(id)manager;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
- (void)_setPreventsSleepDuringVideoPlayback:(BOOL)preventSleep;
@end
