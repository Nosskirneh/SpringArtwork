#define SAColor [UIColor colorWithRed:0.35 green:0.0 blue:0.5 alpha:1.0] // #580080E6
#define SA_IDENTIFIER @"se.nosskirneh.springartwork"
#define kPrefChanged [NSString stringWithFormat:@"%@/preferencesChanged", SA_IDENTIFIER]
#define kPrefPath [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), SA_IDENTIFIER]


#define kPostNotification @"PostNotification"
#define kIconImage @"iconImage"
#define kKey @"key"
#define kDefault @"default"


extern NSString *const kEnabledMode;
extern NSString *const kStaticColor;
