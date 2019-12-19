@interface SABlurEffect : UIBlurEffect
@property (nonatomic, retain) NSNumber *blurRadius;
+ (instancetype)effectWithStyle:(UIBlurEffectStyle)style
                     blurRadius:(NSNumber *)blurRadius;
@end


@interface UIBlurEffect (Private)
@property (nonatomic, readonly) long long _style;
@end

@interface UIVisualEffectView (Private)
- (void)_commonInit;
- (void)_updateEffectsFromLegacyEffect;
@end
