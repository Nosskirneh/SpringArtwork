#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import "../SettingsKeys.h"

@interface SASettingsListController : PSListController {
    UIWindow *settingsView;
}
- (void)setEnabled:(BOOL)enabled forSpecifier:(PSSpecifier *)specifier;
- (void)setEnabled:(BOOL)enabled forSpecifiersAfterSpecifier:(PSSpecifier *)specifier;
- (void)setEnabled:(BOOL)enabled forSpecifiersAfterSpecifier:(PSSpecifier *)specifier
                                         excludedIdentifiers:(NSSet *)excludedIdentifiers;
- (void)presentOKAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)presentAlertWithTitle:(NSString *)title
                      message:(NSString *)message
                      actions:(NSArray<UIAlertAction *> *)actions;
@end
