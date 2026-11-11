// One continent's mission marker (scenes/globe_marker.gd): a small diamond on the continent with a leader line up
// and right to its name. The rect is a point: the diamond's centre. Grey for a locked continent.
using UnityEngine;
using UnityEngine.UI;

public sealed class GlobeMarker : MaskableGraphic
{
    public const float DIAMOND_PX = 9f;  // half the diamond's diagonal, px at 1080p
    public static readonly Vector2 LEADER = new Vector2(22f, -22f);  // diamond centre to the line's elbow
    public const float LEADER_RUN = 10f;  // the line's flat run from the elbow to the name
    public const float LINE_PX = 2f;
    public const float NAME_GAP = 4f;  // line end to the name's left edge

    static readonly Vector2[] diamond = new Vector2[4];

    Text label;
    Color ink = UiKit.ACCENT;

    // A marker under `parent` named `displayName` (shown in capitals, as Godot's).
    public static GlobeMarker Make(Transform parent, string displayName)
    {
        RectTransform rt = UiKit.Box(parent, "Marker");
        rt.sizeDelta = Vector2.zero;
        GlobeMarker m = rt.gameObject.AddComponent<GlobeMarker>();
        m.raycastTarget = false;
        m.label = UiKit.Label(rt, displayName.ToUpperInvariant(), UiKit.SIZE_SMALL, UiKit.ACCENT);
        m.label.alignment = TextAnchor.MiddleLeft;
        RectTransform name = m.label.rectTransform;
        name.anchorMin = name.anchorMax = new Vector2(0.5f, 0.5f);
        name.pivot = new Vector2(0f, 0.5f);
        name.sizeDelta = Vector2.zero;
        // globe_marker.gd _ready: the name's middle sits level with the line's end (y is down there, up here).
        name.anchoredPosition = new Vector2(LEADER.x + LEADER_RUN + NAME_GAP, -LEADER.y);
        return m;
    }

    // Grey for a locked continent, yellow otherwise.
    public void SetLocked(bool on)
    {
        ink = on ? UiKit.LOCKED : UiKit.ACCENT;
        label.color = ink;
        SetVerticesDirty();
    }

    public Color Ink => ink;

    // globe_marker.gd footprint: diamond, leader and name, relative to the diamond's centre, y down.
    public Rect Footprint()
    {
        float w = label.preferredWidth, h = label.preferredHeight;
        float right = LEADER.x + LEADER_RUN + NAME_GAP + w;
        return new Rect(-DIAMOND_PX, LEADER.y - h, right + DIAMOND_PX, h * 2f + DIAMOND_PX);
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        UiPen pen = new UiPen(vh, GetPixelAdjustedRect());
        Color outlineInk = UiKit.OutlineColor();
        float outline = UiKit.OutlinePx(UiKit.SIZE_SMALL);
        Vector2 elbow = LEADER, tip = LEADER + new Vector2(LEADER_RUN, 0f);
        // The outline first, wider, so the colour reads over the bright coastlines.
        for (int pass = 0; pass < 2; pass++)
        {
            Color c = (pass == 0 ? outlineInk : ink) * color;
            float grow = pass == 0 ? outline : 0f;
            float w = LINE_PX + grow * 2f;
            pen.Line(Vector2.zero, elbow, c, w);
            pen.Line(elbow, tip, c, w);
            pen.Circle(elbow, w * 0.5f, c, 6);  // the joint, so the wide pass has no notch
            float r = DIAMOND_PX + grow;
            diamond[0] = new Vector2(0f, -r);
            diamond[1] = new Vector2(r, 0f);
            diamond[2] = new Vector2(0f, r);
            diamond[3] = new Vector2(-r, 0f);
            pen.Poly(diamond, c);
        }
    }
}
