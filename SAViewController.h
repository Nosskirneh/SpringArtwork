#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@interface SAViewController : UIViewController
- (id)initWithTargetView:(UIView *)view;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
- (void)_setPreventsSleepDuringVideoPlayback:(BOOL)preventSleep;
@end
