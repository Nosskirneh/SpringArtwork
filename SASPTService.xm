#import "SASPTService.h"
#import "Spotify.h"
#import "SASPTHandler.h"


@interface SASPTService ()
@property (nonatomic, weak) id<SPTGLUEService> glueService;
@property (nonatomic, weak) SPTNetworkServiceImplementation *networkService;
@property (nonatomic, weak) SPTCanvasServiceImplementation *canvasService;
@property (nonatomic, weak) SPTPlayerFeatureImplementation *playerFeature;
@property (nonatomic, strong) SASPTHandler *handler;
@end


@implementation SASPTService

+ (NSString *)serviceIdentifier {
    return @"";
}

- (void)configureWithServices:(id<SPTServiceProvider>)serviceProvider {
    self.glueService = (id<SPTGLUEService>)[serviceProvider provideServiceForIdentifier:[%c(SPTGLUEServiceImplementation) serviceIdentifier]];
    self.networkService = (SPTNetworkServiceImplementation *)[serviceProvider provideServiceForIdentifier:[%c(SPTNetworkServiceImplementation) serviceIdentifier]];
    self.canvasService = (SPTCanvasServiceImplementation *)[serviceProvider provideServiceForIdentifier:[%c(SPTCanvasServiceImplementation) serviceIdentifier]];
    self.playerFeature = (SPTPlayerFeatureImplementation *)[serviceProvider provideServiceForIdentifier:[%c(SPTPlayerFeatureImplementation) serviceIdentifier]];
}

- (SPTGLUEImageLoader *)provideImageLoader {
    return [[self.glueService provideImageLoaderFactory] createImageLoaderForSourceIdentifier:[self.class serviceIdentifier]];
}

- (SPTCanvasTrackCheckerImplementation *)getCanvasTrackChecker {
    return self.canvasService.trackChecker;
}

- (SPTVideoURLAssetLoaderImplementation *)getVideoURLAssetLoader {
    return self.networkService.videoAssetLoader;
}

- (void)load {
    self.handler = [[SASPTHandler alloc] initWithImageLoader:[self provideImageLoader]
                                                trackChecker:[self getCanvasTrackChecker]
                                            videoAssetLoader:[self getVideoURLAssetLoader]];
    [self.playerFeature addPlayerObserver:self.handler];
}

- (void)unload {
    [self.playerFeature removePlayerObserver:self.handler];

    self.glueService = nil;
    self.networkService = nil;
    self.playerFeature = nil;
    self.handler = nil;
}

@end
