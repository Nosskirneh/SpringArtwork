@interface SAColorInfo : NSObject
@property (nonatomic, retain, readonly) UIColor *background;
@property (nonatomic, retain, readonly) UIColor *primary;
@property (nonatomic, retain, readonly) UIColor *secondary;
@end

typedef enum SAColorEdge {
    Top,
    Left,
    Bottom,
    Right
} SAColorEdge;

@interface SAColorHelper : NSObject
+ (SAColorInfo *)colorsForImage:(UIImage *)image edge:(SAColorEdge)edge;
@end
