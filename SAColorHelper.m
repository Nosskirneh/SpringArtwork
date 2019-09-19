#import "SAColorHelper.h"

// https://stackoverflow.com/questions/15962893/determine-primary-and-secondary-colors-of-a-uiimage

@interface SAColorInfo (Private)
+ (id)infoWithBackground:(UIColor *)background primary:(UIColor *)primary secondary:(UIColor *)secondary;
- (id)infoWithBackground:(UIColor *)background primary:(UIColor *)primary secondary:(UIColor *)secondary;
@end

@implementation SAColorInfo

+ (id)infoWithBackground:(UIColor *)background primary:(UIColor *)primary secondary:(UIColor *)secondary {
    return [[SAColorInfo alloc] infoWithBackground:background primary:primary secondary:secondary];
}

- (id)infoWithBackground:(UIColor *)background primary:(UIColor *)primary secondary:(UIColor *)secondary {
    if (self == [super init]) {
        _background = background;
        _primary = primary;
        _secondary = secondary;
    }
    return self;
}

@end

@interface Color : NSObject
@property int r, g, b, d;
@end

@implementation Color
@end


@interface SAColorHelper (Private)
+ (float)contrastValueFor:(Color *)a andB:(Color *)b;
+ (float)saturationValueFor:(Color *)a andB:(Color *)b;
+ (int)colorDistance:(Color *)a andB:(Color *)b;
@end

@implementation SAColorHelper

+ (SAColorInfo *)colorsForImage:(UIImage *)image edge:(SAColorEdge)edge {
    // 1. Set vars
    float dimension = 20;

    // 2. Resize image and grab raw data.
    // This part pulls the raw data from the image
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

    // 3. Create color array
    NSMutableArray *colors = [NSMutableArray new];
    float x = 0, y = 0; // Used to set coordinates
    float eR = 0, eB = 0, eG = 0; // Used for mean edge color
    for (int n = 0; n < (dimension * dimension); n++) {

        Color *c = [Color new]; // Create color
        int i = (bytesPerRow * y) + x * bytesPerPixel; // Pull index
        c.r = rawData[i]; // Set red
        c.g = rawData[i + 1]; // Set green
        c.b = rawData[i + 2]; // Set blue
        [colors addObject:c]; // Add color

        // Add to edge if true
        if ((edge == Top && y == 0) || // Top
            (edge == Left && x == 0) || // Left
            (edge == Bottom && y == dimension - 1) || // Bottom
            (edge == Right && x == dimension - 1)) { // Right
            eR += c.r;
            eG += c.g;
            eB += c.b; // Add the colors
        }

        // Update pixel coordinate
        x = (x == dimension - 1) ? 0 : x + 1;
        y = (x == 0) ? y + 1 : y;
    }
    free(rawData);

    // 4. Calculate edge color
    Color *e = [Color new];
    e.r = eR / dimension;
    e.g = eG / dimension;
    e.b = eB / dimension;

    // 5. Calculate the frequency of color
    NSMutableArray * accents = [NSMutableArray new]; // Holds valid accents

    float minContrast = 3.1; // Play with this value
    while (accents.count < 3) { // Minimum number of accents
        for (Color *a in colors) {

            // HBLogDebug(@"contrast value is %f", [self contrastValueFor:a andB:e]);

            // 5.1. Ignore if it does not contrast with edge
            if ([self contrastValueFor:a andB:e] < minContrast)
                continue;

            // 5.2. Set distance (frequency)
            for (Color *b in colors)
                a.d += [self colorDistance:a andB:b];

            // 5.3. Add color to accents
            [accents addObject:a];
        }

        minContrast -= 0.1f;
    }

    // 6. Sort colors by the most common
    NSArray *sorted = [[NSArray arrayWithArray:accents] sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"d" ascending:true]]];

    // 6.1. Set primary color (most common)
    Color *p = sorted[0];

    // 7. Get most contrasting color
    float high = 0.0f; // The high
    int index = 0; // The index
    for (int n = 1; n < sorted.count; n++) {
        Color * c = sorted[n];
        float contrast = [self contrastValueFor:c andB:p];
        // float sat = [self saturationValueFor:c andB:p];

        if (contrast > high) {
            high = contrast;
            index = n;
        }
    }
    // 7.1. Set secondary color (most contrasting)
    Color *s = sorted[index];

    // HBLogDebug(@"er %i eg %i eb %i", e.r, e.g, e.b);
    // HBLogDebug(@"pr %i pg %i pb %i", p.r, p.g, p.b);
    // HBLogDebug(@"sr %i sg %i sb %i", s.r, s.g, s.b);

    return [SAColorInfo infoWithBackground:[UIColor colorWithRed:e.r / 255.0f green:e.g / 255.0f blue:e.b / 255.0f alpha:1.0f]
                                   primary:[UIColor colorWithRed:p.r / 255.0f green:p.g / 255.0f blue:p.b / 255.0f alpha:1.0f]
                                 secondary:[UIColor colorWithRed:s.r / 255.0f green:s.g / 255.0f blue:s.b / 255.0f alpha:1.0f]];
}

+ (float)contrastValueFor:(Color *)a andB:(Color *)b {
    float aL = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b;
    float bL = 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b;
    return (aL > bL) ? (aL + 0.05) / (bL + 0.05) : (bL + 0.05) / (aL + 0.05);
}

+ (float)saturationValueFor:(Color *)a andB:(Color *)b {
    float min = MIN(a.r, MIN(a.g, a.b)); // Grab min
    float max = MAX(b.r, MAX(b.g, b.b)); // Grab max
    return (max - min)/max;
}

+ (int)colorDistance:(Color *)a andB:(Color *)b {
    return abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b);
}

@end
