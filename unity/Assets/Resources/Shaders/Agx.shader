// The game's tone map as an HDRP custom post process: Godot's own AgX and grade (servers/rendering, tonemap.glsl),
// copied line for line and checked against Godot's output on a radiance ramp (0.007 at most on 8-bit values).
// MIT License, Copyright (c) 2014-present Godot Engine contributors, Copyright (c) 2007-2014 Juan Linietsky, Ariel
// Manzur. Permission is hereby granted, free of charge,
// to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the
// Software without restriction, including without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished
// to do so, subject to the following conditions: The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
Shader "Hidden/Slice/Agx"
{
    HLSLINCLUDE
    #pragma target 4.5
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

    TEXTURE2D_X(_Source);
    float _AgxExposure, _AgxContrast, _AgxWhite, _AgxSaturation, _AgxPostContrast;

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

    // allenwp_curve; its four constants are what Godot's renderer works out from contrast and white.
    float3 AllenwpCurve(float3 x)
    {
        const float crossover = 0.18;
        const float shoulderMax = 1.0 - crossover;
        float contrastAt = pow(crossover, _AgxContrast);
        float toeA = (1.0 / crossover - 1.0) * contrastAt;
        float denom = contrastAt + toeA;
        float slope = _AgxContrast * pow(crossover, _AgxContrast - 1.0) * toeA / (denom * denom);
        float w = (_AgxWhite - crossover) * (_AgxWhite - crossover) / shoulderMax * slope;

        float3 s = x - crossover;
        float3 slopeS = slope * s;
        s = slopeS * (1.0 + s / w) / (1.0 + slopeS / shoulderMax) + crossover;
        float3 t = pow(x, _AgxContrast);
        t = t / (t + toeA);
        return x < crossover ? t : s;
    }

    // tonemap_agx. The matrices are written as Godot's columns: mul(row vector, M) is its M * v.
    float3 TonemapAgx(float3 color)
    {
        const float3x3 inset = float3x3(
            0.544814746488245, 0.140416948464053, 0.0888104196149096,
            0.373787398372697, 0.754137554567394, 0.178871756420858,
            0.0813978551390581, 0.105445496968552, 0.732317823964232);
        const float3x3 outset = float3x3(
            1.96488741169489, -0.299313364904742, -0.164352742528393,
            -0.855988495690215, 1.32639796461980, -0.238183969428088,
            -0.108898916004672, -0.0270845997150571, 1.40253671195648);
        color = mul(max(color, 0.0), inset);
        color = min(1.0, AllenwpCurve(max(color, 0.0)));
        return mul(color, outset);
    }

    // linear_to_srgb: keeps the negatives the outset leaves, for the saturation step after it.
    float3 EncodeSrgb(float3 color)
    {
        return color < 0.0031308 ? 12.92 * color : 1.055 * pow(abs(color), 1.0 / 2.4) - 0.055;
    }

    float4 Frag(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
        float4 source = LOAD_TEXTURE2D_X(_Source, input.positionCS.xy);
        // Godot's tonemap pass in order: exposure, AgX, sRGB, then contrast and saturation in sRGB.
        float3 display = EncodeSrgb(TonemapAgx(source.rgb * _AgxExposure));
        display = 0.5 + (display - 0.5) * _AgxPostContrast;
        float mean = dot(float3(1.0, 1.0, 1.0), display) / 3.0;
        display = saturate(mean + _AgxSaturation * (display - mean));
        return float4(SRGBToLinear(display), source.a);
    }
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline"="HDRenderPipeline" }
        Pass
        {
            Name "Agx"
            ZWrite Off ZTest Always Blend Off Cull Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
    Fallback Off
}
