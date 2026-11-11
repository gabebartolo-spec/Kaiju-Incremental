// scenes/breath_aim.gd's material: the breath's aim wedge on the street, unshaded, see-through, coloured by its
// corners, drawn both ways up and depth-tested so the kaiju and the city stand in front of it.
Shader "Hidden/Slice/HudAim"
{
    SubShader
    {
        Tags { "RenderPipeline" = "HDRenderPipeline" "RenderType" = "Transparent" "Queue" = "Transparent" }
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            float4 _AimAt;     // world xyz of the cone's origin
            float4 _AimRight;  // world direction of the wedge's +x
            float4 _AimFwd;    // world direction of the wedge's +z (the facing)
            float _AimAlpha;
            float _AimGain;    // the scene's exposure unit, as the other unlit effects

            struct Attributes
            {
                float3 corner : POSITION;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 color : COLOR;
            };

            Varyings Vert(Attributes v)
            {
                float3 world = _AimAt.xyz + _AimRight.xyz * v.corner.x + _AimFwd.xyz * v.corner.z;
                Varyings o;
                o.positionCS = TransformWViewToHClip(TransformWorldToView(GetCameraRelativePositionWS(world)));
                o.color = v.color;
                return o;
            }

            float4 Frag(Varyings i) : SV_Target
            {
                return float4(i.color.rgb * _AimGain, i.color.a * _AimAlpha);
            }
            ENDHLSL
        }
    }
}
