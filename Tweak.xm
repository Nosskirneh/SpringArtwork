#import "Spotify.h"
#import "SpringBoard.h"
#import "SADockViewController.h"
#import "SAManager.h"
#import "Common.h"
#import "DockManagement.h"
#import "Labels.h"


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
            self.homescreenCanvasViewController = [[SADockViewController alloc] initWithTargetView:wallpaperView];
        else
            self.lockscreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView];

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


    /* Set the text color of the app icon labels according
       to the colorInfo in our implementation */
    %hook SBIconLegibilityLabelView

    - (void)updateIconLabelWithSettings:(id)settings
                        imageParameters:(SBMutableIconLabelImageParameters *)parameters {
        if (parameters && manager.colorInfo)
            parameters.textColor = manager.colorInfo.textColor;

        %orig;
    }

    %end


    /* Set the lockscreen date and time labels according
       to the colorInfo in our implementation */
    %hook SBFLockScreenDateView

    - (void)setLegibilitySettings:(_UILegibilitySettings *)settings {
        SAColorInfo *info = manager.colorInfo;
        if (info)
            settings.primaryColor = info.textColor;
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

    self.canvasFadeOutViewController = [[SAViewController alloc] initWithTargetView:self.panelFadeOutWallpaperEffectView.blurView];
}
%end

%group wallpaperEffectView_newiOS11
- (void)_createPanelWallpaperEffectViewIfNeeded {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView];
}
%end

%group wallpaperEffectView_oldiOS11
- (void)_createWallpaperEffectViewFullScreen:(BOOL)fullscreen {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView];
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
    }
}
