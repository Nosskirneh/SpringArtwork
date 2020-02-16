#import "Spotify.h"
#import "Common.h"
#import <notify.h>
#import <AVFoundation/AVAsset.h>

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

static SPTQueueServiceImplementation *getQueueService() {
    return (SPTQueueServiceImplementation *)getSessionServiceForClass(%c(SPTQueueServiceImplementation),
                                                                      session);
}

static SPTGLUEImageLoaderFactoryImplementation *getImageLoaderFactory() {
    return getQueueService().glueImageLoaderFactory;
}

static void sendMessageWithURLOrArtwork(NSURL *url, UIImage *artwork, NSString *trackIdentifier) {
    CPDistributedMessagingCenter *c = [%c(CPDistributedMessagingCenter) centerNamed:SA_IDENTIFIER];
    rocketbootstrap_distributedmessagingcenter_apply(c);

    NSMutableDictionary *dict = [NSMutableDictionary new];

    if (url)
        dict[kCanvasURL] = url.absoluteString;
    else if (artwork) {
        dict[kArtwork] = UIImagePNGRepresentation(artwork);
        dict[kTrackIdentifier] = trackIdentifier;
    }
    [c sendMessageName:kSpotifyMessage userInfo:dict];
}

static void sendCanvasURL(NSURL *url) {
    sendMessageWithURLOrArtwork(url, nil, nil);
}

static void sendArtwork(UIImage *artwork, NSString *trackIdentifier) {
    sendMessageWithURLOrArtwork(nil, artwork, trackIdentifier);
}

static void sendEmptyMessage() {
    sendMessageWithURLOrArtwork(nil, nil, nil);
}

/* This is done to avoid hooking init calls that are likely to change. */
%hook SPTCanvasServiceImplementation

- (void)setCanvasLogger:(SPTCanvasLogger *)canvasLogger {
    %orig;
    [canvasLogger sa_commonInit];
}

%end

/* Another class that can be used is the SPTCanvasNowPlayingContentReloader,
   but it only exists on more recent Spotify versions. */
%hook SPTCanvasLogger

%property (nonatomic, assign) BOOL sa_onlyOnWifi;
%property (nonatomic, assign) BOOL sa_canvasEnabled;
%property (nonatomic, retain) SPTGLUEImageLoader *imageLoader;
%property (nonatomic, retain) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;

%new
- (void)sa_commonInit {
    self.imageLoader = [getImageLoaderFactory() createImageLoaderForSourceIdentifier:@"se.nosskirneh.springartwork"];
    self.videoAssetLoader = getVideoURLAssetLoader();

    int token;
    notify_register_dispatch(kSpotifySettingsChanged,
        &token,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
        ^(int t) {
            [self sa_loadPrefs];
        });
    [self sa_loadPrefs];
}

%new
- (void)sa_loadPrefs {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSNumber *current = preferences[kCanvasOnlyWiFi];
    self.sa_onlyOnWifi = current && [current boolValue];
    current = preferences[kCanvasEnabled];
    self.sa_canvasEnabled = !current || [current boolValue];
}

- (void)setCurrentPlayerState:(SPTPlayerState *)state {
    SPTPlayerTrack *track = state.track;

    if (self.sa_canvasEnabled && track && [self.trackChecker isCanvasEnabledForTrack:track]) {
        NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
        if (![canvasURL.absoluteString hasSuffix:@".mp4"])
            return [self tryWithArtworkForTrack:track];

        SPTVideoURLAssetLoaderImplementation *assetLoader = self.videoAssetLoader;
        if ([assetLoader hasLocalAssetForURL:canvasURL]) {
            sendCanvasURL([assetLoader localURLForAssetURL:canvasURL]);
        } else {
            // The compiler doesn't like `AVURLAsset *` being specified as the type for some reason...
            [assetLoader loadAssetWithURL:canvasURL onlyOnWifi:self.sa_onlyOnWifi completion:^(id asset) {
                sendCanvasURL(((AVURLAsset *)asset).URL);
            }];
        }
    } else {
        [self tryWithArtworkForTrack:track];
    }
    %orig;
}

%new
- (void)tryWithArtworkForTrack:(SPTPlayerTrack *)track {
    if ([self.imageLoader respondsToSelector:@selector(loadImageForURL:imageSize:completion:)]) {
        [self.imageLoader loadImageForURL:track.coverArtURLXLarge
                                imageSize:ARTWORK_SIZE
                               completion:^(UIImage *image) {
            if (!image)
                return sendEmptyMessage();
            sendArtwork(image, track.UID);
        }];
    } else {
        sendEmptyMessage();
    }
}

%end


%ctor {
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];

    if ([bundleID isEqualToString:kSpotifyBundleID] &&
        (!preferences[kCanvasEnabled] || [preferences[kCanvasEnabled] boolValue]))
        %init;
}
