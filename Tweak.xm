#import "Spotify.h"
#import "SpringBoard.h"

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

%hook SPTNowPlayingBarContainerViewController

- (void)setCurrentTrack:(SPTPlayerTrack *)track {
    %log;
    %orig;

    if ([getCanvasTrackChecker() isCanvasEnabledForTrack:track]) {
        NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
        NSURL *localURL = [getVideoURLAssetLoader() localURLForAssetURL:canvasURL];
        HBLogDebug(@"localURL: %@", localURL.absoluteString);
    }
}

%end
%end

%group SpringBoard

// Add background here
%hook SBFStaticWallpaperView

%property (nonatomic, retain) AVPlayerLayer *playerLayer;

%new
- (void)replayMovie:(NSNotification *)notification {
    %log;
    [self.playerLayer.player seekToTime:kCMTimeZero completionHandler:^(BOOL seeked) {
        if (seeked)
            [self.playerLayer.player play];
    }];
}

%new
- (void)_setupPlayerLayer:(UIView *)view {
    // find movie file
    NSString *moviePath = @"file:///var/mobile/Containers/Data/Application/94E12254-06ED-4EB5-8B30-BF02C62BF812/Library/Caches/com.spotify.service.network/1bafb5e3714432b2d883f9cbf0a73e6ac367ec7b.mp4";
    NSURL *movieURL = [NSURL URLWithString:moviePath];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:[[AVPlayer alloc] initWithURL:movieURL]];
    self.playerLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);

    [view.layer addSublayer:self.playerLayer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(replayMovie:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification 
                                               object:self.playerLayer.player.currentItem];
    [self.playerLayer.player play];
}

- (void)_setUpStaticImageContentView:(UIView *)view {
    %log;
    %orig;

    if (!self.playerLayer)
        [self _setupPlayerLayer:view];
}

%end
%end


%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;

    if ([bundleID isEqualToString:@"com.spotify.client"])
        %init(Spotify);
    else
        %init(SpringBoard);
}
