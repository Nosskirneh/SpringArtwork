#import "SAViewController.h"
#import <SpringBoard/SBUserAgent.h>

@interface SBWallpaperEffectView : UIView
@property (nonatomic, retain) UIView *blurView;
@end

@interface SBDockView : UIView {
    SBWallpaperEffectView *_backgroundView;
}
@end

@interface SBRootFolderView : UIView
- (SBDockView *)dockView;
@end

@interface SBRootFolderController : UIViewController
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end

@interface SBIconController : NSObject
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
@end


@interface SBWallpaperController : NSObject
@property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
@property (nonatomic, retain) SAViewController *homescreenCanvasViewController;
@end


@interface SBCoverSheetPrimarySlidingViewController : UIViewController
@property (nonatomic, retain) SAViewController *canvasNormalViewController;
@property (nonatomic, retain) SAViewController *canvasFadeOutViewController;
@property (nonatomic, retain) SBWallpaperEffectView *panelWallpaperEffectView; // iOS 11 and 12
@property (nonatomic, retain) SBWallpaperEffectView *panelFadeOutWallpaperEffectView; // iOS 12
@end


@interface SpringBoard : NSObject
- (SBUserAgent *)pluginUserAgent;
- (id)_accessibilityFrontMostApplication;
@end


@interface FBProcessState : NSObject
@property (assign, getter=isForeground, nonatomic) BOOL foreground;
@end

@interface SBApplicationProcessState : NSObject
@property (getter=isForeground, nonatomic, readonly) BOOL foreground;
@end

@interface SBApplication : NSObject
@property (retain) FBProcessState *processState; // iOS 10 and below
@property (setter=_setInternalProcessState:, getter=_internalProcessState, retain) SBApplicationProcessState *internalProcessState; // iOS 11 and above
@end
