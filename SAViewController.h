#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioSession.h>

@interface SAViewController : UIViewController
@property (nonatomic, retain, readonly) AVPlayerLayer *canvasLayer;
- (id)initWithTargetView:(UIView *)view;
@end
