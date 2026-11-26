// The title city's picture on the menu canvas (TitleCityView's RawImage) with the explosions' light over it
// (title_backdrop.gd _light_sky): Godot adds each glow as a soft disc (FarFire.soft_disc) on its 2D canvas, which
// blends in display (sRGB) units, so a faint glow barely lifts the dark bay. Unity's canvas blends in linear
// units, where the same glow turns the dark water orange; so the glows are added here, to the picture's display
// units, as Godot's canvas does. _SkyAt: centre (u, v, y up) and radius (share of the height); _SkyColour: the
// colour in display units and its alpha. The vertex colour's alpha is the picture's fade.
Shader "Hidden/Slice/TitleSky"
{
    Properties
    {
        [PerRendererData] _MainTex("", 2D) = "white" {}
        [HideInInspector] _Aspect("", Float) = 1.7777778
        [HideInInspector] _SkyCount("", Float) = 0
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "PreviewType" = "Plane" }
        Cull Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 4.5
            #include "UnityCG.cginc"

            #define SKY_MAX 8

            sampler2D _MainTex;
            float _Aspect, _SkyCount;
            float4 _SkyAt[SKY_MAX], _SkyColour[SKY_MAX];

            struct Attributes { float4 vertex : POSITION; float4 color : COLOR; float2 uv : TEXCOORD0; };
            struct Varyings { float4 pos : SV_POSITION; float4 color : COLOR; float2 uv : TEXCOORD0; };

            Varyings Vert(Attributes v)
            {
                Varyings o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.color;
                o.uv = v.uv;
                return o;
            }

            // FarFire.soft_disc: 1 at the centre, 0.4 at 0.3 of the radius, 0 at the edge.
            float SoftDisc(float r)
            {
                return r < 0.3 ? lerp(1.0, 0.4, r / 0.3) : lerp(0.4, 0.0, saturate((r - 0.3) / 0.7));
            }

            float4 Frag(Varyings i) : SV_Target
            {
                float4 c = tex2D(_MainTex, i.uv);
                float3 shown = LinearToGammaSpace(c.rgb);
                for (int k = 0; k < SKY_MAX; k++)
                {
                    if (k >= (int)_SkyCount) break;
                    float2 d = (i.uv - _SkyAt[k].xy) * float2(_Aspect, 1.0);
                    shown += _SkyColour[k].rgb * _SkyColour[k].a * SoftDisc(length(d) / _SkyAt[k].z);
                }
                return float4(GammaToLinearSpace(saturate(shown)), c.a * i.color.a);
            }
            ENDHLSL
        }
    }
}
