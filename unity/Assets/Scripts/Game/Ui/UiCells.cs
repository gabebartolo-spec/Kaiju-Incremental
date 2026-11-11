// A stat meter of whole cells: `filled` of `cells` lit hazard yellow, the rest dark with a faint edge. (scenes/ui_marks.gd; drawn in code, no image to license.)
using UnityEngine;
using UnityEngine.UI;

public sealed class UiCells : MaskableGraphic
{
    public const float MIN_CELL = 14f;
    public const float GAP = 4f;
    const float EMPTY_ALPHA = 0.75f;
    const float EMPTY_EDGE = 2f;

    public int cells = 8;
    public int filled;

    // One cell's drawn width (px) at the current size.
    public float CellWidth()
    {
        return (rectTransform.rect.width - GAP * (cells - 1)) / cells;
    }

    public void Set(int count, int lit)
    {
        cells = count;
        filled = lit;
        SetVerticesDirty();
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        float w = (area.width - GAP * (cells - 1)) / cells;
        for (int i = 0; i < cells; i++)
        {
            Rect r = new Rect(i * (w + GAP), 0f, w, area.height);
            if (i < filled)
            {
                pen.Box(r, UiKit.ACCENT * color);
                continue;
            }
            pen.Box(r, new Color(0f, 0f, 0f, EMPTY_ALPHA) * color);
            // Godot's unfilled draw_rect centres its line on the rect's edge.
            Rect outer = new Rect(r.xMin - EMPTY_EDGE / 2f, r.yMin - EMPTY_EDGE / 2f, r.width + EMPTY_EDGE, r.height + EMPTY_EDGE);
            pen.Frame(outer, UiKit.MUTED * color, EMPTY_EDGE, false);
        }
    }
}
