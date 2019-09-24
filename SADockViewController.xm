#import "SADockViewController.h"
#import "DockManagement.h"
#import "SAManager.h"

extern SAManager *manager;

// Only the homescreen controller is allowed to change the dock,
// otherwise the two will do it simultaneously which obviously causes issues
@implementation SADockViewController {
    BOOL _skipDock;
}

- (id)initWithTargetView:(UIView *)targetView {
    if (self == [super initWithTargetView:targetView])
        [manager setDockViewController:self];
    return self;
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

- (void)_preparePlayerForChange:(AVPlayer *)player {
    if (player.currentItem)
        [[NSNotificationCenter defaultCenter] removeObserver:manager
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];
}

- (void)_canvasUpdatedWithURLString:(NSString *)url isDirty:(BOOL)isDirty changeOfContent:(BOOL)changeOfContent {
    _skipDock = changeOfContent;

    [super _canvasUpdatedWithURLString:url isDirty:isDirty changeOfContent:changeOfContent];
}

- (void)_replaceItemWithItem:(AVPlayerItem *)item player:(AVPlayer *)player {
    [super _replaceItemWithItem:item player:player];

    [[NSNotificationCenter defaultCenter] addObserver:manager
                                             selector:@selector(_videoEnded)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
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
