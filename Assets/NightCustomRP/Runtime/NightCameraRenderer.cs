using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace NightCustomRenderPipeline
{
    public partial class NightCameraRenderer
    {
        private ScriptableRenderContext context;
        private Camera camera;

        
        const string cmdBufferName = "NightCmd";
        CommandBuffer cmd = new CommandBuffer{name = cmdBufferName};
        private CullingResults _cullingResults;
        static ShaderTagId nightCustomRPShaderTagId = new ShaderTagId("NightCustomRPForward");
        //unity shader pass中tag 若不写LightMode 则默认的Lightmode为SRPDefaultUnlit
        static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
        static ShaderTagId universalForwardShaderTagId = new ShaderTagId("UniversalForward");
        
        /// <summary>
        /// NightCameraRender 公有构造函数 构造函数无需返回值
        /// </summary>
        public NightCameraRenderer()
        {
            
        }

        public void Render(ScriptableRenderContext context,Camera camera)
        {
            this.context = context;
            this.camera = camera;

            PrepareBuffer();
            PrepareForSceneWindow();
            if (!Cull())
            {
                return;
            }
            Setup();
            DrawVisibleGeometry();
            DrawUnsupportedShaders();
            DrawGizmos();
            Submit();
        }
        void Setup() 
        {
            //Set Matrix_VP
            context.SetupCameraProperties(camera);

            CameraClearFlags clearFlags = camera.clearFlags;
            
            //ClearTarget方法本身就已经包含在cmd.name 中的一个Sample了
            //ClearTarget方法若放在 SetupCameraProperties之前 则会调用为DrawGL 它不是最有效的清屏方法
            cmd.ClearRenderTarget(clearFlags <= CameraClearFlags.Depth,
                clearFlags == CameraClearFlags.Color,
                clearFlags == CameraClearFlags.Color ? camera.backgroundColor.linear : Color.clear);
            
            //Begin Our own Profile Sample
            cmd.BeginSample(SampleName);
            ExecuteCommandBuffer();
            
        }
        /// <summary>
        /// 先绘制不透明物体，再绘制天空盒，最后绘制透明物体
        /// </summary>
        private void DrawVisibleGeometry()
        {

            //CommonOpaque时 绘制不透明物体不一定是从前向后
            SortingSettings sortingSettings = new SortingSettings(camera) {criteria = SortingCriteria.CommonOpaque};
            DrawingSettings drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
            //drawingSettings.SetShaderPassName(1,unlitShaderTagId);
            FilteringSettings filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

            //Debug.Log(drawingSettings.GetShaderPassName(0).name.ToString());
            context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
            
            //clearFlags被设置为Skybox的时候才会绘制Skybox
            context.DrawSkybox(camera);
            
            //CommonTransparent 绘制透明物体一定是从后向前
            sortingSettings.criteria = SortingCriteria.CommonTransparent;
            drawingSettings.sortingSettings = sortingSettings;
            filteringSettings.renderQueueRange = RenderQueueRange.transparent;
            context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
            
        }
        /// <summary>
        /// 使用ErrorShader(return half4(1,0,1,1))-->绘制默认管线下的Shader
        /// </summary>
        partial void DrawUnsupportedShaders ();//在这里声明 但在partial class内写具体实现方法
        
        partial void DrawGizmos ();
        
        partial void PrepareForSceneWindow ();

        partial void PrepareBuffer();
        private void Submit()
        {
            //End Our own Profile Sample
            cmd.EndSample(SampleName);
            //new ProfilingScope()
            ExecuteCommandBuffer();
            context.Submit();
        }

        void ExecuteCommandBuffer()
        {
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
        }
        
        /// <summary>
        /// 剔除操作 通过context.Cull() 获得CullingResults
        /// </summary>
        /// <returns></returns>
        bool Cull () {
            if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
            {
                _cullingResults = context.Cull(ref p);
                return true;
            }
            return false;
        }
    }
}
