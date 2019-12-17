@interface SABlurEffect : UIBlurEffect
@property (nonatomic, retain) NSNumber *blurRadius;
+ (instancetype)effectWithStyle:(UIBlurEffectStyle)style
                     blurRadius:(NSNumber *)blurRadius;
@end



@interface UIVisualEffectView (Private)
- (void)_resetEffect;
@end
