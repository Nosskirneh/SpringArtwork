#import "SASettingsListController.h"
#import "../SettingsKeys.h"
#import "notifyDefines.h"
#import "../../DRM/respring.xm"

@implementation SASettingsListController

- (id)init {
    if (self == [super init]) {
        UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(respring)];
        self.navigationItem.rightBarButtonItem = respringButton;
    }

    return self;
}

- (void)respring {
    respring(NO);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:kKey];

    if (preferences[key])
        return preferences[key];

    return specifier.properties[kDefault];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!preferences) preferences = [[NSMutableDictionary alloc] init];
    NSString *key = [specifier propertyForKey:kKey];

    [preferences setObject:value forKey:key];
    [preferences writeToFile:kPrefPath atomically:YES];
    
    if (specifier.properties[kPostNotification]) {
        CFStringRef post = (CFStringRef)CFBridgingRetain(specifier.properties[kPostNotification]);
        notify(post);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Tint
    settingsView = [[UIApplication sharedApplication] keyWindow];
    settingsView.tintColor = SAColor;

    [self reloadSpecifiers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    settingsView = [[UIApplication sharedApplication] keyWindow];
    settingsView.tintColor = nil;
}

@end
