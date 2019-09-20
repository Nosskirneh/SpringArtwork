#import "SBWallpaperEffectView.h"

@interface SBDockView : UIView {
    SBWallpaperEffectView *_backgroundView;
}
@end

@interface SBRootFolderView : UIView
- (SBDockView *)dockView;
@end

@interface SBRootFolderController : UIViewController
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end


@interface SBIconView : UIView
- (void)_updateLabel;
@end

@interface SBIconViewMap
- (void)enumerateMappedIconViewsUsingBlock:(void (^)(SBIconView *))block;
@end

@interface SBIconController : NSObject
@property (nonatomic,readonly) SBIconViewMap *homescreenIconViewMap;
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
- (UIView *)contentView;
@end
