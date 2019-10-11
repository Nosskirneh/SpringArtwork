#import "SASettingsListController.h"
#import "../../TwitterStuff/Prompt.h"


@interface SAArtworkListController : SASettingsListController
@end

@implementation SAArtworkListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Artwork" target:self];

    return _specifiers;
}

@end
