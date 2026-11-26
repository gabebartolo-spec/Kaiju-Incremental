// The title's still art (scenes/title_screen.gd _add_sky and _add_live_city, scenes/title_colossus.gd at rest):
// the night sky gradient, the fire glows low on the right, the live burning city fading in over them
// (TitleCityView, Godot's TitleBackdrop, which also draws the colossus's baked silhouette loaded here), and the
// dark pool of shade behind the logo and buttons.
using System.IO;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class TitleBackdrop : MonoBehaviour
{
    public const string COLOSSUS = "assets/title/colossus_0.png";
    const int SKY_TEXELS = 256;
    const int SHADE_TEXELS = 256;

    // True when the silhouette's picture was found and drawn.
    public bool artFound;

    static bool warned;
    Texture2D sky, glow, shade, colossus;
    TitleCityView city;
    S.GDict title;

    // Fills `screen` behind whatever is added after it.
    public static TitleBackdrop Create(Transform screen)
    {
        RectTransform rt = UiKit.Box(screen, "TitleBackdrop");
        UiKit.FullRect(rt);
        TitleBackdrop b = rt.gameObject.AddComponent<TitleBackdrop>();
        b.Build();
        return b;
    }

    void Build()
    {
        title = S.Content.Section("title");
        S.GDict skyCfg = title["sky"];
        sky = Vertical(Hex(S.Gd.Str(skyCfg["top"]), 1f), Hex(S.Gd.Str(skyCfg["bottom"]), 1f));
        UiKit.FullRect(Picture("Sky", sky, Color.white).rectTransform);

        Color glowColour = Hex(S.Gd.Str(skyCfg["glow_color"]), (float)S.Num.F(skyCfg["glow_alpha"]));
        glow = Radial(TitleMenu.GLOW_TEXELS, 0.5f, 0.5f, glowColour, new Color(glowColour.r, glowColour.g, glowColour.b, 0f));
        S.GArray<S.Variant> glows = skyCfg["glows"];
        foreach (S.Variant entry in glows)
        {
            S.GArray<S.Variant> g = entry;
            Place(Picture("Glow", glow, Color.white).rectTransform, TitleMenu.GlowBox(S.Num.F(g[0]), S.Num.F(g[1]), S.Num.F(g[2])));
        }

        city = TitleCityView.Create(transform);
        AddColossus();

        S.GDict shadeCfg = title["shade"];
        string dark = S.Gd.Str(shadeCfg["color"]);
        shade = Radial(SHADE_TEXELS, (float)S.Num.F(shadeCfg["centre_x"]), (float)S.Num.F(shadeCfg["radius"]),
            Hex(dark, (float)S.Num.F(shadeCfg["centre_alpha"])), Hex(dark, (float)S.Num.F(shadeCfg["edge_alpha"])));
        UiKit.FullRect(Picture("Shade", shade, Color.white).rectTransform);
    }

    // The silhouette's picture, handed to the city to draw in its scene. A missing picture is said once and left out.
    void AddColossus()
    {
        string file = Path.Combine(S.FileAccess.Root ?? "", COLOSSUS);
        try
        {
            colossus = new Texture2D(2, 2, TextureFormat.RGBA32, false);
            if (!colossus.LoadImage(File.ReadAllBytes(file), true)) throw new InvalidDataException("not an image");
        }
        catch (System.Exception e)
        {
            if (!warned) Debug.LogWarning($"title: no colossus picture at {file} ({e.Message}); the sky stands alone");
            warned = true;
            if (colossus != null) Destroy(colossus);
            colossus = null;
            return;
        }
        colossus.wrapMode = TextureWrapMode.Clamp;
        artFound = true;
        city.colossusArt = colossus;
    }

    void OnDestroy()
    {
        foreach (Texture2D made in new[] { sky, glow, shade, colossus }) if (made != null) Destroy(made);
    }

    RawImage Picture(string name, Texture texture, Color colour)
    {
        RawImage image = UiKit.Box(transform, name).gameObject.AddComponent<RawImage>();
        image.texture = texture;
        image.color = colour;
        image.raycastTarget = false;
        return image;
    }

    // box: left, bottom, right, top as screen shares.
    static void Place(RectTransform rt, float[] box)
    {
        rt.anchorMin = new Vector2(box[0], box[1]);
        rt.anchorMax = new Vector2(box[2], box[3]);
        rt.offsetMin = Vector2.zero;
        rt.offsetMax = Vector2.zero;
    }

    // One texel wide, `top` at the top row down to `bottom`.
    static Texture2D Vertical(Color top, Color bottom)
    {
        Texture2D tex = new Texture2D(1, SKY_TEXELS, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
        Color[] px = new Color[SKY_TEXELS];
        for (int y = 0; y < SKY_TEXELS; y++) px[y] = Color.Lerp(bottom, top, y / (SKY_TEXELS - 1f));
        tex.SetPixels(px);
        tex.Apply(false, true);
        return tex;
    }

    // A square radial fade as Godot's GradientTexture2D draws it: `inner` at (centreX, 0.5) to `outer` at
    // `radius` away and beyond, measured in shares of the texture.
    static Texture2D Radial(int side, float centreX, float radius, Color inner, Color outer)
    {
        Texture2D tex = new Texture2D(side, side, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
        Color[] px = new Color[side * side];
        for (int y = 0; y < side; y++)
        {
            float dy = (y + 0.5f) / side - 0.5f;
            for (int x = 0; x < side; x++)
            {
                float dx = (x + 0.5f) / side - centreX;
                px[y * side + x] = Color.Lerp(inner, outer, Mathf.Sqrt(dx * dx + dy * dy) / radius);
            }
        }
        tex.SetPixels(px);
        tex.Apply(false, true);
        return tex;
    }

    static Color Hex(string hex, float alpha)
    {
        Color c;
        if (!ColorUtility.TryParseHtmlString("#" + hex, out c)) c = Color.black;
        c.a = alpha;
        return c;
    }
}
