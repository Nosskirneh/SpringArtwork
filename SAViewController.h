#import <AVFoundation/AVFoundation.h>
#import "SAViewControllerManager.h"
#import "SAAnimatingViewController.h"

@interface SAViewController : UIViewController<SAContentViewController, SAAnimatingViewController>
@property (nonatomic, assign, readonly) BOOL noAutomaticRotation;
/* Public */
- (id)initWithManager:(id)manager;
- (id)initWithTargetView:(UIView *)targetView
                 manager:(id<SAViewControllerManager>)manager;
- (id)initWithTargetView:(UIView *)targetView
                 manager:(id<SAViewControllerManager>)manager
                inCharge:(BOOL)inCharge;
- (id)initWithTargetView:(UIView *)targetView
                 manager:(id<SAViewControllerManager>)manager
     noAutomaticRotation:(BOOL)noAutomaticRotation;
- (void)setTargetView:(UIView *)targetView;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(NSError **)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
- (void)_setPreventsSleepDuringVideoPlayback:(BOOL)preventSleep;
@end
