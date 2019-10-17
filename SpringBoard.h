#import "SAViewController.h"
#import "SBWallpaperEffectView.h"


typedef enum AppearState {
    Lockscreen = 1,
    Homescreen = 3
} AppearState;

@interface SBCoverSheetPrimarySlidingViewController : UIViewController
@property (nonatomic, assign) AppearState appearState;
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

@interface SBWallpaperController : NSObject
@property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
@property (nonatomic, retain) SAViewController *homescreenCanvasViewController;
+ (id)sharedInstance;
- (_UILegibilitySettings *)legibilitySettingsForVariant:(long long)variant;
@end

@interface SBDashBoardLegibilityProvider : NSObject
- (_UILegibilitySettings *)currentLegibilitySettings;
@end

@interface SBDashBoardView : UIView
@property (nonatomic, retain) SAViewController *canvasViewController;
@end

@interface SBDashBoardViewController : UIViewController
@property (nonatomic, retain) SBDashBoardView *view;
@property (nonatomic, retain) SBDashBoardLegibilityProvider *legibilityProvider;
- (void)_updateActiveAppearanceForReason:(id)reason;
@end

@interface SBLockScreenManager : NSObject
@property (nonatomic, readonly) SBDashBoardViewController *dashBoardViewController;
+ (id)sharedInstance;
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


typedef enum {
    HomescreenAssertionLevel,
    FolderAssertionLevel,
    ForegroundAppAssertionLevel,
    ForegroundAppAnimationAssertionLevel,
    AppSwitcherAssertionLevel,
    FullscreenAlertAssertionLevel,
    FullscreenAlertAnimationAssertionLevel,
    PowerDownAssertionLevel,
    LoginWindowAssertionLevel,
    InvalidAssertionLevel
} AssertionLevel;


@interface SBAppStatusBarSettingsAssertion : NSObject
@property (nonatomic, readonly) AssertionLevel level;
@property (nonatomic, retain) _UILegibilitySettings *sa_legibilitySettings;
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

@interface SBIconListPageControl : NSObject
- (void)setLegibilitySettings:(_UILegibilitySettings *)settings;
@end

@interface SBFolderView : UIView
@property (nonatomic, retain) SBIconListPageControl *pageControl;
@end

@interface SBRootFolderView : SBFolderView
- (SBDockView *)dockView;
@end

@interface SBRootFolderController : UIViewController
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end


@interface SBIconController : NSObject
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
- (UIView *)contentView;
@end
