#import "SADockViewController.h"
#import "SpringBoard.h"
#import "SAManager.h"

extern SAManager *manager;

// Only the homescreen controller is allowed to change the dock,
// otherwise the two will do it simultaneously which obviously causes issues.
// This class is also responsible for subscribing to the repeat event.
@implementation SADockViewController {
    BOOL _skipDock;
    SAManager *_manager;
}

- (id)initWithTargetView:(UIView *)targetView manager:(SAManager *)manager {
    if (self == [super initWithTargetView:targetView manager:manager]) {
        _manager = manager;
        [manager setDockViewController:self];
    }
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

- (void)_preparePlayerForChange:(AVPlayer *)player {
    if (player.currentItem)
        [[NSNotificationCenter defaultCenter] removeObserver:_manager
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:player.currentItem];
}

- (void)_canvasUpdatedWithAsset:(AVAsset *)asset
                        isDirty:(BOOL)isDirty
                      thumbnail:(UIImage *)thumbnail
                changedContent:(BOOL)changedContent {
    _skipDock = changedContent;

    [super _canvasUpdatedWithAsset:asset isDirty:isDirty thumbnail:thumbnail changedContent:changedContent];
}

- (void)_replaceItemWithItem:(AVPlayerItem *)item player:(AVPlayer *)player {
    [super _replaceItemWithItem:item player:player];

    [[NSNotificationCenter defaultCenter] addObserver:_manager
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
