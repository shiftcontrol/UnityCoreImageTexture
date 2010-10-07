//
//  DrawingUtilities.m
//  Fluid
//
//  Created by Jason Harris on 1/4/07.
//  Copyright 2007 Geekspiff. All rights reserved.
//

#import "DrawingUtilities.h"
#import <Accelerate/Accelerate.h>
#import <QuartzCore/QuartzCore.h>


#if defined(__BIG_ENDIAN__)
	CGImageAlphaInfo const kDefaultAlphaLocation = kCGImageAlphaPremultipliedLast;
#else
	CGImageAlphaInfo const kDefaultAlphaLocation = kCGImageAlphaPremultipliedFirst;
#endif


@implementation DrawingUtilities


+ (DrawingUtilities *)sharedUtilities
{
    static DrawingUtilities *sSingletonInstance = nil;
    if (!sSingletonInstance)
    {
        sSingletonInstance = [[[self class] alloc] init];
        NSParameterAssert( sSingletonInstance != nil );
    }
    return sSingletonInstance;
}


- (void)_killSharedBitmapCache
{
    if (_sharedBitmapData)      free(_sharedBitmapData);            _sharedBitmapData    = NULL;
    if (_sharedBitmapContext)   CFRelease(_sharedBitmapContext);    _sharedBitmapContext = NULL;
    [_sharedCIContext release];                                     _sharedCIContext     = nil;
    _sharedSize = CGSizeZero;
}


- (void)dealloc
{
    if (_screenColorspace) CGColorSpaceRelease(_screenColorspace);
    [self _killSharedBitmapCache];
    [super dealloc];
}


- (CGColorSpaceRef)getScreenColorspace
{	
	if (!_screenColorspace)
	{
		CMProfileRef systemProfile = NULL;
		OSStatus status = CMGetSystemProfile(&systemProfile);
		NSParameterAssert( noErr == status);
		_screenColorspace = CGColorSpaceCreateWithPlatformColorSpace(systemProfile);
		CMCloseProfile(systemProfile);
	}
	return _screenColorspace;
}


- (size_t)optimalRowBytesForWidth: (size_t)width bytesPerPixel: (size_t)bytesPerPixel
{
    size_t rowBytes = width * bytesPerPixel;
    
	/*
	
    //Widen rowBytes out to a integer multiple of 16 bytes
    rowBytes = (rowBytes + 15) & ~15;
    
    //Make sure we are not an even power of 2 wide. 
    //Will loop a few times for rowBytes <= 16.
    while( 0 == (rowBytes & (rowBytes - 1) ) )
        rowBytes += 16;
	 
	*/
    
    return rowBytes;
}
    
    
- (void)_createContextsForImageSize: (CGSize)imageSize
{
    if (imageSize.width > _sharedSize.width || imageSize.height > _sharedSize.height)
        [self _killSharedBitmapCache];
    if (_sharedBitmapData) return;
    
    BOOL success = NO;
    size_t width = (size_t)imageSize.width;
    size_t height = (size_t)imageSize.height;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = [self optimalRowBytesForWidth: width bytesPerPixel: 4];
    CGColorSpaceRef colorspace = [self getScreenColorspace];
    CGBitmapInfo bitmapInfo = kDefaultAlphaLocation | kCGBitmapByteOrderDefault;
	//CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedFirst;
    
    _sharedBitmapData = (uint32_t* )malloc(bytesPerRow * height);
    if (_sharedBitmapData)
    {
        _sharedBitmapContext = CGBitmapContextCreate(_sharedBitmapData, width, height, bitsPerComponent, bytesPerRow, colorspace, bitmapInfo);
        if (_sharedBitmapContext)
        {
            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys: 
                (id)colorspace,     kCIContextOutputColorSpace, 
                (id)colorspace,     kCIContextWorkingColorSpace, 
                nil];
            _sharedCIContext = [[CIContext contextWithCGContext: _sharedBitmapContext options: options] retain];
            if (_sharedCIContext)
                success = YES;
        }
    }
    
    if (!success)
        [self _killSharedBitmapCache];
    else
        _sharedSize = imageSize;
    NSParameterAssert( success == YES );
}


- (uint32_t const *)createPremultipliedRGBA_8888_BitmapForCIImage: (CIImage *)image rowBytes: (size_t *)rowBytes
{
    NSParameterAssert( image != nil );
    NSParameterAssert( rowBytes != NULL );
    
    // - Get the geometry of the image
    
    CGRect extent = [image extent];
    CGRect zeroRect = {CGPointZero, extent.size};
    NSParameterAssert( CGRectIsInfinite(extent) == NO );
    size_t destWidth = (size_t)extent.size.width;
    size_t destHeight = (size_t)extent.size.height;
    
    // - Create shared contexts and render the image into them
    
    [self _createContextsForImageSize: extent.size];
    CGContextClearRect(_sharedBitmapContext, zeroRect);
    [_sharedCIContext drawImage: image atPoint: CGPointZero fromRect: extent];
    CGContextFlush(_sharedBitmapContext);
    
    // - Get the geometry of the shared contexts
    
    size_t sharedHeight = CGBitmapContextGetHeight(_sharedBitmapContext);
    *rowBytes = CGBitmapContextGetBytesPerRow(_sharedBitmapContext);
    
    // - Trim the bitmap to the desired height - we don't care about extra rows
    
    uint32_t const *sharedBitmap = _sharedBitmapData;
    sharedBitmap = (uint32_t const *) ((uintptr_t)sharedBitmap + *rowBytes * (sharedHeight - destHeight));
    
    // - Create the src for the vImage operation
    
    vImage_Buffer src, dest;
    src.data = (void *)sharedBitmap;
    src.width = destWidth;
    src.height = destHeight;
    src.rowBytes = *rowBytes;
    
    // - Create the destination buffer
    
    size_t bufferSize = *rowBytes * destHeight;
    uint32_t *destBuffer = (uint32_t*)malloc(bufferSize);
    NSParameterAssert( destBuffer != NULL );
    
    // - Create the destination for the vImage operation
    
    dest.data = destBuffer;
    dest.width = destWidth;
    dest.height = destHeight;
    dest.rowBytes = *rowBytes;
	
#if defined(__BIG_ENDIAN__)
	memcpy(destBuffer, sharedBitmap, *rowBytes * destHeight);
#else
	uint8_t permuteMap[4] = {3, 2, 1, 0};
	vImage_Error error = vImagePermuteChannels_ARGB8888(&src, &dest, permuteMap, 0);
    NSParameterAssert( error == noErr );
#endif
    return destBuffer;
}


- (uint32_t const *)createUnpremultipliedRGBA_8888_BitmapForCIImage: (CIImage *)image rowBytes: (size_t *)rowBytes
{
	uint32_t const *srcBuffer = [self createPremultipliedRGBA_8888_BitmapForCIImage: image rowBytes: rowBytes];
	NSParameterAssert( srcBuffer != NULL );
	
    // - Get the geometry of the image
    
    CGRect extent = [image extent];
    NSParameterAssert( CGRectIsInfinite(extent) == NO );
    size_t destWidth = (size_t)extent.size.width;
    size_t destHeight = (size_t)extent.size.height;

    // - Create the src for the vImage operation
    
    vImage_Buffer src;
    src.data = (void *)srcBuffer;
    src.width = destWidth;
    src.height = destHeight;
    src.rowBytes = *rowBytes;
	
    vImage_Error error = vImageUnpremultiplyData_RGBA8888(&src, &src, 0);
    NSParameterAssert( error == noErr );
    return srcBuffer;
}


- (CGContextRef)createBitmapContextOfSize: (CGSize)contextSize createdBackingBuffer: (void **)backingBuffer
{    
    CGContextRef context = NULL;
    size_t width = (size_t)contextSize.width;
    size_t height = (size_t)contextSize.height;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = [self optimalRowBytesForWidth: width bytesPerPixel: 4];
    CGColorSpaceRef colorspace = [self getScreenColorspace];
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault;
    
	void *buffer = NULL;
	if (backingBuffer)
		buffer = *backingBuffer = malloc(bytesPerRow * height);
    if (!backingBuffer || *backingBuffer)
    {
        context = CGBitmapContextCreate(buffer, width, height, bitsPerComponent, bytesPerRow, colorspace, bitmapInfo);
        if (!context && backingBuffer)
        {
			free(*backingBuffer);
            *backingBuffer = NULL;
        }
    }
    return context;
}


- (CGImageRef)createCGImageFromCIImage: (CIImage *)ciImage forceRect: (CGRect *)forceRect
{
    if (nil == ciImage) return NULL;
	
	CGRect extent = [ciImage extent];
	if (CGRectIsNull(extent) || CGRectIsEmpty(extent)) return NULL;
	if (CGRectIsInfinite(extent)) {
		extent.size.width = 1024;
		extent.size.height = 1024;
		NSLog(@"CGImageFromCIImage: Trimmed infinite rect to arbitrary finite rect");
	}
	
	if (forceRect)
		extent = *forceRect;
	[self _createContextsForImageSize: extent.size];
	return [_sharedCIContext createCGImage: ciImage fromRect: extent];
}


- (void)convertRGB: (CGFloat const *)rgbComponents toHSV: (CGFloat *)hsvComponents
{
    CGFloat themin,themax,delta;
    
    themin = MIN(rgbComponents[0], MIN(rgbComponents[1], rgbComponents[2]));
    themax = MAX(rgbComponents[0], MAX(rgbComponents[1], rgbComponents[2]));
    delta = themax - themin;
	
    hsvComponents[0] = 0;
    hsvComponents[1] = 0;
    hsvComponents[2] = themax;
	
    if (themax != 0)
	{
        hsvComponents[1] = delta / themax;
		if (delta != 0)
		{
			CGFloat deltaR = (((themax - rgbComponents[0]) / 6.0) + (delta / 2.0)) / delta;
			CGFloat deltaG = (((themax - rgbComponents[1]) / 6.0) + (delta / 2.0)) / delta;
			CGFloat deltaB = (((themax - rgbComponents[2]) / 6.0) + (delta / 2.0)) / delta;
			
			if      (rgbComponents[0] == themax)		hsvComponents[0] = deltaB - deltaG;
			else if (rgbComponents[1] == themax)		hsvComponents[0] = (1.0 / 3.0) + deltaR - deltaB;
			else if (rgbComponents[2] == themax)		hsvComponents[0] = (2.0 / 3.0) + deltaG - deltaR;
			
			while (hsvComponents[0] < 0.0)		hsvComponents[0] += 1.0;
			while (hsvComponents[0] > 1.0)		hsvComponents[0] -= 1.0;
		}
	}
}


- (void)convertHSV: (CGFloat const *)hsvComponents toRGB: (CGFloat *)rgbComponents;
{
	if (0.0 == hsvComponents[1])
	{
		rgbComponents[0] = rgbComponents[1] = rgbComponents[2] = hsvComponents[2];
	}
	else
	{
		CGFloat tempH = hsvComponents[0] * 6.0;
		
		if (tempH >= 6.0 || tempH < 0.0) tempH = 0.0; // H must be < 1
		int intH = (int)floorf(tempH); // guaranteed to be between 0 and 5 inclusive
		CGFloat term1 = hsvComponents[2] * (1.0 - hsvComponents[1]);
		CGFloat term2 = hsvComponents[2] * (1.0 - hsvComponents[1] * (tempH - (CGFloat)intH));
		CGFloat term3 = hsvComponents[2] * (1.0 - hsvComponents[1] * (1.0 - (tempH - (CGFloat)intH)));
		
		switch(intH)
		{
			case 0:
				rgbComponents[0] = hsvComponents[2];
				rgbComponents[1] = term3;
				rgbComponents[2] = term1;
				break;
				
			case 1:
				rgbComponents[0] = term2;
				rgbComponents[1] = hsvComponents[2];
				rgbComponents[2] = term1;
				break;
				
			case 2:
				rgbComponents[0] = term1;
				rgbComponents[1] = hsvComponents[2];
				rgbComponents[2] = term3;
				break;
				
			case 3:
				rgbComponents[0] = term1;
				rgbComponents[1] = term2;
				rgbComponents[2] = hsvComponents[2];
				break;
				
			case 4:
				rgbComponents[0] = term3;
				rgbComponents[1] = term1;
				rgbComponents[2] = hsvComponents[2];
				break;
				
			case 5:
				rgbComponents[0] = hsvComponents[2];
				rgbComponents[1] = term1;
				rgbComponents[2] = term2;
				break;
		}
	}
}


- (NSDictionary *)scalesAndPathsForImageName: (NSString *)imageName directory: (NSString *)directoryName inBundle: (NSBundle *)bundle error: (NSError **)error
{
	NSString *imageFileName = [imageName stringByDeletingPathExtension];
	NSString *imagePathExtension = [imageName pathExtension];
	if (imagePathExtension && 0 == [imagePathExtension length])
		imagePathExtension = nil;
	
	if (!bundle) bundle = [NSBundle mainBundle];
	NSString *directoryPath = [bundle resourcePath];
	if (directoryName)
		directoryPath = [directoryPath stringByAppendingPathComponent: directoryName];
	
	NSMutableDictionary *entries = [NSMutableDictionary dictionary];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *filenames = [fm contentsOfDirectoryAtPath: directoryPath error: error];
	if (!filenames) return nil;
	NSArray *imageFileTypes = [NSImage imageFileTypes];
	
	for (NSString *filename in filenames)
	{
		NSString *extensionlessFilename = [filename stringByDeletingPathExtension];
		if (![extensionlessFilename hasPrefix: imageFileName]) continue;
		NSString *pathExtension = [filename pathExtension];
		if (imagePathExtension && ![imagePathExtension isEqualToString: pathExtension]) continue;
		if (!imagePathExtension && (!pathExtension || ![imageFileTypes containsObject: pathExtension])) continue;
		
		CGFloat scaleFactor;
		NSString *scaleFactorString = [extensionlessFilename substringFromIndex: [imageFileName length]];
		if (0 == [scaleFactorString length])
			scaleFactor = 1.0;
		else
		{
			NSParameterAssert ('_' == [scaleFactorString characterAtIndex: 0] );
			scaleFactorString = [scaleFactorString substringFromIndex: 1];
			NSScanner *scanner = [NSScanner scannerWithString: scaleFactorString];
			BOOL scaleFactorStringWasNumeric = [scanner scanFloat: &scaleFactor];
			NSParameterAssert( scaleFactorStringWasNumeric == YES );
		}
		[entries setObject: [directoryPath stringByAppendingPathComponent: filename] forKey: [NSNumber numberWithFloat: scaleFactor]];
	}
	
	return entries;
}


- (NSString *)bestPathFromChoices: (NSDictionary *)choices forScaleFactor: (CGFloat)scaleFactor
{
	NSUInteger count = [choices count];
	NSParameterAssert( count > 0 );
	
	NSArray *allKeys = [choices allKeys];
	if (1 == count)
		return [choices objectForKey: [allKeys lastObject]];
	
	NSMutableArray *mutableScaleFactors = [NSMutableArray arrayWithArray: allKeys];
	NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey: @"scaleFactor" ascending: YES] autorelease];
	[mutableScaleFactors sortUsingDescriptors: [NSArray arrayWithObject: sd]];
	for (NSNumber *thisScaleFactorObject in mutableScaleFactors)
	{
		float thisScaleFactor = [thisScaleFactorObject floatValue];
		if (scaleFactor <= thisScaleFactor)
			return [choices objectForKey: thisScaleFactorObject];
	}
	return [choices objectForKey: [mutableScaleFactors lastObject]];
}


- (CGImageRef)createCGImageAtPath: (NSString *)path desiredScaleFactor: (float)desiredScaleFactor originalScaleFactor: (float)originalScaleFactor
{
	NSParameterAssert( path != nil );
	NSParameterAssert( originalScaleFactor >= 0.1 );
	NSParameterAssert( desiredScaleFactor >= 0.1 );
	
	CGImageRef			sourceImage = NULL;
	CGImageRef			finalImage = NULL;
	CFDictionaryRef		properties = NULL;
	CGImageSourceRef	imageSource = NULL;
	CGContextRef		context = NULL;
	
	@try
	{
		// - Figure out our destination resolution
		
		float desiredDPIWidth = 72.0, desiredDPIHeight = 72.0;
		desiredDPIWidth  *= desiredScaleFactor;
		desiredDPIHeight *= desiredScaleFactor;
		
		// - Grab the full size image and the image's properties
		
		NSURL *url = [NSURL fileURLWithPath: path];
		imageSource = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
		NSParameterAssert( imageSource != NULL );
		sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
		properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
		CFRelease(imageSource);					imageSource = NULL;
		NSParameterAssert( sourceImage != NULL );
		NSParameterAssert( properties != NULL );
		
		// - Find the image size and resolution
		
		NSNumber *floatObject;
		floatObject = [(NSDictionary *)properties objectForKey: (NSString *)kCGImagePropertyPixelWidth];
		float pixelsWide = floatObject ? [floatObject floatValue] : (float)CGImageGetWidth(sourceImage);
		
		floatObject = [(NSDictionary *)properties objectForKey: (NSString *)kCGImagePropertyPixelHeight];
		float pixelsHigh = floatObject ? [floatObject floatValue] : (float)CGImageGetWidth(sourceImage);
		
		floatObject = [(NSDictionary *)properties objectForKey: (NSString *)kCGImagePropertyDPIWidth];
		float dpiWidth = floatObject ? [floatObject floatValue] : 72.0;
		
		floatObject = [(NSDictionary *)properties objectForKey: (NSString *)kCGImagePropertyDPIHeight];
		float dpiHeight = floatObject ? [floatObject floatValue] : 72.0;
		CFRelease(properties);					properties = NULL;
		
		// - Use a fudge factor for the image's resolution.  If it's between 71 and 76, we'll consider it 
		//   to be 72.
		
		if (dpiWidth  >= 71.0 && dpiWidth  <= 76.0) dpiWidth  = 72.0;
		if (dpiHeight >= 71.0 && dpiHeight <= 76.0) dpiHeight = 72.0;
		
		// - Photoshop CS3 has a bug that adds a rounding error to the DPI.  Floor the DPI in case that bug
		//   is manifesting itself.
		
		dpiWidth  = floorf(dpiWidth);
		dpiHeight = floorf(dpiHeight);
		
		// - If the dpi is 72 but the originalScaleFactor isn't 1x, this is probably an image with its DPI set 
		//   incorrectly.  Do I want to assume that and correct here, or force the artist to regenerate the 
		//   image with the correct DPI?  Probably the latter.
		
		if ((72.0 == dpiWidth || 72.0 == dpiHeight) && 1.0 != originalScaleFactor)
		{
			NSLog(@"Incorrect DPI of (%.1f, %.1f) set for image with scale factor %.1f at \"%@\"\n", dpiWidth, dpiHeight, originalScaleFactor, path);
			
			// - Hack, this works around the incorrectly set DPI
			
			if (72.0 == dpiWidth)
				dpiWidth *= originalScaleFactor;
			if (72.0 == dpiHeight)
				dpiHeight *= originalScaleFactor;
		}
		
		// - Okay, figure out what the actual scale factor of the source image is.  
		
		float adjustedDPIWidth  = dpiWidth  / originalScaleFactor;
		float adjustedDPIHeight = dpiHeight / originalScaleFactor;
		
		// - And figure out the change needed to get to our desired factor.
		
		float finalScaleWidth  = desiredDPIWidth  / adjustedDPIWidth;
		float finalScaleHeight = desiredDPIHeight / adjustedDPIHeight;
		
		// - Bail if we can, otherwise, create a context of the correct size for drawing the "real" image
		//   and blit it out.
		
		if (finalScaleWidth == 1.0 && finalScaleHeight == 1.0)
			return sourceImage;
		
		CGSize destinationSize = {pixelsWide * finalScaleWidth / originalScaleFactor, pixelsHigh * finalScaleHeight / originalScaleFactor};
		CGSize contextSize = {ceilf(destinationSize.width), ceilf(destinationSize.height)};
		context = [self createBitmapContextOfSize: contextSize createdBackingBuffer: NULL];
		NSParameterAssert( context != NULL );
		CGRect destRect = {CGPointZero, destinationSize};
		CGContextDrawImage(context, destRect, sourceImage);
		CFRelease(sourceImage);					sourceImage = NULL;
		finalImage = CGBitmapContextCreateImage(context);
		CFRelease(context);						context = NULL;
		NSParameterAssert( finalImage != NULL );
	}
	@catch (NSException *e)
	{
		if (sourceImage)	CFRelease(sourceImage);
		if (properties)		CFRelease(properties);
		if (imageSource)	CFRelease(imageSource);
		if (context)		CFRelease(context);
		[e raise];
	}
	return finalImage;
}

- (UInt32 const *)createPremultipliedRGBA_8888_BitmapForCIImageWithoutCrop: (CIImage *)image rowBytes: (size_t *)rowBytes
{
    NSParameterAssert( image != nil );
    NSParameterAssert( rowBytes != NULL );
    
    // - Get the geometry of the image
    
    CGRect extent = [image extent];
    CGRect zeroRect = {CGPointZero, extent.size};
    NSParameterAssert( CGRectIsInfinite(extent) == NO );
    size_t destWidth = (size_t)extent.size.width;
    size_t destHeight = (size_t)extent.size.height;
    
    // - Create contexts
    
    CGContextRef cgContext = NULL;
    CIContext *ciContext = nil;
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = [self optimalRowBytesForWidth: destWidth bytesPerPixel: 4];
    CGColorSpaceRef colorspace = [self getScreenColorspace];
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault;
    
    UInt32 *bitmapData = malloc(bytesPerRow * destHeight);
    if (bitmapData)
    {
        cgContext = CGBitmapContextCreate(bitmapData, destWidth, destHeight, bitsPerComponent, bytesPerRow, colorspace, bitmapInfo);
        if (cgContext)
        {
            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys: 
									 (id)colorspace,     kCIContextOutputColorSpace, 
									 (id)colorspace,     kCIContextWorkingColorSpace, 
									 nil];
            ciContext = [CIContext contextWithCGContext: cgContext options: options];
            //if (ciContext)
                //success = YES;
		}
    }
    NSParameterAssert( cgContext != NULL && ciContext != nil );
	
    // - Render the image into the contexts
	
    CGContextClearRect(cgContext, zeroRect);
    [ ciContext drawImage: image atPoint: CGPointZero fromRect: extent];
    CGContextFlush(cgContext);
	
    // - Get the geometry of the context
    
    *rowBytes = CGBitmapContextGetBytesPerRow(cgContext);
    CGContextRelease(cgContext);
    
    return bitmapData;
}

@end