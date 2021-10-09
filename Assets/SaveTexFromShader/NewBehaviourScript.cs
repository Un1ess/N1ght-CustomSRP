using UnityEditor;
using UnityEngine;

public class NewBehaviourScript
{
    static UnityEngine.Object targetObj;
    [MenuItem("Tools/Texture/RGBAFloat")]
    static void trysee()
    {
        targetObj = Selection.activeObject;//这个函数可以得到你选中的对象
        if (targetObj && targetObj is Texture)
        {
            string[] platforms = { "Standalone" };
            string path = AssetDatabase.GetAssetPath(targetObj);
            Debug.Log(path);
            TextureImporter texture = AssetImporter.GetAtPath(path) as TextureImporter;
            texture.textureType = TextureImporterType.Default;
            texture.filterMode = FilterMode.Point;
            texture.isReadable = true;
            texture.mipmapEnabled = false;
            //texture.textureFormat = TextureImporterFormat.RGBAFloat;
            TextureImporterPlatformSettings tips = new TextureImporterPlatformSettings();
            tips.name = "Standalone";
            tips.overridden = true;
            
            tips.format = TextureImporterFormat.RGBAFloat;
            tips.textureCompression = TextureImporterCompression.Uncompressed;
           
            // for (int i = 0; i < platforms.Length; i++) {
            //     texture.SetPlatformTextureSettings(tips);
            // }
            texture.SetPlatformTextureSettings(tips);
            Debug.Log(tips.name);
            texture.SaveAndReimport();
            //AssetDatabase.ImportAsset(path);
        }
    }
}

