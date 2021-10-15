using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class Ripple : MonoBehaviour
{
    public Camera mainCamera;
    public RenderTexture prevRenderTexture;
    public RenderTexture currentRenderTexture;
    public RenderTexture tempRenderTexture;
    public RenderTexture tempRenderTexture2;
    public int rtSize = 1024;
    public Shader drawRippleShader;
    public Shader drawHeightShader;
    private Material drawRippleMat;
    private Material drawHeightMat;
    public LayerMask hitLayer = 5;
    public float radius = 0.1f;

    public GameObject mainInteractiveObj;
    private Vector3 lastMousePos;
    private Vector3 lastObjectPos;

    public float ScaleMapping = 0.5f;
    
    public bool isOpenWave = false;
    // Start is called before the first frame update
    void Start()
    {

        #region 使用 RenderTexture构造函数新建rt

        prevRenderTexture = new RenderTexture(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        currentRenderTexture = new RenderTexture(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        tempRenderTexture = new RenderTexture(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        tempRenderTexture2 = new RenderTexture(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        prevRenderTexture.wrapMode = TextureWrapMode.Clamp;
        currentRenderTexture.wrapMode = TextureWrapMode.Clamp;
        tempRenderTexture.wrapMode = TextureWrapMode.Clamp;
        tempRenderTexture2.wrapMode = TextureWrapMode.Clamp;
        ////rendertexture.Create(); //没有实际作用

            #endregion

        #region 使用 GetTemporary 获取Rt
        // prevRenderTexture = RenderTexture.GetTemporary(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        // prevRenderTexture.name = "PrevRT";
        // currentRenderTexture = RenderTexture.GetTemporary(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        // currentRenderTexture.name = "CurrRT";
        // tempRenderTexture = RenderTexture.GetTemporary(rtSize,rtSize,0,RenderTextureFormat.RFloat);
        // tempRenderTexture.name = "TempRT";
        
            #endregion
        mainCamera = Camera.main;
        drawRippleShader = Shader.Find("RTstudy/DrawRipple");
        drawHeightShader = Shader.Find("RTstudy/DrawHeight");
        drawRippleMat = new Material(drawRippleShader);
        drawHeightMat = new Material(drawHeightShader);
        GetComponent<Renderer>().material.mainTexture = currentRenderTexture;
        lastObjectPos = mainInteractiveObj.transform.position;
    }
    
    /// <summary>
    /// 绘制交互信息
    /// </summary>
    /// <param name="x"></param>
    /// <param name="y"></param>
    /// <param name="radius">半径</param>
    private void CurrRT(float x,float y,float radius)
    {
        //设置材质球参数

        //drawRippleMat.SetTexture("_MainTex",currentRenderTexture);
        drawRippleMat.SetVector("_PosUV",new Vector4(x,y,radius));
        //Graphics.Blit(null,currentRenderTexture,drawRippleMat);
        //Blit 绘制到TempRT
        Graphics.Blit(currentRenderTexture,tempRenderTexture,drawRippleMat);
        
        //Switch RenderTexure
        //为什么在FrameDebugger中看不到绘制过程？
        //答：应该是FrameDebugger Enable后 暂停了游戏运行，此时没有TempRt被绘制
        RenderTexture rt = tempRenderTexture;
        tempRenderTexture = currentRenderTexture; 
        currentRenderTexture = rt;

        //RenderTexture.active = prev;

    }
    // Update is called once per frame
    void Update()
    {
        drawRippleMat.SetFloat("_ScaleMapping",ScaleMapping);
        if (Input.GetMouseButton(0))
        {
            Ray ray = mainCamera.ScreenPointToRay(Input.mousePosition);
            RaycastHit hitinfo;
            if (Physics.Raycast(ray, out hitinfo,1000.0f, hitLayer))
            {
                if ((hitinfo.point - lastMousePos).sqrMagnitude > 0.0001f)
                {
                    drawRippleMat.SetVector("_DeltaPosWS",
                        hitinfo.point-lastMousePos);
                    Debug.Log("_DeltaPosWSDistance: "+(hitinfo.point - lastMousePos).sqrMagnitude );
                    //射线碰撞点的uv坐标
                    //RaycastHit.textureCoord 只有在MeshCollide下才会生效
                    // drawRippleMat.SetVector("_PosWS",new Vector4(
                    //     hitinfo.point.x,hitinfo.point.y,hitinfo.point.z,0));
                    Debug.Log("WS hit.x: "+hitinfo.point.x );
                    CurrRT(hitinfo.textureCoord.x,hitinfo.textureCoord.y,radius);

                    lastMousePos = hitinfo.point;
                }
                
            }
        }
    
        if (Vector3.Distance(mainInteractiveObj.transform.position , lastObjectPos) > 0.001f)
        {
            Shader.SetGlobalVector("_MainTriggerPosWS", mainInteractiveObj.transform.position);
            drawHeightMat.SetVector("_DeltaPosWS",
                mainInteractiveObj.transform.position - lastObjectPos);
            drawRippleMat.SetVector("_DeltaPosWS",
                mainInteractiveObj.transform.position - lastObjectPos);
            drawRippleMat.SetVector("_PosWS", mainInteractiveObj.transform.position);
            CurrRT(1,1,radius);
            lastObjectPos = mainInteractiveObj.transform.position;

        }
        #region 涟漪

        if (isOpenWave)
        {
            //计算涟漪
            //计算涟漪的方法写在了drawHeight Shader里 主要是依靠像素计算得到的
            //材质球赋值
            drawHeightMat.SetTexture("_PrevTex",prevRenderTexture);
            drawHeightMat.SetTexture("_CurrTex",currentRenderTexture);
            //绘制RT
            Graphics.Blit(null,tempRenderTexture,drawHeightMat);
            Graphics.Blit(tempRenderTexture,prevRenderTexture);
            //Switch PrevRT and CurrRT
            RenderTexture rtt = prevRenderTexture;
            prevRenderTexture = currentRenderTexture; //将上一帧的curr赋予给当前帧的prevRT
            currentRenderTexture = rtt; //此时真正的当前帧
        }
        

        

        #endregion
        
    }

    
    private void OnDestroy()
    {
        prevRenderTexture.Release();
        currentRenderTexture.Release();
        tempRenderTexture.Release();
        tempRenderTexture2.Release();
        Debug.Log("结束");
    }
}
