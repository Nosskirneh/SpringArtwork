@interface SAColorInfo : NSObject
@property (nonatomic, retain, readonly) UIColor *backgroundColor;
@property (nonatomic, retain, readonly) UIColor *textColor;
@property (nonatomic, retain, readonly) UIColor *primaryColor;
@property (nonatomic, retain, readonly) UIColor *secondaryColor;
@end

@interface SAColorHelper : NSObject
+ (SAColorInfo *)colorsForImage:(UIImage *)image;
+ (BOOL)compareImage:(UIImage *)first withImage:(UIImage *)second;
+ (NSString *)imageToString:(UIImage *)image;
+ (UIImage *)stringToImage:(NSString *)string;
@end
