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

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


extern "C" {
	//Sets the directory when downloaded images will be saved for faster loading next time
	//Cache is disabled until you set the uri for the first time
	//Requires "/" at the end of the path
	void SetImageCacheDir(char* uri);
	
	//Sets the string that divides file name from path.
	//Look at GetCacheFileName documentation for more info.
	void SetFileNameSeparator(char* speparator);
	
	//Loads image from path or url into texture with given id.
	//Notice: Since Unity 3.0 you have to use Texture.GetNativeTextureID()
	void LoadImageIntoTexture(int textureID, char* uri);
}
