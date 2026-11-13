// The title's still art (scenes/title_screen.gd _add_sky and _add_live_city, scenes/title_colossus.gd at rest):
// the night sky gradient, the fire glows low on the right, the live burning city fading in over them
// (TitleCityView, Godot's TitleBackdrop), the colossus's baked silhouette where the title camera sees it with its
// one slow red eye (title_colossus.gd: a step along its path per far stomp, lit when a big boom reveals it), and
// the dark pool of shade behind the logo and buttons.
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
    const int EYE_TEXELS = 64;

    // True when the silhouette's picture was found and drawn.
    public bool artFound;

    static bool warned;
    Texture2D sky, glow, shade, colossus, disc;
    RawImage eye, card;
    TitleCityView city;
    S.GDict title;
    float[] cardBox, eyeBox;
    Color eyeColour;
    S.GDict eyeCfg;
    float t;

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
        AddColossus(title);

        S.GDict shadeCfg = title["shade"];
        string dark = S.Gd.Str(shadeCfg["color"]);
        shade = Radial(SHADE_TEXELS, (float)S.Num.F(shadeCfg["centre_x"]), (float)S.Num.F(shadeCfg["radius"]),
            Hex(dark, (float)S.Num.F(shadeCfg["centre_alpha"])), Hex(dark, (float)S.Num.F(shadeCfg["edge_alpha"])));
        UiKit.FullRect(Picture("Shade", shade, Color.white).rectTransform);
    }

    // The silhouette at its resting faintness and the eye over it. A missing picture is said once and left out.
    void AddColossus(S.GDict title)
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
        S.GDict cfg = title["colossus"];
        // The camera keeps its height, so a wider window sees more to the sides (Godot's keep-height).
        double aspect = Screen.height > 0 ? (double)Screen.width / Screen.height : UiKit.CANVAS_WIDTH / UiKit.CANVAS_HEIGHT;
        card = Picture("Colossus", colossus, new Color(1f, 1f, 1f, (float)S.Num.F(cfg["idle_alpha"])));
        cardBox = TitleMenu.ColossusBox(title, aspect, colossus.width, colossus.height);
        Place(card.rectTransform, cardBox);

        eyeCfg = cfg["eye"];
        eyeColour = Hex(S.Gd.Str(eyeCfg["colour"]), 1f);
        float[] at = TitleMenu.ColossusEye(title, aspect, colossus.width, colossus.height);
        disc = Radial(EYE_TEXELS, 0.5f, 0.5f, Color.white, new Color(1f, 1f, 1f, 0f));
        eye = Picture("Eye", disc, eyeColour);
        float halfV = at[2] * 0.5f, halfU = halfV / (float)aspect;
        eyeBox = new[] { at[0] - halfU, at[1] - halfV, at[0] + halfU, at[1] + halfV };
        Place(eye.rectTransform, eyeBox);
        ShowEye();
    }

    void Update()
    {
        if (eye == null) return;
        t += Time.unscaledDeltaTime;
        ShowEye();
    }

    // title_colossus.gd _show: the body at least its idle faintness, the eye from its slow pulse to its peak as
    // the reveal lights it, both under the city's fade; moved along by its steps.
    void ShowEye()
    {
        float fade = city != null ? city.Fade : 1f, amount = city != null ? (float)city.RevealAmount : 0f;
        S.GDict cfg = title["colossus"];
        card.color = new Color(1f, 1f, 1f, Mathf.Max((float)S.Num.F(cfg["idle_alpha"]), amount) * fade);
        float glint = Mathf.Lerp(TitleMenu.EyeAlpha(eyeCfg, t), (float)S.Num.F(eyeCfg["peak"]), amount);
        eye.color = new Color(eyeColour.r, eyeColour.g, eyeColour.b, glint * fade);
        if (city == null) return;
        double aspect = Screen.height > 0 ? (double)Screen.width / Screen.height : UiKit.CANVAS_WIDTH / UiKit.CANVAS_HEIGHT;
        float[] shift = TitleCity.ColossusShift(title, city.Steps, aspect);
        Place(card.rectTransform, Shifted(cardBox, shift));
        Place(eye.rectTransform, Shifted(eyeBox, shift));
    }

    static float[] Shifted(float[] box, float[] by) => new[] { box[0] + by[0], box[1] + by[1], box[2] + by[0], box[3] + by[1] };

    void OnDestroy()
    {
        foreach (Texture2D made in new[] { sky, glow, shade, colossus, disc }) if (made != null) Destroy(made);
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
