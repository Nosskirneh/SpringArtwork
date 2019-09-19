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
- (void)setup;
- (void)togglePlayManually;
- (void)loadHaptic;
- (BOOL)isCanvasActive;
@end
