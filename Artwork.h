#import <MediaPlayer/MediaPlayer.h>

@interface MPArtworkCatalog : NSObject
@property (nonatomic, readonly) BOOL hasImageOnDisk;
@property (assign, nonatomic) double destinationScale;
@property (assign, nonatomic) CGSize fittingSize;
- (id)bestImageFromDisk;
- (void)requestImageWithCompletionHandler:(id)arg1;
@end

typedef MPArtworkCatalog *(^block)(void);

@interface MPMusicPlayerController (Addition)
- (id)nowPlayingItemAtIndex:(NSUInteger)arg1;
@end

@interface MPModelObjectMediaItem : MPMediaItem
@property (nonatomic, readonly) id modelObject;
@end

@interface MPModelSong : NSObject
- (id)valueForModelKey:(id)aa;
@end
