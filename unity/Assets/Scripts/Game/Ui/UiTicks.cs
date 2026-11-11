// A meter's scale: a dark tick every tenth, over the fill, so its level reads by position as well as colour. (scenes/ui_marks.gd; drawn in code, no image to license.)
using UnityEngine;
using UnityEngine.UI;

public sealed class UiTicks : MaskableGraphic
{
    public const int STEPS = 10;
    public const float WIDTH = 3f;
    const float ALPHA = 0.85f;

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        Color line = new Color(UiKit.BG.r, UiKit.BG.g, UiKit.BG.b, ALPHA) * color;
        for (int i = 1; i < STEPS; i++)
            pen.Box(new Rect(Mathf.Round(area.width * i / STEPS - WIDTH / 2f), 0f, WIDTH, area.height), line);
    }
}
