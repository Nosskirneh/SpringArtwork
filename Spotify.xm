#import "Spotify.h"
#import "Common.h"
#import <notify.h>
#import <AVFoundation/AVAsset.h>
#import "SASPTService.h"
#import <HBLog.h>

#define SERVICE_CLASS %c(SASPTService)

static NSDictionary *_addSAServiceToClassScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes,
                                                id classObject) {
    NSMutableDictionary *newScopes = [scopes mutableCopy];
    NSMutableArray *newSessionArray = [newScopes[@"session"] mutableCopy];
    [newSessionArray addObject:classObject];
    newScopes[@"session"] = newSessionArray;
    return newScopes;
}

static NSDictionary *addSAServiceToClassNamesScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes) {
    return _addSAServiceToClassScopes(scopes, NSStringFromClass(SERVICE_CLASS));
}

static NSDictionary *addSAServiceToClassScopes(NSDictionary<NSString *, NSArray<NSString *> *> *scopes) {
    return _addSAServiceToClassScopes(scopes, SERVICE_CLASS);
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
- (NSArray *)initWithScopeGraph:(id)graph serviceClassesByScope:(NSDictionary<NSString *, NSArray<NSString *> *> *)scopes {
    return %orig(graph, addSAServiceToClassScopes(scopes));
}
%end

%end


static inline BOOL initServiceSystem(Class serviceListClass) {
    if (serviceListClass) {
        if ([serviceListClass instancesRespondToSelector:@selector(initWithScopeGraph:serviceClassesByScope:)]) {
            %init(SPTServiceSystem_864, SPTServiceList = serviceListClass);
        } else {
            %init(SPTServiceSystem, SPTServiceList = serviceListClass);
        }
        return YES;
    }
    return NO;
}


%group AppDelegate
%hook AppDelegate

- (NSArray *)sessionServices {
    NSArray *orig = %orig;
    if (!orig) {
        return @[SERVICE_CLASS];
    }

    NSMutableArray *newArray = [orig mutableCopy];
    [newArray addObject:SERVICE_CLASS];
    return newArray;
}

%end
%end


%hookf(int, UIApplicationMain, int argc, char *_Nullable *argv, NSString *principalClassName, NSString *delegateClassName) {
    Class Delegate = NSClassFromString(delegateClassName);
    if ([Delegate instancesRespondToSelector:@selector(sessionServices)]) {
        %init(AppDelegate, AppDelegate = Delegate);
    } else {
        Class SpotifyServiceList = objc_getClass("SPTClientServices.SpotifyServiceList");
        if (SpotifyServiceList && [SpotifyServiceList respondsToSelector:@selector(setSessionServices:)]) {
            NSArray *sessionServices = [SpotifyServiceList sessionServices]();
            [SpotifyServiceList setSessionServices:^{
                NSMutableArray *newSessionServicesArray = [sessionServices mutableCopy];
                [newSessionServicesArray addObject:SERVICE_CLASS];
                return newSessionServicesArray;
            }];
        }
    }

    return %orig;
}


%ctor {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSNumber *canvasEnabled = preferences[kCanvasEnabled];

    if (isSpotify(bundleID) && (!canvasEnabled || [canvasEnabled boolValue])) {
        %init;

        if (!initServiceSystem(%c(SPTServiceList)) &&
            !initServiceSystem(objc_getClass("SPTServiceSystem.SPTServiceList"))) {
            %init(SPTDictionaryBasedServiceList);
        }
    }
}
