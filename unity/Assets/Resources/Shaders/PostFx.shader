// The rampage's two post effects (D-142) as one HDRP custom post process after AgX: the colour fringe
// (scenes/fringe.gdshader) and the vignette (scenes/vignette.gdshader). The source is the display picture stored
// linear (Agx.shader ends in SRGBToLinear), so the vignette blends in sRGB, where Godot's canvas blends it.
Shader "Hidden/Slice/PostFx"
{
    HLSLINCLUDE
    #pragma target 4.5
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

    TEXTURE2D_X(_Source);
    float4 _PostTint;
    float _PostStrength, _PostInner, _PostOuter, _PostFringePx;

    // scenes/vignette.gdshader CORNER and LEVEL; scenes/fringe.gdshader's 1080 lines.
    static const float VIGNETTE_CORNER = 0.70710678;
    static const float VIGNETTE_LEVEL = 1.0 / 255.0;
    static const float FRINGE_LINES = 1080.0;

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        return output;
    }

    float4 Tap(float2 uv)
    {
        return SAMPLE_TEXTURE2D_X_LOD(_Source, s_linear_clamp_sampler, ClampAndScaleUVForBilinearPostProcessTexture(uv), 0);
    }

    float4 Frag(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float2 uv = input.positionCS.xy * _PostProcessScreenSize.zw;
        float2 centred = (uv - 0.5) * 2.0;
        float4 source = Tap(uv);
        float3 color = source.rgb;
        // The fringe: red and blue split along the line from the centre, amount_px at 1080 lines at the edge.
        if (_PostFringePx > 0.0)
        {
            float2 shift = centred * _PostFringePx * (_PostProcessScreenSize.y / FRINGE_LINES) * _PostProcessScreenSize.zw;
            color.r = Tap(uv + shift).r;
            color.b = Tap(uv - shift).b;
        }
        // The vignette: 0 = the centre, 1 = a screen corner; dithered by a third of a level against banding.
        float d = length(centred) * VIGNETTE_CORNER;
        float dark = smoothstep(_PostInner, _PostOuter, d) * _PostStrength;
        float noise = frac(52.9829189 * frac(dot(input.positionCS.xy, float2(0.06711056, 0.00583715)))) - 0.5;
        dark = dark > 0.0 ? saturate(dark + noise * VIGNETTE_LEVEL * 0.66) : 0.0;
        float3 display = lerp(LinearToSRGB(max(color, 0.0)), _PostTint.rgb, dark);
        return float4(SRGBToLinear(display), source.a);
    }
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline"="HDRenderPipeline" }
        Pass
        {
            Name "PostFx"
            ZWrite Off ZTest Always Blend Off Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
    Fallback Off
}
