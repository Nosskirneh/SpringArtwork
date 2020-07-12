#import "SettingsKeys.h"

#define kSpringBoardBundleID @"com.apple.springboard"
#define kMusicBundleID @"com.apple.Music"
#define kDeezerBundleID @"com.deezer.Deezer"

#define ANIMATION_DURATION 0.75

extern NSString *const kSpotifyMessage;
extern NSString *const kCanvasURL;
extern NSString *const kArtwork;
extern NSString *const kTrackIdentifier;
extern NSString *const kBundleID;

extern NSString *const kCanvasAsset;
extern NSString *const kCanvasThumbnail;
extern NSString *const kIsDirty;
extern NSString *const kArtworkImage;
extern NSString *const kBlurredImage;
extern NSString *const kColor;
extern NSString *const kChangeOfContent;

#define kManualSpotifyUpdate "se.nosskirneh.springartwork/manualSpotifyUpdate"


#ifdef __cplusplus
extern "C" {
#endif

BOOL isSpotify(NSString *bundleID);

#ifdef __cplusplus
}
#endif
