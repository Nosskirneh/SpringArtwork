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

    static void setNoInterruptionMusic(AVPlayer *player) {
        AVAudioSessionMediaPlayerOnly *session = [player playerAVAudioSession];
        NSError *error = nil;
        [session setCategory:AVAudioSessionCategoryAmbient error:&error];
    }

    static void hideDock(BOOL hide) {
        SBRootFolderController *rootFolderController = [[%c(SBIconController) sharedInstance] _rootFolderController];
        SBDockView *dockView = [rootFolderController.contentView dockView];
        UIView *background = MSHookIvar<UIView *>(dockView, "_backgroundView");

        [UIView animateWithDuration:ANIMATION_DURATION
                         animations:^{
                            background.alpha = hide ? 0.0f : 1.0f;
                         }
                         completion:nil];
    }

    %hook SBFStaticWallpaperView

    %property (nonatomic, retain) AVPlayerLayer *canvasLayer;

    - (void)_setUpStaticImageContentView:(UIView *)view {
        %orig;

        if (!self.canvasLayer)
            [self _setupCanvasLayer:view];
    }

    %new
    - (void)replayMovie:(NSNotification *)notification {
        [self.canvasLayer.player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
            if (seeked)
                [self.canvasLayer.player play];
        }];
    }

    %new
    - (void)_setupCanvasLayer:(UIView *)view {
        AVPlayer *player = [[AVPlayer alloc] init];
        player.muted = YES;
        setNoInterruptionMusic(player);
        self.canvasLayer = [AVPlayerLayer playerLayerWithPlayer:player];
        self.canvasLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(canvasUpdated:)
                                                     name:kUpdateCanvas
                                                   object:nil];
    }

    %new
    - (void)canvasUpdated:(NSNotification *)notification {
        AVPlayer *player = self.canvasLayer.player;
        if (player.currentItem)
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:player.currentItem];

        NSString *canvasURL = notification.userInfo[kCanvasURL];
        if (canvasURL) {
            [self fadeCanvasLayerIn];
            [self changeCanvasURL:[NSURL URLWithString:canvasURL]];
        } else {
            [self fadeCanvasLayerOut];
        }
    }

    %new
    - (void)changeCanvasURL:(NSURL *)url {
        AVPlayerItem *newItem = [[AVPlayerItem alloc] initWithURL:url];

        AVPlayer *player = self.canvasLayer.player;
        [player replaceCurrentItemWithPlayerItem:newItem];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(replayMovie:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:player.currentItem];
        [player play];
    }

    %new
    - (void)fadeCanvasLayerIn {
        if (self.canvasLayer.superlayer)
            return;

        [self.layer addSublayer:self.canvasLayer];

        hideDock(YES);
        [self _showCanvasLayer:YES];
    }

    %new
    - (void)fadeCanvasLayerOut {
        if (!self.canvasLayer.superlayer)
            return;

        hideDock(NO);
        [self _showCanvasLayer:NO completion:^() {
            AVPlayer *player = self.canvasLayer.player;
            [player pause];
            [self.canvasLayer removeFromSuperlayer];
        }];
    }

    %new
    - (void)_showCanvasLayer:(BOOL)show {
        [self _showCanvasLayer:show completion:nil];
    }

    %new
    - (void)_showCanvasLayer:(BOOL)show completion:(void (^)(void))completion {
        float fromValueFloat;
        float toValueFloat;
        if (show) {
            fromValueFloat = 0.0;
            toValueFloat = 1.0;
        } else {
            fromValueFloat = 1.0;
            toValueFloat = 0.0;
        }
        self.canvasLayer.opacity = fromValueFloat;

        [CATransaction begin];
        [CATransaction setDisableActions:YES];

        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        animation.duration = ANIMATION_DURATION;
        animation.toValue = [NSNumber numberWithFloat:toValueFloat];
        animation.fromValue = [NSNumber numberWithFloat:fromValueFloat];

        [CATransaction setCompletionBlock:completion];
        [self.canvasLayer addAnimation:animation forKey:@"timeViewFadeIn"];
        self.canvasLayer.opacity = toValueFloat;
        [CATransaction commit];
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
