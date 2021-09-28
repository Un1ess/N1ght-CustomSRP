using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class SaveTexFromShader : MonoBehaviour
{
    public bool enableSave = false;
    public int size = 1024;

    private Material _material;
    // Start is called before the first frame update
    void Start()
    {
        _material = GetComponent<Renderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        if (enableSave)
        {
            enableSave = false; 
            SaveTexture();
        }
    }

    void SaveTexture()
    {
        Debug.Log("保存");
        RenderTexture rt = new RenderTexture(size, (int) size, 0);
        CommandBuffer cmd = new CommandBuffer();
        cmd.Blit(null,rt,_material);
        Texture2D newTexture = new Texture2D(size, size, TextureFormat.ARGB32, false);
        RenderTexture.active = rt;
        newTexture.ReadPixels(new Rect(0,0,size,size),0,0);
        newTexture.Apply();
        byte[] bytes = newTexture.EncodeToPNG();
        FileStream file = File.Open(Application.dataPath+"/test.png", FileMode.Create);
        BinaryWriter binary = new BinaryWriter( file );
        binary.Write(bytes);
        file.Close();
        //rt.Release();
    }
}
