#import "Spotify.h"
#import "Common.h"
#import <notify.h>
#import <AVFoundation/AVAsset.h>
#import "SASPTService.h"

static NSDictionary *addSAServiceToClassNamesScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes) {
    NSMutableDictionary *newScopes = [scopes mutableCopy];
    NSMutableArray *newSessionArray = [newScopes[@"session"] mutableCopy];
    [newSessionArray addObject:NSStringFromClass(%c(SASPTService))];
    newScopes[@"session"] = newSessionArray;
    return newScopes;
}

%group SPTDictionaryBasedServiceList
%hook SPTDictionaryBasedServiceList

- (id)initWithClassNamesByScope:(NSDictionary<NSString *, NSArray<NSString *> *> *)scopes
                   scopeParents:(NSDictionary *)scopeParents {
    return %orig(addSAServiceToClassNamesScopes(scopes), scopeParents);
}

%end
%end


%group SPTServiceSystem
%hook SPTServiceList

- (id)initWithScopes:(NSDictionary<NSString *, NSArray<NSString *> *> *)scopes
        scopeParents:(NSDictionary *)scopeParents {
    return %orig(addSAServiceToClassNamesScopes(scopes), scopeParents);
}

%end
%end


static inline BOOL initServiceSystem(Class serviceListClass) {
    if (serviceListClass) {
        %init(SPTServiceSystem, SPTServiceList = serviceListClass);
        return YES;
    }
    return NO;
}

%ctor {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSNumber *canvasEnabled = preferences[kCanvasEnabled];

    if (isSpotify(bundleID) && (!canvasEnabled || [canvasEnabled boolValue])) {
        if (!initServiceSystem(%c(SPTServiceList)) &&
            !initServiceSystem(objc_getClass("SPTServiceSystem.SPTServiceList"))) {
            %init(SPTDictionaryBasedServiceList);
        }
    }
}
