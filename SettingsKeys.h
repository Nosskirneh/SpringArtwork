#define SAColor [UIColor colorWithRed:0.35 green:0.0 blue:0.5 alpha:1.0] // #580080E6
#define SA_IDENTIFIER @"se.nosskirneh.springartwork"
#define kPrefChanged [NSString stringWithFormat:@"%@/preferencesChanged", SA_IDENTIFIER]
#define kPrefPath [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), SA_IDENTIFIER]


#define kPostNotification @"PostNotification"
#define kIconImage @"iconImage"
#define kKey @"key"
#define kDefault @"default"
#define kCell @"cell"


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
