#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>

#define ARTWORK_WIDTH [UIScreen mainScreen].nativeBounds.size.width
#define ARTWORK_SIZE CGSizeMake(ARTWORK_WIDTH, ARTWORK_WIDTH)

@protocol SPTService <NSObject>
+ (NSString *)serviceIdentifier;
@end

@interface SpotifyAppDelegate : NSObject
- (id<SPTService>)serviceForIdentifier:(NSString *)identifier inScope:(NSString *)scope;
@end


@interface SPTVideoURLAssetLoaderImplementation : NSObject
- (NSURL *)localURLForAssetURL:(NSURL *)url;
- (void)loadAssetWithURL:(id)arg1 onlyOnWifi:(BOOL)arg2 completion:(id)arg3;
- (BOOL)hasLocalAssetForURL:(id)arg1;
@end

@interface SPTNetworkServiceImplementation : NSObject<SPTService>
@property (retain, nonatomic) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;
@end

@interface SPTPlayerTrack : NSObject
@property (copy, nonatomic) NSDictionary *metadata;
@property (readonly, nonatomic) NSURL *coverArtURLXLarge;
@property (copy, nonatomic) NSString *UID;
@end

@interface SPTCanvasTrackCheckerImplementation : NSObject
- (BOOL)isCanvasEnabledForTrack:(SPTPlayerTrack *)track;
@end

@class SPTCanvasLogger, SPTCanvasNowPlayingContentReloader;
@interface SPTCanvasServiceImplementation : NSObject<SPTService>
@property (retain, nonatomic) SPTCanvasTrackCheckerImplementation *trackChecker;
@property (retain, nonatomic) SPTCanvasLogger *canvasLogger;
@property (retain, nonatomic) SPTCanvasNowPlayingContentReloader *canvasContentReloader;
@end

@interface SPTGLUEImageLoaderFactoryImplementation : NSObject
- (id)createImageLoaderForSourceIdentifier:(NSString *)sourceIdentifier;
@end

@interface SPTQueueServiceImplementation : NSObject
@property (retain, nonatomic) SPTGLUEImageLoaderFactoryImplementation *glueImageLoaderFactory;
@end

@interface SPTPlayerState : NSObject
@property (retain, nonatomic) SPTPlayerTrack *track;
@end

@interface SPTGLUEImageLoader : NSObject
- (id)loadImageForURL:(NSURL *)URL imageSize:(CGSize)size completion:(id)completion;
@end


@protocol SpringArtworkTarget<NSObject>

@property (nonatomic, assign) BOOL sa_onlyOnWifi;
@property (nonatomic, assign) BOOL sa_canvasEnabled;
@property (nonatomic, retain) SPTGLUEImageLoader *imageLoader;
@property (nonatomic, retain) SPTCanvasTrackCheckerImplementation *trackChecker;
@property (retain, nonatomic) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;

- (void)sa_commonInit;
- (void)sa_loadPrefs;
- (void)sa_fetchDataForState:(SPTPlayerState *)state;
- (void)tryWithArtworkForTrack:(SPTPlayerTrack *)track;
- (SPTPlayerState *)sa_getPlayerState;

@optional
@property (retain, nonatomic) SPTPlayerState *currentState;
@property (retain, nonatomic) SPTPlayerState *currentPlayerState;

@end

@interface SPTCanvasLogger : NSObject<SpringArtworkTarget>
@property (retain, nonatomic) SPTPlayerState *currentState; // Old
@property (retain, nonatomic) SPTPlayerState *currentPlayerState; // New
@end


@interface SPTCanvasNowPlayingContentReloader : NSObject<SpringArtworkTarget>
@property (retain, nonatomic) SPTPlayerState *currentState;
@end


typedef enum SpotifyServiceScope {
    zero,
    application,
    session
} SpotifyServiceScope;


@interface NSDictionary (SPTTypeSafety)
- (NSURL *)spt_URLForKey:(NSString *)key;
@end
