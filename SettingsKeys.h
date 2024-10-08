#import <Foundation/Foundation.h>

#define SAColor [UIColor colorWithRed:0.62 green:0.20 blue:0.54 alpha:1.00] // ~ #9B348F
#define SA_IDENTIFIER @"se.nosskirneh.springartwork"
#define kPrefPath [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", SA_IDENTIFIER]


#define kPostNotification @"PostNotification"
#define kIconImage @"iconImage"
#define kKey @"key"
#define kID @"id"
#define kDefault @"default"
#define kCell @"cell"
#define kEnabled @"enabled"
#define kFooterText @"footerText"


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

typedef enum BlurColoringMode {
    BasedOnArtwork,
    BasedOnDarkMode,
    DarkBlurWhiteText,
    LightBlurBlackText
} BlurColoringMode;

typedef enum OverrideTextColorMode {
    InheritFromBlurMode,
    ForceWhiteText,
    ForceDarkText
} OverrideTextColorMode;


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
extern NSString *const kBlurColoringMode;
extern NSString *const kOverrideTextColorMode;
extern NSString *const kBlurRadius;
extern NSString *const kAnimateArtwork;
extern NSString *const kArtworkCornerRadiusPercentage;
extern NSString *const kArtworkWidthPercentage;
extern NSString *const kArtworkYOffsetPercentage;

// Video artwork
extern NSString *const kCanvasEnabled;
extern NSString *const kCanvasOnlyWiFi;
