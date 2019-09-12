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

// Add background here

%end


%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;

    if ([bundleID isEqualToString:@"com.spotify.client"])
        %init(Spotify);
    else
        %init(SpringBoard);
}
