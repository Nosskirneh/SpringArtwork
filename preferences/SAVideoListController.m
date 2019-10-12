#import "SASettingsListController.h"


@interface SAVideoListController : SASettingsListController
@end

@implementation SAVideoListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Video" target:self];

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kCanvasEnabled] && ![preferences[key] boolValue])
        [super setEnabled:[preferences[key] boolValue] forSpecifiersAfterSpecifier:specifier];

    return [super readPreferenceValue:specifier];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kCanvasEnabled]) {
        BOOL enableCanvas = [value boolValue];
        [super setEnabled:enableCanvas forSpecifiersAfterSpecifier:specifier];

        if (enableCanvas) {
            [super presentOKAlertWithTitle:@"Restart of Spotify"
                                   message:@"If Spotify was opened with this setting disabled, the app must be restarted for it to take effect."];
        }
    }

    [super setPreferenceValue:value specifier:specifier];
}

@end
