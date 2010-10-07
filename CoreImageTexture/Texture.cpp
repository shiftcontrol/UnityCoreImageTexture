#include "Texture.h"
#include <vector>
#include <OpenGL/gl.h>

//extern "C"
//{
// We pass the texture id width and current time to the plugin
// The C++ plugin can then assign any kind of texture to opengl directly.
void UpdateTexture (int textureID, int width, int height, float time)
{
	// 32 bit rgba texture
	char* data = new char[4 * width * height];
	
	//Hello* hello = new Hello();

	// Generate the texture data in funky ways
	// Or could just stream it from Quicktime or however you like.
	int intTime = time * 100;
	for (int y=0;y<height;y++)
	{
		for (int x=0;x<width;x++)
		{
			char* pixel = data + (y * width + x) * 4;
			pixel[0] = 255;// * hello->getDoubled(0.25f);
			pixel[1] = 255;
			pixel[2] = 0;  
			pixel[3] = 255;
			//pixel[0] = (intTime * 3 + y * 10 + x * 3) % 255;// r
			//pixel[1] = (intTime * 4 + y * 33 + x * 4) % 255;// g
			//pixel[2] = (intTime * 5 + y * 44 + x * 5) % 255;// b
			//pixel[3] = (intTime * 6 + y * 55 + x * 6) % 255;// alpha
		}
	}

	// Push gl state (We need to leave the bound texture like it was before)
	glPushAttrib (GL_TEXTURE_BIT);

	// Upload the texture to gl
	glBindTexture(GL_TEXTURE_2D, textureID);
	//glTexImage2D (GL_TEXTURE_2D, 0, GL_BGRA, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, data);
	glTexImage2D (GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV, data);
	
	// Revert bind texture calls
	glPopAttrib ();
	
	delete []data;
}

//}