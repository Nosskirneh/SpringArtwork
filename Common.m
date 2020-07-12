NSString *const kSpotifyMessage = @"se.nosskirneh.springartwork/spotifyMessage";
NSString *const kCanvasURL = @"canvasURL";
NSString *const kArtwork = @"artwork";
NSString *const kTrackIdentifier = @"trackIdentifier";
NSString *const kBundleID = @"bundleID";

NSString *const kCanvasAsset = @"canvasAsset";
NSString *const kCanvasThumbnail = @"canvasThumbnail";
NSString *const kIsDirty = @"isDirty";
NSString *const kArtworkImage = @"artworkImage";
NSString *const kBlurredImage = @"blurredImage";
NSString *const kColor = @"color";
NSString *const kChangeOfContent = @"changeOfContent";


#define kSpotifyBundleID @"com.spotify.client"
#define kSpotifyInternalBundleID @"com.spotify.client.internal"

BOOL isSpotify(NSString *bundleID) {
    return [bundleID isEqualToString:kSpotifyBundleID] ||
           [bundleID isEqualToString:kSpotifyInternalBundleID];
}
