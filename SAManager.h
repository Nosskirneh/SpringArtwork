#import "SAImageHelper.h"
#import "SpringBoard.h"
#import "SADockViewController.h"

typedef enum Mode {
    None,
    Canvas,
    Artwork
} Mode;

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
- (void)setDockViewController:(SADockViewController *)dockViewController;
- (void)_videoEnded;
@end

typedef enum EnabledMode {
    BothMode,
    LockscreenMode,
    HomescreenMode
} EnabledMode;

@interface SAManager : NSObject<SAViewControllerManager>
@property (nonatomic, retain, readonly) NSString *canvasURL;
@property (nonatomic, retain, readonly) SAColorInfo *colorInfo;
@property (nonatomic, retain, readonly) UIImage *artworkImage;
@property (nonatomic, assign, readonly) EnabledMode enabledMode;
- (void)setup;
- (void)togglePlayManually;
- (void)loadHaptic;
- (BOOL)isCanvasActive;
@end
