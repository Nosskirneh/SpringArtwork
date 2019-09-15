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
@property (nonatomic, retain, readonly) UIImpactFeedbackGenerator *hapticGenerator;
- (void)setup;
- (void)loadHaptic;
- (BOOL)isActive;
@end
