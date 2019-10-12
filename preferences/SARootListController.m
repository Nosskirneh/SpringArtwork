#import <Preferences/Preferences.h>
#import "SASettingsListController.h"
#import <UIKit/UITableViewLabel.h>
#import "../Common.h"
#import "../DRMOptions.mm"
#import "../../DRM/PFStatusBarAlert/PFStatusBarAlert.h"
#import "../../TwitterStuff/Prompt.h"
#import "../SettingsKeys.h"


@interface SARootListController : SASettingsListController <PFStatusBarAlertDelegate, DRMDelegate>
@property (nonatomic, strong) PFStatusBarAlert *statusAlert;
@property (nonatomic, weak) UIAlertAction *okAction;
@property (nonatomic, weak) NSString *okRegex;
@property (nonatomic, strong) UIAlertController *giveawayAlertController;
@end

@interface PSSegmentTableCell : PSControlTableCell 
- (void)setValue:(id)value;
@end

@implementation SARootListController

- (id)init {
    if (self == [super init]) {
        UIBarButtonItem *respringButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(respring)];
        self.navigationItem.rightBarButtonItem = respringButton;
    }

    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

    // Add license specifier
    NSMutableArray *mspecs = (NSMutableArray *)[_specifiers mutableCopy];
    _specifiers = addDRMSpecifiers(mspecs, self, licensePath$bs(), kPrefPath, package$bs(), licenseFooterText$bs(), trialFooterText$bs());

    return _specifiers;
}

- (void)loadView {
    [super loadView];
    presentFollowAlert(kPrefPath, self);
}

- (void)respring {
    respring(NO);
}

- (void)activate {
    activate(licensePath$bs(), package$bs(), self);
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    [self textFieldChanged:textField];
    return YES;
}

- (void)textFieldChanged:(UITextField *)textField {
    determineUnlockOKButton(textField, self);
}

- (void)trial {
    trial(licensePath$bs(), package$bs(), self);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:kKey];
    if ([key isEqualToString:kEnabledMode]) {
        UIAlertAction *respringAction = [UIAlertAction actionWithTitle:@"Yes"
                                                                 style:UIAlertActionStyleDestructive
                                                               handler:^(UIAlertAction *action) {
                                            [super setPreferenceValue:value specifier:specifier];
                                            respring(NO);
                                        }];

        UIAlertAction *laterAction = [UIAlertAction actionWithTitle:@"I'll respring later"
                                                              style:UIAlertActionStyleDestructive
                                                            handler:nil];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Revert change"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:^(UIAlertAction *action) {
                                            NSIndexPath *indexPath = [self indexPathForSpecifier:specifier];
                                            PSSegmentTableCell *cell = [self tableView:self.table cellForRowAtIndexPath:indexPath];

                                            NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
                                            EnabledMode mode = preferences && preferences[kEnabledMode] ? (EnabledMode)[preferences[kEnabledMode] intValue] :
                                                                                                          BothMode;
                                            [cell setValue:@(mode)];
                                        }];
        [super presentAlertWithTitle:@"Restart of SpringBoard"
                             message:@"Changing this setting requires SpringBoard to be restarted. Do you wish to proceed?"
                             actions:@[respringAction, cancelAction, laterAction]];
        return;
    }
    [super setPreferenceValue:value specifier:specifier];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!self.statusAlert) {
        self.statusAlert = [[PFStatusBarAlert alloc] initWithMessage:nil
                                                        notification:nil
                                                              action:@selector(respring)
                                                              target:self];
        self.statusAlert.backgroundColor = [UIColor colorWithHue:0.590 saturation:1 brightness:1 alpha:0.9];
        self.statusAlert.textColor = [UIColor whiteColor];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    if (self.statusAlert)
        [self.statusAlert hideOverlay];
}

- (void)sendEmail {
    openURL([NSURL URLWithString:@"mailto:andreaskhenriksson@gmail.com?subject=SpringArtwork"]);
}

- (void)purchase {
    fetchPrice(package$bs(), self, ^(const NSString *respondingServer, const NSString *price, const NSString *URL) {
        redirectToCheckout(respondingServer, URL, self);
    });
}

- (void)myTweaks {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://henrikssonbrothers.com/cydia/repo/packages.html"]];
}

- (void)safariViewControllerDidFinish:(id)arg1 {
    safariViewControllerDidFinish(self);
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
