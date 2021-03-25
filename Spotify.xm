#import "Spotify.h"
#import "Common.h"
#import <notify.h>
#import <AVFoundation/AVAsset.h>
#import "SASPTService.h"

static NSDictionary *_addSAServiceToClassScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes,
                                                id classObject) {
    NSMutableDictionary *newScopes = [scopes mutableCopy];
    NSMutableArray *newSessionArray = [newScopes[@"session"] mutableCopy];
    [newSessionArray addObject:classObject];
    newScopes[@"session"] = newSessionArray;
    return newScopes;
}

static NSDictionary *addSAServiceToClassNamesScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes) {
    return _addSAServiceToClassScopes(scopes, NSStringFromClass(%c(SASPTService)));
}

static NSDictionary *addSAServiceToClassScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes) {
    return _addSAServiceToClassScopes(scopes, %c(SASPTService));
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

%group SPTServiceSystem_864
%hook SPTServiceList

- (id)initWithScopeGraph:(id)graph
   serviceClassesByScope:(NSDictionary<NSString *, NSArray<NSString *> *> *)scopes {
    return %orig(graph, addSAServiceToClassScopes(scopes));
}

%end
%end


%hook AppDelegate

- (NSArray *)sessionServices {
    NSArray *orig = %orig;
    if (!orig) {
        return @[%c(SASPTService)];
    }

    NSMutableArray *newArray = [orig mutableCopy];
    [newArray addObject:%c(SASPTService)];
    return newArray;
}

%end


static inline BOOL initServiceSystem(Class serviceListClass) {
    if (serviceListClass) {
        if ([serviceListClass instancesRespondToSelector:@selector(initWithScopeGraph:serviceClassesByScope:)]) {
            %init(SPTServiceSystem_864);
        } else {
            %init(SPTServiceSystem, SPTServiceList = serviceListClass);
        }
        return YES;
    }
    return NO;
}

%ctor {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSNumber *canvasEnabled = preferences[kCanvasEnabled];

    if (isSpotify(bundleID) && (!canvasEnabled || [canvasEnabled boolValue])) {
        Class AppDelegateClass = objc_getClass("AppKernelFeature.AppDelegate");
        if ([AppDelegateClass instancesRespondToSelector:@selector(sessionServices)]) {
            %init(AppDelegate = AppDelegateClass);
        } else if (!initServiceSystem(%c(SPTServiceList)) &&
                   !initServiceSystem(objc_getClass("SPTServiceSystem.SPTServiceList"))) {
            %init(SPTDictionaryBasedServiceList);
        }
    }
}
