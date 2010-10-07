using UnityEngine;
using System.Collections;
using System;
using System.Runtime.InteropServices;
                 
public class CoreImageTextureTest : MonoBehaviour {                                    
  
  [DllImport("CoreImageTexture")]
  private static extern void SetImageCacheDir(string uri);
  
  [DllImport("CoreImageTexture")]
  private static extern void LoadImageIntoTexture(int textureID, string uri);    
            
  [DllImport("CoreImageTexture")]
  private static extern void SetFileNameSeparator(string speparator);
  
  public GUISkin skin;
  private Texture2D tex;      
  
	void Start () {   
	  tex = new Texture2D(512, 512, TextureFormat.ARGB32, false);  

    //draw saome nice fractal to indicate that texture was generated
	  for (int y = 0; y < tex.height; ++y) {
      for (int  x = 0; x < tex.width; ++x) {
        Color color = ((x & y) == 0) ? Color.black : Color.white;
        tex.SetPixel (x, y, color);
      }
    }        
    tex.Apply();                                 
                 
	  GetComponent<GUITexture>().texture = tex;	   	

	  //files from http://farm5.static.flickr.com/X/Y.jpg
	  //will be saved in cache as /tmp/X_Y.jpg	           
	  SetImageCacheDir("/tmp/");            
	  SetFileNameSeparator("farm5.static.flickr.com/");  
	}

	void OnGUI() {    
	  GUI.skin = skin; 
	  int x = (Screen.width-400)/2;
	  int y = 60;                    
	  GUI.Box(new Rect(x, y,400,84), "This texture is procedurally generated. Click '1', '2' or '3' to download external images.");
	   
    if (GUI.Button(new Rect(x + 10, y + 50,20,20), "1")) {
      LoadImageIntoTexture(tex.GetNativeTextureID(), "http://farm5.static.flickr.com/4139/4795878610_6411ac6f01_b.jpg");  
    }
    
    if (GUI.Button(new Rect(x + 40, y + 50,20,20), "2")) {
      LoadImageIntoTexture(tex.GetNativeTextureID(), "http://farm5.static.flickr.com/4088/4946181705_c4e2256eb3_b.jpg");  
    } 
    
    if (GUI.Button(new Rect(x + 70, y + 50,20,20), "3")) {
      LoadImageIntoTexture(tex.GetNativeTextureID(), "http://farm3.static.flickr.com/2795/4540035448_48eef63b98_b.jpg");  
    }
	}
}
