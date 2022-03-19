#import "Spotify.h"

@interface SASPTHandler : NSObject<SPTPlayerObserver>
- (id)initWithImageLoader:(SPTGLUEImageLoader *)imageLoader
         videoAssetLoader:(SPTVideoURLAssetLoaderImplementation *)videoAssetLoader;
@end
