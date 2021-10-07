using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode]
public class SaveTex : MonoBehaviour
{
    

    public SaveFile saveFile;
    public Shader shader;
    public Material mat;
    public string foldername;
    public string pictureName;
    public Texture tex;
    public bool enableSave = false;

    public Texture m_Tex;
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
        m_Tex = new Texture2D(tex.width, tex.height, TextureFormat.RGBAFloat, false);
        
        Debug.Log("m_Tex.Format: "+m_Tex.graphicsFormat);
    }

    // Update is called once per frame
    void Update()
    {
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
                    SaveRenderTextureToEXR32(tex, mat, contents, pictureName);
                    break;
                    
            }
        }

        bool supportOrNot =  SystemInfo.SupportsTextureFormat(TextureFormat.RGBAFloat);
        //Debug.Log(supportOrNot);
        Debug.Log(tex.graphicsFormat);

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
