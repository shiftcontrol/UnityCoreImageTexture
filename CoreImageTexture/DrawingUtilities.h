//
//  DrawingUtilities.h
//  Fluid
//
//  Created by Jason Harris on 1/4/07.
//  Copyright 2007 Geekspiff. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DrawingUtilities : NSObject {
    CGColorSpaceRef _screenColorspace;
    CGSize _sharedSize;
    uint32_t *_sharedBitmapData;
    CGContextRef _sharedBitmapContext;
    CIContext *_sharedCIContext;
}

// Return the non-thread-safe shared image utilities instance.
+ (DrawingUtilities *)sharedUtilities;

// Return a CGColorSpaceRef representing the current main screen. This does not need to be released by the caller.
- (CGColorSpaceRef)getScreenColorspace;

// Return the optimal bytesPerRow to use with CoreGraphics for an image/context of the given width and bytesPerPixel.
- (size_t)optimalRowBytesForWidth: (size_t)width bytesPerPixel: (size_t)bytesPerPixel;

// Create a premultiplied RGBA_8888 bitmap buffer for the given CIImage. The number of bytes per row for the bitmap
// is returned in the non-optional rowBytes argument. The caller should release the returned buffer using "free".
- (uint32_t const *)createPremultipliedRGBA_8888_BitmapForCIImage: (CIImage *)image rowBytes: (size_t *)rowBytes;
- (UInt32 const *)createPremultipliedRGBA_8888_BitmapForCIImageWithoutCrop: (CIImage *)image rowBytes: (size_t *)rowBytes;

// Same as above, but returns an unpremultiplied bitmap buffer.
- (uint32_t const *)createUnpremultipliedRGBA_8888_BitmapForCIImage: (CIImage *)image rowBytes: (size_t *)rowBytes;

// Returns a bitmap CGContextRef (CGBitmapContext.h) of the given size. If backingBuffer is non-NULL, the bitmap 
// buffer that backs the context will be returned in that argument and must be freed by the caller using "free".
- (CGContextRef)createBitmapContextOfSize: (CGSize)contextSize createdBackingBuffer: (void **)backingBuffer;

// Creates a CGImage from the specified CIImage. If forceRect is specified, it will be the rectangle used to render the 
// image, otherwise, the image's extent will be used.
- (CGImageRef)createCGImageFromCIImage: (CIImage *)ciImage forceRect: (CGRect *)forceRect;

// RGB <-> HSV conversions. 'rgbComponents' and 'hsvComponents' are arrays of three floating color components, in 
// R, G, B and H, S, V order respectively.
- (void)convertRGB: (CGFloat const *)rgbComponents toHSV: (CGFloat *)hsvComponents;
- (void)convertHSV: (CGFloat const *)hsvComponents toRGB: (CGFloat *)rgbComponents;


// The remainder of the methods here deal with resolution independence

// The following method looks for images named something like "Blah.png", "Blah_1.25.png", "Blah_4.tiff", which would correspond
// to images for 1x, 1.25x and 4x scale factors .  If "imageName" contains a path extension, results will be constrained to it.  
// If not, any valid image path extension will return results. If directoryName is non-nil, images will be searched for in the named
// directory within the given bundles' Resources folder, otherwise, the search will happen at the root of the Resources folder.  If 
// nil is returned, *error will describe what went wrong. The returned dictionary contains filesystem paths keyed by scale factors.
- (NSDictionary *)scalesAndPathsForImageName: (NSString *)imageName directory: (NSString *)directoryName inBundle: (NSBundle *)bundle error: (NSError **)error;

// Returns the best filesystem path for the given scale factor from the given choices, as obtained by the method above.
- (NSString *)bestPathFromChoices: (NSDictionary *)choices forScaleFactor: (CGFloat)scaleFactor;

// Creates the "best" CGImage based on the image at "path" for the given desired scale factor and original scale factor. This will 
// try not to scale the image, but will do so if necessary. This takes the resolution metadata of the image into account and assumes
// a display resolution of 72 DPI. The caller is reponsible for releasing the returned image.
- (CGImageRef)createCGImageAtPath: (NSString *)path desiredScaleFactor: (float)desiredScaleFactor originalScaleFactor: (float)originalScaleFactor;

@end
