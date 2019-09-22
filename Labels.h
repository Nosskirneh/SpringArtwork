@interface _UILegibilitySettings : NSObject
@property (nonatomic, retain) UIColor *primaryColor;
@end

@interface SBUILegibilityLabel : UIView
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
- (void)setTextColor:(UIColor *)color;
- (void)_updateLegibilityView;
- (void)_updateLabelForLegibilitySettings;
@end

@interface SBFLockScreenDateSubtitleDateView : UIView {
    SBUILegibilityLabel *_label;
}
@end

@interface SBFLockScreenDateView : UIView {
    SBUILegibilityLabel *_timeLabel;
    SBFLockScreenDateSubtitleDateView *_dateSubtitleView;
}
- (SBUILegibilityLabel *)_timeLabel;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
@end

@interface SBLockScreenDateViewController : UIViewController
@property (nonatomic, retain) SBFLockScreenDateView *view;
@end

@interface SBDashBoardViewController : UIViewController
@property (nonatomic, retain) SBLockScreenDateViewController *dateViewController;
@end

@interface SBLockScreenManager : NSObject
@property (nonatomic, readonly) SBDashBoardViewController *dashBoardViewController;
@end
