#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

@interface SAManager : NSObject

@property (nonatomic, assign) BOOL enabled;

+ (instancetype)sharedManager;

- (void)toggleEnabled;
- (void)setEnabled:(BOOL)enabled;

@end

@interface SpringArtworkFlipswitchSwitch : NSObject <FSSwitchDataSource>
@end

@implementation SpringArtworkFlipswitchSwitch

- (NSString *)titleForSwitchIdentifier:(NSString *)switchIdentifier {
    return @"SpringArtwork";
}

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier {
    return (FSSwitchState)((SAManager *)[%c(SAManager) sharedManager]).enabled;
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier {
    [((SAManager *)[%c(SAManager) sharedManager]) toggleEnabled];
}

@end
