#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>
#import <UIKit/UIKit.h>

#define ARTWORK_WIDTH [UIScreen mainScreen].nativeBounds.size.width
#define ARTWORK_SIZE CGSizeMake(ARTWORK_WIDTH, ARTWORK_WIDTH)


@interface SpotifyServiceList
+ (NSArray *(^)(void))sessionServices;
+ (void)setSessionServices:(NSArray *(^)(void))sessionServices;
@end


@protocol SPTServiceList <NSObject>
- (NSArray *)serviceClassesForScope:(NSString *)scope;
@end

@protocol SPTService;

@protocol SPTServiceProvider <NSObject>
- (id <SPTService>)provideOptionalServiceForIdentifier:(NSString *)identifier;
- (id <SPTService>)provideServiceForIdentifier:(NSString *)identifier;
@end

@protocol SPTServiceProvider;

@protocol SPTService <NSObject>
@property (atomic, class, readonly) NSString *serviceIdentifier;
- (void)configureWithServices:(id<SPTServiceProvider>)serviceProvider;

@optional
- (void)idleStateWasReached;
- (void)initialViewDidAppear;
- (void)load;
- (void)unload;
@end

@interface SPTVideoURLAssetLoaderImplementation : NSObject
- (NSURL *)localURLForAssetURL:(NSURL *)url;
- (void)loadAssetWithURL:(id)url onlyOnWifi:(BOOL)onlyOnWifi completion:(id)completion;
- (BOOL)hasLocalAssetForURL:(id)url;
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

@interface SPTPlayerState : NSObject
@property (retain, nonatomic) SPTPlayerTrack *track;
@end

@interface SPTGLUEImageLoader : NSObject
- (id)loadImageForURL:(NSURL *)URL imageSize:(CGSize)size completion:(id)completion;
@end

@protocol SPTGLUEImageLoaderFactory <NSObject>
- (SPTGLUEImageLoader *)createImageLoaderForSourceIdentifier:(NSString *)sourceIdentifier;
@end

@protocol SPTGLUEService <SPTService>
- (id <SPTGLUEImageLoaderFactory>)provideImageLoaderFactory;
@end

@protocol SPTPlayer <NSObject>
@end

@protocol SPTPlayerObserver <NSObject>
@optional
- (void)player:(id <SPTPlayer>)player didEncounterError:(NSError *)error;
- (void)player:(id <SPTPlayer>)player stateDidChange:(SPTPlayerState *)newState fromState:(SPTPlayerState *)oldState;
- (void)player:(id <SPTPlayer>)player stateDidChange:(SPTPlayerState *)newState;
@end


@interface SPTPlayerFeatureImplementation : NSObject<SPTService>
- (void)removePlayerObserver:(id<SPTPlayerObserver>)observer;
- (void)addPlayerObserver:(id<SPTPlayerObserver>)observer;
@end


typedef enum SpotifyServiceScope {
    zero,
    application,
    session
} SpotifyServiceScope;


@interface NSDictionary (SPTTypeSafety)
- (NSURL *)spt_URLForKey:(NSString *)key;
@end
