#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/Preferences.h>
#import <HBLog.h>
#import "SASettingsListController.h"
#import <UIKit/UITableViewLabel.h>
#import "../Common.h"
#import "../../TwitterStuff/Prompt.h"
#import "../SettingsKeys.h"


@interface SARootListController : SASettingsListController
@end

@implementation SARootListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

    return _specifiers;
}

- (void)loadView {
    [super loadView];
    presentFollowAlert(kPrefPath, self);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    id value = [super readPreferenceValue:specifier];

    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kEnabledMode]) {
        EnabledMode pickedMode = (EnabledMode)[value intValue];
        [self enableHomescreenSpecifiers:pickedMode];
    }

    return value;
}

- (void)preferenceValueChanged:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kEnabledMode]) {
        EnabledMode pickedMode = (EnabledMode)[value intValue];
        [self enableHomescreenSpecifiers:pickedMode];
    }
}

- (void)enableHomescreenSpecifiers:(EnabledMode)mode {
    BOOL homescreenEnabled = (mode != LockscreenMode);
    [self setEnabled:homescreenEnabled
        forSpecifier:[self specifierForID:kTintFolderIcons]];

    [self setEnabled:homescreenEnabled
        forSpecifier:[self specifierForID:kHideDockBackground]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

- (void)sendEmail {
    openURL([NSURL URLWithString:@"mailto:andreaskhenriksson@gmail.com?subject=SpringArtwork"]);
}

- (void)myTweaks {
    openURL([NSURL URLWithString:@"https://henrikssonbrothers.com/cydia/repo/packages.html"]);
}

- (void)followTwitter {
    openTwitter();
}

- (void)discordServer {
    openURL([NSURL URLWithString:@"https://discord.gg/qMc63e6"]);
}

- (void)iconCredits {
    openTwitterWithUsername(@"pupsicola_");
}

@end


// Colorful UISwitches
@interface PSSwitchTableCell : PSControlTableCell
- (id)initWithStyle:(int)style reuseIdentifier:(id)identifier specifier:(id)specifier;
@end

@interface SASwitchTableCell : PSSwitchTableCell
@end

@implementation SASwitchTableCell

- (id)initWithStyle:(int)style reuseIdentifier:(id)identifier specifier:(id)specifier {
    self = [super initWithStyle:style reuseIdentifier:identifier specifier:specifier];
    if (self)
        [((UISwitch *)[self control]) setOnTintColor:SAColor];
    return self;
}

@end


// Header
@interface SASettingsHeaderCell : PSTableCell {
    UILabel *_label;
}
@end

@implementation SASettingsHeaderCell
- (id)initWithSpecifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"headerCell" specifier:specifier];
    if (self) {
        _label = [[UILabel alloc] initWithFrame:[self frame]];
        [_label setTranslatesAutoresizingMaskIntoConstraints:NO];
        [_label setAdjustsFontSizeToFitWidth:YES];
        [_label setFont:[UIFont fontWithName:@"HelveticaNeue-UltraLight" size:48]];

        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"SpringArtwork"];

        [_label setAttributedText:attributedString];
        [_label setTextAlignment:NSTextAlignmentCenter];
        [_label setBackgroundColor:[UIColor clearColor]];

        [self addSubview:_label];
        [self setBackgroundColor:[UIColor clearColor]];

        // Setup constraints
        NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
        NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
        NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
        NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:_label attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
        [self addConstraints:[NSArray arrayWithObjects:leftConstraint, rightConstraint, bottomConstraint, topConstraint, nil]];
    }
    return self;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    // Return a custom cell height.
    return 140.f;
}

@end


@interface SAColorButtonCell : PSTableCell
@end


@implementation SAColorButtonCell

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.textLabel setTextColor:SAColor];
}

@end
