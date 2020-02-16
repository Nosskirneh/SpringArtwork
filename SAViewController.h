#import <AVFoundation/AVFoundation.h>
#import "SAViewControllerManager.h"
#import "SAAnimatingViewController.h"

@interface SAViewController : UIViewController<SAContentViewController, SAAnimatingViewController>
/* Public */
- (id)initWithManager:(id)manager;
- (id)initWithTargetView:(UIView *)targetView
                 manager:(id<SAViewControllerManager>)manager;
- (id)initWithTargetView:(UIView *)targetView
                 manager:(id<SAViewControllerManager>)manager
                inCharge:(BOOL)inCharge;
- (void)setTargetView:(UIView *)targetView;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
- (void)_setPreventsSleepDuringVideoPlayback:(BOOL)preventSleep;
@end
