#import "SADockViewController.h"
#import "SpringBoard.h"
#import "SAManager.h"

extern SAManager *manager;

// Only the homescreen controller is allowed to change the dock,
// otherwise the two will do it simultaneously which obviously causes issues.
// This class is also responsible for subscribing to the repeat event.
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

    [self _performLayerOpacityAnimation:background.layer
                                   show:!hide
                             completion:^{
        if (hide)
            background.hidden = YES;
    }];
}

- (void)_noCheck_ArtworkUpdatedWithImage:(UIImage *)artwork
                            blurredImage:(UIImage *)blurredImage
                                   color:(UIColor *)color
                          changedContent:(BOOL)changedContent {
    _skipDock = changedContent;
    [super _noCheck_ArtworkUpdatedWithImage:artwork
                               blurredImage:blurredImage
                                      color:color
                            changedContent:changedContent];
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

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                changedContent:(BOOL)changedContent {
    _skipDock = changedContent;

    [super _canvasUpdatedWithAsset:asset
                           isDirty:isDirty
                         thumbnail:thumbnail
                    changedContent:changedContent];
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
