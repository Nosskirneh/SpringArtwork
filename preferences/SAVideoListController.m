#import "SASettingsListController.h"
#import "../../TwitterStuff/Prompt.h"


@interface SAVideoListController : SASettingsListController
@end

@implementation SAVideoListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Video" target:self];

    return _specifiers;
}

@end
