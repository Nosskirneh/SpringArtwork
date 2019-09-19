#import "SADockViewController.h"
#import "DockManagement.h"

// Only the homescreen controller is allowed to change the dock,
// otherwise the two will do it simultaneously which obviously causes issues
@implementation SADockViewController

#pragma mark Private

- (void)_hideDock:(BOOL)hide {
    SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
    SBDockView *dockView = [rootFolderController.contentView dockView];
    UIView *background = MSHookIvar<UIView *>(dockView, "_backgroundView");

    if (!hide)
        background.hidden = NO;

    [self _performLayerOpacityAnimation:background.layer show:!hide completion:^() {
        if (hide)
            background.hidden = YES;
    }];
}

- (void)_showArtworkViews {
    [super _showArtworkViews];
    [self _hideDock:YES];
}

- (void)_hideArtworkViews {
    [super _hideArtworkViews];
    [self _hideDock:NO];
}

- (void)_fadeCanvasLayerIn {
    [super _fadeCanvasLayerIn];
    [self _hideDock:YES];
}

- (void)_fadeCanvasLayerOut {
    [super _fadeCanvasLayerOut];
    [self _hideDock:NO];
}

@end
