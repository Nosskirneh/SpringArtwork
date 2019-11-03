#import "SAImageHelper.h"

@interface SAColorInfo (Private)
+ (id)infoWithBackgroundColor:(UIColor *)backgroundColor
                 primaryColor:(UIColor *)primaryColor
               secondaryColor:(UIColor *)secondaryColor
                    textColor:(UIColor *)textColor;
@end

@implementation SAColorInfo

+ (id)infoWithBackgroundColor:(UIColor *)backgroundColor
                 primaryColor:(UIColor *)primaryColor
               secondaryColor:(UIColor *)secondaryColor
                    textColor:(UIColor *)textColor {
    return [[SAColorInfo alloc] infoWithBackgroundColor:backgroundColor
                                           primaryColor:primaryColor
                                         secondaryColor:secondaryColor
                                              textColor:textColor];
}

- (id)infoWithBackgroundColor:(UIColor *)backgroundColor
                 primaryColor:(UIColor *)primaryColor
               secondaryColor:(UIColor *)secondaryColor
                    textColor:(UIColor *)textColor {
    if (self == [super init]) {
        _backgroundColor = backgroundColor;
        _primaryColor = primaryColor;
        _secondaryColor = secondaryColor;
        _textColor = textColor;

        _hasDarkTextColor = ![SAImageHelper colorIsLight:textColor];
    }
    return self;
}

@end

typedef union {
    uint32_t raw;
    unsigned char bytes[4];
    struct {
        char red;
        char green;
        char blue;
        char alpha;
    } __attribute__((packed)) pixels;
} ComparePixel;

// https://ideone.com/W4TVMn and
// https://stackoverflow.com/questions/15962893/determine-primary-and-secondary-colors-of-a-uiimage
@implementation SAImageHelper

+ (SAColorInfo *)colorsForImage:(UIImage *)image {
    return [self colorsForImage:image withStaticBackgroundColor:nil];
}

+ (SAColorInfo *)colorsForImage:(UIImage *)image
      withStaticBackgroundColor:(UIColor *)staticBackgroundColor {
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
    CGContextRef context = CGBitmapContextCreate(rawData, dimension, dimension, bitsPerComponent, bytesPerRow,
                                                 colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
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
    float factor = flexFactor * flexFactor * 3; // (r, g, b) => * 3
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
 
    // Count the occurences in the array
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

    UIColor *backgroundColor = staticBackgroundColor ? staticBackgroundColor : colorArray[0];
    UIColor *primaryColor = nil;
    UIColor *secondaryColor = nil;
    if (colorArray.count > 1) {
        primaryColor = colorArray[1];
        if (colorArray.count > 2)
            secondaryColor = colorArray[2];
    }
    UIColor *textColor = [self labelColorForBackgroundColor:backgroundColor];

    return [SAColorInfo infoWithBackgroundColor:backgroundColor
                                   primaryColor:primaryColor
                                 secondaryColor:secondaryColor
                                      textColor:textColor];
}

+ (NSString *)imageToString:(UIImage *)image {
    NSData *data = UIImagePNGRepresentation(image);
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}

+ (UIImage *)stringToImage:(NSString *)string {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters];
    return [UIImage imageWithData:data];
}

+ (BOOL)colorIsLight:(UIColor *)color {
    CGFloat colorBrightness = 0;
    CGColorSpaceRef colorSpace = CGColorGetColorSpace(color.CGColor);
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);

    if (colorSpaceModel == kCGColorSpaceModelRGB){
        const CGFloat *componentColors = CGColorGetComponents(color.CGColor);
        colorBrightness = ((componentColors[0] * 299) + (componentColors[1] * 587) + (componentColors[2] * 114)) / 1000;
    } else {
        [color getWhite:&colorBrightness alpha:0];
    }

    return colorBrightness >= .5f;
}

+ (UIColor *)lighterColorForColor:(UIColor *)color {
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a])
        return [UIColor colorWithRed:MIN(r + 0.2, 1.0)
                               green:MIN(g + 0.2, 1.0)
                                blue:MIN(b + 0.2, 1.0)
                               alpha:a];
    return nil;
}

+ (UIColor *)darkerColorForColor:(UIColor *)color {
    CGFloat r, g, b, a;
    if ([color getRed:&r green:&g blue:&b alpha:&a])
        return [UIColor colorWithRed:MAX(r - 0.2, 0.0)
                               green:MAX(g - 0.2, 0.0)
                                blue:MAX(b - 0.2, 0.0)
                               alpha:a];
    return nil;
}

+ (UIColor *)labelColorForBackgroundColor:(UIColor *)color {
    return [self colorIsLight:color] ? UIColor.blackColor : UIColor.whiteColor;
}

+ (BOOL)compareImage:(UIImage *)first withImage:(UIImage *)second {
    if (first.size.width != second.size.width) {
        // Transform into the same size, and compare them with higher tolerance
        if (first.size.width > second.size.width)
            first = [self imageWithImage:first scaledToSize:second.size];
        else
            second = [self imageWithImage:second scaledToSize:first.size];
    }

    return [self compareImage:first withImage:second tolerance:0.1];
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    /* In next line, pass 0.0 to use the current device's pixel scaling factor
       (and thus account for Retina resolution). Pass 1.0 to force exact pixel size. */
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

+ (BOOL)compareImage:(UIImage *)first
           withImage:(UIImage *)second
           tolerance:(CGFloat)tolerance {
    if (!CGSizeEqualToSize(first.size, second.size))
        return NO;

    CGSize firstImageSize = CGSizeMake(CGImageGetWidth(first.CGImage), CGImageGetHeight(first.CGImage));
    CGSize secondImageSize = CGSizeMake(CGImageGetWidth(second.CGImage), CGImageGetHeight(second.CGImage));

    // The images have the equal size, so we could use the smallest amount of bytes because of byte padding
    size_t minBytesPerRow = MIN(CGImageGetBytesPerRow(first.CGImage), CGImageGetBytesPerRow(second.CGImage));

    size_t firstImageSizeBytes = firstImageSize.height * minBytesPerRow;
    void *firstImagePixels = calloc(1, firstImageSizeBytes);
    void *secondImagePixels = calloc(1, firstImageSizeBytes);

    if (!firstImagePixels || !secondImagePixels) {
        free(firstImagePixels);
        free(secondImagePixels);
        return NO;
    }

    CGContextRef firstImageContext = CGBitmapContextCreate(firstImagePixels,
                                                           firstImageSize.width,
                                                           firstImageSize.height,
                                                           CGImageGetBitsPerComponent(first.CGImage),
                                                           minBytesPerRow,
                                                           CGImageGetColorSpace(first.CGImage),
                                                           (CGBitmapInfo)kCGImageAlphaPremultipliedLast);

    CGContextRef secondimageContext = CGBitmapContextCreate(secondImagePixels,
                                                            secondImageSize.width,
                                                            secondImageSize.height,
                                                            CGImageGetBitsPerComponent(second.CGImage),
                                                            minBytesPerRow,
                                                            CGImageGetColorSpace(second.CGImage),
                                                            (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    if (!firstImageContext || !secondimageContext) {
        CGContextRelease(firstImageContext);
        CGContextRelease(secondimageContext);
        free(firstImagePixels);
        free(secondImagePixels);
        return NO;
    }

    CGContextDrawImage(firstImageContext, CGRectMake(0, 0, firstImageSize.width, firstImageSize.height), first.CGImage);
    CGContextDrawImage(secondimageContext, CGRectMake(0, 0, secondImageSize.width, secondImageSize.height), second.CGImage);

    CGContextRelease(firstImageContext);
    CGContextRelease(secondimageContext);

    BOOL imageEqual = NO;

    // Do a fast compare if we can
    if (tolerance == 0) {
        imageEqual = memcmp(firstImagePixels, secondImagePixels, firstImageSizeBytes) == 0;
    } else {
        // Go through each pixel in turn and see if it is different
        const NSInteger pixelCount = firstImageSize.width * firstImageSize.height;

        ComparePixel *p1 = firstImagePixels;
        ComparePixel *p2 = secondImagePixels;

        NSInteger numDiffPixels = 0;
        NSInteger numMatchedPixels = 0;
        const int checkTotal = 1500;
        const long step = pixelCount / checkTotal;

        NSInteger weightedDiffIncrement = 1;
        NSInteger weightedMatchIncrement = 1;

        for (int n = 0; n < pixelCount; n += step) {
            // If this pixel is different, increment the pixel diff count and see
            // if we have hit our limit.
            if (p1->raw != p2->raw) {
                numDiffPixels++;
                weightedDiffIncrement *= 2;
                weightedMatchIncrement = 1;

                CGFloat diffPercent = (CGFloat)(numDiffPixels + weightedDiffIncrement - 1) / checkTotal;
                #ifdef DEBUG
                HBLogDebug(@"[pixel %d/%ld]: numDiffPixels: %ld (+%ld), diffPercent: %f, tolerance: %f",
                           n, (long)pixelCount, (long)numDiffPixels, (long)weightedDiffIncrement, diffPercent, tolerance);
                #endif
                if (diffPercent > tolerance) {
                    imageEqual = NO;
                    break;
                }
            } else {
                numMatchedPixels++;
                weightedMatchIncrement *= 2;
                weightedDiffIncrement = 1;

                // If we have a match percentage already higher than the tolerance, return here
                CGFloat currentlyMatchedPercentage = (CGFloat)(numMatchedPixels + weightedMatchIncrement - 1) / step;
                #ifdef DEBUG
                HBLogDebug(@"[pixel %d/%ld]: numMatchedPixels: %ld (+%ld), currentlyMatchedPercentage: %f, tolerance: %f",
                           n, (long)pixelCount, (long)numMatchedPixels, (long)weightedMatchIncrement, currentlyMatchedPercentage, tolerance);
                #endif
                if (currentlyMatchedPercentage > tolerance) {
                    imageEqual = YES;
                    break;
                }
            }

            p1 += step;
            p2 += step;
        }
    }

    free(firstImagePixels);
    free(secondImagePixels);

    #ifdef DEBUG
    HBLogDebug(@"imageEqual: %d", imageEqual);
    #endif
    return imageEqual;
}

@end
