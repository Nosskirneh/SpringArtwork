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
        %log;
        %orig;

        NSURL *localURL = nil;  
        if ([getCanvasTrackChecker() isCanvasEnabledForTrack:track]) {
            NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
            localURL = [getVideoURLAssetLoader() localURLForAssetURL:canvasURL];
            HBLogDebug(@"localURL: %@", localURL.absoluteString);
        }
        sendCanvasURL(localURL);
    }

    %end
%end

%group SpringBoard
    CanvasReceiver *receiver;

    static void setInterruptMusic(AVPlayer *player, BOOL interrupt) {
        AVAudioSessionMediaPlayerOnly *session = [player playerAVAudioSession];
        NSError *error = nil;

        if (interrupt)
            [session setCategory:AVAudioSessionCategorySoloAmbient error:&error];
        else
            [session setCategory:AVAudioSessionCategoryAmbient error:&error];
    }

    static void hideDock(BOOL hide) {
        SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
        SBDockView *dockView = [rootFolderController.contentView dockView];
        MSHookIvar<UIView *>(dockView, "_backgroundView").hidden = hide;
    }

    // Add background here
    %hook SBFStaticWallpaperView

    %property (nonatomic, retain) AVPlayerLayer *canvasLayer;

    - (void)_setUpStaticImageContentView:(UIView *)view {
        %log;
        %orig;

        if (!self.canvasLayer)
            [self _setupCanvasLayer:view];
    }

    %new
    - (void)replayMovie:(NSNotification *)notification {
        %log;
        [self.canvasLayer.player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
            if (seeked)
                [self.canvasLayer.player play];
        }];
    }

    %new
    - (void)_setupCanvasLayer:(UIView *)view {
        %log;

        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        self.canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        self.canvasLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(canvasUpdated)
                                                     name:kUpdateCanvas
                                                   object:nil];
    }

    %new
    - (void)canvasUpdated {
        %log;

        AVPlayer *player = self.canvasLayer.player;

        if (player.currentItem)
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:player.currentItem];

        if (receiver.canvasURL) {
            [self.layer addSublayer:self.canvasLayer];

            hideDock(YES);

            AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:receiver.canvasURL]];
            [player replaceCurrentItemWithPlayerItem:newItem];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(replayMovie:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:player.currentItem];
            setInterruptMusic(player, NO);
            [player play];
        } else {
            setInterruptMusic(player, YES);
            [player pause];
            [self.canvasLayer removeFromSuperlayer];
            hideDock(NO);
        }
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
