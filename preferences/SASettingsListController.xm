#import "SASettingsListController.h"
#import "../notifyDefines.h"
#import "../../DRM/respring.xm"

@interface UISegmentedControl (Missing)
- (void)selectSegment:(int)index;
@end

@interface PSSegmentTableCell : PSControlTableCell
@property (retain) UISegmentedControl *control;
@end

@interface PSSwitchTableCell : PSControlTableCell
@property (retain) UISwitch *control;
@end

@interface PSSliderTableCell : PSControlTableCell
@property (retain) UISlider *control;
@end

#define kRequiresRespring @"requiresRespring"

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

- (void)savePreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];

    NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
    if (!preferences) preferences = [[NSMutableDictionary alloc] init];
    [preferences setObject:value forKey:key];
    [preferences writeToFile:kPrefPath atomically:YES];
    
    if (specifier.properties[kPostNotification]) {
        CFStringRef post = (CFStringRef)CFBridgingRetain(specifier.properties[kPostNotification]);
        notify(post);
    }
}

- (void)preferenceValueChanged:(id)value specifier:(PSSpecifier *)specifier {}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [self preferenceValueChanged:value specifier:specifier];

    NSNumber *respringNumber = [specifier propertyForKey:kRequiresRespring];
    if (respringNumber && [respringNumber boolValue]) {
        UIAlertAction *respringAction = [UIAlertAction actionWithTitle:@"Yes"
                                                                 style:UIAlertActionStyleDestructive
                                                               handler:^(UIAlertAction *action) {
                                            [self savePreferenceValue:value specifier:specifier];
                                            respring(NO);
                                        }];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"No, revert change"
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
            NSIndexPath *indexPath = [self indexPathForSpecifier:specifier];
            PSTableCell *cell = [self tableView:self.table cellForRowAtIndexPath:indexPath];
            id pickedValue = [self readPreferenceValue:specifier];

            if ([cell isKindOfClass:%c(PSSegmentTableCell)]) {
                PSSegmentTableCell *segmentCell = (PSSegmentTableCell *)cell;
                int segmentIndex = [MSHookIvar<NSArray *>(segmentCell, "_values") indexOfObject:pickedValue];
                [segmentCell.control selectSegment:segmentIndex];
            } else if ([cell isKindOfClass:%c(PSSwitchTableCell)]) {
                PSSwitchTableCell *switchCell = (PSSwitchTableCell *)cell;
                [switchCell.control setOn:[pickedValue boolValue] animated:YES];
            } else if ([cell isKindOfClass:%c(PSSliderTableCell)]) {
                PSSliderTableCell *sliderCell = (PSSliderTableCell *)cell;
                [sliderCell.control setValue:[pickedValue floatValue] animated:YES];
            }

            [self preferenceValueChanged:pickedValue specifier:specifier];
        }];

        UIAlertAction *laterAction = [UIAlertAction actionWithTitle:@"No, I'll respring later"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
            [self savePreferenceValue:value specifier:specifier];
        }];
        [self presentAlertWithTitle:@"Restart of SpringBoard"
                            message:@"Changing this setting requires SpringBoard to be restarted. Do you wish to proceed?"
                            actions:@[respringAction, cancelAction, laterAction]];
        return;
    }

    [self savePreferenceValue:value specifier:specifier];
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
