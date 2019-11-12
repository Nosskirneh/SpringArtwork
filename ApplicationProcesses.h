#import <SpringBoard/SBUserAgent.h>
#import <SpringBoard/SBApplication.h>

@interface SpringBoard : NSObject
- (SBUserAgent *)pluginUserAgent;
@end


typedef enum ProcessVisiblity {
    Unknown = 0,
    Background = 1,
    Foreground = 2,
    ForegroundObscured = 3
} ProcessVisiblity;

@protocol ProcessStateInfo
@property (getter=isForeground, nonatomic, readonly) BOOL foreground;
@property (nonatomic, readonly) ProcessVisiblity visibility;
@end


@interface FBProcessState : NSObject<ProcessStateInfo>
@end

@interface SBApplicationProcessState : NSObject<ProcessStateInfo>
@end


@interface SBApplication (Addition)
@property (retain) FBProcessState *processState; // iOS 10 and below
@property (setter=_setInternalProcessState:, getter=_internalProcessState, retain) SBApplicationProcessState *internalProcessState; // iOS 11 and above
@end
