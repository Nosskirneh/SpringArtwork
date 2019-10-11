#import <Preferences/Preferences.h>

@interface SASettingsListController : PSListController {
    UIWindow *settingsView;
}
- (void)setEnabled:(BOOL)enabled forSpecifier:(PSSpecifier *)specifier;
@end
