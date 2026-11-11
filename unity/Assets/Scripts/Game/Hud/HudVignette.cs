using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/hurt_vignette.gd: red closing in from the screen's edge as health falls, a flash on each hit and a
// heartbeat when low. Godot's shader is evaluated at the corners of a grid, so no shader is needed.
public sealed class HudVignette : Graphic
{
    // Grid cells a side: the fade is a smooth ramp, so a coarse grid draws it.
    const int CELLS = 24;
    readonly HudHurt hurt = new HudHurt();
    Color tint;
    double widthMax, alphaMax, easeRate, below, hz, depth, flashS, flashAlpha;
    float drawnWidth = -1f, drawnStrength = -1f;

    public double Strength => hurt.Strength;

    public static HudVignette Create(Transform parent)
    {
        RectTransform rt = UiKit.Box(parent, "Hurt");
        UiKit.FullRect(rt);
        HudVignette v = rt.gameObject.AddComponent<HudVignette>();
        v.raycastTarget = false;
        S.GDict cfg = UiKit.Ui()["hurt"];
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(cfg["color"]), out v.tint);
        v.widthMax = S.Num.F(cfg["width_max"]);
        v.alphaMax = S.Num.F(cfg["alpha_max"]);
        v.easeRate = S.Num.F(cfg["ease_rate"]);
        v.below = S.Num.F(cfg["heartbeat_below"]);
        v.hz = S.Num.F(cfg["heartbeat_hz"]);
        v.depth = S.Num.F(cfg["heartbeat_depth"]);
        v.flashS = S.Num.F(cfg["flash_s"]);
        v.flashAlpha = S.Num.F(cfg["flash_alpha"]);
        return v;
    }

    public void Step(double hp, double maxHp, float dt)
    {
        hurt.Step(hp, maxHp, dt, widthMax, alphaMax, easeRate, below, hz, depth, flashS, flashAlpha);
        float w = (float)hurt.Width, s = (float)hurt.Strength;
        if (Mathf.Approximately(w, drawnWidth) && Mathf.Approximately(s, drawnStrength)) return;
        drawnWidth = w;
        drawnStrength = s;
        SetVerticesDirty();
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        if (hurt.Strength <= 0.0 || hurt.Width <= 0.0) return;
        Rect area = GetPixelAdjustedRect();
        for (int y = 0; y <= CELLS; y++)
        {
            for (int x = 0; x <= CELLS; x++)
            {
                float u = (float)x / CELLS, v = (float)y / CELLS;
                float a = (float)HudText.VignetteAlpha(u, v, hurt.Width, hurt.Strength);
                vh.AddVert(new Vector3(area.xMin + area.width * u, area.yMin + area.height * v, 0f), new Color(tint.r, tint.g, tint.b, tint.a * a), Vector4.zero);
            }
        }
        for (int y = 0; y < CELLS; y++)
        {
            for (int x = 0; x < CELLS; x++)
            {
                int a = y * (CELLS + 1) + x, b = a + CELLS + 1;
                vh.AddTriangle(a, b, b + 1);
                vh.AddTriangle(a, b + 1, a + 1);
            }
        }
    }
}
