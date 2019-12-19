#import "SAImageHelper.h"
#import "SAViewControllerManager.h"
#import "SpringBoard.h"
#import "SettingsKeys.h"
#import "SABlurEffect.h"

typedef enum UIImpactFeedbackStyle : NSInteger {
    UIImpactFeedbackStyleHeavy,
    UIImpactFeedbackStyleLight,
    UIImpactFeedbackStyleMedium
} UIImpactFeedbackStyle;

@interface UIImpactFeedbackGenerator : NSObject
- (id)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
@end

@interface SAManager : NSObject<SAViewControllerManager>
@property (nonatomic, retain, readonly) AVAsset *canvasAsset;
@property (nonatomic, retain, readonly) UIImage *canvasThumbnail;
@property (nonatomic, retain, readonly) SAColorInfo *colorInfo;
@property (nonatomic, retain, readonly) UIColor *blendedCDBackgroundColor;
@property (nonatomic, retain, readonly) UIColor *folderColor;
@property (nonatomic, retain, readonly) UIColor *folderBackgroundColor;
@property (nonatomic, assign, readonly) BOOL useBackgroundColor;
@property (nonatomic, retain, readonly) UIImage *artworkImage;
@property (nonatomic, retain, readonly) UIImage *blurredImage;
@property (nonatomic, retain, readonly) SABlurEffect *blurEffect;

@property (nonatomic, assign, readonly) EnabledMode enabledMode;
@property (nonatomic, retain) SAViewController *inChargeController;
@property (nonatomic, assign) BOOL isSharedWallpaper;
@property (nonatomic, retain, readonly) _UILegibilitySettings *legibilitySettings;
@property (nonatomic, assign, readonly) BOOL insideApp;
@property (nonatomic, assign) BOOL lockscreenPulledDownInApp;

/* Settings properties */
@property (nonatomic, assign, readonly) BOOL onlyBackground;
@property (nonatomic, assign, readonly) int artworkWidthPercentage;
@property (nonatomic, assign, readonly) int artworkYOffsetPercentage;
@property (nonatomic, assign, readonly) BOOL shakeToPause;
@property (nonatomic, assign, readonly) BOOL hideDockBackground;
// ---

@property (nonatomic, assign, readonly) BOOL trialEnded;
- (void)setTrialEnded;

- (void)setupWithPreferences:(NSDictionary *)preferences;
- (void)togglePlayManually;
- (void)setupHaptic;

- (BOOL)hasContent;
- (BOOL)hasPlayableContent;
- (BOOL)isCanvasActive;
- (BOOL)hasAnimatingArtwork;

/* isDirty marks that there has been a change of canvasURL,
   but we're not updating it because once the event occurred
   the device was either at sleep or some app was in the foreground. */
- (BOOL)isDirty;
- (BOOL)changedContent;

- (void)hide;
- (void)mediaWidgetDidActivate:(BOOL)activate;
- (CMTime)canvasCurrentTime;
- (NSNumber *)artworkAnimationTime;

- (int)artworkCornerRadiusPercentage;
- (void)setShouldAddRotation;
@end
