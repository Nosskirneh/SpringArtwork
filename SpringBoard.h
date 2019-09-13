#import "CanvasReceiver.h"
#import "SAViewController.h"

#define ANIMATION_DURATION 0.75

@interface SBFStaticWallpaperView : UIView
@property (nonatomic, retain) SAViewController *canvasViewController;
@end


@interface SBWallpaperEffectView : UIView {
    SBWallpaperEffectView *_backgroundView;
}
@end

@interface SBDockView : UIView
@end

@interface SBRootFolderView : UIView
- (SBDockView *)dockView;
@end

@interface SBRootFolderController : UIViewController
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end

@interface SBIconController
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(id *)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
@end
