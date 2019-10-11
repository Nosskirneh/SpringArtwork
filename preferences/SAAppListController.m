#import "../SettingsKeys.h"
#import "SAAppListController.h"
#import <Preferences/PSSpecifier.h>
#import <AppList/AppList.h>

@interface PSSpecifier (Missing)
+ (id)groupSpecifierWithHeader:(NSString *)header footer:(NSString *)footer;
@end

@implementation SAAppListController

- (id)specifiers {
	if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray new];
        PSSpecifier *spec;

        // System applications
        spec = [PSSpecifier groupSpecifierWithHeader:@"System Applications" footer:nil];
        [specifiers addObject:spec];
        [self addApplicationsToList:specifiers systemApps:YES];

        // User applications
        spec = [PSSpecifier groupSpecifierWithHeader:@"User Applications" footer:nil];
        [specifiers addObject:spec];
        [self addApplicationsToList:specifiers systemApps:NO];

        _specifiers = specifiers;
    }

	return _specifiers;
}

- (void)addApplicationsToList:(NSMutableArray *)specifiers systemApps:(BOOL)systemApps {
    NSArray *sortedDisplayIdentifiers;
    NSString *predStr = systemApps ? @"isSystemApplication = TRUE" : @"isSystemApplication = FALSE";
    NSDictionary *applications = [[ALApplicationList sharedApplicationList] applicationsFilteredUsingPredicate:[NSPredicate predicateWithFormat:predStr]
                                                                                                   onlyVisible:YES
                                                                                        titleSortedIdentifiers:&sortedDisplayIdentifiers];
    // Sort the array
    NSArray *orderedKeys = [applications keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];

    // Add each application as a switch
    for (NSString *key in orderedKeys) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:applications[key]
                                                           target:self
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSSwitchCell
                                                             edit:nil];
        [spec setProperty:key forKey:kKey];
        [spec setProperty:@NO forKey:kDefault];

        UIImage *icon = [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall
                                                         forDisplayIdentifier:key];
        [spec setProperty:icon forKey:kIconImage];

        [specifiers addObject:spec];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!preferences) preferences = [[NSMutableDictionary alloc] init];
    NSString *key = [specifier propertyForKey:kKey];

    if ([value isEqualToNumber:@NO])
        [preferences removeObjectForKey:key];
    else if ([value isEqualToNumber:@YES])
        [preferences setObject:value forKey:key];

    [preferences writeToFile:kPrefPath atomically:YES];
}

@end
