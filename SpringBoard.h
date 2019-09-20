#import "SAViewController.h"
#import "SBWallpaperEffectView.h"


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


@interface SBHomeScreenBackdropView : UIView {
    UIView *_materialView;
    UIImageView *_blurredContentSnapshotImageView;
}
@end


@interface SBUIController : NSObject {
    SBHomeScreenBackdropView *_homeScreenBackdropView; // iOS 12

    // iOS 11.1.2 and below (11.3.1 unknown)
    UIView *_homeScreenContentBackdropView;
    UIImageView *_homeScreenBlurredContentSnapshotImageView;
}
@property (nonatomic, retain) SAViewController *canvasViewController;
@end


@interface SpringBoard : NSObject
- (id)_accessibilityFrontMostApplication;
@end


@interface SBMutableIconLabelImageParameters
@property (nonatomic, retain) UIColor *textColor;
@end
