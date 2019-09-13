#import <AppSupport/CPDistributedMessagingCenter.h>
#import <rocketbootstrap/rocketbootstrap.h>

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


typedef enum SpotifyServiceScope {
    zero,
    application,
    session
} SpotifyServiceScope;


@interface NSDictionary (SPTTypeSafety)
- (NSURL *)spt_URLForKey:(NSString *)key;
@end
