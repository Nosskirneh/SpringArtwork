#import "SASettingsListController.h"
#import "../SettingsKeys.h"
#import "../SAManager.h"


@interface SAArtworkListController : SASettingsListController
@end

@implementation SAArtworkListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Artwork" target:self];

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:@"enabledMode"])
        [super setEnabled:[preferences[key] intValue] == StaticColor
             forSpecifier:[self specifierForID:@"staticColor"]];

    return [super readPreferenceValue:specifier];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:@"enabledMode"])
        [super setEnabled:[value intValue] == StaticColor
             forSpecifier:[self specifierForID:@"staticColor"]];

    [super setPreferenceValue:value specifier:specifier];
}

@end
