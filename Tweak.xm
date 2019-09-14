#import "Spotify.h"
#import "SpringBoard.h"
#import "CanvasReceiver.h"
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
        CPDistributedMessagingCenter *c = [%c(CPDistributedMessagingCenter) centerNamed:SPBG_IDENTIFIER];
        rocketbootstrap_distributedmessagingcenter_apply(c);

        NSMutableDictionary *dict = [NSMutableDictionary new];

        if (url)
            dict[kCanvasURL] = url.absoluteString;
        [c sendMessageName:kCanvasURLMessage userInfo:dict];
    }

    %hook SPTNowPlayingBarContainerViewController

    - (void)setCurrentTrack:(SPTPlayerTrack *)track {
        %orig;

        NSURL *localURL = nil;  
        if ([getCanvasTrackChecker() isCanvasEnabledForTrack:track]) {
            NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
            localURL = [getVideoURLAssetLoader() localURLForAssetURL:canvasURL];
        }
        sendCanvasURL(localURL);
    }

    %end
%end

%group SpringBoard
    CanvasReceiver *receiver;

    @interface SBWallpaperController : NSObject
    @property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
    @property (nonatomic, retain) SAViewController *homescreenCanvasViewController;
    @end


    %hook SBWallpaperController
    %property (nonatomic, retain) SAViewController *lockscreenCanvasViewController;
    %property (nonatomic, retain) SAViewController *homescreenCanvasViewController;

    - (UIView *)_makeAndInsertWallpaperViewWithConfiguration:(id)config forVariant:(long long)variant shared:(BOOL)shared options:(unsigned long long)options {
        UIView *wallpaperView = %orig;

        BOOL homescreen = shared || variant == 1;
        if (homescreen)
            self.homescreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView homescreen:YES];
        else
            self.lockscreenCanvasViewController = [[SAViewController alloc] initWithTargetView:wallpaperView homescreen:NO];

        return wallpaperView;
    }

    %end


    %hook UIApplication

    - (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
        %orig;

        if (event.type != UIEventSubtypeMotionShake)
            return;

        [[NSNotificationCenter defaultCenter] postNotificationName:kTogglePlayPause
                                                            object:nil];
    }

    %end
%end


%hook SBCoverSheetPrimarySlidingViewController
%property (nonatomic, retain) SAViewController *canvasNormalViewController;
%property (nonatomic, retain) SAViewController *canvasFadeOutViewController;

%group newiOS11
- (void)_createFadeOutWallpaperEffectView {
    %orig;

    self.canvasFadeOutViewController = [[SAViewController alloc] initWithTargetView:self.panelFadeOutWallpaperEffectView.blurView homescreen:NO];
}
%end

%group wallpaperEffectView_newiOS11
- (void)_createPanelWallpaperEffectViewIfNeeded {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView homescreen:NO];
}
%end

%group wallpaperEffectView_oldiOS11
- (void)_createWallpaperEffectViewFullScreen:(BOOL)fullscreen {
    %orig;

    self.canvasNormalViewController = [[SAViewController alloc] initWithTargetView:self.panelWallpaperEffectView.blurView homescreen:NO];
}
%end
%end



%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;

    if ([bundleID isEqualToString:@"com.spotify.client"]) {
        %init(Spotify);
    } else {
        // if (fromUntrustedSource(package$bs()))
        //     %init(PackagePirated);

        receiver = [[CanvasReceiver alloc] init];

        [receiver setup];
        %init(SpringBoard);
        %init();

        if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createFadeOutWallpaperEffectView)])
            %init(newiOS11);

        if ([%c(SBCoverSheetPrimarySlidingViewController) instancesRespondToSelector:@selector(_createPanelWallpaperEffectViewIfNeeded:)])
            %init(wallpaperEffectView_newiOS11);
        else
            %init(wallpaperEffectView_oldiOS11);
    }
}
