#import "SAViewController.h"
#import "SBWallpaperEffectView.h"


typedef enum AppearState {
    Lockscreen = 1,
    Homescreen = 3
} AppearState;

@interface SBCoverSheetPrimarySlidingViewController : UIViewController
@property (nonatomic, assign) AppearState appearState;
@property (nonatomic, assign) BOOL pulling;
@property (nonatomic, retain) SAViewController *canvasNormalViewController;
@property (nonatomic, retain) SAViewController *canvasFadeOutViewController;
@property (nonatomic, retain) SBWallpaperEffectView *panelWallpaperEffectView; // iOS 11 and 12
@property (nonatomic, retain) SBWallpaperEffectView *panelFadeOutWallpaperEffectView; // iOS 12
- (void)sa_checkCreationOfNormalController;
- (void)sa_hideWallpaperView:(BOOL)hide;
@end


@interface SBFProceduralWallpaperView : UIView
@property (nonatomic, readonly) UIView *proceduralWallpaper;
@end


typedef NS_ENUM(NSUInteger, IrisWallpaperMode) {
    LockscreenVisible = 0,
    LockscreenNotVisible = 1
};

@interface ISPlayerView : UIView
@property (nonatomic, readonly) UIGestureRecognizer *gestureRecognizer;
@end

@interface SBFIrisWallpaperView : UIView
- (UIGestureRecognizer *)irisGestureRecognizer;
@end


/* iOS 11 media widget inactivity */
typedef enum NowPlayingState {
    Inactive,
    Paused,
    Playing
} NowPlayingState;

@interface SBLockScreenNowPlayingController : NSObject
@property (nonatomic, readonly) NowPlayingState currentState;
@end
//---


// iOS 12
@interface SBHomeScreenBackdropView : UIView {
    UIView *_materialView;
    UIImageView *_blurredContentSnapshotImageView;
}
- (NSString *)sa_appSwitcherBackdropReason;
@end

@interface SBUIController : NSObject {
    SBHomeScreenBackdropView *_homeScreenBackdropView; // iOS 12

    // iOS 11.1.2 and below (11.3.1 unknown)
    UIView *_homeScreenContentBackdropView;
    UIImageView *_homeScreenBlurredContentSnapshotImageView;
}
@property (nonatomic, retain) SAViewController *canvasViewController;
+ (id)sharedInstance;
@end


@class SBIcon;

@interface SBFolderIconImageView : UIImageView
@property (nonatomic, retain) SBWallpaperEffectView *backgroundView;
@property (nonatomic, readonly) SBIcon *icon;
- (void)sa_colorizeFolderBackground:(UIColor *)color;
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


@interface SBFloatingDockPlatterView : UIView
@property (nonatomic, retain) UIView *backgroundView;
@end

@interface SBFloatingDockView : UIView
@property(retain, nonatomic) UIView *backgroundView; // iOS 13 only
@property (nonatomic, retain) SBFloatingDockPlatterView *mainPlatterView; // iOS 11-12
@end

@interface SBFloatingDockViewController : UIViewController
@property (nonatomic, retain) SBFloatingDockView *dockView;
@end

@interface SBFloatingDockRootViewController : UIViewController
@property (nonatomic, retain) SBFloatingDockViewController *floatingDockViewController;
@end

@interface SBFloatingDockController : NSObject
@property (nonatomic, readonly) SBFloatingDockViewController *floatingDockViewController; // iOS 13 only
@property (nonatomic, readonly) UIViewController *viewController; // iOS 11-13
+ (id)sharedInstance; // iOS 11-12 only
+ (BOOL)isFloatingDockSupported;
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
    UIImageView *_tintView;
}
- (UIColor *)_tintViewBackgroundColorAtFullAlpha;
@end

@interface SBFloatyFolderBackgroundClipView : UIView
@property (nonatomic, readonly) SBFolderBackgroundView *backgroundView;
- (void)nu_colorizeFolderBackground:(UIColor *)color;
@end

@interface SBFloatyFolderView : UIView {
    SBFloatyFolderBackgroundClipView *_scrollClipView;
}
@end



@interface SBIcon : NSObject
@end

@interface SBFolderIcon : SBIcon
@end

@class SBIconController;

@interface SBIconView : UIView
@property (assign, nonatomic) SBIconController *delegate;

// iOS 13 only
@property (nonatomic,retain) UIView * folderIconBackgroundView;
- (SBFolderIconImageView *)_folderIconImageView;
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
- (void)sa_colorizeFolderBackground:(SBFolderIconBackgroundView *)backgroundView
                              color:(UIColor *)color;
@end

@interface SBIconViewMap : NSObject
- (SBIconView *)mappedIconViewForIcon:(SBIcon *)icon;
@end

@interface SBIconListModel : NSObject
- (void)enumerateFolderIconsUsingBlock:(void (^)(SBFolderIcon *))block;
@end

@interface SBIconListView : UIView
@property (nonatomic, retain) SBIconListModel *model;
@property (nonatomic, retain) SBIconViewMap *viewMap;

- (SBIconView *)iconViewForIcon:(SBIcon *)icon;
- (void)enumerateIconsUsingBlock:(void (^)(SBIcon *))block;
@end

@interface SBRootIconListView : SBIconListView
@end

@protocol SBWallpaperControllerClass
@property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
@property (nonatomic, retain) SAViewController *homescreenCanvasViewController;
- (UIView *)sa_newWallpaperViewCreated:(UIView *)wallpaperView
                               variant:(long long)variant
                                shared:(BOOL)shared;
- (void)updateHomescreenCanvasViewControllerWithWallpaperView:(UIView *)wallpaperView;
- (void)updateLockscreenCanvasViewControllerWithWallpaperView:(UIView *)wallpaperView;
- (void)destroyLockscreenCanvasViewController;
@end

@interface SBWallpaperController : NSObject <SBWallpaperControllerClass>
+ (id)sharedInstance;
- (_UILegibilitySettings *)legibilitySettingsForVariant:(long long)variant;
- (CGImage *)homescreenLightForegroundBlurImage;
@end

@interface SBWallpaperViewController : UIViewController <SBWallpaperControllerClass>
@end


@interface _SBIconWallpaperBackgroundProvider : NSObject
- (void)_updateAllClients;
@end

@interface SBDashBoardLegibilityProvider : NSObject
- (_UILegibilitySettings *)currentLegibilitySettings;
@end



@interface SBFolderController : UIViewController
@property (assign, nonatomic) id folderDelegate;
@property (nonatomic, copy, readonly) NSArray *iconListViews;
@end

@interface SBRootFolderController : SBFolderController
@property (nonatomic, readonly) SBIconListView *currentIconListView;
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end

@interface SBFolderController (Extra)
@property (nonatomic, readonly) SBFloatyFolderView *contentView;
@end


@interface SBIconController : NSObject
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
@property (nonatomic, readonly) SBFloatingDockController *floatingDockController; // iOS 13 only
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
- (SBFolderController *)_openFolderController;
- (UIView *)contentView;
@end




@protocol CoverSheetView
@property (nonatomic, retain) SAViewController *canvasViewController;
@end

@interface CSCoverSheetView : UIView<CoverSheetView>
@end

@interface SBDashBoardView : UIView<CoverSheetView>
@end


@protocol CoverSheetViewController
@property (nonatomic, retain) UIView<CoverSheetView> *view;
@property (nonatomic, retain) SBFIrisWallpaperView *irisWallpaperView;
@property (nonatomic, retain) SBDashBoardLegibilityProvider *legibilityProvider;
- (void)_updateActiveAppearanceForReason:(id)reason;
@end

@interface CSCoverSheetViewController : UIViewController<CoverSheetViewController>
@end

@interface SBDashBoardViewController : UIViewController<CoverSheetViewController>
@end

@interface SBLockScreenManager : NSObject
@property (nonatomic, readonly) SBDashBoardViewController *dashBoardViewController; // iOS 11 & 12
@property (nonatomic, readonly) CSCoverSheetViewController *coverSheetViewController; // iOS 13
+ (id)sharedInstance;
- (void)sa_playArtworkAnimation:(BOOL)play;
@end

@interface SBCoverSheetPresentationManager : NSObject
@property (nonatomic, retain) SBCoverSheetPrimarySlidingViewController *coverSheetSlidingViewController;
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
- (void)modifySettingsWithBlock:(void (^)(SBMutableAppStatusBarSettings *))block;
@end


@interface SBAppStatusBarAssertionManager : NSObject
+ (id)sharedInstance;
- (SBMutableAppStatusBarSettings *)currentStatusBarSettings;
- (void)_enumerateAssertionsToLevel:(unsigned long long)level
                          withBlock:(void (^)(SBAppStatusBarSettingsAssertion *))completion;
@end



#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
typedef enum UIUserInterfaceStyle : NSInteger {
    UIUserInterfaceStyleUnspecified,
    UIUserInterfaceStyleLight,
    UIUserInterfaceStyleDark
} UIUserInterfaceStyle;

@interface UITraitCollection (iOS12_13)
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
@end
#endif
