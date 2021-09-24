using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class LUTColorGradingTest : MonoBehaviour
{
    public Material material;

    public int lutHeight;

    private int lutWidth;
    // Start is called before the first frame update
    void Start()
    {
        //shaderKeywords = null;
         material.DisableKeyword("_TONEMAP_FXT_ACES");
         material.DisableKeyword("_TONEMAP_FXT_NEUTRAL");
    }

    // Update is called once per frame
    void Update()
    {
        function();
    }

    void function()
    {
        // Fetch all color grading settings
        var stack = VolumeManager.instance.stack;
        var channelMixer              = stack.GetComponent<ChannelMixer>();
        var colorAdjustments          = stack.GetComponent<ColorAdjustments>();
        var curves                    = stack.GetComponent<ColorCurves>();
        var liftGammaGain             = stack.GetComponent<LiftGammaGain>();
        var shadowsMidtonesHighlights = stack.GetComponent<ShadowsMidtonesHighlights>();
        var splitToning               = stack.GetComponent<SplitToning>();
        var tonemapping               = stack.GetComponent<Tonemapping>();
        var whiteBalance              = stack.GetComponent<WhiteBalance>();

        
        lutWidth = lutHeight * lutHeight;
        // Prepare data
            var lmsColorBalance = ColorUtils.ColorBalanceToLMSCoeffs(whiteBalance.temperature.value, whiteBalance.tint.value);
            var hueSatCon = new Vector4(colorAdjustments.hueShift.value / 360f, colorAdjustments.saturation.value / 100f + 1f, colorAdjustments.contrast.value / 100f + 1f, 0f);
            var channelMixerR = new Vector4(channelMixer.redOutRedIn.value / 100f, channelMixer.redOutGreenIn.value / 100f, channelMixer.redOutBlueIn.value / 100f, 0f);
            var channelMixerG = new Vector4(channelMixer.greenOutRedIn.value / 100f, channelMixer.greenOutGreenIn.value / 100f, channelMixer.greenOutBlueIn.value / 100f, 0f);
            var channelMixerB = new Vector4(channelMixer.blueOutRedIn.value / 100f, channelMixer.blueOutGreenIn.value / 100f, channelMixer.blueOutBlueIn.value / 100f, 0f);

            var shadowsHighlightsLimits = new Vector4(
                shadowsMidtonesHighlights.shadowsStart.value,
                shadowsMidtonesHighlights.shadowsEnd.value,
                shadowsMidtonesHighlights.highlightsStart.value,
                shadowsMidtonesHighlights.highlightsEnd.value
            );

            var (shadows, midtones, highlights) = ColorUtils.PrepareShadowsMidtonesHighlights(
                shadowsMidtonesHighlights.shadows.value,
                shadowsMidtonesHighlights.midtones.value,
                shadowsMidtonesHighlights.highlights.value
            );

            var (lift, gamma, gain) = ColorUtils.PrepareLiftGammaGain(
                liftGammaGain.lift.value,
                liftGammaGain.gamma.value,
                liftGammaGain.gain.value
            );

            var (splitShadows, splitHighlights) = ColorUtils.PrepareSplitToning(
                splitToning.shadows.value,
                splitToning.highlights.value,
                splitToning.balance.value
            );

            var lutParameters = new Vector4(lutHeight, 0.5f / lutWidth, 0.5f / lutHeight, lutHeight / (lutHeight - 1f));
        
        // Fill in constants
            material.SetVector(ShaderConstants._Lut_Params, lutParameters);
            material.SetVector(ShaderConstants._ColorBalance, lmsColorBalance);
            material.SetVector(ShaderConstants._ColorFilter, colorAdjustments.colorFilter.value.linear);
            material.SetVector(ShaderConstants._ChannelMixerRed, channelMixerR);
            material.SetVector(ShaderConstants._ChannelMixerGreen, channelMixerG);
            material.SetVector(ShaderConstants._ChannelMixerBlue, channelMixerB);
            material.SetVector(ShaderConstants._HueSatCon, hueSatCon);
            material.SetVector(ShaderConstants._Lift, lift);
            material.SetVector(ShaderConstants._Gamma, gamma);
            material.SetVector(ShaderConstants._Gain, gain);
            material.SetVector(ShaderConstants._Shadows, shadows);
            material.SetVector(ShaderConstants._Midtones, midtones);
            material.SetVector(ShaderConstants._Highlights, highlights);
            material.SetVector(ShaderConstants._ShaHiLimits, shadowsHighlightsLimits);
            material.SetVector(ShaderConstants._SplitShadows, splitShadows);
            material.SetVector(ShaderConstants._SplitHighlights, splitHighlights);

            // YRGB curves
            material.SetTexture(ShaderConstants._CurveMaster, curves.master.value.GetTexture());
            material.SetTexture(ShaderConstants._CurveRed, curves.red.value.GetTexture());
            material.SetTexture(ShaderConstants._CurveGreen, curves.green.value.GetTexture());
            material.SetTexture(ShaderConstants._CurveBlue, curves.blue.value.GetTexture());

            // Secondary curves
            material.SetTexture(ShaderConstants._CurveHueVsHue, curves.hueVsHue.value.GetTexture());
            material.SetTexture(ShaderConstants._CurveHueVsSat, curves.hueVsSat.value.GetTexture());
            material.SetTexture(ShaderConstants._CurveLumVsSat, curves.lumVsSat.value.GetTexture());
            material.SetTexture(ShaderConstants._CurveSatVsSat, curves.satVsSat.value.GetTexture());
            
            switch (tonemapping.mode.value)
            {
                case TonemappingMode.Neutral: 
                    material.DisableKeyword("_TONEMAP_FXT_ACES");
                    material.EnableKeyword("_TONEMAP_FXT_NEUTRAL");
                    //material.DisableKeyword(ShaderKeywordStrings.TonemapACES);
                    Debug.Log(tonemapping.mode); break;
                case TonemappingMode.ACES: 
                    material.DisableKeyword("_TONEMAP_FXT_NEUTRAL");
                    material.EnableKeyword("_TONEMAP_FXT_ACES"); 
                    Debug.Log(tonemapping.mode); break;
                default:
                    //将所有宏keyword禁用掉
                    material.shaderKeywords = null;
                    // material.DisableKeyword("_TONEMAP_FXT_NEUTRAL");
                    // material.DisableKeyword("_TONEMAP_FXT_ACES");
                    
                    break; // None
            }
    }
    
        static class ShaderConstants
        {
            public static readonly int _Lut_Params        = Shader.PropertyToID("_Lut_Params");
            public static readonly int _ColorBalance      = Shader.PropertyToID("_ColorBalance");
            public static readonly int _ColorFilter       = Shader.PropertyToID("_ColorFilter");
            public static readonly int _ChannelMixerRed   = Shader.PropertyToID("_ChannelMixerRed");
            public static readonly int _ChannelMixerGreen = Shader.PropertyToID("_ChannelMixerGreen");
            public static readonly int _ChannelMixerBlue  = Shader.PropertyToID("_ChannelMixerBlue");
            public static readonly int _HueSatCon         = Shader.PropertyToID("_HueSatCon");
            public static readonly int _Lift              = Shader.PropertyToID("_Lift");
            public static readonly int _Gamma             = Shader.PropertyToID("_Gamma");
            public static readonly int _Gain              = Shader.PropertyToID("_Gain");
            public static readonly int _Shadows           = Shader.PropertyToID("_Shadows");
            public static readonly int _Midtones          = Shader.PropertyToID("_Midtones");
            public static readonly int _Highlights        = Shader.PropertyToID("_Highlights");
            public static readonly int _ShaHiLimits       = Shader.PropertyToID("_ShaHiLimits");
            public static readonly int _SplitShadows      = Shader.PropertyToID("_SplitShadows");
            public static readonly int _SplitHighlights   = Shader.PropertyToID("_SplitHighlights");
            public static readonly int _CurveMaster       = Shader.PropertyToID("_CurveMaster");
            public static readonly int _CurveRed          = Shader.PropertyToID("_CurveRed");
            public static readonly int _CurveGreen        = Shader.PropertyToID("_CurveGreen");
            public static readonly int _CurveBlue         = Shader.PropertyToID("_CurveBlue");
            public static readonly int _CurveHueVsHue     = Shader.PropertyToID("_CurveHueVsHue");
            public static readonly int _CurveHueVsSat     = Shader.PropertyToID("_CurveHueVsSat");
            public static readonly int _CurveLumVsSat     = Shader.PropertyToID("_CurveLumVsSat");
            public static readonly int _CurveSatVsSat     = Shader.PropertyToID("_CurveSatVsSat");
        }
        
        
}
