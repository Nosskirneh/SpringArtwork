#import "Spotify.h"

@interface SASPTHandler : NSObject<SPTPlayerObserver>
- (id)initWithImageLoader:(SPTGLUEImageLoader *)imageLoader
             trackChecker:(SPTCanvasTrackCheckerImplementation *)trackChecker
         videoAssetLoader:(SPTVideoURLAssetLoaderImplementation *)videoAssetLoader;
@end
