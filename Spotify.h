#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>

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

@interface SPTPlayerTrack : NSObject
@property (copy, nonatomic) NSDictionary *metadata;
@end

@interface SPTCanvasTrackCheckerImplementation : NSObject
- (BOOL)isCanvasEnabledForTrack:(SPTPlayerTrack *)track;
@end

@interface SPTCanvasServiceImplementation : NSObject<SPTService>
@property (retain, nonatomic) SPTCanvasTrackCheckerImplementation *trackChecker;
@end

@interface SPTPlayerState : NSObject
@property (retain, nonatomic) SPTPlayerTrack *track;
@end

@interface SPTCanvasNowPlayingContentReloader
@property (retain, nonatomic) SPTVideoURLAssetLoaderImplementation *videoAssetLoader;
@property (retain, nonatomic) SPTPlayerState *currentState;

@property (nonatomic, assign) BOOL sa_onlyOnWifi;
@end


typedef enum SpotifyServiceScope {
    zero,
    application,
    session
} SpotifyServiceScope;


@interface NSDictionary (SPTTypeSafety)
- (NSURL *)spt_URLForKey:(NSString *)key;
@end
