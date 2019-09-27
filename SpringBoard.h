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




@interface _UILegibilitySettings : NSObject
@property (nonatomic, retain) UIColor *primaryColor;
+ (id)sharedInstanceForStyle:(NSInteger)style;
@end

@interface SBUILegibilityLabel : UIView
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
- (void)setTextColor:(UIColor *)color;
- (void)_updateLegibilityView;
- (void)_updateLabelForLegibilitySettings;
@end

@interface SBFLockScreenDateSubtitleDateView : UIView {
    SBUILegibilityLabel *_label;
}
@end

@interface SBFLockScreenDateView : UIView {
    SBUILegibilityLabel *_timeLabel;
    SBFLockScreenDateSubtitleDateView *_dateSubtitleView;
}
- (SBUILegibilityLabel *)_timeLabel;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
@end

@interface SBLockScreenDateViewController : UIViewController
@property (nonatomic, retain) SBFLockScreenDateView *view;
@end

@interface SBDashBoardViewController : UIViewController
@property (nonatomic, retain) SBLockScreenDateViewController *dateViewController;
@end

@interface SBLockScreenManager : NSObject
@property (nonatomic, readonly) SBDashBoardViewController *dashBoardViewController;
@end



#import <UIKit/UIStatusBar.h>
@interface UIStatusBar (Missing)
@property (retain, nonatomic) UIColor *foregroundColor;
@end



@interface SBMutableAppStatusBarSettings : NSObject
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
- (void)setStyle:(long long)style;
- (void)setLegibilitySettings:(_UILegibilitySettings *)settings;
@end



@interface SBAppStatusBarSettingsAssertion : NSObject
@property (nonatomic, copy, readonly) SBMutableAppStatusBarSettings *settings;
- (void)modifySettingsWithBlock:(void (^)(SBMutableAppStatusBarSettings *))arg1;
@end


@interface SBAppStatusBarAssertionManager : NSObject
+ (id)sharedInstance;
- (SBMutableAppStatusBarSettings *)currentStatusBarSettings;
- (void)_enumerateAssertionsToLevel:(unsigned long long)arg1 withBlock:(void (^)(SBAppStatusBarSettingsAssertion *))completion;
@end






@interface SBMutableIconLabelImageParameters
@property (nonatomic, retain) UIColor *textColor;
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


@interface SBIconView : UIView
@property (nonatomic,retain) _UILegibilitySettings * legibilitySettings;
- (void)_updateLabel;
@end

@interface SBIconViewMap
@property (retain, nonatomic) _UILegibilitySettings *legibilitySettings;
- (void)enumerateMappedIconViewsUsingBlock:(void (^)(SBIconView *))block;
@end

@interface SBIconController : NSObject
@property (nonatomic,readonly) SBIconViewMap *homescreenIconViewMap;
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
- (UIView *)contentView;
@end

