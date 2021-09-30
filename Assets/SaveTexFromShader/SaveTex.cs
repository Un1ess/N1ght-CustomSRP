using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

[ExecuteInEditMode]
public class SaveTex : MonoBehaviour
{
    

    public SaveFile saveFile;
    public Shader shader;
    public Material mat;
    public string foldername;
    public string pngName;
    public Texture tex;
    public bool enableSave = false;
    public enum SaveFile
    {
        PNG,
        EXR
    }
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (enableSave)
        {
            enableSave = false;
            Debug.Log("保存");
            //SaveRenderTextureToPNG(tex, shader, Application.dataPath+"/"+foldername, pngName);
            SaveRenderTextureToEXR(tex, mat, Application.dataPath + "/" + foldername, pngName);
        }
        
    }
    public bool SaveRenderTextureToPNG(Texture inputTex,Shader outputShader, string contents, string pngName)

    {
        RenderTexture temp = RenderTexture.GetTemporary(inputTex.width, inputTex.height, 0, RenderTextureFormat.ARGB32);

        Material mat = new Material(outputShader);

        Graphics.Blit(inputTex, temp, mat);
        
        bool ret = SaveRenderTextureToPNG(temp, contents,pngName);

        RenderTexture.ReleaseTemporary(temp);

        return ret;

    }
    
    public bool SaveRenderTextureToEXR(Texture inputTex,Material outputMaterial, string contents, string pngName)

    {
        RenderTexture temp = RenderTexture.GetTemporary(inputTex.width, inputTex.height, 0, RenderTextureFormat.ARGBHalf);

        //Material mat = new Material(outputShader);

        Graphics.Blit(inputTex, temp, outputMaterial);
        bool ret = SaveRenderTextureToEXR(temp, contents,pngName);

        RenderTexture.ReleaseTemporary(temp);

        return ret;

    }

//将RenderTexture保存成一张png图片

    public bool SaveRenderTextureToPNG(RenderTexture rt,string contents, string pngName)

    {
        RenderTexture prev = RenderTexture.active;

        RenderTexture.active = rt;

        Texture2D png = new Texture2D(rt.width, rt.height, TextureFormat.ARGB32, false);
        Texture2D exr = new Texture2D(rt.width, rt.height, TextureFormat.RGBAHalf, false);

        png.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        exr.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
 
        //byte[] bytes = png.EncodeToPNG();
        byte[] bytes = exr.EncodeToEXR(Texture2D.EXRFlags.None);

        if (!Directory.Exists(contents))

            Directory.CreateDirectory(contents);

        FileStream file = File.Open( contents + "/" + pngName + ".exr", FileMode.Create);

        Debug.Log(contents + "/" + pngName + ".exr");
        BinaryWriter writer = new BinaryWriter(file);

        writer.Write(bytes);

        file.Close();

        Texture2D.DestroyImmediate(png);

        png = null;

        RenderTexture.active = prev;

        return true;

    }    
    public bool SaveRenderTextureToEXR(RenderTexture rt,string contents, string pngName)

    {
        RenderTexture prev = RenderTexture.active;

        RenderTexture.active = rt;
        
        Texture2D exr = new Texture2D(rt.width, rt.height, TextureFormat.RGBAHalf, false);
        
        exr.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        
        byte[] bytes = exr.EncodeToEXR(Texture2D.EXRFlags.None);

        if (!Directory.Exists(contents))

            Directory.CreateDirectory(contents);

        FileStream file = File.Open( contents + "/" + pngName + ".exr", FileMode.Create);

        Debug.Log(contents + "/" + pngName + ".exr");
        BinaryWriter writer = new BinaryWriter(file);

        writer.Write(bytes);

        file.Close();

        Texture2D.DestroyImmediate(exr);

        exr = null;

        RenderTexture.active = prev;

        return true;

    }
}
