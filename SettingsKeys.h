#define SAColor [UIColor colorWithRed:0.35 green:0.0 blue:0.5 alpha:1.0] // #580080E6
#define SA_IDENTIFIER @"se.nosskirneh.springartwork"
#define kPrefPath [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), SA_IDENTIFIER]


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

// Normal artwork
extern NSString *const kArtworkEnabled;
extern NSString *const kArtworkBackgroundMode;
extern NSString *const kStaticColor;
extern NSString *const kArtworkWidthPercentage;

// Video artwork
extern NSString *const kCanvasEnabled;
extern NSString *const kCanvasOnlyWiFi;
