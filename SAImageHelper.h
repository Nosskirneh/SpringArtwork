@interface SAColorInfo : NSObject
@property (nonatomic, retain, readonly) UIColor *backgroundColor;
@property (nonatomic, retain, readonly) UIColor *textColor;
@property (nonatomic, retain, readonly) UIColor *primaryColor;
@property (nonatomic, retain, readonly) UIColor *secondaryColor;
@property (nonatomic, assign, readonly) BOOL hasDarkTextColor;
@end

@interface SAImageHelper : NSObject
+ (SAColorInfo *)colorsForImage:(UIImage *)image;
+ (SAColorInfo *)colorsForImage:(UIImage *)image
      withStaticBackgroundColor:(UIColor *)staticBackgroundColor;
+ (BOOL)colorIsLight:(UIColor *)color;
+ (UIColor *)lighterColorForColor:(UIColor *)color;
+ (UIColor *)darkerColorForColor:(UIColor *)color;
+ (BOOL)compareImage:(UIImage *)first withImage:(UIImage *)second;
+ (NSString *)imageToString:(UIImage *)image;
+ (UIImage *)stringToImage:(NSString *)string;
@end
