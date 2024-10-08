#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SASettingsListController.h"
#import <notify.h>
#import <substrate.h>
#import <objc/runtime.h>
#import <spawn.h>

typedef enum {
      NoneRespringStyle      = 0,
      RestartRenderServer    = (1 << 0), // also relaunch backboardd
      SnapshotTransition     = (1 << 1),
      FadeToBlackTransition  = (1 << 2),
} SBSRelaunchActionStyle;

@interface SBSRelaunchAction : NSObject
+ (id)actionWithReason:(NSString *)reason
               options:(SBSRelaunchActionStyle)options
             targetURL:(NSURL *)url;
@end

@interface SBSRestartRenderServerAction : SBSRelaunchAction
+ (id)restartActionWithTargetRelaunchURL:(NSURL *)url;
@end

@interface FBSSystemService : NSObject
+ (id)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)completion;
@end

static void killProcess(const char *name) {
    pid_t pid;
    int status;
    const char *args[] = { "killall", "-9", name, NULL };
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
    waitpid(pid, &status, WEXITED);
}

static void respring() {
    if (objc_getClass("FBSSystemService")) {
        Class relaunchAction = objc_getClass("SBSRelaunchAction");
        SBSRelaunchAction *restartAction = relaunchAction ?
                                               [relaunchAction actionWithReason:@"RestartRenderServer"
                                                                        options:FadeToBlackTransition
                                                                      targetURL:nil] :
                                               [objc_getClass("SBSRestartRenderServerAction") restartActionWithTargetRelaunchURL:nil];
        [[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction]
                                                            withResult:nil];
    } else {
        killProcess("SpringBoard");
    }
}

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
    respring();
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

    NSMutableDictionary *preferences = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath];
    if (!preferences)
        preferences = [NSMutableDictionary new];
    [preferences setObject:value forKey:key];
    [preferences writeToFile:kPrefPath atomically:YES];

    NSString *notificationString = specifier.properties[kPostNotification];
    if (notificationString)
        notify_post([notificationString UTF8String]);
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
                                            respring();
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
    PSTableCell *cell = [self tableView:self.table cellForRowAtIndexPath:indexPath];
    if (cell) {
        cell.userInteractionEnabled = enabled;
        cell.textLabel.enabled = enabled;
        cell.detailTextLabel.enabled = enabled;

        if ([cell isKindOfClass:[PSControlTableCell class]]) {
            PSControlTableCell *controlCell = (PSControlTableCell *)cell;
            if (controlCell.control)
                controlCell.control.enabled = enabled;
        } else {
            [cell setCellEnabled:enabled];
        }
    }
}

- (void)setEnabled:(BOOL)enabled forSpecifiersAfterSpecifier:(PSSpecifier *)specifier {
    long long index = [self indexOfSpecifier:specifier];
    for (int i = index + 1; i < _specifiers.count; i++)
        [self setEnabled:enabled forSpecifier:_specifiers[i]];
}

- (void)setEnabled:(BOOL)enabled forSpecifiersAfterSpecifier:(PSSpecifier *)specifier
                                         excludedIdentifiers:(NSSet *)excludedIdentifiers {
    if (!excludedIdentifiers)
        return [self setEnabled:enabled forSpecifiersAfterSpecifier:specifier];

    long long index = [self indexOfSpecifier:specifier];
    for (int i = index + 1; i < _specifiers.count; i++) {
        PSSpecifier *specifier = _specifiers[i];
        if (![excludedIdentifiers containsObject:specifier.identifier])
            [self setEnabled:enabled forSpecifier:specifier];
    }
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

- (void)presentAlertWithTitle:(NSString *)title
                      message:(NSString *)message
                      actions:(NSArray<UIAlertAction *> *)actions {
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
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    settingsView = [[UIApplication sharedApplication] keyWindow];
    settingsView.tintColor = nil;
}

@end
