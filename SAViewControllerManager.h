#import "SAImageHelper.h"
#import "SAAnimatingViewController.h"

@protocol SAViewControllerManager
@property (nonatomic, retain, readonly) AVAsset *canvasAsset;
@property (nonatomic, retain, readonly) UIImage *canvasThumbnail;
@property (nonatomic, retain, readonly) UIImage *artworkImage;
@property (nonatomic, retain, readonly) UIImage *blurredImage;
@property (nonatomic, retain, readonly) SAColorInfo *colorInfo;
@property (nonatomic, assign, readonly) BOOL useBackgroundColor;
@property (nonatomic, retain) id<SAAnimatingViewController> inChargeController;
- (void)addNewViewController:(id<SAAnimatingViewController>)viewController;
- (void)removeViewController:(id<SAAnimatingViewController>)viewController;
- (void)videoEnded;
- (BOOL)isDirty;
- (BOOL)changedContent;
@end
