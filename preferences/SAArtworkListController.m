#import "SASettingsListController.h"
#import "SAColorListItemsController.h"
#import "SAAppListController.h"
#include <dlfcn.h>

@interface SAArtworkListController : SASettingsListController
@end

@implementation SAArtworkListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Artwork" target:self];

    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self insertBlurredColoringModes];
    [self insertAppListSpecifier];
}

- (void)reloadSpecifiers {
    [super reloadSpecifiers];

    [self insertBlurredColoringModes];
    [self insertAppListSpecifier];
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
                                     excludedIdentifiers:[NSSet setWithArray:@[kBlurRadius,
                                                                               kBlurColoringMode,
                                                                               kOverrideTextColorMode]]];
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
                                                     excludedIdentifiers:[NSSet setWithArray:@[kBlurRadius,
                                                                                               kBlurColoringMode,
                                                                                               kOverrideTextColorMode]]];
    } else if ([key isEqualToString:kArtworkBackgroundMode]) {
        [super setEnabled:[value intValue] == StaticColor
             forSpecifier:[self specifierForID:kStaticColor]];

        BOOL enableBlurOptions = [value intValue] == BlurredImage;
        [super setEnabled:enableBlurOptions forSpecifier:[self specifierForID:kBlurRadius]];
        [super setEnabled:enableBlurOptions forSpecifier:[self specifierForID:kBlurColoringMode]];
    } else if ([key isEqualToString:kAnimateArtwork]) {
        [super setEnabled:![value boolValue]
             forSpecifier:[self specifierForID:kArtworkCornerRadiusPercentage]];
    }

    [super setPreferenceValue:value specifier:specifier];
}

- (void)insertAppListSpecifier {
    void *dylibLink = dlopen("/usr/lib/libapplist.dylib", RTLD_NOW);
    PSSpecifier *applistSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Disabled apps"
                                                                   target:self
                                                                      set:@selector(setPreferenceValue:specifier:)
                                                                      get:@selector(readPreferenceValue:)
                                                                   detail:SAAppListController.class
                                                                     cell:PSLinkCell
                                                                     edit:nil];
    if (dylibLink == NULL) {
        [applistSpecifier setProperty:@NO forKey:kEnabled];
        PSSpecifier *groupSpecifier = [self specifierForID:@"disabledGroup"];
        [groupSpecifier setProperty:@"Install AppList to disable apps." forKey:kFooterText];
    }

    [self insertSpecifier:applistSpecifier afterSpecifierID:kArtworkEnabled animated:NO];
}

- (void)insertBlurredColoringModes {
    NSMutableArray *coloringModes = [NSMutableArray arrayWithArray:@[@"Based on artwork",
                                                                     @"Dark blur & white text",
                                                                     @"Light blur & black text"]];
    NSMutableArray *coloringModeValues = [NSMutableArray arrayWithArray:@[@(BasedOnArtwork),
                                                                          @(DarkBlurWhiteText),
                                                                          @(LightBlurBlackText)]];
    if (@available(iOS 13, *)) {
        [coloringModes insertObject:@"Based on dark mode" atIndex:1];
        [coloringModeValues insertObject:@(BasedOnDarkMode) atIndex:1];
    }

    // Create a specifier for it
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"Blur coloring mode"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:SAColorListItemsController.class
                                                              cell:PSLinkListCell
                                                              edit:nil];

    [specifier setProperty:coloringModeValues[0] forKey:kDefault];
    [specifier setProperty:kBlurColoringMode forKey:kID];
    [specifier setProperty:kBlurColoringMode forKey:kKey];
    [specifier setProperty:[NSString stringWithUTF8String:kSettingsChanged]
                    forKey:kPostNotification];
    [specifier setValues:coloringModeValues titles:coloringModes];

    // Add the specifiers
    [self insertSpecifier:specifier afterSpecifierID:@"colors" animated:NO];
}

@end
