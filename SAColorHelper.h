@interface SAColorInfo : NSObject
@property (nonatomic, retain, readonly) UIColor *backgroundColor;
@property (nonatomic, retain, readonly) UIColor *textColor;
@property (nonatomic, retain, readonly) UIColor *primaryColor;
@property (nonatomic, retain, readonly) UIColor *secondaryColor;
@end

@interface SAColorHelper : NSObject
+ (SAColorInfo *)colorsForImage:(UIImage *)image;
@end
