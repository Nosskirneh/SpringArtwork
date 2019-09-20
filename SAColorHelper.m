#import "SAColorHelper.h"

@interface SAColorInfo (Private)
+ (id)infoWithBackgroundColor:(UIColor *)backgroundColor
                 primaryColor:(UIColor *)primaryColor
               secondaryColor:(UIColor *)secondaryColor
       inverseBackgroundColor:(UIColor *)inverseBackgroundColor;
@end

@implementation SAColorInfo

+ (id)infoWithBackgroundColor:(UIColor *)backgroundColor
                 primaryColor:(UIColor *)primaryColor
               secondaryColor:(UIColor *)secondaryColor
       inverseBackgroundColor:(UIColor *)inverseBackgroundColor {
    return [[SAColorInfo alloc] infoWithBackgroundColor:backgroundColor
                                           primaryColor:primaryColor
                                         secondaryColor:secondaryColor
                                 inverseBackgroundColor:inverseBackgroundColor];
}

- (id)infoWithBackgroundColor:(UIColor *)backgroundColor
                 primaryColor:(UIColor *)primaryColor
               secondaryColor:(UIColor *)secondaryColor
       inverseBackgroundColor:(UIColor *)inverseBackgroundColor {
    if (self == [super init]) {
        _backgroundColor = backgroundColor;
        _primaryColor = primaryColor;
        _secondaryColor = secondaryColor;
        _inverseBackgroundColor = inverseBackgroundColor;
    }
    return self;
}

@end

// https://ideone.com/W4TVMn and
// https://stackoverflow.com/questions/15962893/determine-primary-and-secondary-colors-of-a-uiimage
@implementation SAColorHelper

+ (SAColorInfo *)colorsForImage:(UIImage *)image {
    const float dimension = 10;
    const float flexibility = 2;
    const float range = 60;
 
    // 2. Determine the colors in the image
    NSMutableArray *colors = [NSMutableArray new];
    CGImageRef imageRef = [image CGImage];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char *)calloc(dimension * dimension * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * dimension;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, dimension, dimension, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, dimension, dimension), imageRef);
    CGContextRelease(context);
 
    float x = 0;
    float y = 0;
    for (int n = 0; n < (dimension * dimension); n++) {
        int index = (bytesPerRow * y) + x * bytesPerPixel;
        int red   = rawData[index];
        int green = rawData[index + 1];
        int blue  = rawData[index + 2];
        int alpha = rawData[index + 3];
        [colors addObject:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%i", red],
                                                    [NSString stringWithFormat:@"%i", green],
                                                    [NSString stringWithFormat:@"%i", blue],
                                                    [NSString stringWithFormat:@"%i", alpha],
                                                    nil]];
        y++;
        if (y == dimension) {
            y = 0;
            x++;
        }
    }
    free(rawData);
 
    // 3. Add some color flexibility (adds more colors either side of the colors in the image)
    NSArray *copyColors = [NSArray arrayWithArray:colors];
    NSMutableArray *flexibleColors = [NSMutableArray new];
 
    float flexFactor = flexibility * 2 + 1;
    float factor = flexFactor * flexFactor * 3; //(r,g,b) == *3
    for (int n = 0; n < (dimension * dimension); n++) {
 
        NSArray *pixelColors = copyColors[n];
        NSMutableArray *reds = [NSMutableArray new];
        NSMutableArray *greens = [NSMutableArray new];
        NSMutableArray *blues = [NSMutableArray new];
 
        for (int p = 0; p < 3; p++) {
            NSString *rgbStr = pixelColors[p];
            int rgb = [rgbStr intValue];
 
            for (int f = -flexibility; f < flexibility + 1; f++) {
                int newRGB = rgb + f;
                if (newRGB < 0)
                    newRGB = 0;

                if (p == 0)
                    [reds addObject:[NSString stringWithFormat:@"%i",newRGB]];
                else if (p == 1)
                    [greens addObject:[NSString stringWithFormat:@"%i",newRGB]];
                else if (p == 2)
                    [blues addObject:[NSString stringWithFormat:@"%i",newRGB]];
            }
        }
 
        int r = 0;
        int g = 0;
        int b = 0;
        for (int k = 0; k < factor; k++) {
            int red = [reds[r] intValue];
            int green = [greens[g] intValue];
            int blue = [blues[b] intValue];
 
            NSString *rgbString = [NSString stringWithFormat:@"%i,%i,%i", red, green, blue];
            [flexibleColors addObject:rgbString];
 
            b++;
            if (b == flexFactor) {
                b = 0;
                g++;
            }
            if (g == flexFactor) {
                g=0;
                r++;
            }
        }
    }
 
    // 4. Distinguish the colors
    //    Orders the flexible colors by their occurrence
    //    then keeps them if they are sufficiently disimilar
 
    NSMutableDictionary *colorCounter = [NSMutableDictionary new];
 
    //count the occurences in the array
    NSCountedSet *countedSet = [[NSCountedSet alloc] initWithArray:flexibleColors];
    for (NSString *item in countedSet) {
        NSUInteger count = [countedSet countForObject:item];
        [colorCounter setValue:[NSNumber numberWithInteger:count] forKey:item];
    }
 
    // Sort keys highest occurrence to lowest
    NSArray *orderedKeys = [colorCounter keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj2 compare:obj1];
    }];
 
    // Checks if the color is similar to another one already included
    NSMutableArray *ranges = [NSMutableArray new];
    for (NSString *key in orderedKeys) {
        NSArray *rgb = [key componentsSeparatedByString:@","];
        int r = [rgb[0] intValue];
        int g = [rgb[1] intValue];
        int b = [rgb[2] intValue];
        bool exclude = NO;
        for (NSString *ranged_key in ranges) {
            NSArray *ranged_rgb = [ranged_key componentsSeparatedByString:@","];
 
            int ranged_r = [ranged_rgb[0] intValue];
            int ranged_g = [ranged_rgb[1] intValue];
            int ranged_b = [ranged_rgb[2] intValue];
 
            if ((r >= ranged_r - range && r <= ranged_r + range) &&
                (g >= ranged_g - range && g <= ranged_g + range) &&
                (b >= ranged_b - range && b <= ranged_b + range))
                exclude = YES;
        }
 
        if (!exclude)
            [ranges addObject:key];
    }
 
    NSMutableArray *colorArray = [NSMutableArray new];
    for (NSString *key in ranges) {
        NSArray *rgb = [key componentsSeparatedByString:@","];
        float r = [rgb[0] floatValue];
        float g = [rgb[1] floatValue];
        float b = [rgb[2] floatValue];
        UIColor *color = [UIColor colorWithRed:(r / 255.0f) green:(g / 255.0f) blue:(b / 255.0f) alpha:1.0f];
        [colorArray addObject:color];
    }

    UIColor *backgroundColor = colorArray[0];
    UIColor *primaryColor = nil;
    UIColor *secondaryColor = nil;
    if (colorArray.count > 1) {
        primaryColor = colorArray[1];
        if (colorArray.count > 2)
            secondaryColor = colorArray[2];
    }
    UIColor *inverseBackgroundColor = [self inverseColor:backgroundColor];

    return [SAColorInfo infoWithBackgroundColor:backgroundColor
                                   primaryColor:primaryColor
                                 secondaryColor:secondaryColor
                         inverseBackgroundColor:inverseBackgroundColor];
}


+ (UIColor *)inverseColor:(UIColor *)color {
    CGFloat alpha;

    CGFloat white;
    if ([color getWhite:&white alpha:&alpha])
        return [UIColor colorWithWhite:1.0 - white alpha:alpha];

    CGFloat hue, saturation, brightness;
    if ([color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha])
        return [UIColor colorWithHue:1.0 - hue saturation:1.0 - saturation brightness:1.0 - brightness alpha:alpha];

    CGFloat red, green, blue;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha])
        return [UIColor colorWithRed:1.0 - red green:1.0 - green blue:1.0 - blue alpha:alpha];

    return nil;
}

@end
