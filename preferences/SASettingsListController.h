#import <Preferences/Preferences.h>
#import "../SettingsKeys.h"

@interface SASettingsListController : PSListController {
    UIWindow *settingsView;
}
- (void)setEnabled:(BOOL)enabled forSpecifier:(PSSpecifier *)specifier;
- (void)setEnabled:(BOOL)enabled forSpecifiersAfterSpecifier:(PSSpecifier *)specifier;
@end
