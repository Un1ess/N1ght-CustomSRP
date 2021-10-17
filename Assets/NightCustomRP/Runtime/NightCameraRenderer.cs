using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace NightCustomRenderPipeline
{
    public class NightCameraRenderer
    {
        private ScriptableRenderContext context;
        private Camera camera;

        
        const string cmdBufferName = "NightCmd";
        CommandBuffer cmd = new CommandBuffer{name = cmdBufferName};
        private CullingResults _cullingResults;
        static ShaderTagId nightCustomRPShaderTagId = new ShaderTagId("NightCustomRPForward");
        //unity shader pass中tag 若不写LightMode 则默认的Lightmode为SRPDefaultUnlit
        static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit");
        
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

            if (!Cull())
            {
                return;
            }
            Setup();
            DrawVisibleGeometry();
            Submit();
        }
        void Setup() 
        {
            //Set Matrix_VP
            context.SetupCameraProperties(camera);
            
            //ClearTarget方法本身就已经包含在cmd.name 中的一个Sample了
            //ClearTarget方法若放在 SetupCameraProperties之前 则会调用为DrawGL 它不是最有效的清屏方法
            cmd.ClearRenderTarget(true, true, Color.clear);
            
            //Begin Our own Profile Sample
            cmd.BeginSample(cmdBufferName);
            ExecuteCommandBuffer();
            
        }
        private void DrawVisibleGeometry()
        {
            SortingSettings sortingSettings = new SortingSettings(camera);
            DrawingSettings drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
            drawingSettings.SetShaderPassName(1,nightCustomRPShaderTagId);
            FilteringSettings filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

            //Debug.Log(drawingSettings.GetShaderPassName(0).name.ToString());
            context.DrawRenderers(_cullingResults, ref drawingSettings, ref filteringSettings);
            context.DrawSkybox(camera);
        }
        private void Submit()
        {
            //End Our own Profile Sample
            cmd.EndSample(cmdBufferName);
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
