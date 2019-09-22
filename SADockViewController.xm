#import "SADockViewController.h"
#import "DockManagement.h"

// Only the homescreen controller is allowed to change the dock,
// otherwise the two will do it simultaneously which obviously causes issues
@implementation SADockViewController {
    BOOL _skipDock;
}

#pragma mark Private

- (void)_hideDock:(BOOL)hide {
    if (_skipDock) {
        _skipDock = NO;
        return;
    }

    SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
    SBDockView *dockView = [rootFolderController.contentView dockView];
    if (!dockView)
        return;

    UIView *background = MSHookIvar<UIView *>(dockView, "_backgroundView");

    if (!hide)
        background.hidden = NO;

    [self _performLayerOpacityAnimation:background.layer show:!hide completion:^() {
        if (hide)
            background.hidden = YES;
    }];
}

- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork blurredImage:(UIImage *)blurredImage color:(UIColor *)color changeOfContent:(BOOL)changeOfContent {
    _skipDock = changeOfContent;
    [super _noCheck_ArtworkUpdatedWithImage:artwork blurredImage:blurredImage color:color changeOfContent:changeOfContent];
}

- (BOOL)_showArtworkViews {
    if (![super _showArtworkViews])
        return NO;
    [self _hideDock:YES];
    return YES;
}

- (BOOL)_hideArtworkViews {
    if (![super _hideArtworkViews])
        return NO;
    [self _hideDock:NO];
    return YES;
}

- (void)_canvasUpdatedWithURLString:(NSString *)url isDirty:(BOOL)isDirty changeOfContent:(BOOL)changeOfContent {
    _skipDock = changeOfContent;
    [super _canvasUpdatedWithURLString:url isDirty:isDirty changeOfContent:changeOfContent];
}

- (BOOL)_fadeCanvasLayerIn {
    if (![super _fadeCanvasLayerIn])
        return NO;
    [self _hideDock:YES];
    return YES;
}

- (BOOL)_fadeCanvasLayerOut {
    if (![super _fadeCanvasLayerOut])
        return NO;
    [self _hideDock:NO];
    return YES;
}

@end
