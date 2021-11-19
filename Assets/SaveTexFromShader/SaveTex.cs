using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;


public class SaveTex : MonoBehaviour
{
    

    public SaveFile saveFile;
    public Shader shader;
    public Material mat;
    public string foldername;
    public string pictureName;
    public Texture tex;
    public bool enableSave = false;

    public bool useNewTex2d = true;
    public Texture2D newTexture2D;
    public enum SaveFile
    {
        PNG,
        EXR16,
        EXR32
    }
    // Start is called before the first frame update
    void Start()
    {
        //tex.graphicsFormat = GraphicsFormat.R32G32B32_SFloat;
        //m_Tex = new Texture2D(tex.width, tex.height, TextureFormat.RGBAFloat, false);
        newTexture2D = new Texture2D(4096, 64, TextureFormat.RGBAFloat, false);
        newTexture2D.filterMode = FilterMode.Point;
        newTexture2D.wrapMode = TextureWrapMode.Clamp;
        float  distanceR = (float)(1.0 / 63.0);
        Color customColorForLut = Color.white;
        for (int height = 0; height < 64; height++)
        {
            for (int width = 0; width < 4096; width++)
            {
                customColorForLut.r = (width%64) * distanceR;
                customColorForLut.g = Mathf.Floor((float) (width / 64.0)) * distanceR;
                customColorForLut.b = (63 - height) * distanceR;
                newTexture2D.SetPixel(width,height,customColorForLut);
            }
        }
        
        newTexture2D.Apply();
        
        string filename = Application.dataPath + "/" + "SaveTexFromShader" + "/" + "linear_to_linear.exr";
        //newTexture2D.ReadUncompressed(filename);
        //var file = System.IO.File.OpenRead(filename);
        //Debug.Log(filename);
        
        Debug.Log("newTexture2D.Format: "+newTexture2D.graphicsFormat);
    }

    // Update is called once per frame
    void Update()
    {
        float mathr = 64 / 64 - 1;
        Debug.Log(mathr);
        float testColor = 0.5f;
        testColor *= (float)(64.0 / 63.0);
        Debug.Log("tex.format: "+tex.graphicsFormat);
        if (enableSave)
        {
            enableSave = false;
            Debug.Log("保存");
            //SaveRenderTextureToPNG(tex, shader, Application.dataPath+"/"+foldername, pictureName);
            string contents = Application.dataPath + "/" + foldername;
            switch (saveFile)
            {
                case SaveFile.PNG:
                    SaveRenderTextureToPNG(tex, mat, contents, pictureName);
                    break;
                case SaveFile.EXR16:
                    SaveRenderTextureToEXR16(tex, mat, contents, pictureName);
                    break;
                case SaveFile.EXR32:
                    if (useNewTex2d)
                    {
                        SaveRenderTextureToEXR32(newTexture2D, mat, contents, pictureName);
                    }
                    else
                    {
                        SaveRenderTextureToEXR32(tex, mat, contents, pictureName);
                    }
                    
                    break;
                    
            }
            AssetDatabase.Refresh();
        }

        bool supportOrNot =  SystemInfo.SupportsTextureFormat(TextureFormat.RGBAFloat);
        Debug.Log(supportOrNot);
        
        //Debug.Log(tex.graphicsFormat);

    }
    public bool SaveRenderTextureToPNG(Texture inputTex,Material outputMaterial, string contents, string pictureName)

    {
        RenderTexture temp = RenderTexture.GetTemporary(inputTex.width, inputTex.height, 0, RenderTextureFormat.ARGB32);

        //Material mat = new Material(outputShader);

        Graphics.Blit(inputTex, temp, outputMaterial);
        
        bool ret = SaveRenderTextureToPNG(temp, contents,pictureName);

        RenderTexture.ReleaseTemporary(temp);
        return ret;

    }

    public bool SaveRenderTextureToEXR16(Texture inputTex,Material outputMaterial, string contents, string pictureName)

    {
        RenderTexture temp = RenderTexture.GetTemporary(inputTex.width, inputTex.height, 0, RenderTextureFormat.ARGBHalf);

        Graphics.Blit(inputTex, temp, outputMaterial);
        bool ret = SaveRenderTextureToEXR16(temp, contents,pictureName);

        RenderTexture.ReleaseTemporary(temp);

        return ret;

    }
    
    public bool SaveRenderTextureToEXR32(Texture inputTex,Material outputMaterial, string contents, string pictureName)

    {
        RenderTexture temp = RenderTexture.GetTemporary(inputTex.width, inputTex.height, 0, RenderTextureFormat.ARGBFloat);
        
        Graphics.Blit(inputTex, temp, outputMaterial);
        bool ret = SaveRenderTextureToEXR32(temp, contents,pictureName);
        
        RenderTexture.ReleaseTemporary(temp);

        return ret;

    }

    //将RenderTexture保存成一张png图片

    public bool SaveRenderTextureToPNG(RenderTexture rt,string contents, string pictureName)

    {
        RenderTexture prev = RenderTexture.active;

        RenderTexture.active = rt;
        Texture2D png = new Texture2D(rt.width, rt.height, TextureFormat.ARGB32, false);

        png.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);

        byte[] bytes = png.EncodeToPNG();

        if (!Directory.Exists(contents))
            Directory.CreateDirectory(contents);

        FileStream file = File.Open( contents + "/" + pictureName + ".png", FileMode.Create);

        Debug.Log(contents + "/" + pictureName + ".png");
        BinaryWriter writer = new BinaryWriter(file);
        
        writer.Write(bytes);
        file.Close();
        Texture2D.DestroyImmediate(png);
        png = null;

        RenderTexture.active = prev;

        return true;

    }    
    public bool SaveRenderTextureToEXR16(RenderTexture rt,string contents, string pictureName)

    {
        RenderTexture prev = RenderTexture.active;

        RenderTexture.active = rt;
        
        Texture2D exr = new Texture2D(rt.width, rt.height, TextureFormat.RGBAHalf, false);

        exr.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        
        byte[] bytes = exr.EncodeToEXR(Texture2D.EXRFlags.None);

        if (!Directory.Exists(contents))

            Directory.CreateDirectory(contents);

        FileStream file = File.Open( contents + "/" + pictureName + ".exr", FileMode.Create);

        Debug.Log(contents + "/" + pictureName + ".exr");
        BinaryWriter writer = new BinaryWriter(file);

        writer.Write(bytes);

        file.Close();

        Texture2D.DestroyImmediate(exr);

        exr = null;

        RenderTexture.active = prev;

        return true;

    }
    public bool SaveRenderTextureToEXR32(RenderTexture rt,string contents, string pictureName)

    {
        RenderTexture prev = RenderTexture.active;

        RenderTexture.active = rt;
        
        Texture2D exr = new Texture2D(rt.width, rt.height, TextureFormat.RGBAFloat, false);
        
        exr.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        
        //需要注意unity EncodeToEXR 保存为32bitEXR格式时 需要设置EXRFloat的Flag
        byte[] bytes = exr.EncodeToEXR(Texture2D.EXRFlags.OutputAsFloat);

        if (!Directory.Exists(contents))

            Directory.CreateDirectory(contents);

        FileStream file = File.Open( contents + "/" + pictureName + ".exr", FileMode.Create);

        Debug.Log(contents + "/" + pictureName + ".exr");
        BinaryWriter writer = new BinaryWriter(file);

        writer.Write(bytes);

        file.Close();

        Texture2D.DestroyImmediate(exr);

        exr = null;

        RenderTexture.active = prev;

        return true;

    }
}
