// Hazard tape filling the rect. (scenes/ui_marks.gd; drawn in code, no image to license.)
using UnityEngine;
using UnityEngine.UI;

public sealed class UiTape : MaskableGraphic
{
    static readonly Color OFF = new Color32(0x11, 0x11, 0x14, 0xff);

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        new UiPen(vh, area).Tape(new Rect(0f, 0f, area.width, area.height), UiKit.ACCENT * color, OFF * color);
    }
}
