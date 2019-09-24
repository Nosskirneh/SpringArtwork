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
// iOS 11.3.1 and above
- (MPCFuture *)contentItemArtworkForContentItemIdentifier:(NSString *)identifier
                                        artworkIdentifier:(NSString *)artworkIdentifier
                                                     size:(CGSize)size;
// iOS 11.1.2 and below
- (MPCFuture *)contentItemArtworkForIdentifier:(NSString *)identifier
                                          size:(CGSize)size;
@end
