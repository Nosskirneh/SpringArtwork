#import <SpringBoard/SBUserAgent.h>
#import <SpringBoard/SBApplication.h>

@interface SpringBoard (Processes)
- (SBUserAgent *)pluginUserAgent;
@end


@interface FBProcessState : NSObject
@property (assign, getter=isForeground, nonatomic) BOOL foreground;
@end

@interface SBApplicationProcessState : NSObject
@property (getter=isForeground, nonatomic, readonly) BOOL foreground;
@end


@interface SBApplication (Addition)
@property (retain) FBProcessState *processState; // iOS 10 and below
@property (setter=_setInternalProcessState:, getter=_internalProcessState, retain) SBApplicationProcessState *internalProcessState; // iOS 11 and above
@end
