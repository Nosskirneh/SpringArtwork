
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerLayer.h>

@protocol SPTService <NSObject>
+ (NSString *)serviceIdentifier;
@end

@interface SpotifyAppDelegate : NSObject
- (id)serviceForIdentifier:(NSString *)identifier inScope:(NSString *)scope;
@end


@interface SPTVideoURLAssetLoaderImplementation : NSObject
- (NSURL *)localURLForAssetURL:(NSURL *)url;
@end

@interface SPTNetworkServiceImplementation : NSObject<SPTService>
@property (retain, nonatomic) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;
@end

@interface SPTPlayerTrack : NSObject
@property (copy, nonatomic) NSDictionary *metadata;
@end

@interface SPTCanvasTrackCheckerImplementation : NSObject
- (BOOL)isCanvasEnabledForTrack:(SPTPlayerTrack *)track;
@end

@interface SPTCanvasServiceImplementation : NSObject<SPTService>
@property (retain, nonatomic) SPTCanvasTrackCheckerImplementation *trackChecker;
@end


static SpotifyAppDelegate *getSpotifyAppDelegate() {
    return (SpotifyAppDelegate *)[[UIApplication sharedApplication] delegate];
}

typedef enum SpotifyServiceScope {
    zero,
    application,
    session
} SpotifyServiceScope;

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


@interface NSDictionary (SPTTypeSafety)
- (NSURL *)spt_URLForKey:(NSString *)key;
@end


%group Spotify

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


// @interface AVPlayerLayer : CALayer
// @property (nonatomic, retain) AVPlayer *player;
// + (id)playerLayerWithPlayer:(id)arg1;
// @end

@interface SBFStaticWallpaperView : UIView
@property (nonatomic, retain) AVPlayerLayer *playerLayer;
- (void)_setupPlayerLayer;
@end

// Add background here
%hook SBFStaticWallpaperView

%property (nonatomic, retain) AVPlayerLayer *playerLayer;

%new
- (void)replayMovie:(NSNotification *)notification {
    %log;
    [self.playerLayer.player play];
}

%new
- (void)_setupPlayerLayer {
    // find movie file
    NSString *moviePath = @"file:///var/mobile/Containers/Data/Application/94E12254-06ED-4EB5-8B30-BF02C62BF812/Library/Caches/com.spotify.service.network/1bafb5e3714432b2d883f9cbf0a73e6ac367ec7b.mp4";
    // NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    NSURL *movieURL = [NSURL URLWithString:moviePath];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:[[AVPlayer alloc] initWithURL:movieURL]];
    HBLogDebug(@"url: %@", movieURL.absoluteString);
    HBLogDebug(@"%f, %f", self.frame.size.width, self.frame.size.height);
    self.playerLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    [self.playerLayer.player play];
}

- (void)_setUpStaticImageContentView:(id)arg1 {
    %log;
    %orig;

    if (!self.playerLayer)
        [self _setupPlayerLayer];

    [self.layer addSublayer:self.playerLayer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(replayMovie:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification 
                                               object:nil];
}

%end

%end


%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;

    if ([bundleID isEqualToString:@"com.spotify.client"])
        %init(Spotify);
    else {
        HBLogDebug(@"ctor sb");

        %init(SpringBoard);
    }
}
