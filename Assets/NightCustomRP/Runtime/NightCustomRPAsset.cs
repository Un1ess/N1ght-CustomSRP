using UnityEngine;
using UnityEngine.Rendering;

namespace NightCustomRenderPipeline
{
    [CreateAssetMenu(menuName = "Rendering/Night Custom RP")]
    public class NightCustomRPAsset : RenderPipelineAsset
    {
        protected override RenderPipeline CreatePipeline()
        {
            return new NightCustomRP();
        }
    }

}
