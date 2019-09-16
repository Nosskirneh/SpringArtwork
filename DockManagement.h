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

@interface SBIconController : NSObject
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
@end
