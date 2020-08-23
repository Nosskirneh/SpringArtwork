#import "Spotify.h"

@interface SASPTService : NSObject<SPTService>
- (SPTGLUEImageLoader *)provideImageLoader;
- (SPTCanvasTrackCheckerImplementation *)getCanvasTrackChecker;
- (SPTVideoURLAssetLoaderImplementation *)getVideoURLAssetLoader;
@end
