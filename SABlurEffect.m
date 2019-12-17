#import "SABlurEffect.h"
#import <objc/runtime.h>

@interface _UIBackdropViewSettings : NSObject
@end

@interface UIVisualEffect (Addition)
@property (nonatomic, readonly) _UIBackdropViewSettings *effectSettings;
@end

@implementation SABlurEffect

+ (instancetype)effectWithStyle:(UIBlurEffectStyle)style
                     blurRadius:(NSNumber *)blurRadius {
    SABlurEffect *effect = (SABlurEffect *)[self effectWithStyle:style];
    effect.blurRadius = blurRadius;
    object_setClass(effect, self);

    return effect;
}

- (_UIBackdropViewSettings *)effectSettings {
    _UIBackdropViewSettings *settings = [super effectSettings];
    [settings setValue:_blurRadius forKey:@"blurRadius"];
    return settings;
}

- (id)copyWithZone:(NSZone *)zone {
    id result = [super copyWithZone:zone];
    object_setClass(result, [self class]);
    return result;
}

@end
