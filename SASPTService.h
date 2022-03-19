#import "Spotify.h"

@interface SASPTService : NSObject<SPTService>
- (SPTGLUEImageLoader *)provideImageLoader;
- (SPTVideoURLAssetLoaderImplementation *)getVideoURLAssetLoader;
@end
