#define SAColor [UIColor colorWithRed:0.88 green:0.42 blue:0.04 alpha:1.0] // ~ #E26C0B
#define SA_IDENTIFIER @"se.nosskirneh.springartwork"
#define kPrefPath [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", SA_IDENTIFIER]


#define kPostNotification @"PostNotification"
#define kIconImage @"iconImage"
#define kKey @"key"
#define kDefault @"default"
#define kCell @"cell"


typedef enum EnabledMode {
    BothMode,
    LockscreenMode,
    HomescreenMode
} EnabledMode;

typedef enum Mode {
    None,
    Canvas,
    Artwork
} Mode;

typedef enum ArtworkBackgroundMode {
    MatchingColor,
    BlurredImage,
    StaticColor
} ArtworkBackgroundMode;


extern const char *kSpotifySettingsChanged;
extern const char *kSettingsChanged;

// General
extern NSString *const kEnabledMode;
extern NSString *const kTintFolderIcons;
extern NSString *const kHideDockBackground;
extern NSString *const kShakeToPause;
extern NSString *const kPauseContentWithMedia;

// Normal artwork
extern NSString *const kArtworkEnabled;
extern NSString *const kDisabledApps;
extern NSString *const kArtworkBackgroundMode;
extern NSString *const kStaticColor;

extern NSString *const kOnlyBackground;
extern NSString *const kBlurRadius;
extern NSString *const kAnimateArtwork;
extern NSString *const kArtworkCornerRadiusPercentage;
extern NSString *const kArtworkWidthPercentage;
extern NSString *const kArtworkYOffsetPercentage;

// Video artwork
extern NSString *const kCanvasEnabled;
extern NSString *const kCanvasOnlyWiFi;
