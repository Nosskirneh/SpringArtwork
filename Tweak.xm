#import "Spotify.h"
#import "SpringBoard.h"
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

    %hook SBFStaticWallpaperView

    %property (nonatomic, retain) SAViewController *canvasViewController;

    - (void)_setUpStaticImageContentView:(UIView *)view {
        %orig;

        if (!self.canvasViewController)
            self.canvasViewController = [[SAViewController alloc] initWithTargetView:self];
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
    }
}
