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

static SPTCanvasTrackCheckerImplementation *getCanvasTrackChecker() {
    return ((SPTCanvasServiceImplementation *)getSessionServiceForClass(%c(SPTCanvasServiceImplementation),
                                                                        session)).trackChecker;
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

    dict[kBundleID] = [NSBundle mainBundle].bundleIdentifier;
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


/* SPTCanvasNowPlayingContentReloader only exists on more recent Spotify versions. */
%group SPTCanvasNowPlayingContentReloader

/* This is done to avoid hooking init calls that are likely to change. */
%hook SPTCanvasServiceImplementation

- (void)load {
    %orig;

    [self.canvasContentReloader sa_commonInit];
}

%end

%hook SPTCanvasNowPlayingContentReloader

// This exists in the SPTCanvasLogger class
%property (nonatomic, retain) SPTCanvasTrackCheckerImplementation *trackChecker;

- (void)setCurrentState:(SPTPlayerState *)state {
    %orig;
    [self sa_fetchDataForState:state];
}

%end
%end


// Used on older Spotify versions
%group SPTCanvasLogger

/* This is done to avoid hooking init calls that are likely to change. */
%hook SPTCanvasServiceImplementation

- (void)setCanvasLogger:(SPTCanvasLogger *)canvasLogger {
    %orig;
    [canvasLogger sa_commonInit];
}

%end

%hook SPTCanvasLogger

// This exists in the SPTCanvasNowPlayingContentReloader class
%property (nonatomic, retain) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;

- (void)setCurrentPlayerState:(SPTPlayerState *)state {
    %orig;
    [self sa_fetchDataForState:state];
}

%end
%end


%hook TargetClass

%property (nonatomic, assign) BOOL sa_onlyOnWifi;
%property (nonatomic, assign) BOOL sa_canvasEnabled;
%property (nonatomic, retain) SPTGLUEImageLoader *imageLoader;

%new
- (void)sa_commonInit {
    id<SpringArtworkTarget> _self = (id<SpringArtworkTarget>)self;
    _self.imageLoader = [getImageLoaderFactory() createImageLoaderForSourceIdentifier:@"se.nosskirneh.springartwork"];

    if (!_self.videoAssetLoader) {
        _self.videoAssetLoader = getVideoURLAssetLoader();
    }

    if (!_self.trackChecker) {
        _self.trackChecker = getCanvasTrackChecker();
    }

    int token;
    notify_register_dispatch(kSpotifySettingsChanged,
        &token,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
        ^(int t) {
            [_self sa_loadPrefs];
        });

    notify_register_dispatch(kManualSpotifyUpdate,
        &token,
        dispatch_get_main_queue(),
        ^(int t) {
            SPTPlayerState *playerState;
            if ([_self respondsToSelector:@selector(currentPlayerState)])
                playerState = _self.currentPlayerState;
            else
                playerState = _self.currentState;

            [_self sa_fetchDataForState:playerState];
        });

    [_self sa_loadPrefs];
}

%new
- (void)sa_loadPrefs {
    id<SpringArtworkTarget> _self = (id<SpringArtworkTarget>)self;

    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSNumber *current = preferences[kCanvasOnlyWiFi];
    _self.sa_onlyOnWifi = current && [current boolValue];
    current = preferences[kCanvasEnabled];
    _self.sa_canvasEnabled = !current || [current boolValue];
}

%new
- (void)sa_fetchDataForState:(SPTPlayerState *)state {
    id<SpringArtworkTarget> _self = (id<SpringArtworkTarget>)self;
    SPTPlayerTrack *track = state.track;

    if (_self.sa_canvasEnabled && track && [_self.trackChecker isCanvasEnabledForTrack:track]) {
        NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
        if (![canvasURL.absoluteString hasSuffix:@".mp4"])
            return [_self tryWithArtworkForTrack:track];

        SPTVideoURLAssetLoaderImplementation *assetLoader = _self.videoAssetLoader;
        if ([assetLoader hasLocalAssetForURL:canvasURL]) {
            sendCanvasURL([assetLoader localURLForAssetURL:canvasURL]);
        } else {
            // The compiler doesn't like `AVURLAsset *` being specified as the type for some reason...
            [assetLoader loadAssetWithURL:canvasURL
                               onlyOnWifi:_self.sa_onlyOnWifi
                               completion:^(id asset) {
                sendCanvasURL(((AVURLAsset *)asset).URL);
            }];
        }
    } else {
        [_self tryWithArtworkForTrack:track];
    }
}

%new
- (void)tryWithArtworkForTrack:(SPTPlayerTrack *)track {
    id<SpringArtworkTarget> _self = (id<SpringArtworkTarget>)self;

    if ([_self.imageLoader respondsToSelector:@selector(loadImageForURL:imageSize:completion:)]) {
        [_self.imageLoader loadImageForURL:track.coverArtURLXLarge
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
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSNumber *canvasEnabled = preferences[kCanvasEnabled];

    if (isSpotify(bundleID) && (!canvasEnabled || [canvasEnabled boolValue])) {
        Class targetClass = %c(SPTCanvasNowPlayingContentReloader);
        if (targetClass) {
            %init(SPTCanvasNowPlayingContentReloader);
        } else {
            targetClass = %c(SPTCanvasLogger);
            %init(SPTCanvasLogger);
        }

        %init(TargetClass = targetClass);
    }
}
