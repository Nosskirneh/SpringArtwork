#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@interface SAViewController : UIViewController
@property (nonatomic, readonly) BOOL homescreen;
@property (nonatomic, retain, readonly) AVPlayerLayer *canvasLayer;
- (id)initWithTargetView:(UIView *)view homescreen:(BOOL)homescreen;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
@end
