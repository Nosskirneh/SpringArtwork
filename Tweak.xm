#import "Spotify.h"
#import "SpringBoard.h"
#import "SADockViewController.h"
#import "SAManager.h"
#import "Common.h"


%group Spotify
    static SpotifyAppDelegate *getSpotifyAppDelegate() {
        return (SpotifyAppDelegate *)[[UIApplication sharedApplication] delegate];
    }

    static id<SPTService> getSessionServiceForClass(Class<SPTService> c, int scope) {
        NSString *scopeStr;
        switch (scope) {
            case session:
                scopeStr = @"session";
                break;
            case application:
                scopeStr = @"application";
                break;
            case zero:
                scopeStr = @"zero";
                break;
        }

        return [getSpotifyAppDelegate() serviceForIdentifier:[c serviceIdentifier] inScope:scopeStr];
    }

    static SPTVideoURLAssetLoaderImplementation *getVideoURLAssetLoader() {
        return ((SPTNetworkServiceImplementation *)getSessionServiceForClass(%c(SPTNetworkServiceImplementation), application)).videoAssetLoader;
    }

    static SPTCanvasTrackCheckerImplementation *getCanvasTrackChecker() {
        return ((SPTCanvasServiceImplementation *)getSessionServiceForClass(%c(SPTCanvasServiceImplementation), session)).trackChecker;
    }

    static void sendCanvasURL(NSURL *url) {
        CPDistributedMessagingCenter *c = [%c(CPDistributedMessagingCenter) centerNamed:SA_IDENTIFIER];
        rocketbootstrap_distributedmessagingcenter_apply(c);

        NSMutableDictionary *dict = [NSMutableDictionary new];

        if (url)
            dict[kCanvasURL] = url.absoluteString;
        [c sendMessageName:kCanvasURLMessage userInfo:dict];
    }

    %hook SPTNowPlayingBarContainerViewController

    - (void)setCurrentTrack:(SPTPlayerTrack *)track {
        NSURL *localURL = nil;  
        if ([getCanvasTrackChecker() isCanvasEnabledForTrack:track]) {
            NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
            localURL = [getVideoURLAssetLoader() localURLForAssetURL:canvasURL];
        }
        sendCanvasURL(localURL);
        %orig;
    }

    %end
%end


%group SpringBoard
    SAManager *manager;

    _UILegibilitySettings *legibilitySettingsForDarkText(BOOL darkText) {
        return [_UILegibilitySettings sharedInstanceForStyle:darkText ? 2 : 1];
    }

    SBDashBoardViewController *getDashBoardViewController() {
        return ((SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance]).dashBoardViewController;
    }

    %hook SBWallpaperController
    %property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
    %property (nonatomic, retain) SAViewController *homescreenCanvasViewController;

    - (id)init {
        [manager loadHaptic];
        return %orig;
    }

    - (UIView *)_makeAndInsertWallpaperViewWithConfiguration:(id)config
                                                  forVariant:(long long)variant
                                                      shared:(BOOL)shared
                                                     options:(unsigned long long)options {
        UIView *wallpaperView = %orig;

        BOOL homescreen = shared || variant == 1;
        if (homescreen)
            self.homescreenCanvasViewController = [[SADockViewController alloc] initWithTargetView:wallpaperView manager:manager];
        else
            self.lockscreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView manager:manager];

        return wallpaperView;
    }

    %end


    /* Register shake gesture to play/pause canvas video */
    %hook UIApplication

    - (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
        %orig;

        if (event.type != UIEventSubtypeMotionShake ||
            ![manager isCanvasActive] ||
            [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication])
            return;

        [manager togglePlayManually];
    }

    %end

    /* Lockscreen */
    %hook SBDashBoardLegibilityProvider

    - (_UILegibilitySettings *)currentLegibilitySettings {
        if (manager.enabledMode == HomescreenMode)
            return %orig;

        SAColorInfo *info = manager.colorInfo;
        if (info)
            return legibilitySettingsForDarkText(info.hasDarkTextColor);

        return %orig;
    }    

    %end


    /* Lockscreen statusbar */
    /* Fix for fake statusbar which is visible when bringing down the lockscreen from
       the homescreen. This is not perfect since it still has a black shadow that then
       jumps to a white one, but it's better than a complete white status bar. */
    %hook SBDashBoardViewController

    - (id)_createFakeStatusBar {
        if (manager.enabledMode == HomescreenMode)
            return %orig;

        UIStatusBar *orig = %orig;

        SAColorInfo *info = manager.colorInfo;
        if (info)
            orig.foregroundColor = info.textColor;

        return orig;
    }

    %end
    // ---

    /* Homescreen app labels */
    %hook SBIconViewMap

    - (void)_recycleIconView:(SBIconView *)iconView {
        %orig;

        if (manager.enabledMode != LockscreenMode) {
            iconView.legibilitySettings = self.legibilitySettings;
            [iconView _updateLabel];
        }
    }

    %end
    // ---

    /* Both LS & HS */
    %hook SBAppStatusBarSettingsAssertion

    %property (nonatomic, retain) _UILegibilitySettings *sa_legibilitySettings;

    - (void)modifySettingsWithBlock:(void (^)(SBMutableAppStatusBarSettings *))completion {
        if (!self.sa_legibilitySettings)
            return %orig;

        if ((manager.enabledMode == HomescreenMode && self.level == FullscreenAlertAnimationAssertionLevel) ||
            (manager.enabledMode == LockscreenMode && self.level == HomescreenAssertionLevel))
            return %orig;

        __block _UILegibilitySettings *_settings = self.sa_legibilitySettings;

        void(^newCompletion)(SBMutableAppStatusBarSettings *) = ^(SBMutableAppStatusBarSettings *statusBarSettings) {
            if (completion)
                completion(statusBarSettings);

            [statusBarSettings setLegibilitySettings:_settings];
        };

        %orig(newCompletion);
    }

    %end
    // ---
%end

%group SBIconViewMap_iOS12
%hook SBIconViewMap
%property (nonatomic, retain) _UILegibilitySettings *legibilitySettings;
%end
%end


/* When opening the app switcher, this method is taking an image of the SB wallpaper, blurs and
   appends it to the SBHomeScreenView. The video is thus seen as paused while actually still playing.
   The solution is to hide the UIImageView and instead always show the transition MTMaterialView. */
%group SwitcherBackdrop_iOS11
%hook SBUIController

- (void)_updateBackdropViewIfNeeded {
    %orig;

    if ([manager isCanvasActive]) {
        MSHookIvar<UIView *>(self, "_homeScreenContentBackdropView").hidden = NO;
        MSHookIvar<UIImageView *>(self, "_homeScreenBlurredContentSnapshotImageView").hidden = YES;
    }
}

%end
%end

%group SwitcherBackdrop_iOS12
%hook SBHomeScreenBackdropView

- (void)_updateBackdropViewIfNeeded {
    %orig;

    if ([manager isCanvasActive]) {
        MSHookIvar<UIView *>(self, "_materialView").hidden = NO;
        MSHookIvar<UIImageView *>(self, "_blurredContentSnapshotImageView").hidden = YES;
        [[%c(SBIconController) sharedInstance] contentView].hidden = NO;
    }
}

%end
%end


// Lockscreen ("NC pulldown")
%hook SBCoverSheetPrimarySlidingViewController
%property (nonatomic, retain) SAViewController *canvasNormalViewController;
%property (nonatomic, retain) SAViewController *canvasFadeOutViewController;

%group newiOS11
- (void)_createFadeOutWallpaperEffectView {
    %orig;

    self.canvasFadeOutViewController = [[SAViewController alloc] initWithTargetView:self.panelFadeOutWallpaperEffectView.blurView manager:manager];
}
%end

%group wallpaperEffectView_newiOS11
- (void)_createPanelWallpaperEffectViewIfNeeded {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView manager:manager];
}
%end

%group wallpaperEffectView_oldiOS11
- (void)_createWallpaperEffectViewFullScreen:(BOOL)fullscreen {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView manager:manager];
}
%end
%end


%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;

    if ([bundleID isEqualToString:kSpotifyBundleID]) {
        %init(Spotify);
    } else {
        // if (fromUntrustedSource(package$bs()))
        //     %init(PackagePirated);

        manager = [[SAManager alloc] init];

        [manager setup];
        %init(SpringBoard);
        %init;

        if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createFadeOutWallpaperEffectView)])
            %init(newiOS11);

        if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createPanelWallpaperEffectViewIfNeeded)])
            %init(wallpaperEffectView_newiOS11);
        else
            %init(wallpaperEffectView_oldiOS11);

        if (%c(SBHomeScreenBackdropView))
            %init(SwitcherBackdrop_iOS12);
        else
            %init(SwitcherBackdrop_iOS11);

        if (![%c(SBIconViewMap) instancesRespondToSelector:@selector(legibilitySettings)])
            %init(SBIconViewMap_iOS12);
    }
}
