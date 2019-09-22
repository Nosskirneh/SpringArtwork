#import "SAColorHelper.h"
#import "Artwork.h"

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

@interface SAManager : NSObject
@property (nonatomic, retain, readonly) NSString *canvasURL;
@property (nonatomic, retain, readonly) SAColorInfo *colorInfo;
@property (nonatomic, retain, readonly) UIImage *artworkImage;
- (void)setup;
- (void)togglePlayManually;
- (void)loadHaptic;
- (BOOL)isCanvasActive;
@end
