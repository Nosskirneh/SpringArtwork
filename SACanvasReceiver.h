typedef enum UIImpactFeedbackStyle : NSInteger {
    UIImpactFeedbackStyleHeavy,
    UIImpactFeedbackStyleLight,
    UIImpactFeedbackStyleMedium
} UIImpactFeedbackStyle;

@interface UIImpactFeedbackGenerator : NSObject
- (id)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
@end

@interface SACanvasReceiver : NSObject
@property (nonatomic, assign, readonly) NSString *canvasURL;
- (void)setup;
- (void)togglePlayManually;
- (void)loadHaptic;
- (BOOL)isActive;
@end
