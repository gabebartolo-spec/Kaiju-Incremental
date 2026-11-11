// Faint horizontal lines, like an old broadcast monitor. (scenes/ui_marks.gd; drawn in code, no image to license.)
using UnityEngine;
using UnityEngine.UI;

public sealed class UiScanlines : MaskableGraphic
{
    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        Color line = new Color(1f, 1f, 1f, UiKit.SCANLINE_ALPHA) * color;
        for (float y = 0f; y < area.height; y += UiKit.SCANLINE_STEP)
            pen.Box(new Rect(0f, y, area.width, UiKit.SCANLINE_STEP / 2f), line);
    }
}
