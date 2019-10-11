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
    if ([key isEqualToString:kCanvasEnabled])
        [super setEnabled:[value boolValue] forSpecifiersAfterSpecifier:specifier];

    [super setPreferenceValue:value specifier:specifier];
}

@end
