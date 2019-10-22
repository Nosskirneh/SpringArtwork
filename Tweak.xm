#import "Spotify.h"
#import "SpringBoard.h"
#import "SADockViewController.h"
#import "SAManager.h"
#import "Common.h"
#import <AVFoundation/AVAsset.h>
#import "notifyDefines.h"
#import <notify.h>
#import "DRMValidateOptions.mm"


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

    %property (nonatomic, assign) BOOL sa_onlyOnWifi;

    - (void)loadView {
        %orig;

        int token;
        notify_register_dispatch(kSpotifySettingsChanged,
            &token,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
            ^(int t) {
                NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
                self.sa_onlyOnWifi = preferences[kCanvasOnlyWiFi] && [preferences[kCanvasOnlyWiFi] boolValue];
            });
    }

    - (void)setCurrentTrack:(SPTPlayerTrack *)track {
        if ([getCanvasTrackChecker() isCanvasEnabledForTrack:track]) {
            NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
            if (![canvasURL.absoluteString hasSuffix:@".mp4"])
                return sendCanvasURL(nil);

            SPTVideoURLAssetLoaderImplementation *assetLoader = getVideoURLAssetLoader();

            if ([assetLoader hasLocalAssetForURL:canvasURL]) {
                sendCanvasURL([assetLoader localURLForAssetURL:canvasURL]);
            } else {
                // The compiler doesn't like when I specify AVURLAsset * as type for some reason...
                [assetLoader loadAssetWithURL:canvasURL onlyOnWifi:self.sa_onlyOnWifi completion:^(id asset) {
                    sendCanvasURL(((AVURLAsset *)asset).URL);
                }];
            }

        } else {
            sendCanvasURL(nil);
        }
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

    SBWallpaperController *getWallpaperController() {
        return ((SBWallpaperController *)[%c(SBWallpaperController) sharedInstance]);
    }

    SBIconController *getIconController() {
        return ((SBIconController *)[%c(SBIconController) sharedInstance]);
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

        manager.isSharedWallpaper = shared;
        if (shared) {
            if (manager.enabledMode == LockscreenMode)
                self.lockscreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView
                                                                                           manager:manager
                                                                                          inCharge:YES];
            else
                self.homescreenCanvasViewController = [[SADockViewController alloc] initWithTargetView:wallpaperView
                                                                                               manager:manager
                                                                                              inCharge:YES];
        } else {
            BOOL homescreen = variant == 1;
            if (homescreen) {
                if (manager.enabledMode != LockscreenMode)
                    self.homescreenCanvasViewController = [[SADockViewController alloc] initWithTargetView:wallpaperView
                                                                                                   manager:manager
                                                                                                  inCharge:YES];
            } else if (manager.enabledMode != HomescreenMode)
                self.lockscreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView
                                                                                           manager:manager
                                                                                          inCharge:YES];
        }

        return wallpaperView;
    }

    %end


    /* Dynamic wallpapers send themselves to the front after unlock.
       This overrides that. */
    %hook SBFProceduralWallpaperView

    - (void)prepareToAppear {
        %orig;

        [self sendSubviewToBack:self.proceduralWallpaper];
    }

    %end


    /* Register shake gesture to play/pause canvas video */
    %hook UIApplication

    - (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
        %orig;

        if (event.type != UIEventSubtypeMotionShake ||
            ![manager isCanvasActive] ||
            [(SpringBoard *)[UIApplication sharedApplication] _accessibilityFrontMostApplication] ||
            !manager.shakeToPause)
            return;

        [manager togglePlayManually];
    }

    %end


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


/* If only one of LS and HS is set and the wallpaper is shared, 
   we need to hide/show depending on where the user is looking. */
%group NotBoth
%hook SBCoverSheetPrimarySlidingViewController
%property (nonatomic, assign) AppearState appearState;

- (void)_transitionToViewControllerAppearState:(AppearState)appearState
                                      ifNeeded:(BOOL)needed
                                forUserGesture:(BOOL)forUserGesture {
    %orig;
    self.appearState = appearState;
}

- (void)_finishTransitionToPresented:(BOOL)finish
                            animated:(BOOL)animated
                      withCompletion:(id)completion {
    %orig;
    if (!manager.isSharedWallpaper)
        return;

    BOOL hide = ((self.appearState == Lockscreen && manager.enabledMode == HomescreenMode) ||
                 (self.appearState == Homescreen && manager.enabledMode == LockscreenMode));
    manager.inChargeController.view.hidden = hide;
}

- (void)_beginTransitionFromAppeared:(BOOL)fromLockscreen {
    %orig;

    if (!manager.isSharedWallpaper)
        return;

    // Show when returning from LS?
    if (manager.enabledMode == HomescreenMode && fromLockscreen)
        manager.inChargeController.view.hidden = NO;
    else if (manager.enabledMode == LockscreenMode && fromLockscreen)
        manager.inChargeController.view.hidden = YES;
}

%end
%end
// ---


%group Lockscreen
    /* Lockscreen background when transitioning to camera */
    %hook SBDashBoardViewController

    - (void)loadView {
        %orig;

        self.view.canvasViewController = [[SAViewController alloc] initWithManager:manager];
    }

    %end

    %hook SBDashBoardView
    %property (nonatomic, retain) SAViewController *canvasViewController;

    - (void)setWallpaperEffectView:(UIView *)effectView {
        %orig;

        [self.canvasViewController setTargetView:effectView];
    }

    %end
    // ---


    /* Lockscreen text coloring */
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
    // ---


    /* Lockscreen statusbar */
    /* Fix for fake statusbar which is visible when bringing down the lockscreen from
       the homescreen. This is not perfect since it still has a black shadow that then
       jumps to a white one, but it's better than a complete white status bar. */
    %hook SBDashBoardViewController

    - (UIStatusBar *)_createFakeStatusBar {
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

    %hook SBCoverSheetPrimarySlidingViewController
    %property (nonatomic, retain) SAViewController *canvasNormalViewController;
    %property (nonatomic, retain) SAViewController *canvasFadeOutViewController;
    %end
%end


/* Lockscreen ("NC pulldown") */
%hook SBCoverSheetPrimarySlidingViewController
%group newiOS11
- (void)_createFadeOutWallpaperEffectView {
    %orig;

    self.canvasFadeOutViewController = [[SAViewController alloc] initWithTargetView:self.panelFadeOutWallpaperEffectView.blurView
                                                                            manager:manager];
}
%end

%group wallpaperEffectView_newiOS11
- (void)_createPanelWallpaperEffectViewIfNeeded {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView
                                                                           manager:manager];
}
%end

%group wallpaperEffectView_oldiOS11
- (void)_createWallpaperEffectViewFullScreen:(BOOL)fullscreen {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView
                                                                           manager:manager];
}
%end
%end
// ---


/* Homescreen down below */
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
// ---


%group FolderIcons
/* Folder icons */
%hook SBFolderIconView

%new
- (void)sa_colorFolderBackground:(SBFolderIconBackgroundView *)backgroundView {
    UIColor *color = manager.folderColor;
    if (color) {
        [backgroundView setWallpaperBackgroundRect:[backgroundView wallpaperRelativeBounds]
                                       forContents:nil
                                 withFallbackColor:color.CGColor];
    }
}

- (void)setIcon:(SBIcon *)icon {
    %orig;

    if (icon)
        [self sa_colorFolderBackground:[self iconBackgroundView]];
}
%end

%hook SBFolderIconBackgroundView

- (void)setWallpaperBackgroundRect:(CGRect)rect
                       forContents:(CGImageRef)contents
                 withFallbackColor:(CGColorRef)color {
    UIColor *folderColor = manager.folderColor;
    if (folderColor)
        %orig(rect, nil, folderColor.CGColor);
    else
        %orig;
}

%end
// ---


/* Background of an open folder */
%hook SBFloatyFolderView
- (void)enumeratePageBackgroundViewsUsingBlock:(void(^)(SBFloatyFolderBackgroundClipView *))block {
    if (!manager.folderColor)
        return %orig;

    void (^newBlock)(SBFloatyFolderBackgroundClipView *) = ^(SBFloatyFolderBackgroundClipView *clipView) {
        block(clipView);

        SBFolderBackgroundView *backgroundView = clipView.backgroundView;
        MSHookIvar<UIView *>(backgroundView, "_tintView").backgroundColor = manager.folderColor;
    };

    %orig(newBlock);
}

%end
// ---
%end


%group PackagePirated
%hook SBCoverSheetPresentationManager

- (void)_cleanupDismissalTransition {
    %orig;

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        showPiracyAlert(packageShown$bs());
    });
}

%end
%end


%group Welcome
%hook SBCoverSheetPresentationManager

- (void)_cleanupDismissalTransition {
    %orig;
    showSpringBoardDismissAlert(packageShown$bs(), WelcomeMsg$bs());
}

%end
%end


%group CheckTrialEnded
%hook SBCoverSheetPresentationManager

- (void)_cleanupDismissalTransition {
    %orig;

    if (!manager.trialEnded && check_lic(licensePath$bs(), package$bs()) == CheckInvalidTrialLicense) {
        [manager setTrialEnded];
        showSpringBoardDismissAlert(packageShown$bs(), TrialEndedMsg$bs());
    }
}

%end
%end

static inline void initTrial() {
    %init(CheckTrialEnded);
}


static inline void initLockscreen() {
    %init(Lockscreen);

    if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createFadeOutWallpaperEffectView)])
        %init(newiOS11);

    if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createPanelWallpaperEffectViewIfNeeded)])
        %init(wallpaperEffectView_newiOS11);
    else
        %init(wallpaperEffectView_oldiOS11);
}

static inline void initHomescreen() {
    %init(FolderIcons);

    if (%c(SBHomeScreenBackdropView))
        %init(SwitcherBackdrop_iOS12);
    else
        %init(SwitcherBackdrop_iOS11);
}

%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];

    if ([bundleID isEqualToString:kSpotifyBundleID] &&
        (!preferences[kCanvasEnabled] || [preferences[kCanvasEnabled] boolValue])) {
        %init(Spotify);
    } else {
        if (fromUntrustedSource(package$bs()))
            %init(PackagePirated);

        manager = [[SAManager alloc] init];

        // License check – if no license found, present message. If no valid license found, do not init
        switch (check_lic(licensePath$bs(), package$bs())) {
            case CheckNoLicense:
                %init(Welcome);
                return;
            case CheckInvalidTrialLicense:
                initTrial();
                return;
            case CheckValidTrialLicense:
                initTrial();
                break;
            case CheckValidLicense:
                break;
            case CheckInvalidLicense:
            case CheckUDIDsDoNotMatch:
            default:
                return;
        }
        // ---

        [manager setupWithPreferences:preferences];
        %init(SpringBoard);
        %init;

        if (manager.enabledMode != BothMode) {
            %init(NotBoth);

            /* Enable lockscreen? */
            if (manager.enabledMode != HomescreenMode)
                initLockscreen();
            /* Enable homescreen? */
            else if (manager.enabledMode != LockscreenMode)
                initHomescreen();
        } else {
            initLockscreen();
            initHomescreen();
        }
    }
}
