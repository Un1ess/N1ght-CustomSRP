using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

[CreateAssetMenu(menuName = "Feature/SoulVisualDistortion")]
public class SoulVisualDistortion : ScriptableRendererFeature
{
    /// <summary>
    /// 通过RenderTexture.GetTemporary 获取RT
    /// </summary>
    /// <param name="rt"></param>
    /// <param name="width"></param>
    /// <param name="height"></param>
    /// <param name="format"></param>
    /// <param name="filterMode"></param>
    /// <param name="depthBits"></param>
    /// <param name="antiAliasing"></param>
    /// <returns></returns>
    public static bool EnsureRenderTarget(ref RenderTexture rt, int width, int height, RenderTextureFormat format,
        FilterMode filterMode, int depthBits = 0, int antiAliasing = 1)
    {
        if (rt != null && (rt.width != width || rt.height != height || rt.format != format ||
                           rt.filterMode != filterMode || rt.antiAliasing != antiAliasing))
        {
            RenderTexture.ReleaseTemporary(rt);
            rt = null;
        }

        if (rt == null)
        {
            rt = RenderTexture.GetTemporary(width, height, depthBits, format, RenderTextureReadWrite.Default,
                antiAliasing);
            rt.filterMode = filterMode;
            rt.wrapMode = TextureWrapMode.Clamp;
            return true; // new target
        }

        return false; // same target
    }

    public class SoulVisualDistortionPass : ScriptableRenderPass
    {
        public RenderTexture PrevColorTexture;

        private Material _heightMaskMat = null;
        private Material _distortionMaterial = null;
        private Material _kawaseBlurMat;
        public FilterMode FilterMode { get; set; }

        private SoulVisualDistortSettings _settings;
        private HeightMaskSettings _heightMaskSettings;
        private DistortionSettings _distortionSettings;
        private RenderTargetIdentifier Source { get; set; }
        private RenderTargetIdentifier Destination { get; set; }

        RenderTargetHandle _mTemporaryColorTexture;
        private RenderTargetHandle _mHeightMaskTexture;
        private RenderTargetHandle _mHeightMaskTempTexture1;
        private RenderTargetHandle _mHeightMaskTempTexture2;
        private RenderTargetHandle _mHeightMaskTempTextureScatter;
        

        string _mProfilerTag;

        private Matrix4x4 lastMatrix;

        // private RenderTexture heightMaskRT;
        public SoulVisualDistortionPass(RenderPassEvent renderPassEvent, SoulVisualDistortSettings settings,
            DistortionSettings distortionSettings,
            HeightMaskSettings heightMaskSettings, string tag)
        {
            this.renderPassEvent = renderPassEvent;
            this._settings = settings;
            this._heightMaskSettings = heightMaskSettings;
            this._distortionSettings = distortionSettings;
            _mProfilerTag = tag;
            _mTemporaryColorTexture.Init("_TemporaryColorTexture");
            _mHeightMaskTempTexture1.Init("_heightMaskTempRT1");
            _mHeightMaskTempTexture2.Init("_heightMaskTempRT2");
            _mHeightMaskTexture.Init("_HeightMaskTex");
            _mHeightMaskTempTextureScatter.Init("m_HeightMaskTempTexture_Scatter");
        }

        private void InitMaterial(SoulVisualDistortSettings settings)
        {
            if (_distortionMaterial == null)
            {
                _distortionMaterial = new Material(settings.distortionShader);
            }

            if (_heightMaskMat == null)
            {
                _heightMaskMat = new Material(settings.heightMaskShader);
            }

            if (_kawaseBlurMat == null)
                _kawaseBlurMat = new Material(Shader.Find("SoulVisual/KawaseBlur"));
        }

        public void Setup(RenderTargetIdentifier source, RenderTargetIdentifier destination,
            Texture2D heightMask, Vector4 heightMapCenterRange, float heightMapDepth)
        {
            this.Source = source;
            this.Destination = destination;
            
            //PG项目中直接引用Depth图
            // ConfigureInput(ScriptableRenderPassInput.Depth);
            InitMaterial(_settings);
            _heightMaskMat.SetTexture(_heightMapID, heightMask);
            _heightMaskMat.SetVector(_heightMapCenterRangeID, heightMapCenterRange);
            _heightMaskMat.SetFloat(_heightMapDepthID, heightMapDepth);

            _distortionMaterial.SetVector(_heightMapCenterRangeID, heightMapCenterRange);
            _distortionMaterial.SetFloat(_heightMapDepthID, heightMapDepth);
            SetMaterialProperty();
        }

        private void SetMaterialProperty()
        {
            _heightMaskMat.SetFloat(_depthZoomFactorID, _heightMaskSettings.depthZoomFactor);
            _heightMaskMat.SetFloat(_heightMinRangeID, _heightMaskSettings.heightMinRange);
            _heightMaskMat.SetFloat(_heightMaxRangeID, _heightMaskSettings.heightMaxRange);
            _heightMaskMat.SetFloat(_heightClampRangeID, _heightMaskSettings.heightClampRange);

            _distortionMaterial.SetFloat(_prevTexWeightID, _distortionSettings.prevTexWeight);
            _distortionMaterial.SetTexture(_distortionTexID, _distortionSettings.distortionTex);
            _distortionMaterial.SetTexture(_spotsNoiseTexID, _distortionSettings.spotsNoiseTex);
            _distortionMaterial.SetTexture(_maskNoiseTexID, _distortionSettings.maskNoiseTex);
            _distortionMaterial.SetTexture(_colorNoiseTexID, _distortionSettings.colorNoiseTex);
            _distortionMaterial.SetTexture("_GalaxyTex", _distortionSettings.galaxyTex);
            _distortionMaterial.SetFloat(_distortionTexTilingID, _distortionSettings.distortionTexTiling);
            _distortionMaterial.SetFloat(_distortionTexTiling2ID, _distortionSettings.distortionTexTiling2);
            _distortionMaterial.SetFloat(_maskNoiseTexTilingID, _distortionSettings.maskNoiseTexTiling);
            _distortionMaterial.SetFloat(_spotsNoiseTilingWsid, _distortionSettings.spotsNoiseTexTilingWS);
            _distortionMaterial.SetVector(_blurDirectionID, _distortionSettings.blurDirection);
            _distortionMaterial.SetFloat(_distortNoiseWeightID, _distortionSettings.distortNoiseWeight);
            _distortionMaterial.SetFloat(_distortIntID, _distortionSettings.distortInt);
            _distortionMaterial.SetFloat(_depthZoomFactorID, _distortionSettings.depthZoomFactor);
            _distortionMaterial.SetFloat(_depthMin1ID, _distortionSettings.depthMin1);
            _distortionMaterial.SetFloat(_depthMax1ID, _distortionSettings.depthMax1);
            _distortionMaterial.SetFloat(_depthMin2ID, _distortionSettings.depthMin2);
            _distortionMaterial.SetFloat(_nearbyDepthMin1ID, _distortionSettings.nearbyDepthMin1);
            _distortionMaterial.SetFloat(_nearbyDepthMaxID, _distortionSettings.nearbyDepthMax);
            _distortionMaterial.SetFloat(_nearbyDepthMin2ID, _distortionSettings.nearbyDepthMin2);
            _distortionMaterial.SetFloat(_depthMax2ID, _distortionSettings.depthMax2);
            _distortionMaterial.SetColor(_distortRimColorID, _distortionSettings.distortColor);
            _distortionMaterial.SetColor(_distortFloorColorID, _distortionSettings.distortFloorColor);
            _distortionMaterial.SetColor(_skyRimColorID, _distortionSettings.skyRimColor);
            _distortionMaterial.SetColor(_distantColorID, _distortionSettings.distantColor);
            _distortionMaterial.SetFloat(_heightMinRangeID, _heightMaskSettings.heightMinRange);
            _distortionMaterial.SetFloat(_spotsNoiseRangeMinID, _distortionSettings.spotsNoiseRangeMin);
            _distortionMaterial.SetFloat(_spotsNoiseRangeMaxID, _distortionSettings.spotsNoiseRangeMax);
            _distortionMaterial.SetFloat(_colorNoiseTilingID, _distortionSettings.colorNoiseTexTiling);
            _distortionMaterial.SetFloat(_distortionTexTilingMaskID, _distortionSettings.distortionTexTiling_Mask);
            
            //方向模糊配置
            float sinVal = (Mathf.Sin(_settings.directionalBlurAngle) * _settings.directionalBlurRadius * 0.05f) / _settings.directionalBlurIteration;
            float cosVal = (Mathf.Cos(_settings.directionalBlurAngle) * _settings.directionalBlurRadius * 0.05f) / _settings.directionalBlurIteration;
            Vector3 directionalBlurParams = new Vector3(_settings.directionalBlurIteration, sinVal, cosVal);
            _kawaseBlurMat.SetVector(_directionBlurParamsID,directionalBlurParams);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(_mProfilerTag);

            RenderTextureDescriptor opaqueDesc = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDesc.depthBufferBits = 0;

            int bufferW = opaqueDesc.width;
            int bufferH = opaqueDesc.height;

            EnsureRenderTarget(ref PrevColorTexture, bufferW, bufferH,
                opaqueDesc.colorFormat,
                FilterMode.Bilinear);

            PrevColorTexture.name = "_PrevRT";
            
            Matrix4x4 projMatrix = GL.GetGPUProjectionMatrix(renderingData.cameraData.GetProjectionMatrix(), false);
            var viewProj = projMatrix * renderingData.cameraData.GetViewMatrix();
            _distortionMaterial.SetMatrix(_clipToLastClipID, lastMatrix * viewProj.inverse);
            lastMatrix = viewProj;
            
            

            if (Source == Destination)
            {
                int heightMaskW = (int) (opaqueDesc.width / 2f);
                int heightMaskH = (int) (opaqueDesc.height / 2f);
                cmd.GetTemporaryRT(_mHeightMaskTexture.id, heightMaskW, heightMaskH, 0, FilterMode);
                //生成初始高度mask
                Blit(cmd, Source, _mHeightMaskTexture.Identifier(), _heightMaskMat, 0);
                cmd.GetTemporaryRT(_mHeightMaskTempTexture1.id, heightMaskW, heightMaskH, 0, FilterMode);
                cmd.GetTemporaryRT(_mHeightMaskTempTexture2.id, heightMaskW, heightMaskH, 0, FilterMode);
                cmd.GetTemporaryRT(_mHeightMaskTempTextureScatter.id, heightMaskW, heightMaskH, 0, FilterMode);
                //同时拷贝一份
                Blit(cmd, _mHeightMaskTexture.Identifier(), _mHeightMaskTempTextureScatter.Identifier());
                //扩展像素
                Blit(cmd, _mHeightMaskTexture.Identifier(), _mHeightMaskTempTexture2.Identifier(), _kawaseBlurMat, 0);

                //方向模糊
                Blit(cmd, _mHeightMaskTempTexture2.Identifier(), _mHeightMaskTempTexture1.Identifier(), _kawaseBlurMat, 3);
                
                //高斯模糊
                for (int i = 0; i < _settings.blurIterationNum; i++)
                {
                    Blit(cmd, _mHeightMaskTempTexture1.Identifier(), _mHeightMaskTempTexture2.Identifier(),
                        _kawaseBlurMat, 4);
                    Blit(cmd, _mHeightMaskTempTexture2.Identifier(), _mHeightMaskTempTexture1.Identifier(),
                        _kawaseBlurMat, 5);
                }
                
                //低次数迭代 kawase有马赛克
                // float maskOffset = _settings.blurRadius;
                // // kawaseBlurMat.SetFloat("_KawaseOffset",offset);//不能用materia.setFloat来设置半径 因为它会立即执行 而不是按照次序执行
                // cmd.SetGlobalFloat("_KawaseOffset_Mask", maskOffset);
                // for (int i = 0; i < _settings.blurIterationNum; i++)
                // {
                //     maskOffset += 1.0f;
                //     cmd.SetGlobalFloat("_KawaseOffset_Mask", maskOffset);
                //     Blit(cmd, _mHeightMaskTempTexture1.Identifier(), _mHeightMaskTempTexture2.Identifier(),
                //         _kawaseBlurMat, 1);
                //     Blit(cmd, _mHeightMaskTempTexture2.Identifier(), _mHeightMaskTempTexture1.Identifier(),
                //         _kawaseBlurMat, 1);
                // }

                Blit(cmd, _mHeightMaskTempTexture1.Identifier(), _mHeightMaskTexture.Identifier());
                cmd.SetGlobalTexture("_HeightMaskTex", _mHeightMaskTexture.Identifier());

                //KawaseBlue --> Scatter
                float scatterOffset = _settings.scatterRadius;
                cmd.SetGlobalFloat("_KawaseOffset_Scatter", scatterOffset);
                Blit(cmd, _mHeightMaskTempTextureScatter.Identifier(), _mHeightMaskTempTexture1.Identifier());
                for (int i = 0; i < _settings.scatterIteration; i++)
                {
                    scatterOffset += 1.0f;
                    cmd.SetGlobalFloat("_KawaseOffset_Scatter", scatterOffset);
                    Blit(cmd, _mHeightMaskTempTexture1.Identifier(), _mHeightMaskTempTexture2.Identifier(),
                        _kawaseBlurMat, 2);
                    Blit(cmd, _mHeightMaskTempTexture2.Identifier(), _mHeightMaskTempTexture1.Identifier(),
                        _kawaseBlurMat, 2);
                }
                Blit(cmd, _mHeightMaskTempTexture1.Identifier(), _mHeightMaskTempTextureScatter.Identifier());
                cmd.SetGlobalTexture("_HeightMaskScatter", _mHeightMaskTempTextureScatter.Identifier());

                cmd.GetTemporaryRT(_mTemporaryColorTexture.id, opaqueDesc, FilterMode);
                Blit(cmd, Source, _mTemporaryColorTexture.Identifier(), _distortionMaterial,
                    _settings.blitMaterialPassIndex);
                Blit(cmd, _mTemporaryColorTexture.Identifier(), Destination);
            }
            Blit(cmd, Destination, PrevColorTexture);
            //cmd.SetGlobalTexture("_PrevColorTex",prevId);	
            _distortionMaterial.SetTexture("_PrevColorTex", PrevColorTexture);
            

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(_mTemporaryColorTexture.id);
            cmd.ReleaseTemporaryRT(_mHeightMaskTempTexture1.id);
            cmd.ReleaseTemporaryRT(_mHeightMaskTempTexture2.id);
            cmd.ReleaseTemporaryRT(_mHeightMaskTexture.id);
            cmd.ReleaseTemporaryRT(_mHeightMaskTempTextureScatter.id);
        }

        /// <summary>
        /// custom dispose function
        /// </summary>
        public void Dispose()
        {
            CoreUtils.Destroy(_heightMaskMat);
            CoreUtils.Destroy(_kawaseBlurMat);
            CoreUtils.Destroy(_distortionMaterial);
        }

        private readonly int _heightMapCenterRangeID = Shader.PropertyToID("_HeightMapCenterRange");
        private readonly int _heightMapDepthID = Shader.PropertyToID("_HeightMapDepth");
        private readonly int _heightMapID = Shader.PropertyToID("_HeightMap");
        private readonly int _depthZoomFactorID = Shader.PropertyToID("_DepthZoomFactor");
        private readonly int _heightMinRangeID = Shader.PropertyToID("_HeightMinRange");
        private readonly int _heightMaxRangeID = Shader.PropertyToID("_HeightMaxRange");
        private readonly int _heightClampRangeID = Shader.PropertyToID("_HeightClampRange");
        private readonly int _prevTexWeightID = Shader.PropertyToID("_PrevTexWeight");
        private readonly int _distortionTexID = Shader.PropertyToID("_DistortionTex");
        private readonly int _spotsNoiseTexID = Shader.PropertyToID("_SpotsNoiseTex");
        private readonly int _maskNoiseTexID = Shader.PropertyToID("_MaskNoiseTex");
        private readonly int _colorNoiseTexID = Shader.PropertyToID("_ColorNoiseTex");
        private readonly int _distortionTexTilingID = Shader.PropertyToID("_DistortionTexTiling");
        private readonly int _distortionTexTiling2ID = Shader.PropertyToID("_DistortionTexTiling2");
        private readonly int _distortionTexTilingMaskID = Shader.PropertyToID("_DistortionTexTiling_Mask");
        private readonly int _maskNoiseTexTilingID = Shader.PropertyToID("_MaskNoiseTexTiling");
        private readonly int _spotsNoiseTilingWsid = Shader.PropertyToID("_SpotsNoiseTilingWS");
        private readonly int _blurDirectionID = Shader.PropertyToID("_BlurDirection");
        private readonly int _distortNoiseWeightID = Shader.PropertyToID("_DistortNoiseWeight");
        private readonly int _distortIntID = Shader.PropertyToID("_DistortInt");
        private readonly int _depthMin1ID = Shader.PropertyToID("_DepthMin1");
        private readonly int _depthMax1ID = Shader.PropertyToID("_DepthMax1");
        private readonly int _depthMin2ID = Shader.PropertyToID("_DepthMin2");
        private readonly int _depthMax2ID = Shader.PropertyToID("_DepthMax2");
        private readonly int _nearbyDepthMin1ID = Shader.PropertyToID("_NearbyDepthMin1");
        private readonly int _nearbyDepthMaxID = Shader.PropertyToID("_NearbyDepthMax");
        private readonly int _nearbyDepthMin2ID = Shader.PropertyToID("_NearbyDepthMin2");
        private readonly int _distortRimColorID = Shader.PropertyToID("_DistortRimColor");
        private readonly int _distortFloorColorID = Shader.PropertyToID("_DistortFloorColor");
        private readonly int _skyRimColorID = Shader.PropertyToID("_SkyRimColor");
        private readonly int _distantColorID = Shader.PropertyToID("_DistantColor");
        private readonly int _buildingColorID = Shader.PropertyToID("_BuildingColor");
        private readonly int _spotsNoiseRangeMinID = Shader.PropertyToID("_SpotsNoiseRangeMin");
        private readonly int _spotsNoiseRangeMaxID = Shader.PropertyToID("_SpotsNoiseRangeMax");
        private readonly int _colorNoiseTilingID = Shader.PropertyToID("_ColorNoiseTiling");
        private readonly int _clipToLastClipID = Shader.PropertyToID("_ClipToLastClip");
        private readonly int _directionBlurParamsID = Shader.PropertyToID("_DirectionBlurParams");
    }

    /// <summary>
    /// Blur
    /// </summary>
    [System.Serializable]
    public class SoulVisualDistortSettings
    {
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

        public Shader heightMaskShader = null;
        public Shader distortionShader = null;

        public int blitMaterialPassIndex = 0;
        //因为使用的是高斯模糊 我没有给高斯模糊算法设置半径 所以先隐藏此参数
        [HideInInspector][Range(0, 25)] public float blurRadius = 0.1f;
        [Range(0, 10)] public int blurIterationNum = 2;
        [Range(0, 25)] public float scatterRadius = 9.7f;
        [Range(0, 15)] public int scatterIteration = 6;
        //方向模糊
        [Range(0, 35)] public int directionalBlurIteration = 22;
        [Range(0, 15)] public float directionalBlurRadius = 0.25f;
        [Range(0.0f, 6.0f)] public float directionalBlurAngle =  3.1f;
        
        public bool overrideGraphicsFormat = false;
        public UnityEngine.Experimental.Rendering.GraphicsFormat graphicsFormat;
    }

    
    /// <summary>
    /// 
    /// </summary>
    [System.Serializable]
    public class HeightMaskSettings
    {
        [HideInInspector][Range(0.001f, 2f)] public float depthZoomFactor = 1f;
        [Range(0.0f, 1f)] public float heightMinRange = 0.545f;

        [InspectorName("极远处某一范围以上 算在高度mask中")][Range(0.0f, 10f)]
        public float heightMaxRange = 2.4f;

        [Range(0.1f, 5f)] public float heightClampRange = 0.56f;
    }

    [System.Serializable]
    public class DistortionSettings
    {
        [InspectorName("混合上一帧的权重系数" )][Range(0.1f, 1f)]
        public float prevTexWeight = 0.965f;

        [InspectorName("扭曲贴图(要求是法线贴图)")] public Texture2D distortionTex;

        [InspectorName("对于上一帧扭曲，采样Tiling值")][Range(0.1f, 10f)]
        public float distortionTexTiling = 3.33f;

        [InspectorName("对于Mask部分的噪声图 采样Tiling值")][Range(0.1f, 10f)]
        public float distortionTexTiling_Mask = 1.11f;
        
        [InspectorName("对于全屏幕扭曲，采样Tiling值" )][Range(0.1f, 10f)]
        public float distortionTexTiling2 = 0.66f;

        [InspectorName("模糊方向")] public Vector4 blurDirection = new Vector4(0, -25, 0, 0);

        [InspectorName("插值模糊方向与扭曲贴图的权重")][Range( 0f, 1f)]
        public float distortNoiseWeight = 0.767f;

        [InspectorName("扭曲强度")] public float distortInt = 1.2f;
        
        [InspectorName("Mask部分的噪声图")] public Texture2D maskNoiseTex;

        [InspectorName("Mask部分上添加的噪声采样Tiling值")][Range( 0.1f, 10f)]
        public float maskNoiseTexTiling = 1.47f;
        
        
        [InspectorName("点状噪声图")] public Texture2D spotsNoiseTex;
        [InspectorName("对于地面扭曲：点状噪声图世界空间采样比例")][Range( 1f, 50f)]
        public float spotsNoiseTexTilingWS = 19.0f;
        

        [InspectorName("点噪声范围 min")][Range( 0f, 1f)] public float spotsNoiseRangeMin = 0.016f;
        [InspectorName("点噪声范围 max")][Range( 0f, 1f)] public float spotsNoiseRangeMax = 0.231f;
        [InspectorName("深度缩放因子")][Range( 0.0001f, 2f)] public float depthZoomFactor = 1f;

        [InspectorName("远景深度范围 min1")][Range( 0f, 1f)] public float depthMin1 = 0.142f;
        [InspectorName("远景深度范围 max1")][Range( 0f, 1f)] public float depthMax1 = 0.393f;
        [InspectorName("远景深度范围 min2")][Range( 0f, 1f)] public float depthMin2 = 0.418f;
        [InspectorName("远景深度范围 max2")][Range( 0f, 1f)] public float depthMax2 = 0.619f;

        [InspectorName("近景深度范围 min1")][Range( 0f, 1f)] public float nearbyDepthMin1 = 0.0f;
        [InspectorName("近景深度范围 max1")][Range( 0f, 1f)] public float nearbyDepthMax = 0.034f;
        [InspectorName("近景深度范围 min2")] public float nearbyDepthMin2 = 0.081f;

        //和雾 配合 取舍!!!
        [InspectorName("远景颜色")] [ColorUsageAttribute(true, true)]
        public Color distantColor = Color.gray;

        [ColorUsageAttribute(true, true)] public Color distortColor = Color.white;

        [ColorUsageAttribute(true, true)]
        [InspectorName("地面扰动颜色")]  public Color distortFloorColor = Color.white;

        [ColorUsageAttribute(true, true)] public Color skyRimColor = Color.white;
        [InspectorName("星空遮罩噪声图")] public Texture2D colorNoiseTex;

        [InspectorName("星空遮罩噪声图采样Tiling值")][Range(0.001f, 5f)]
        public float colorNoiseTexTiling;
        
        //星空图最好4方连续
        [InspectorName("星空")] public Texture2D galaxyTex;
    }

    public SoulVisualDistortSettings settings = new SoulVisualDistortSettings();
    public HeightMaskSettings heightMaskSettings = new HeightMaskSettings();
    public DistortionSettings distortionSettings = new DistortionSettings();

    public SoulVisualDistortionPass blitPass;

    private RenderTargetIdentifier srcIdentifier, dstIdentifier;

    //DistortionHeightTexFetch 脚本传入 或 手动传入
    public Texture2D heightMask;
    public Vector4 heightMapCenterRange;
    public float heightMapDepth;


    public override void Create()
    {
        settings.blitMaterialPassIndex = Mathf.Clamp(settings.blitMaterialPassIndex, -1, 0);
        blitPass = new SoulVisualDistortionPass(settings.Event, settings, distortionSettings, heightMaskSettings, name);
        if (settings.heightMaskShader == null)
        {
            settings.heightMaskShader = Shader.Find("distortion/HeightMask");
        }

        if (settings.distortionShader == null)
        {
            settings.distortionShader = Shader.Find("distortion/Distortion");
        }

        if (settings.Event == RenderPassEvent.AfterRenderingPostProcessing)
        {
            Debug.LogWarning(
                "Note that the \"After Rendering Post Processing\"'s Color target doesn't seem to work? (or might work, but doesn't contain the post processing) :( -- Use \"After Rendering\" instead!");
        }

        // InitTexture();

        if (settings.graphicsFormat == UnityEngine.Experimental.Rendering.GraphicsFormat.None)
        {
            settings.graphicsFormat =
                SystemInfo.GetGraphicsFormat(UnityEngine.Experimental.Rendering.DefaultFormat.LDR);
        }
    }


    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.Event == RenderPassEvent.AfterRenderingPostProcessing)
        {
        }
        else if (settings.Event == RenderPassEvent.AfterRendering && renderingData.postProcessingEnabled)
        {
        }
        var src = renderer.cameraColorTarget;
        var dest = renderer.cameraColorTarget;

        blitPass.Setup(src, dest, heightMask, heightMapCenterRange, heightMapDepth);
        renderer.EnqueuePass(blitPass);
    }

    protected  void Dispose(bool disposing)
    {
        ///base.Dispose(disposing);
        blitPass.Dispose();
    }
    
    
}