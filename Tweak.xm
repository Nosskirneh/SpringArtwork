#import "Spotify.h"
#import "SpringBoard.h"
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
        return ((SPTNetworkServiceImplementation *)getSessionServiceForClass(%c(SPTNetworkServiceImplementation),
                                                                             application)).videoAssetLoader;
    }

    static SPTCanvasTrackCheckerImplementation *getCanvasTrackChecker() {
        return ((SPTCanvasServiceImplementation *)getSessionServiceForClass(%c(SPTCanvasServiceImplementation),
                                                                            session)).trackChecker;
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
                self.sa_onlyOnWifi = preferences[kCanvasOnlyWiFi] &&
                                     [preferences[kCanvasOnlyWiFi] boolValue];
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
                // The compiler doesn't like when `AVURLAsset *` is specified as the type for some reason...
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


%group SBWallpaperController_iOS12
%hook SBWallpaperController
- (UIView *)_makeAndInsertWallpaperViewWithConfiguration:(id)config
                                              forVariant:(long long)variant
                                                  shared:(BOOL)shared
                                                 options:(unsigned long long)options {
    return [self sa_newWallpaperViewCreated:%orig variant:variant shared:shared];
}
%end
%end

%group SBWallpaperController_iOS13
%hook SBWallpaperController
- (UIView *)_makeWallpaperViewWithConfiguration:(id)config
                                     forVariant:(long long)variant
                                         shared:(BOOL)shared
                                        options:(unsigned long long)options {
    return [self sa_newWallpaperViewCreated:%orig variant:variant shared:shared];
}
%end
%end


%group SpringBoard
    SAManager *manager;

    _UILegibilitySettings *legibilitySettingsForDarkText(BOOL darkText) {
        return [_UILegibilitySettings sharedInstanceForStyle:darkText ? 2 : 1];
    }

    UIViewController<CoverSheetViewController> *getCoverSheetViewController() {
        SBLockScreenManager *lockscreenManager = (SBLockScreenManager *)[%c(SBLockScreenManager) sharedInstance];
        if ([lockscreenManager respondsToSelector:@selector(coverSheetViewController)])
            return lockscreenManager.coverSheetViewController;
        return lockscreenManager.dashBoardViewController;
    }

    SBWallpaperController *getWallpaperController() {
        return ((SBWallpaperController *)[%c(SBWallpaperController) sharedInstance]);
    }

    SBIconController *getIconController() {
        return ((SBIconController *)[%c(SBIconController) sharedInstance]);
    }

    SBCoverSheetPrimarySlidingViewController *getSlidingViewController() {
        return ((SBCoverSheetPresentationManager *)[%c(SBCoverSheetPresentationManager) sharedInstance]).coverSheetSlidingViewController;
    }

    %hook SBWallpaperController
    %property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
    %property (nonatomic, retain) SAViewController *homescreenCanvasViewController;

    - (id)init {
        [manager setupHaptic];
        return %orig;
    }

    %new
    - (UIView *)sa_newWallpaperViewCreated:(UIView *)wallpaperView
                                   variant:(long long)variant
                                    shared:(BOOL)shared {
        manager.isSharedWallpaper = shared;
        if (shared) {
            if (manager.enabledMode == LockscreenMode)
                self.lockscreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView
                                                                                           manager:manager
                                                                                          inCharge:YES];
            else {
                self.homescreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView
                                                                                           manager:manager
                                                                                          inCharge:YES];
            }
        } else {
            BOOL homescreen = variant == 1;
            if (homescreen) {
                if (manager.enabledMode != LockscreenMode)
                    self.homescreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView
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


    /* Register shake gesture to play/pause canvas video */
    %hook UIApplication

    - (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
        %orig;

        if (event.type != UIEventSubtypeMotionShake ||
            !manager.shakeToPause ||
            ![manager hasPlayableContent] ||
            [manager isDirty])
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
%end


/* Hide views when the media widget is hidden due to inactivity. */
%group MediaWidgetInactivity_iOS13
    /* SBLockScreenNowPlayingController exists but is not used any
       longer on iOS 13, but this works just as good on iOS 12. */
    %hook AdjunctListModel

    - (void)_handleLockScreenContentActionInvalidation:(id)action {

        if ([action isKindOfClass:%c(SBSLockScreenContentAction)])
            [manager mediaWidgetDidActivate:NO];

        %orig;
    }

    - (void)_handleLockScreenContentActionAddition:(id)action {
        if ([action isKindOfClass:%c(SBSLockScreenContentAction)])
            [manager mediaWidgetDidActivate:YES];

        %orig;
    }

    - (void)suspendItemHandling {}

    %end
%end

%group MediaWidgetInactivity_iOS11
    /* AdjunctListModel does not exist on iOS 11. */
    %hook SBLockScreenNowPlayingController

    - (void)setEnabled:(BOOL)enabled {
        %orig(YES);
    }

    - (void)_updateToState:(long long)newState {
        if (self.currentState != Inactive && newState == Inactive)
            [manager mediaWidgetDidActivate:NO];
        else if (self.currentState == Inactive && newState != Inactive)
            [manager mediaWidgetDidActivate:YES];

        %orig;
    }

    %end
%end
// ---


// Does not exist in iOS 13
%group SBFProceduralWallpaperView
/* Dynamic wallpapers send themselves to the front after unlock.
   This overrides that. */
%hook SBFProceduralWallpaperView

- (void)prepareToAppear {
    %orig;

    [self sendSubviewToBack:self.proceduralWallpaper];
}

%end
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

- (void)_finishTransitionToPresented:(BOOL)presented
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
    if (fromLockscreen) {
        if (manager.enabledMode == HomescreenMode)
            manager.inChargeController.view.hidden = NO;
        else if (manager.enabledMode == LockscreenMode)
            manager.inChargeController.view.hidden = YES;
    }
}

%end
%end
// ---


%group Lockscreen

    /* We need to manually resume the view controller that transitions
       to the lockscreen. Note that these methods are specific for the
       transition view controller and not should not be mixed up with
       the SBCoverSheetPrimarySlidingViewController's methods
       _finish and _begin down below. They are general ones to not only
       targetting the transition view controller. That one needs special
       patching. Canvas videos doesn't need this as they always play
       regardless if switching target view. */
    %hook SBLockScreenManager

    - (void)lockScreenViewControllerWillPresent {
        %orig;

        [self sa_playArtworkAnimation:YES];
    }

    - (void)lockScreenViewControllerDidPresent {
        %orig;

        [self sa_playArtworkAnimation:NO];
    }

    - (void)lockScreenViewControllerWillDismiss {
        %orig;

        [self sa_playArtworkAnimation:YES];
    }

    - (void)lockScreenViewControllerDidDismiss {
        %orig;

        [self sa_playArtworkAnimation:NO];
    }

    %new
    - (void)sa_playArtworkAnimation:(BOOL)play {
        if (![manager hasAnimatingArtwork])
            return;

        SBCoverSheetPrimarySlidingViewController *slidingViewController = getSlidingViewController();

        SAViewController *viewController = manager.insideApp ?
                                           slidingViewController.canvasNormalViewController :
                                           slidingViewController.canvasFadeOutViewController;
        if (play) {
            [viewController updateAnimationStartTime];
            [viewController addArtworkRotation];
        } else {
            [viewController removeArtworkRotation];
        }
    }

    %end

    /* This allows content to play or pause when showing
       or returning from NC pulldown when inside an app. */
    %hook SBCoverSheetPrimarySlidingViewController

    %property (nonatomic, assign) BOOL pulling;

    - (void)_beginTransitionFromAppeared:(BOOL)fromLockscreen {
        if (!fromLockscreen && self.pulling && manager.insideApp)
            manager.lockscreenPulledDownInApp = YES;

        %orig;
    }

    - (void)_finishTransitionToPresented:(BOOL)presented
                                animated:(BOOL)animated
                          withCompletion:(id)completion {
        if (!presented && manager.lockscreenPulledDownInApp && manager.insideApp)
            manager.lockscreenPulledDownInApp = NO;

        %orig;
    }

    /* This is to prevent setting lockscreenPulledDownInApp
       when locking the device when inside an app. */
    - (void)grabberTongueBeganPulling:(id)tongue
                         withDistance:(double)distance
                          andVelocity:(double)velocity {
        self.pulling = YES;
        %orig;
    }
    - (void)grabberTongueEndedPulling:(id)tongue
                         withDistance:(double)distance
                          andVelocity:(double)velocity {
        self.pulling = NO;
        %orig;
    }
    - (void)grabberTongueCanceledPulling:(id)tongue
                            withDistance:(double)distance
                             andVelocity:(double)velocity {
        self.pulling = NO;
        %orig;
    }

    %end


    /* Lockscreen background when transitioning to camera */
    %hook CoverSheetViewController

    - (void)loadView {
        %orig;

        UIViewController<CoverSheetViewController> *_self = (UIViewController<CoverSheetViewController> *)self;
        UIView<CoverSheetView> *view = (UIView<CoverSheetView> *)_self.view;
        view.canvasViewController = [[SAViewController alloc] initWithManager:manager];
    }

    %end

    %hook CoverSheetView
    %property (nonatomic, retain) SAViewController *canvasViewController;

    - (void)setWallpaperEffectView:(UIView *)effectView {
        %orig;

        UIView<CoverSheetView> *_self = (UIView<CoverSheetView> *)self;
        [_self.canvasViewController setTargetView:effectView];
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
    %hook CoverSheetViewController

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

%new
- (void)sa_hideWallpaperView:(BOOL)hide {
    UIView *blurView = self.panelFadeOutWallpaperEffectView.blurView;
    MSHookIvar<UIView *>(blurView, "_wallpaperView").hidden = hide;
}
%end

%new
- (void)sa_checkCreationOfNormalController {
    if (!self.canvasNormalViewController)
        self.canvasNormalViewController = [[SAViewController alloc] initWithManager:manager];
    [self.canvasNormalViewController setTargetView:self.panelWallpaperEffectView.blurView];
}

%group wallpaperEffectView_newiOS11
- (void)_createPanelWallpaperEffectViewIfNeeded {
    %orig;

    [self sa_checkCreationOfNormalController];
}
%end

%group wallpaperEffectView_oldiOS11
- (void)_createWallpaperEffectViewFullScreen:(BOOL)fullscreen {
    %orig;

    [self sa_checkCreationOfNormalController];
}
%end
%end
// ---


/* Homescreen down below */
/* Make app labels coloring persistent after unlock */
%group Homescreen
%hook SBIconController

- (void)setLegibilitySettings:(_UILegibilitySettings *)settings {
    _UILegibilitySettings *mSettings = manager.legibilitySettings;
    if (mSettings)
        return %orig(mSettings);
    %orig;
}

%end
%end

/* When opening the app switcher, this method is taking an image of the SB wallpaper, blurs and
   appends it to the SBHomeScreenView. The video is thus seen as paused while actually still playing.
   The solution is to hide the UIImageView and instead always show the transition MTMaterialView. */
%group SwitcherBackdrop_iOS11
%hook SBUIController

- (void)_updateBackdropViewIfNeeded {
    %orig;

    MSHookIvar<UIView *>(self, "_homeScreenContentBackdropView").hidden = NO;
    MSHookIvar<UIImageView *>(self, "_homeScreenBlurredContentSnapshotImageView").hidden = YES;
}

%end
%end

%group SwitcherBackdrop_iOS12
/* On iOS 12 and 13, the homescreen becomes hidden after the snapshot is taken.
   If we simply unhide it in the _updateBackdropViewIfNeeded method below,
   it results in home screen layout not being editible. So instead we're just
   making sure it never hides in the first place. */
%hook SBIconContentView
- (void)setHidden:(BOOL)hide {}
%end

%hook SBHomeScreenBackdropView

- (void)_updateBackdropViewIfNeeded {
    %orig;

    MSHookIvar<UIView *>(self, "_materialView").hidden = NO;
    MSHookIvar<UIImageView *>(self, "_blurredContentSnapshotImageView").hidden = YES;
}
%end
%end
// ---


/* Folder icons */
%group FolderIcons_iOS12
%hook SBFolderIconView

%new
- (void)sa_colorizeFolderBackground:(SBFolderIconBackgroundView *)backgroundView
                              color:(UIColor *)color {
    if (color) {
        [backgroundView setWallpaperBackgroundRect:[backgroundView wallpaperRelativeBounds]
                                       forContents:nil
                                 withFallbackColor:color.CGColor];
    }
}

- (void)setIcon:(SBIcon *)icon {
    %orig;

    if (icon) {
        UIColor *color = manager.folderColor;
        [self sa_colorizeFolderBackground:[self iconBackgroundView] color:color];
    }
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
%end

%group FolderIcons_iOS13
%hook SBFolderIconImageView

- (void)updateImageAnimated:(BOOL)animated {
    %orig;

    UIColor *color = self.icon ? manager.folderColor : nil;
    [self sa_colorizeFolderBackground:color];
}

%new
- (void)sa_colorizeFolderBackground:(UIColor *)color {
    SBWallpaperEffectView *backgroundView = [self backgroundView];
    if ([backgroundView isKindOfClass:%c(SBWallpaperEffectView)]) {
        backgroundView.blurView.hidden = color != nil;
        backgroundView.backgroundColor = color;
    }
}

%end
%end
// ---


%group FolderIcons
/* Background of an open folder */
%hook SBFloatyFolderView

- (void)enumeratePageBackgroundViewsUsingBlock:(void(^)(SBFloatyFolderBackgroundClipView *))block {
    UIColor *color = manager.folderBackgroundColor;
    if (!color)
        return %orig;

    void (^newBlock)(SBFloatyFolderBackgroundClipView *) = ^(SBFloatyFolderBackgroundClipView *clipView) {
        block(clipView);
        [clipView nu_colorizeFolderBackground:color];
    };

    %orig(newBlock);
}

%end

%hook SBFloatyFolderBackgroundClipView

%new
- (void)nu_colorizeFolderBackground:(UIColor *)color {
    SBFolderBackgroundView *backgroundView = self.backgroundView;

    if (!color)
        color = [[backgroundView _tintViewBackgroundColorAtFullAlpha] colorWithAlphaComponent:0.8];

    UIView *view = MSHookIvar<UIView *>(backgroundView, "_blurView");
    if (!view)
        view = MSHookIvar<UIView *>(backgroundView, "_tintView");
    view.backgroundColor = color;
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

__attribute__((always_inline, visibility("hidden")))
static inline void initTrial() {
    %init(CheckTrialEnded);
}


__attribute__((always_inline, visibility("hidden")))
static inline void initLockscreen() {
    Class coverSheetViewControllerClass = %c(CSCoverSheetViewController);
    if (!coverSheetViewControllerClass)
        coverSheetViewControllerClass = %c(SBDashBoardViewController);

    Class coverSheetViewClass = %c(CSCoverSheetView);
    if (!coverSheetViewClass)
        coverSheetViewClass = %c(SBDashBoardView);

    %init(Lockscreen, CoverSheetViewController = coverSheetViewControllerClass,
                      CoverSheetView = coverSheetViewClass);

    if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createFadeOutWallpaperEffectView)])
        %init(newiOS11);

    [%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createPanelWallpaperEffectViewIfNeeded)] ?
        (%init(wallpaperEffectView_newiOS11)) :
        (%init(wallpaperEffectView_oldiOS11));
}

__attribute__((always_inline, visibility("hidden")))
static inline void initHomescreen() {
    %init(Homescreen);

    %init(FolderIcons);
    if (%c(SBFolderIconView) &&
        [%c(SBRootIconListView) instancesRespondToSelector:@selector(viewMap)])
        %init(FolderIcons_iOS12);
    else // the class used in iOS 13 exist on iOS 12, but hooking it crashes instantly (?)
        %init(FolderIcons_iOS13);

    %c(SBHomeScreenBackdropView) ? (%init(SwitcherBackdrop_iOS12)) :
                                   (%init(SwitcherBackdrop_iOS11));
}

__attribute__((always_inline, visibility("hidden")))
static inline void initMediaWidgetInactivity_iOS13(Class adjunctListModelClass) {
    %init(MediaWidgetInactivity_iOS13, AdjunctListModel = adjunctListModelClass);
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
        Class adjunctListModelClass = %c(CSAdjunctListModel);
        if (!adjunctListModelClass) {
            adjunctListModelClass = %c(SBDashBoardAdjunctListModel);
            !adjunctListModelClass ? (%init(MediaWidgetInactivity_iOS11)) :
                                     initMediaWidgetInactivity_iOS13(adjunctListModelClass);
        } else {
            initMediaWidgetInactivity_iOS13(adjunctListModelClass);
        }

        %init(SpringBoard);

        [%c(SBWallpaperController) instancesRespondToSelector:
            @selector(_makeWallpaperViewWithConfiguration:forVariant:shared:options:)] ?
            (%init(SBWallpaperController_iOS13)) :
            (%init(SBWallpaperController_iOS12));

        if (%c(SBFProceduralWallpaperView))
            %init(SBFProceduralWallpaperView);

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
