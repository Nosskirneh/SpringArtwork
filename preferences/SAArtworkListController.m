#import "SASettingsListController.h"


@interface SAArtworkListController : SASettingsListController
@end

@implementation SAArtworkListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Artwork" target:self];

    return _specifiers;
}

- (void)checkStaticColorEnableStateWithKey:(NSString *)key {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    [self checkStaticColorEnableStateWithKey:key preferences:preferences];
}

- (void)checkStaticColorEnableStateWithKey:(NSString *)key preferences:(NSDictionary *)preferences {
    [super setEnabled:[preferences[key] intValue] == StaticColor
         forSpecifier:[self specifierForID:kStaticColor]];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kArtworkEnabled] && ![preferences[key] boolValue])
        [super setEnabled:NO forSpecifiersAfterSpecifier:specifier];
    else if ([key isEqualToString:kArtworkBackgroundMode])
        [self checkStaticColorEnableStateWithKey:key preferences:preferences];

    return [super readPreferenceValue:specifier];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kArtworkEnabled]) {
        BOOL enable = [value boolValue];
        [super setEnabled:enable forSpecifiersAfterSpecifier:specifier];
        if (enable)
            [self checkStaticColorEnableStateWithKey:key];
    } else if ([key isEqualToString:kArtworkBackgroundMode])
        [super setEnabled:[value intValue] == StaticColor
             forSpecifier:[self specifierForID:kStaticColor]];

    [super setPreferenceValue:value specifier:specifier];
}

@end
