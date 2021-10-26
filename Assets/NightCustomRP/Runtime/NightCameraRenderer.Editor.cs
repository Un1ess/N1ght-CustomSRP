using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

namespace NightCustomRenderPipeline
{
    public partial class NightCameraRenderer
    {
        #if UNITY_EDITOR
        static ShaderTagId[] legacyShaderTagIds = {
            new ShaderTagId("Always"),
            new ShaderTagId("ForwardBase"),
            new ShaderTagId("PrepassBase"),
            new ShaderTagId("Vertex"),
            new ShaderTagId("VertexLMRGBM"),
            new ShaderTagId("VertexLM")
        };
        static Material errorMaterial;
        
        partial void DrawUnsupportedShaders () {
            if (errorMaterial == null)
            {
                errorMaterial = new Material(Shader.Find("Hidden/Universal Render Pipeline/FallbackError"));
            }
            var drawingSettings = new DrawingSettings(
                legacyShaderTagIds[0], new SortingSettings(camera)
            )
            {
                overrideMaterial = errorMaterial
            };
            for (int i = 1; i < legacyShaderTagIds.Length; i++) {
                drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
            }
            var filteringSettings = FilteringSettings.defaultValue;
            context.DrawRenderers(
                _cullingResults, ref drawingSettings, ref filteringSettings
            );
        }
        
        
        partial void DrawGizmos () {
            if (Handles.ShouldRenderGizmos()) {
                context.DrawGizmos(camera, GizmoSubset.PreImageEffects);//这里的ImageEffect指后处理
                context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
            }
        }
        
        /// <summary>
        /// 用于在Editor Window下绘制UI
        /// </summary>
        partial void PrepareForSceneWindow () {
            if (camera.cameraType == CameraType.SceneView) {
                ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
            }
        }
        
        string SampleName { get; set; }
        
        /// <summary>
        /// 设置buffer名字
        /// </summary>
        partial void PrepareBuffer () {
            Profiler.BeginSample("EditorOnly");
            cmd.name = SampleName = camera.name;
            Profiler.EndSample();
        }
        
        #else
        
        const string SampleName = bufferName;
        
        #endif
    }
}
