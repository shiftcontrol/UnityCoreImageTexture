// CoreImageTexture, an Unity plugin for loading textures using OSX CoreImage technology.
// (c) Marcin Ignac <marcin.ignac@gmail.com> / marcinignac.com, October 2010.
// (c) Shiftcontrol / shiftcontrol.dk, October 2010
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

#import "CoreImageTexture.h"
#import "DrawingUtilities.h"

static NSString* cacheDir = @"";
static NSString* fileNameSeparator = @"";

void SetImageCacheDir(char* uri) {
	NSLog(@"COREIMAGETEXTURE v0.1.22");
	
	cacheDir = [NSString stringWithCString:uri encoding:[NSString defaultCStringEncoding]];	
	[cacheDir retain];
	NSLog(@"COREIMAGETEXTURE Setting cache dir:'%@'", cacheDir);
}

void SetFileNameSeparator(char* speparator) {	
	fileNameSeparator = [NSString stringWithCString:speparator encoding:[NSString defaultCStringEncoding]];	
	[fileNameSeparator retain];
	NSLog(@"COREIMAGETEXTURE Setting file name separator:'%@'", fileNameSeparator);
}

bool IsCacheEnabled() {
	return [cacheDir length] > 0;
}

void SaveJPEGImage(CGImageRef imageRef, NSString *path) {
	CFMutableDictionaryRef mSaveMetaAndOpts = CFDictionaryCreateMutable(nil, 0, &kCFTypeDictionaryKeyCallBacks,  &kCFTypeDictionaryValueCallBacks);
	CFDictionarySetValue(mSaveMetaAndOpts, kCGImageDestinationLossyCompressionQuality, [NSNumber numberWithFloat:1.0]);
	NSURL *outURL = [NSURL fileURLWithPath:path];
	NSLog(@"COREIMAGETEXTURE SavePath:'%@'", [outURL path]);	
	NSLog(@"COREIMAGETEXTURE Creating destination");	
	CGImageDestinationRef dr = CGImageDestinationCreateWithURL((CFURLRef)outURL, kUTTypeJPEG , 1, NULL);
	NSLog(@"COREIMAGETEXTURE Adding image");	
	CGImageDestinationAddImage(dr, imageRef, mSaveMetaAndOpts);
	NSLog(@"COREIMAGETEXTURE Finalizing");	
	CGImageDestinationFinalize(dr);
}

// Converts file URI to valid file name by spliting URI at 'fileNameSeparator' 
// and replacing non alpha numeric characters by '_'
//
// E.g. with fileNameSeparator = 'blogs.dir'
// marcinignac.com/wp-content/blogs.dir/2/files/2010/07/DRP3G09.jpg
// would be converted to 
// 2_files_2010_07_DRP3G09.jpg
NSString* GetCacheFileName(NSString* uriString) {
	NSLog(@"COREIMAGETEXTURE Using cache dir:'%@' ans separator'%@'", cacheDir, fileNameSeparator);	
	NSRange range = [uriString rangeOfString:fileNameSeparator];
	if (range.location == NSNotFound) {
		NSLog(@"COREIMAGETEXTURE Not found '%@' in '%@'", fileNameSeparator, uriString);	
		range.location = 0;
		range.length = [uriString length];
	}	
	else {
		range.location += [fileNameSeparator length];
	}
	
	NSString* validCharacters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_";
	NSString* cachedFileName = [uriString substringFromIndex:range.location];	
	cachedFileName = [[cachedFileName componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:validCharacters] invertedSet]] componentsJoinedByString:@"_"];
	return [cacheDir stringByAppendingString:cachedFileName];	
}

CIImage* LoadImageFromCache(NSString* uriString) {
	if (!IsCacheEnabled()) {
		return nil;
	}
	
	NSString* cachedFileName = GetCacheFileName(uriString);	
	NSLog(@"COREIMAGETEXTURE cachedFileName:'%@'", cachedFileName);	
	
	NSURL *cachedFileUrl = [NSURL fileURLWithPath:cachedFileName];
	CIImage* image = [CIImage imageWithContentsOfURL:cachedFileUrl];
	
	if (image == nil && IsCacheEnabled()) {
		NSLog(@"COREIMAGETEXTURE downloading");	
		NSURL *url = [[NSURL alloc] initWithString:uriString];
		image = [CIImage imageWithContentsOfURL:url];		
		NSLog(@"COREIMAGETEXTURE converting");	
		NSBitmapImageRep* rep = [[[NSBitmapImageRep alloc] initWithCIImage:image] autorelease];		
		CGImageRef cgImage = rep.CGImage;
		NSLog(@"COREIMAGETEXTURE saving");	
		SaveJPEGImage(cgImage, cachedFileName);		
		NSLog(@"COREIMAGETEXTURE done");	
	}
	
	return image;
}

void LoadImageIntoTexture(int textureID, char* uri) {

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	NSString* uriString = [NSString stringWithCString:uri encoding:[NSString defaultCStringEncoding]];	
	CIImage *image = LoadImageFromCache(uriString);
	//NSLog(@"COREIMAGETEXTURE retain count %d", [image retainCount]);
	if (image == nil) {
		NSLog(@"COREIMAGETEXTURE Image not found in cache. Loading from URI %@", uriString);
		NSURL *url = [[NSURL alloc] initWithString:uriString];
		image = [CIImage imageWithContentsOfURL:url];
	}
	
	unsigned char* data = 0;
	
	int w = 0;
	int h = 0;
	
	if (image == nil) {
		NSLog(@"COREIMAGETEXTURE failed to initialize the image");
		return;
	}
	else {
		CGRect extent = [image extent];
		w = (size_t)extent.size.width;
		h = (size_t)extent.size.height;
		
		UInt32 bytesPerRow;
		id utils = [[DrawingUtilities alloc] init];
		[utils retain];
		data = (unsigned char*)[utils createPremultipliedRGBA_8888_BitmapForCIImage:image rowBytes:&bytesPerRow];				
		[utils release];
	}
	
	if (data == nil) {
		NSLog(@"COREIMAGETEXTURE failed to initialize the data");
		return;
	}

	unsigned char* data2 = new unsigned char[4 * w * h];
	
	for (int y=0;y<h;y++)
	{
		for (int x=0;x<w;x++)
		{
			unsigned char* pixel = data2 + (y * w + x) * 4;
			const unsigned char* src = data + ((h - y - 1) * w + x) * 4; 
			pixel[0] = src[2];
			pixel[1] = src[1];
			pixel[2] = src[0];
			pixel[3] = 255;
		}
	}	
	
	glPushAttrib (GL_TEXTURE_BIT);
	glBindTexture(GL_TEXTURE_2D, textureID);
	glTexImage2D (GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV, data2);
	glPopAttrib();	
	
	delete[] data2;	
	
	free((UInt32 *)data);
	[pool release];	
}
