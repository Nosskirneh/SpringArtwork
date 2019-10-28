#import "SAImageHelper.h"
#import "SpringBoard.h"
#import "SettingsKeys.h"

typedef enum UIImpactFeedbackStyle : NSInteger {
    UIImpactFeedbackStyleHeavy,
    UIImpactFeedbackStyleLight,
    UIImpactFeedbackStyleMedium
} UIImpactFeedbackStyle;

@interface UIImpactFeedbackGenerator : NSObject
- (id)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
@end

@protocol SAViewControllerManager
- (void)addNewViewController:(SAViewController *)viewController;
- (void)_videoEnded;
@end

@interface SAManager : NSObject<SAViewControllerManager>
@property (nonatomic, retain, readonly) AVAsset *canvasAsset;
@property (nonatomic, retain, readonly) SAColorInfo *colorInfo;
@property (nonatomic, retain, readonly) UIColor *folderColor;
@property (nonatomic, assign, readonly) BOOL useBackgroundColor;
@property (nonatomic, retain, readonly) UIImage *artworkImage;
@property (nonatomic, retain, readonly) UIImage *blurredImage;
@property (nonatomic, retain, readonly) UIImage *canvasThumbnail;

@property (nonatomic, assign, readonly) EnabledMode enabledMode;
@property (nonatomic, retain) SAViewController *inChargeController;
@property (nonatomic, assign) BOOL isSharedWallpaper;
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;

/* Settings properties */
@property (nonatomic, assign, readonly) int artworkWidthPercentage;
@property (nonatomic, assign, readonly) int artworkYOffsetPercentage;
@property (nonatomic, assign, readonly) BOOL shakeToPause;
@property (nonatomic, assign, readonly) BOOL hideDockBackground;
// ---

@property (nonatomic, assign, readonly) BOOL trialEnded;
- (void)setTrialEnded;

- (void)setupWithPreferences:(NSDictionary *)preferences;
- (void)togglePlayManually;
- (void)loadHaptic;
/* isDirty marks that there has been a change of canvasURL,
   but we're not updating it because once the event occurred
   the device was either at sleep or some app was in the foreground. */
- (BOOL)isDirty;
- (BOOL)isCanvasActive;
- (BOOL)changedContent;

- (void)mediaWidgetWillHide;
@end
