#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerLayer.h>

@interface SBFStaticWallpaperView : UIView
@property (nonatomic, retain) AVPlayerLayer *playerLayer;
- (void)_setupPlayerLayer:(UIView *)view;
@end
