using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SeparableSSS : ScriptableRendererFeature
{
    [System.Serializable]
    public class Setting
    {
        //标记头发模型的Layer
        public LayerMask SubsurfaceScattingLayer;

        //Render Opaque的设置
        [Range(1000, 5000)]
        public int queueMin = 2000;
        [Range(1000, 5000)]
        public int queueMax = 3000;
        //public Texture2D BlueNoise;
        [Range(0,2)] public float SubsurfaceScaler = 0.25f;
        [ColorUsage(false, false)] public Color SubsurfaceColor = Color.black;
        [ColorUsage(false, false)] public Color SubsurfaceFalloff = Color.black;
        //使用Material
        public Material material;

    }

    public Setting settings = new Setting();

    class DrawSkinColorPass : ScriptableRenderPass
    {
        Setting curSetting = new Setting();
        SeparableSSS separableSSS = null;
        ShaderTagId renderTagId = new ShaderTagId("SeparableSkinPrePass");//只有在这个标签LightMode对应的shader才会被绘制
        FilteringSettings filter;

        static int rawSkinColorID = Shader.PropertyToID("_RawSkinColor");
        

        public DrawSkinColorPass(Setting setting, SeparableSSS separableSSSRender)
        {
            curSetting = setting;
            separableSSS = separableSSSRender;
            //过滤设定
            RenderQueueRange queue = new RenderQueueRange();
            queue.lowerBound = Mathf.Min(curSetting.queueMax, curSetting.queueMin);
            queue.upperBound = Mathf.Max(curSetting.queueMax, curSetting.queueMin);
            filter = new FilteringSettings(queue, curSetting.SubsurfaceScattingLayer);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            cmd.GetTemporaryRT(rawSkinColorID, desc);
            ConfigureTarget(rawSkinColorID);
            ConfigureClear(ClearFlag.All,Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("RawSkinColorPass");
            var drawSetting = CreateDrawingSettings(renderTagId, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);

            context.DrawRenderers(renderingData.cullResults, ref drawSetting, ref filter);
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

    }

    class BlurSSSSPass: ScriptableRenderPass
    {
        Setting curSetting = new Setting();
        SeparableSSS separableSSS = null;
        RenderTargetIdentifier source;
        static int sourceID = Shader.PropertyToID("_SourceColor");
        static int tempTargetID = Shader.PropertyToID("_SeparableSSColor");
        static private List<Vector4> KernelArray = new List<Vector4>();
        static int SSSSSColorID = Shader.PropertyToID("_SubsurfaceColor");
        static int Kernel = Shader.PropertyToID("_Kernel");
        static int SSSScaler = Shader.PropertyToID("_SSSScale");
        static int screenSize = Shader.PropertyToID("_screenSize");
        static int loopCount = Shader.PropertyToID("_loopCount");


        public BlurSSSSPass(Setting setting, SeparableSSS render, RenderTargetIdentifier source)
        {
            curSetting = setting;
            separableSSS = render;
            this.source = source;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            cmd.GetTemporaryRT(sourceID, desc);
            cmd.GetTemporaryRT(tempTargetID, desc);
            ConfigureTarget(tempTargetID);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get("SeparableSSSMixingPass");
            
            cmd.CopyTexture(source, sourceID);

            Vector3 SSSC = Vector3.Normalize(new Vector3(
                   curSetting.SubsurfaceColor.r,
                   curSetting.SubsurfaceColor.g,
                   curSetting.SubsurfaceColor.b));
            Vector3 SSSFC = Vector3.Normalize(new Vector3(
                curSetting.SubsurfaceFalloff.r,
                curSetting.SubsurfaceFalloff.g,
                curSetting.SubsurfaceFalloff.b));
            SeparableSSSLibrary.CalculateKernel(KernelArray, 25, SSSC, SSSFC);
            Vector2 jitterSample = GenerateRandomOffset();
            cmd.SetGlobalVector(screenSize, new Vector4((float)renderingData.cameraData.cameraTargetDescriptor.width, (float)renderingData.cameraData.cameraTargetDescriptor.height, 0, 0));
            cmd.SetGlobalVectorArray(Kernel, KernelArray);
            cmd.SetGlobalFloat(SSSScaler, curSetting.SubsurfaceScaler);
            cmd.SetGlobalFloat("_RandomSeed", Random.Range(0, 100));

            cmd.Blit(source, tempTargetID, curSetting.material, 0);
            cmd.Blit(tempTargetID, sourceID, curSetting.material, 1);
            cmd.SetGlobalTexture(sourceID, sourceID);
            ConfigureTarget(source);
            ConfigureClear(ClearFlag.Color, Color.black);
            context.ExecuteCommandBuffer(cmd);
            cmd.ReleaseTemporaryRT(sourceID);
            cmd.ReleaseTemporaryRT(tempTargetID);
            
            CommandBufferPool.Release(cmd);
        }

        ///// Cleanup any allocated resources that were created during the execution of this render pass.
        //public override void FrameCleanup(CommandBuffer cmd)
        //{
        //    base.FrameCleanup(cmd);
        //}
        #region SSSSS
        private float GetHaltonValue(int index, int radix)
        {
            float result = 0f;
            float fraction = 1f / (float)radix;

            while (index > 0)
            {
                result += (float)(index % radix) * fraction;
                index /= radix;
                fraction /= (float)radix;
            }
            return result;
        }

        private int SampleCount = 64;
        private int SampleIndex = 0;
        private Vector2 GenerateRandomOffset()
        {
            var offset = new Vector2(GetHaltonValue(SampleIndex & 1023, 2), GetHaltonValue(SampleIndex & 1023, 3));
            if (SampleIndex++ >= SampleCount)
                SampleIndex = 0;
            return offset;
        }
        #endregion
    }

    DrawSkinColorPass m_DrawSkinColorPass;
    BlurSSSSPass m_BlurSSSSPass;

    public override void Create()
    {
        m_DrawSkinColorPass = new DrawSkinColorPass(settings, this);
        m_DrawSkinColorPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.material != null)
        {
            RenderTargetIdentifier scr = renderer.cameraColorTarget;
            renderer.EnqueuePass(m_DrawSkinColorPass);
            m_BlurSSSSPass = new BlurSSSSPass(settings, this, scr);
            m_BlurSSSSPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
            renderer.EnqueuePass(m_BlurSSSSPass);
            
        }
        else
        {
            Debug.LogWarning("次表面散射Pass材质球丢失！请检查！");
        }
    }
}


