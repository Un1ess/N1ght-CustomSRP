using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

[ExecuteInEditMode]
public class SaveTex : MonoBehaviour
{
    public Shader shader;
    public string foldername;
    public string pngName;
    public Texture tex;
    public bool enableSave = false;
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
            SaveRenderTextureToPNG(tex, shader, Application.dataPath+"/"+foldername, pngName);
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

//将RenderTexture保存成一张png图片

    public bool SaveRenderTextureToPNG(RenderTexture rt,string contents, string pngName)

    {
        RenderTexture prev = RenderTexture.active;

        RenderTexture.active = rt;

        Texture2D png = new Texture2D(rt.width, rt.height, TextureFormat.ARGB32, false);

        png.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);

        byte[] bytes = png.EncodeToPNG();

        if (!Directory.Exists(contents))

            Directory.CreateDirectory(contents);

        FileStream file = File.Open( contents + "/" + pngName + ".png", FileMode.Create);

        Debug.Log(contents + "/" + pngName + ".png");
        BinaryWriter writer = new BinaryWriter(file);

        writer.Write(bytes);

        file.Close();

        Texture2D.DestroyImmediate(png);

        png = null;

        RenderTexture.active = prev;

        return true;

    }
}
