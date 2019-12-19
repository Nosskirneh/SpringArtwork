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
    if ([key isEqualToString:kArtworkEnabled] && preferences[key] && ![preferences[key] boolValue])
        [super setEnabled:NO forSpecifiersAfterSpecifier:specifier];
    else if ([key isEqualToString:kOnlyBackground] && preferences[key] && [preferences[key] boolValue])
        [super setEnabled:NO forSpecifiersAfterSpecifier:specifier
                                     excludedIdentifiers:[NSSet setWithArray:@[kBlurRadius]]];
    else if ([key isEqualToString:kArtworkBackgroundMode])
        [self checkStaticColorEnableStateWithKey:key preferences:preferences];
    else if ([key isEqualToString:kAnimateArtwork] && preferences[key])
        [super setEnabled:![preferences[key] boolValue]
             forSpecifier:[self specifierForID:kArtworkCornerRadiusPercentage]];

    return [super readPreferenceValue:specifier];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kArtworkEnabled]) {
        BOOL enable = [value boolValue];
        [super setEnabled:enable forSpecifiersAfterSpecifier:specifier];
        if (enable)
            [self checkStaticColorEnableStateWithKey:key];
    } else if ([key isEqualToString:kOnlyBackground]) {
        [super setEnabled:![value boolValue] forSpecifiersAfterSpecifier:specifier
                                                     excludedIdentifiers:[NSSet setWithArray:@[kBlurRadius]]];
    } else if ([key isEqualToString:kArtworkBackgroundMode]) {
        [super setEnabled:[value intValue] == StaticColor
             forSpecifier:[self specifierForID:kStaticColor]];

        [super setEnabled:[value intValue] == BlurredImage
             forSpecifier:[self specifierForID:kBlurRadius]];
    } else if ([key isEqualToString:kAnimateArtwork]) {
        [super setEnabled:![value boolValue]
             forSpecifier:[self specifierForID:kArtworkCornerRadiusPercentage]];
    }

    [super setPreferenceValue:value specifier:specifier];
}

@end
