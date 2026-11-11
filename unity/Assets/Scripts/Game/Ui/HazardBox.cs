// The emergency-broadcast box (UI look A), a port of scenes/hazard_box.gd as one uGUI Graphic: a flat fill
// with square corners, an edge (solid or dashed), a band of hazard tape on the left, the top or both sides, a
// focus ring just inside the edge, corner brackets and a focus pointer. With `plated` it is the worn steel
// plate the buttons use: cut corners, a bevel, a sheen, scuffs, four rivets and a drop shadow.
// Set the fields, then call Redraw().
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class HazardBox : MaskableGraphic
{
    public enum Band { None, Left, Top, Sides }

    // The focus ring sits this far inside the box's edge and is this thick.
    public const float RING_GAP = 4f;
    public const float RING_WIDTH = 3f;
    // Corner brackets: each arm this long and thick, this far inside the edge.
    public const float CORNER_LEN = 26f;
    public const float CORNER_WIDTH = 4f;
    public const float CORNER_GAP = 6f;
    // The plate: chamfer, drop shadow (kept inside the box's rect), bevel, scuffs and rivets.
    public const float CUT = 7f;
    public static readonly Vector2 PLATE_SHADOW = new Vector2(4f, 6f);
    public const float PLATE_BEVEL = 3f;
    public const float RIVET = 3.2f;
    // The outline of a plate in focus, and of one that is not.
    public const float FOCUS_OUTLINE = 4.5f;
    public const float PLATE_OUTLINE = 2.5f;
    // A button without the focus pointer needs only this much room between its tape and its text.
    public const float POINTERLESS_ROOM = 16f;
    public const int SCUFFS = 9;
    // Scratches stay in a strip this share of the plate's height along the top and the bottom edge.
    public const float SCUFF_STRIP = 0.16f;
    // The focus pointer: a solid triangle this wide, this far in from the right edge (or this far inside the
    // right tape), its height a share of the box's.
    public const float CHEVRON_WIDTH = 14f;
    public const float CHEVRON_INSET = 14f;
    public const float CHEVRON_GAP = 6f;
    public const float CHEVRON_SHARE = 0.36f;

    public Color fill = Color.black;
    public Color edge = Color.white;
    public float border = 2f;
    public Band band = Band.None;
    public float bandSize = 20f;
    public Color tapeOn = new Color32(0xff, 0xcc, 0x00, 0xff);
    public Color tapeOff = new Color32(0x11, 0x11, 0x14, 0xff);
    public bool dashed;
    // A share (0..1) of the box filled from the bottom (the tree's glass cells), a bright line on top.
    public float liquid;
    public Color liquidColor = new Color32(0x6a, 0x2b, 0xd6, 0xff);
    public Color liquidTop = new Color32(0xc7, 0x9b, 0xff, 0xff);
    public bool ring;
    public Color ringColor = new Color32(0xff, 0xcc, 0x00, 0xff);
    // A plate in focus (or pressed) is outlined in this, thicker.
    public Color focusEdge = Color.white;
    public bool corners;
    public Color cornerColor = new Color32(0xff, 0xcc, 0x00, 0xff);
    // A pointer in `ringColor` at the right edge (the focused button: "you are here").
    public bool chevron;
    public bool plated;
    // 0 normal, 1 pressed (the plate sinks, the bevel flips, the shadow shrinks).
    public float press;

    static readonly List<Vector2> shape = new List<Vector2>(8);
    static readonly List<Color> shades = new List<Color>(8);
    static readonly Vector2[] tri = new Vector2[3];
    static readonly Vector2[] quad = new Vector2[4];
    static readonly Color[] quadShades = new Color[4];
    static readonly Color RIVET_COLOUR = new Color32(0x55, 0x55, 0x5c, 0xff);

    // The fields are plain, so a change shows only after this.
    public void Redraw()
    {
        SetVerticesDirty();
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        Rect rect = new Rect(0f, 0f, area.width, area.height);
        if (plated)
        {
            rect = DrawPlate(pen, rect);
        }
        else
        {
            pen.Box(rect, Tint(fill));
            if (liquid > 0f)
            {
                float depth = rect.height * Mathf.Clamp01(liquid);
                pen.Box(new Rect(rect.xMin, rect.yMax - depth, rect.width, depth), Tint(liquidColor));
                pen.Box(new Rect(rect.xMin, rect.yMax - depth, rect.width, Mathf.Min(2f, depth)), Tint(liquidTop));
            }
            DrawBand(pen, rect);
            pen.Frame(rect, Tint(edge), border, dashed);
        }
        if (corners) Corners(pen, rect);
        if (chevron)
        {
            float h = rect.height * CHEVRON_SHARE;
            float inset = band != Band.Sides ? CHEVRON_INSET : bandSize + CHEVRON_GAP;
            Vector2 tip = new Vector2(rect.xMax - inset, rect.center.y);
            float back = tip.x - CHEVRON_WIDTH;
            tri[0] = new Vector2(back, tip.y - h / 2f);
            tri[1] = tip;
            tri[2] = new Vector2(back, tip.y + h / 2f);
            pen.Poly(tri, Tint(ringColor));
        }
        if (ring && !plated)
        {
            Rect inner = Grow(rect, -(border + RING_GAP));
            // Clear of the tape too: a ring crossing the stripe reads as a glitch.
            if (band == Band.Left || band == Band.Sides) inner.xMin += bandSize;
            if (band == Band.Sides) inner.xMax -= bandSize;
            else if (band == Band.Top) inner.yMin += bandSize;
            pen.Frame(inner, Tint(ringColor), RING_WIDTH, false);
        }
    }

    // The Graphic's own colour multiplies everything, so a CanvasGroup-less fade can still dim a box.
    Color Tint(Color c)
    {
        return c * color;
    }

    static Rect Grow(Rect r, float by)
    {
        return new Rect(r.xMin - by, r.yMin - by, r.width + 2f * by, r.height + 2f * by);
    }

    // The band of tape on the left, the top or both sides.
    void DrawBand(UiPen pen, Rect rect)
    {
        if (band == Band.Left || band == Band.Sides)
            pen.Tape(new Rect(rect.xMin, rect.yMin, bandSize, rect.height), Tint(tapeOn), Tint(tapeOff));
        if (band == Band.Sides)
            pen.Tape(new Rect(rect.xMax - bandSize, rect.yMin, bandSize, rect.height), Tint(tapeOn), Tint(tapeOff));
        else if (band == Band.Top)
            pen.Tape(new Rect(rect.xMin, rect.yMin, rect.width, bandSize), Tint(tapeOn), Tint(tapeOff));
    }

    // The corner brackets, inside the edge; never on the tape (the band's corners have none).
    void Corners(UiPen pen, Rect rect)
    {
        Rect inner = Grow(rect, -(border + CORNER_GAP));
        for (int i = 0; i < 4; i++)
        {
            bool right = (i & 1) == 0, bottom = i < 2;
            if (!bottom && band == Band.Top) continue;
            if (!right && band == Band.Left) continue;
            Vector2 p = new Vector2(right ? inner.xMax : inner.xMin, bottom ? inner.yMax : inner.yMin);
            float sx = right ? -1f : 1f, sy = bottom ? -1f : 1f;
            pen.Box(Abs(p, CORNER_LEN * sx, CORNER_WIDTH * sy), Tint(cornerColor));
            pen.Box(Abs(p, CORNER_WIDTH * sx, CORNER_LEN * sy), Tint(cornerColor));
        }
    }

    static Rect Abs(Vector2 at, float w, float h)
    {
        return new Rect(w < 0f ? at.x + w : at.x, h < 0f ? at.y + h : at.y, Mathf.Abs(w), Mathf.Abs(h));
    }

    // The worn plate; returns the rect of its face (the room the pointer works in).
    Rect DrawPlate(UiPen pen, Rect rect)
    {
        Vector2 gap = PLATE_SHADOW * (press > 0f ? 0.35f : 1f);
        Rect body = new Rect(rect.xMin, rect.yMin, rect.width - PLATE_SHADOW.x, rect.height - PLATE_SHADOW.y);
        Octagon(new Rect(body.xMin + gap.x, body.yMin + gap.y, body.width, body.height), CUT);
        pen.Poly(shape, Tint(new Color(0f, 0f, 0f, 0.6f)));
        if (press > 0f) body.yMin += 2f;
        Octagon(body, CUT);
        Color topShade = UiKit.Lightened(fill, 0.18f), bottomShade = UiKit.Darkened(fill, 0.28f);
        shades.Clear();
        for (int i = 0; i < shape.Count; i++)
            shades.Add(Tint(Color.Lerp(topShade, bottomShade, Mathf.Clamp01((shape[i].y - body.yMin) / body.height))));
        pen.Poly(shape, shades);
        float inset = band == Band.Sides ? bandSize : 0f;
        if (band == Band.Sides)
        {
            // Tape down both sides of the plate, inside its chamfered corners.
            pen.Tape(new Rect(body.xMin, body.yMin + CUT, inset, body.height - 2f * CUT), Tint(tapeOn), Tint(tapeOff));
            pen.Tape(new Rect(body.xMax - inset, body.yMin + CUT, inset, body.height - 2f * CUT), Tint(tapeOn), Tint(tapeOff));
        }
        Bevel(pen, body, inset);
        Sheen(pen, body, inset);
        Scuffs(pen, body, inset);
        Rivets(pen, body, inset);
        Octagon(body, CUT);
        pen.Outline(shape, Tint(ring ? focusEdge : edge), ring ? FOCUS_OUTLINE : PLATE_OUTLINE);
        return body;
    }

    static void Octagon(Rect r, float cut)
    {
        shape.Clear();
        shape.Add(new Vector2(r.xMin + cut, r.yMin));
        shape.Add(new Vector2(r.xMax - cut, r.yMin));
        shape.Add(new Vector2(r.xMax, r.yMin + cut));
        shape.Add(new Vector2(r.xMax, r.yMax - cut));
        shape.Add(new Vector2(r.xMax - cut, r.yMax));
        shape.Add(new Vector2(r.xMin + cut, r.yMax));
        shape.Add(new Vector2(r.xMin, r.yMax - cut));
        shape.Add(new Vector2(r.xMin, r.yMin + cut));
    }

    void Bevel(UiPen pen, Rect body, float inset)
    {
        Color light = Tint(new Color(1f, 1f, 1f, press == 0f ? 0.34f : 0.1f));
        Color dark = Tint(new Color(0f, 0f, 0f, press == 0f ? 0.45f : 0.6f));
        float x0 = body.xMin + inset, x1 = body.xMax - inset;
        pen.Box(new Rect(x0, body.yMin, x1 - x0, PLATE_BEVEL), light);
        pen.Box(new Rect(x0, body.yMax - PLATE_BEVEL, x1 - x0, PLATE_BEVEL), dark);
        pen.Box(new Rect(x0, body.yMin, 2f, body.height), light);
        pen.Box(new Rect(x1 - 2f, body.yMin, 2f, body.height), dark);
    }

    // A soft diagonal gleam across the upper half, as on brushed steel.
    void Sheen(UiPen pen, Rect body, float inset)
    {
        float x0 = body.xMin + inset + 8f, x1 = body.xMax - inset - 8f;
        float y0 = body.yMin + PLATE_BEVEL, y1 = body.yMin + body.height * 0.5f;
        quad[0] = new Vector2(x0, y0);
        quad[1] = new Vector2(x1, y0);
        quad[2] = new Vector2(x1, y1 - 10f);
        quad[3] = new Vector2(x0, y1);
        quadShades[0] = quadShades[1] = Tint(new Color(1f, 1f, 1f, 0.14f));
        quadShades[2] = quadShades[3] = Tint(new Color(1f, 1f, 1f, 0f));
        pen.Poly(quad, quadShades);
    }

    // Short light and dark scratches, seeded from the size so a plate never changes between frames; each
    // stays in the strip along the top or the bottom edge (never the label's band), alternating.
    void Scuffs(UiPen pen, Rect body, float inset)
    {
        S.RandomNumberGenerator rng = new S.RandomNumberGenerator();
        rng.seed = (long)(int)body.width * 7919L + (long)(int)body.height * 104729L;
        float x0 = body.xMin + inset + 10f;
        float w = body.width - 2f * inset - 20f;
        float strip = body.height * SCUFF_STRIP;
        float laneTop = body.yMin + PLATE_BEVEL + 1f;
        float laneBottom = body.yMax - PLATE_BEVEL - 1f - strip;
        for (int i = 0; i < SCUFFS; i++)
        {
            float lane = (i >> 1) % 2 == 0 ? laneTop : laneBottom;
            Vector2 at = new Vector2(x0 + (float)rng.Randf() * w, lane + (float)rng.Randf() * strip);
            Vector2 along = new Vector2((float)rng.RandfRange(10.0, 34.0), (float)rng.RandfRange(-1.5, 1.5));
            along.y = Mathf.Clamp(at.y + along.y, lane, lane + strip) - at.y;
            along.x = Mathf.Min(along.x, x0 + w - at.x);  // never on into the tape
            pen.Line(at, at + along, Tint(i % 2 == 0 ? new Color(1f, 1f, 1f, 0.16f) : new Color(0f, 0f, 0f, 0.3f)), 1.5f);
        }
    }

    void Rivets(UiPen pen, Rect body, float inset)
    {
        float x0 = body.xMin + inset + 11f, x1 = body.xMax - inset - 11f;
        float y0 = body.yMin + 10f, y1 = body.yMax - 10f;
        for (int i = 0; i < 4; i++)
        {
            Vector2 p = new Vector2((i & 1) == 0 ? x0 : x1, i < 2 ? y0 : y1);
            pen.Circle(p + new Vector2(1f, 1.5f), RIVET + 1f, Tint(new Color(0f, 0f, 0f, 0.55f)));
            pen.Circle(p, RIVET, Tint(RIVET_COLOUR));
            pen.Circle(p + new Vector2(-1f, -1f), RIVET * 0.45f, Tint(new Color(1f, 1f, 1f, 0.55f)));
        }
    }
}
