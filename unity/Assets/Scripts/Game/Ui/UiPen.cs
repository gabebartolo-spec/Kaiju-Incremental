// The kit's drawing pen: rectangles, polygons, lines, circles, hazard tape and frames written into a uGUI mesh.
// Every shape is given the way scenes/hazard_box.gd gives it (origin at the box's top left, y down), so the
// drawing code reads line for line like the Godot file; the pen turns it into the Graphic's own space.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public struct UiPen
{
    // One stripe of tape is this wide (px, measured along the band); a dash and its gap on a dashed edge.
    public const float STRIPE = 10f;
    public const float DASH = 12f;
    // A circle is drawn as a fan of this many pieces: a rivet is 3 px wide, so more would not show.
    const int CIRCLE_STEPS = 14;

    readonly VertexHelper vh;
    readonly float left, top;
    static readonly List<Vector2> clipA = new List<Vector2>(8), clipB = new List<Vector2>(8);
    static readonly Vector2[] four = new Vector2[4];

    // `area` is the Graphic's rect (GetPixelAdjustedRect): its top left becomes the origin.
    public UiPen(VertexHelper helper, Rect area)
    {
        vh = helper;
        left = area.xMin;
        top = area.yMax;
    }

    int Vert(Vector2 p, Color c)
    {
        vh.AddVert(new Vector3(left + p.x, top - p.y, 0f), c, Vector4.zero);
        return vh.currentVertCount - 1;
    }

    public void Box(Rect r, Color c)
    {
        if (r.width <= 0f || r.height <= 0f) return;
        int a = Vert(new Vector2(r.xMin, r.yMin), c);
        Vert(new Vector2(r.xMax, r.yMin), c);
        Vert(new Vector2(r.xMax, r.yMax), c);
        Vert(new Vector2(r.xMin, r.yMax), c);
        vh.AddTriangle(a, a + 1, a + 2);
        vh.AddTriangle(a, a + 2, a + 3);
    }

    // A convex polygon in one colour (a fan from its first corner).
    public void Poly(IList<Vector2> pts, Color c)
    {
        if (pts.Count < 3) return;
        int a = Vert(pts[0], c);
        for (int i = 1; i < pts.Count; i++) Vert(pts[i], c);
        for (int i = 1; i < pts.Count - 1; i++) vh.AddTriangle(a, a + i, a + i + 1);
    }

    // A convex polygon with one colour per corner (the plate's top-to-bottom shade, the sheen's fade).
    public void Poly(IList<Vector2> pts, IList<Color> colours)
    {
        if (pts.Count < 3) return;
        int a = Vert(pts[0], colours[0]);
        for (int i = 1; i < pts.Count; i++) Vert(pts[i], colours[i]);
        for (int i = 1; i < pts.Count - 1; i++) vh.AddTriangle(a, a + i, a + i + 1);
    }

    // A shape every point of which the `middle` can see (the gear): a fan from the middle.
    public void Fan(Vector2 middle, IList<Vector2> rim, Color c)
    {
        if (rim.Count < 3) return;
        int a = Vert(middle, c);
        for (int i = 0; i < rim.Count; i++) Vert(rim[i], c);
        for (int i = 0; i < rim.Count; i++) vh.AddTriangle(a, a + 1 + i, a + 1 + (i + 1) % rim.Count);
    }

    public void Line(Vector2 from, Vector2 to, Color c, float width)
    {
        Vector2 along = to - from;
        if (along.sqrMagnitude < 1e-6f) return;
        Vector2 side = new Vector2(-along.y, along.x).normalized * (width * 0.5f);
        four[0] = from - side;
        four[1] = to - side;
        four[2] = to + side;
        four[3] = from + side;
        Poly(four, c);
    }

    // A closed outline: one piece per side and a dot at each corner, so the joints have no notch.
    public void Outline(IList<Vector2> pts, Color c, float width)
    {
        for (int i = 0; i < pts.Count; i++)
        {
            Line(pts[i], pts[(i + 1) % pts.Count], c, width);
            Circle(pts[i], width * 0.5f, c, 6);
        }
    }

    public void Circle(Vector2 middle, float radius, Color c, int steps = CIRCLE_STEPS)
    {
        int a = Vert(middle, c);
        for (int i = 0; i < steps; i++)
        {
            float angle = Mathf.PI * 2f * i / steps;
            Vert(middle + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius, c);
        }
        for (int i = 0; i < steps; i++) vh.AddTriangle(a, a + 1 + i, a + 1 + (i + 1) % steps);
    }

    // Diagonal hazard tape filling `rect`: stripes of `on` over `off`, leaning like road tape.
    public void Tape(Rect rect, Color on, Color off, float stripe = STRIPE)
    {
        if (rect.width <= 0f || rect.height <= 0f) return;
        Box(rect, off);
        float h = rect.height;
        for (float x = rect.xMin - h; x < rect.xMax; x += stripe * 2f)
        {
            clipA.Clear();
            clipA.Add(new Vector2(x, rect.yMax));
            clipA.Add(new Vector2(x + stripe, rect.yMax));
            clipA.Add(new Vector2(x + stripe + h, rect.yMin));
            clipA.Add(new Vector2(x + h, rect.yMin));
            // The stripe already sits between the band's top and bottom: only the two ends need cutting.
            Cut(clipA, clipB, 1f, rect.xMin);
            Cut(clipB, clipA, -1f, -rect.xMax);
            Poly(clipA, on);
        }
    }

    // Keeps the part of a convex polygon where sign * x >= limit.
    static void Cut(List<Vector2> from, List<Vector2> to, float sign, float limit)
    {
        to.Clear();
        for (int i = 0; i < from.Count; i++)
        {
            Vector2 a = from[i], b = from[(i + 1) % from.Count];
            float da = sign * a.x - limit, db = sign * b.x - limit;
            if (da >= 0f) to.Add(a);
            if ((da >= 0f) != (db >= 0f)) to.Add(Vector2.Lerp(a, b, da / (da - db)));
        }
    }

    // A rectangle's edge drawn inside `rect`, `width` thick; dashed draws DASH-long pieces.
    public void Frame(Rect rect, Color c, float width, bool dashed)
    {
        if (width <= 0f) return;
        Side(new Rect(rect.xMin, rect.yMin, rect.width, width), c, width, dashed);
        Side(new Rect(rect.xMin, rect.yMax - width, rect.width, width), c, width, dashed);
        Side(new Rect(rect.xMin, rect.yMin, width, rect.height), c, width, dashed);
        Side(new Rect(rect.xMax - width, rect.yMin, width, rect.height), c, width, dashed);
    }

    void Side(Rect side, Color c, float width, bool dashed)
    {
        if (!dashed)
        {
            Box(side, c);
            return;
        }
        bool alongX = side.width > side.height;
        float length = alongX ? side.width : side.height;
        for (float at = 0f; at < length; at += DASH * 2f)
        {
            float piece = Mathf.Min(DASH, length - at);
            Box(alongX ? new Rect(side.xMin + at, side.yMin, piece, width) : new Rect(side.xMin, side.yMin + at, width, piece), c);
        }
    }
}
