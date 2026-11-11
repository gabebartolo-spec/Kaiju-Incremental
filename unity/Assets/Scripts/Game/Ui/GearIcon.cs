// A settings gear drawn in code (scenes/gear_icon.gd): eight teeth round a hub with a hole, centred in its
// rect, in the Graphic's colour. Used on the title's settings button.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public sealed class GearIcon : MaskableGraphic
{
    public const int TEETH = 8;
    // Shares of the rect's shorter side: the tooth tips, the body, the hub hole.
    public const float TIP = 0.46f;
    public const float BODY = 0.34f;
    public const float HOLE = 0.15f;
    // The hole shows what is behind the gear: a near-black.
    static readonly Color HOLE_COLOUR = new Color32(0x11, 0x11, 0x14, 0xff);
    // One tooth: up from the body to the tip, along it, back down (share of a tooth's angle, radius).
    static readonly Vector2[] TOOTH = { new Vector2(-0.3f, BODY), new Vector2(-0.17f, TIP), new Vector2(0.17f, TIP), new Vector2(0.3f, BODY) };
    const int HOLE_STEPS = 24;

    static readonly List<Vector2> rim = new List<Vector2>(TEETH * 4);

    protected override void Awake()
    {
        base.Awake();
        raycastTarget = false;
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        Vector2 middle = new Vector2(area.width, area.height) / 2f;
        float side = Mathf.Min(area.width, area.height);
        float step = Mathf.PI * 2f / TEETH;
        rim.Clear();
        for (int tooth = 0; tooth < TEETH; tooth++)
            foreach (Vector2 part in TOOTH)
            {
                float angle = step * tooth + step * part.x;
                rim.Add(middle + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * side * part.y);
            }
        pen.Fan(middle, rim, color);
        pen.Circle(middle, side * HOLE, new Color(HOLE_COLOUR.r, HOLE_COLOUR.g, HOLE_COLOUR.b, color.a), HOLE_STEPS);
    }
}
