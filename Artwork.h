@interface _MRNowPlayingClientProtobuf
@property (nonatomic, retain) NSString *bundleIdentifier;
@end


@interface MRContentItem : NSObject
- (NSDictionary *)dictionaryRepresentation;
@end

@interface MPCPlayerPath : NSObject
+ (id)deviceActivePlayerPath;
@end

@interface MPCFuture : NSObject
- (MPCFuture *)onCompletion:(void (^)(id))completion;
@end

@interface MPCMediaRemoteController : NSObject
+ (MPCFuture *)controllerForPlayerPath:(MPCPlayerPath *)path;
- (MPCFuture *)contentItemArtworkForContentItemIdentifier:(NSString *)identifier artworkIdentifier:(NSString *)artworkIdentifier size:(CGSize)size;
@end
