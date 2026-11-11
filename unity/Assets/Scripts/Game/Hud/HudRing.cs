using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/hud_ring.gd: an icon inside a charge ring that fills clockwise from the top and pops when it is ready.
public sealed class HudRing : MaskableGraphic
{
    float radius, width, ratio = 1f;
    float popT = -1f;
    RawImage icon;
    CanvasGroup group;
    static readonly HashSet<string> missing = new HashSet<string>();
    static readonly List<Vector2> quad = new List<Vector2>(4) { Vector2.zero, Vector2.zero, Vector2.zero, Vector2.zero };

    public float Ratio => ratio;

    // `id`: tuning ui.hud.icons' key (breath, dash, ultimate).
    public static HudRing Create(Transform parent, string id, float radius, float width)
    {
        RectTransform rt = UiKit.Box(parent, "Ring_" + id);
        HudRing ring = rt.gameObject.AddComponent<HudRing>();
        ring.radius = radius;
        ring.width = width;
        ring.raycastTarget = false;
        ring.group = rt.gameObject.AddComponent<CanvasGroup>();
        ring.group.blocksRaycasts = false;
        float side = (float)HudText.RingSide(radius, width);
        UiKit.Size(ring, side, side);
        Texture2D art = LoadIcon(id);
        if (art != null)
        {
            RectTransform box = UiKit.Box(rt, "Icon");
            float half = (float)HudText.IconHalf(radius, width);
            box.anchorMin = box.anchorMax = box.pivot = new Vector2(0.5f, 0.5f);
            // The icon keeps its shape inside the square.
            float wide = art.width >= art.height ? 1f : (float)art.width / art.height;
            float tall = art.height >= art.width ? 1f : (float)art.height / art.width;
            box.sizeDelta = new Vector2(half * 2f * wide, half * 2f * tall);
            ring.icon = box.gameObject.AddComponent<RawImage>();
            ring.icon.texture = art;
            ring.icon.raycastTarget = false;
        }
        ring.Tint();
        return ring;
    }

    // tuning ui.hud.icons: read from the build's res folder; a missing file is said once and the ring is bare.
    static Texture2D LoadIcon(string id)
    {
        S.GDict hud = UiKit.Ui()["hud"];
        S.GDict icons = hud["icons"];
        string path = Path.Combine(S.FileAccess.Root ?? "", S.Gd.Str(icons[id]).Replace("res://", ""));
        try
        {
            if (File.Exists(path))
            {
                Texture2D art = new Texture2D(2, 2, TextureFormat.RGBA32, true);
                if (art.LoadImage(File.ReadAllBytes(path))) return art;
                Destroy(art);
            }
        }
        catch (IOException) { }
        if (missing.Add(path)) Debug.LogWarning($"hud: no icon at {path}; the ring is drawn without it");
        return null;
    }

    // A ring the kaiju does not have keeps its place, unseen.
    public void Show(bool on)
    {
        group.alpha = on ? 1f : 0f;
    }

    public void SetRatio(double value)
    {
        float v = Mathf.Clamp01((float)value);
        bool ready = v >= 1f && ratio < 1f;
        if (Mathf.Approximately(v, ratio)) return;
        ratio = v;
        Tint();
        SetVerticesDirty();
        if (ready) popT = 0f;
    }

    void Tint()
    {
        if (icon != null) icon.color = ratio >= 1f ? Color.white : UiKit.Darkened(UiKit.MUTED, (float)HudText.RING_IDLE_DARKEN);
    }

    public void Step(float dt, float readyScale, float readySeconds)
    {
        if (popT < 0f) return;
        popT += dt;
        float s = (float)HudText.BackOut(readyScale, 1.0, popT, readySeconds);
        rectTransform.localScale = new Vector3(s, s, 1f);
        if (popT >= readySeconds) popT = -1f;
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        Vector2 middle = new Vector2(area.width * 0.5f, area.height * 0.5f);
        float outline = (float)HudText.RING_OUTLINE;
        Color disc = new Color(UiKit.BG.r, UiKit.BG.g, UiKit.BG.b, (float)HudText.RING_DISC_ALPHA);
        pen.Circle(middle, radius + width * 0.5f + outline, disc, HudText.RING_SEGMENTS);
        Arc(pen, middle, 1f, width + 2f * outline, UiKit.OutlineColor());
        Arc(pen, middle, 1f, width, UiKit.PANEL_EDGE);
        if (ratio > 0f) Arc(pen, middle, ratio, width, UiKit.ACCENT);
    }

    // `share` of the circle from the top, clockwise, `thick` px wide.
    void Arc(UiPen pen, Vector2 middle, float share, float thick, Color c)
    {
        int steps = Mathf.Max(1, Mathf.CeilToInt(HudText.RING_SEGMENTS * share));
        float inner = radius - thick * 0.5f, outer = radius + thick * 0.5f;
        for (int i = 0; i < steps; i++)
        {
            Vector2 a = Dir(share * i / steps), b = Dir(share * (i + 1) / steps);
            quad[0] = middle + a * inner;
            quad[1] = middle + a * outer;
            quad[2] = middle + b * outer;
            quad[3] = middle + b * inner;
            pen.Poly(quad, c * color);
        }
    }

    // The pen's y runs down the screen, so a growing angle from the top turns clockwise.
    static Vector2 Dir(float turn)
    {
        float angle = -Mathf.PI * 0.5f + Mathf.PI * 2f * turn;
        return new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
    }
}
