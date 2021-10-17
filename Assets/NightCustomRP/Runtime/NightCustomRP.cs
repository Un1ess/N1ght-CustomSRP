using UnityEngine;
using UnityEngine.Rendering;

namespace NightCustomRenderPipeline
{
    public class NightCustomRP : RenderPipeline
    {
        private NightCameraRenderer _nightCameraRender = new NightCameraRenderer();
        protected override void Render(ScriptableRenderContext context, Camera[] cameras)
        {
            //每个摄像机的渲染是独立的 Independent
            foreach (var camera in cameras)
            {
                _nightCameraRender.Render(context,camera);
            }
        }
    }
}

