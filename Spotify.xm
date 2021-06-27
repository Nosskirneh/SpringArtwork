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

- (id)initWithScopeGraph:(id)graph
   serviceClassesByScope:(NSDictionary<NSString *, NSArray<NSString *> *> *)scopes {
    return %orig(graph, addSAServiceToClassScopes(scopes));
}

%end
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


void (*orig_UIApplicationMain)(int, char **, NSString *, NSString *);
void hooked_UIApplicationMain(int argc,
                              char *_Nullable *argv,
                              NSString *principalClassName,
                              NSString *delegateClassName) {
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

    return orig_UIApplicationMain(argc, argv, principalClassName, delegateClassName);
}


%ctor {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    NSNumber *canvasEnabled = preferences[kCanvasEnabled];

    if (isSpotify(bundleID) && (!canvasEnabled || [canvasEnabled boolValue])) {
        MSHookFunction(((void *)MSFindSymbol(NULL, "_UIApplicationMain")),
                       (void *)hooked_UIApplicationMain, (void **)&orig_UIApplicationMain);

        if (!initServiceSystem(%c(SPTServiceList)) &&
            !initServiceSystem(objc_getClass("SPTServiceSystem.SPTServiceList"))) {
            %init(SPTDictionaryBasedServiceList);
        }
    }
}
