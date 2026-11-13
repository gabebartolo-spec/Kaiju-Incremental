using UnityEngine;

// The wet streets on the city's ground (ground_slab.gdshader `wet` and `sheen_color`; weather_view.gd
// _wet_the_ground, D-484): CityGround.hlsl darkens and glosses the ground and gives back the sky's colour at glancing
// angles. A new ground is dry (the shader's g_wet and g_sheen unset read 0); only WeatherView wets it.
public sealed partial class CityGround
{
    // How wet the streets are (0 dry, 1 soaked) and the sky colour (linear) the wet road gives back.
    public void Wet(float wet, Color sheen)
    {
        mat.SetFloat("g_wet", wet);
        mat.SetVector("g_sheen", new Vector4(sheen.r, sheen.g, sheen.b, 0f));
    }

    public float WetNow => mat.GetFloat("g_wet");
}
