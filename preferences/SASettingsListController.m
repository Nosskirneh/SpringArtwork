#import "SASettingsListController.h"
#import "../notifyDefines.h"
#import "../../DRM/respring.xm"

@implementation SASettingsListController

- (void)respring {
    respring(NO);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:kKey];

    if (preferences[key])
        return preferences[key];

    return specifier.properties[kDefault];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!preferences) preferences = [[NSMutableDictionary alloc] init];
    NSString *key = [specifier propertyForKey:kKey];

    [preferences setObject:value forKey:key];
    [preferences writeToFile:kPrefPath atomically:YES];
    
    if (specifier.properties[kPostNotification]) {
        CFStringRef post = (CFStringRef)CFBridgingRetain(specifier.properties[kPostNotification]);
        notify(post);
    }
}

- (void)setEnabled:(BOOL)enabled forSpecifier:(PSSpecifier *)specifier {
    if (!specifier || [[specifier propertyForKey:kCell] isEqualToString:@"PSGroupCell"])
        return;

    NSIndexPath *indexPath = [self indexPathForSpecifier:specifier];
    UITableViewCell *cell = [self tableView:self.table cellForRowAtIndexPath:indexPath];
    if (cell) {
        cell.userInteractionEnabled = enabled;
        cell.textLabel.enabled = enabled;
        cell.detailTextLabel.enabled = enabled;
        
        if ([cell isKindOfClass:[PSControlTableCell class]]) {
            PSControlTableCell *controlCell = (PSControlTableCell *)cell;
            if (controlCell.control)
                controlCell.control.enabled = enabled;
        }
    }
}

- (void)setEnabled:(BOOL)enabled forSpecifiersAfterSpecifier:(PSSpecifier *)specifier {
    long long index = [self indexOfSpecifier:specifier];
    for (int i = index + 1; i < _specifiers.count; i++)
        [self setEnabled:enabled forSpecifier:_specifiers[i]];
}

- (void)presentOKAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:nil];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentAlertWithTitle:(NSString *)title message:(NSString *)message actions:(NSArray<UIAlertAction *> *)actions {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    if (actions) {
        for (UIAlertAction *action in actions)
            [alert addAction:action];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    // Tint
    settingsView = [[UIApplication sharedApplication] keyWindow];
    settingsView.tintColor = SAColor;

    [self reloadSpecifiers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    settingsView = [[UIApplication sharedApplication] keyWindow];
    settingsView.tintColor = nil;
}

@end
