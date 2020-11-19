#import "SASPTHandler.h"
#import "Common.h"
#import <notify.h>
#import <AVFoundation/AVAsset.h>


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
    [c sendMessageName:kCanvasMessage userInfo:dict];
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



@interface SASPTHandler ()
@property (nonatomic, assign, readonly) BOOL canvasEnabled;
@property (nonatomic, assign, readonly) BOOL onlyOnWifi;

@property (nonatomic, strong, readonly) SPTGLUEImageLoader *imageLoader;
@property (nonatomic, strong, readonly) SPTCanvasTrackCheckerImplementation *trackChecker;
@property (nonatomic, strong, readonly) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;

@property (nonatomic, strong, nullable) SPTPlayerState *currentState;
@end

@implementation SASPTHandler

- (id)initWithImageLoader:(SPTGLUEImageLoader *)imageLoader
             trackChecker:(SPTCanvasTrackCheckerImplementation *)trackChecker
         videoAssetLoader:(SPTVideoURLAssetLoaderImplementation *)videoAssetLoader {
    if (self == [super init]) {
        _imageLoader = imageLoader;
        _trackChecker = trackChecker;
        _videoAssetLoader = videoAssetLoader;

        int token;
        notify_register_dispatch(kSpotifySettingsChanged,
            &token,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0l),
            ^(int t) {
                [self loadPrefs];
            });

        notify_register_dispatch(kManualSpotifyUpdate,
            &token,
            dispatch_get_main_queue(),
            ^(int t) {
                [self fetchDataForState:self.currentState];
            });

        [self loadPrefs];
    }

    return self;
}

- (void)loadPrefs {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSNumber *current = preferences[kCanvasOnlyWiFi];
    _onlyOnWifi = current && [current boolValue];

    current = preferences[kCanvasEnabled];
    _canvasEnabled = !current || [current boolValue];
}

- (void)player:(id <SPTPlayer>)player stateDidChange:(SPTPlayerState *)newState fromState:(SPTPlayerState *)oldState {
    self.currentState = newState;
}

- (void)setCurrentState:(SPTPlayerState *)currentState {
    _currentState = currentState;
    [self fetchDataForState:currentState];
}

- (void)fetchDataForState:(SPTPlayerState *)state {
    SPTPlayerTrack *track = state.track;

    if (self.canvasEnabled && track && [self.trackChecker isCanvasEnabledForTrack:track]) {
        NSURL *canvasURL = [track.metadata spt_URLForKey:@"canvas.url"];
        if (![canvasURL.absoluteString hasSuffix:@".mp4"])
            return [self tryWithArtworkForTrack:track state:state];

        SPTVideoURLAssetLoaderImplementation *assetLoader = self.videoAssetLoader;
        if ([assetLoader hasLocalAssetForURL:canvasURL]) {
            sendCanvasURL([assetLoader localURLForAssetURL:canvasURL]);
        } else {
            // The compiler doesn't like `AVURLAsset *` being specified as the type for some reason...
            [assetLoader loadAssetWithURL:canvasURL
                               onlyOnWifi:self.onlyOnWifi
                               completion:^(id asset) {
                sendCanvasURL(((AVURLAsset *)asset).URL);
            }];
        }
    } else {
        [self tryWithArtworkForTrack:track state:state];
    }
}

- (void)tryWithArtworkForTrack:(SPTPlayerTrack *)track state:(SPTPlayerState *)state {
    if ([self.imageLoader respondsToSelector:@selector(loadImageForURL:imageSize:completion:)]) {
        [self.imageLoader loadImageForURL:track.coverArtURLXLarge
                                imageSize:ARTWORK_SIZE
                               completion:^(UIImage *image) {
            if (!image)
                return sendEmptyMessage();

            if (state.track == track) {
                sendArtwork(image, track.UID);
            }
        }];
    } else {
        sendEmptyMessage();
    }
}

@end
