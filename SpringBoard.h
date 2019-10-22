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


@interface SBFProceduralWallpaperView : UIView
@property (nonatomic, readonly) UIView *proceduralWallpaper;
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

@interface SBIconListPageControl : NSObject
- (void)setLegibilitySettings:(_UILegibilitySettings *)settings;
@end

@interface SBFolderView : UIView
@property (nonatomic, retain) SBIconListPageControl *pageControl;
@end

@interface SBMutableIconLabelImageParameters
@property (nonatomic, retain) UIColor *textColor;
@end

@interface SBDockView : UIView {
    SBWallpaperEffectView *_backgroundView;
}
@end

@interface SBRootFolderView : SBFolderView
@property (nonatomic, copy, readonly) NSArray *iconListViews;
- (SBDockView *)dockView;
@end

@interface SBFolderBackgroundView : UIView {
    UIImageView *_tintView;;
}
@end

@interface SBFloatyFolderBackgroundClipView : UIView
@property (nonatomic, readonly) SBFolderBackgroundView *backgroundView;
@end

@interface SBFloatyFolderView : UIView {
    SBFloatyFolderBackgroundClipView *_scrollClipView;
}
@end

@interface SBFolderController : UIViewController
@property (assign, nonatomic) id folderDelegate;
@property (nonatomic, copy, readonly) NSArray *iconListViews;
@end

@interface SBRootFolderController : SBFolderController
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end

@interface SBFolderController (Extra)
@property (nonatomic, readonly) SBFloatyFolderView *contentView;
@end


@interface SBIconController : NSObject
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
- (UIView *)contentView;
@end


@interface SBIcon : NSObject
@end

@interface SBFolderIcon : SBIcon
@end

@interface SBIconView : UIView
@property (assign, nonatomic) SBIconController *delegate;
@end

@interface SBIconBlurryBackgroundView : UIView
- (void)setWallpaperBackgroundRect:(CGRect)rect
                       forContents:(CGImageRef)image
                 withFallbackColor:(CGColorRef)color;
- (CGRect)wallpaperRelativeBounds;
@end

@interface SBFolderIconBackgroundView : SBIconBlurryBackgroundView
@end

@interface SBFolderIconView : SBIconView
- (SBFolderIconBackgroundView *)iconBackgroundView;
- (void)sa_tryChangeColor;
- (void)sa_colorFolderBackground:(SBFolderIconBackgroundView *)backgroundView;
@end

@interface SBIconViewMap : NSObject
- (SBIconView *)mappedIconViewForIcon:(SBIcon *)icon;
@end

@interface SBIconListModel : NSObject
- (void)enumerateFolderIconsUsingBlock:(void (^)(SBFolderIcon *))completion;
@end

@interface SBIconListView : UIView
@property (nonatomic, retain) SBIconListModel *model;
@property (nonatomic, retain) SBIconViewMap *viewMap;
@end

@interface SBRootIconListView : SBIconListView
@end


@interface SBWallpaperController : NSObject
@property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
@property (nonatomic, retain) SAViewController *homescreenCanvasViewController;
+ (id)sharedInstance;
- (_UILegibilitySettings *)legibilitySettingsForVariant:(long long)variant;
- (CGImage *)homescreenLightForegroundBlurImage;
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
