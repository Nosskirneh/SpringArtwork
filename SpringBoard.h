#import "CanvasReceiver.h"
#import <AVFoundation/AVPlayerItem.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <AVFoundation/AVAudioSession.h>

#define ANIMATION_DURATION 0.75

@interface SBFStaticWallpaperView : UIView
@property (nonatomic, retain) AVPlayerLayer *canvasLayer;
- (void)_setupCanvasLayer:(UIView *)view;
- (void)changeCanvasURL:(NSURL *)url;
- (void)fadeCanvasLayerIn;
- (void)fadeCanvasLayerOut;
- (void)_showCanvasLayer:(BOOL)show;
- (void)_showCanvasLayer:(BOOL)show completion:(void (^)(void))completion;
@end


@interface SBWallpaperEffectView : UIView {
    SBWallpaperEffectView *_backgroundView;
}
@end

@interface SBDockView : UIView
@end

@interface SBRootFolderView : UIView
- (SBDockView *)dockView;
@end

@interface SBRootFolderController : UIViewController
@property (nonatomic, readonly) SBRootFolderView *contentView;
@end

@interface SBIconController
+ (id)sharedInstance;
- (SBRootFolderController *)_rootFolderController;
@end


@interface AVAudioSessionMediaPlayerOnly : NSObject
- (BOOL)setCategory:(NSString *)category error:(id *)error;
@end

@interface AVPlayer (Private)
- (AVAudioSessionMediaPlayerOnly *)playerAVAudioSession;
@end
