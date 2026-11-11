// A meter (ui_kit.gd bar): square, white-edged on black, filled from the left to `Value` (0..1).
using UnityEngine;

public sealed class KitBar : MonoBehaviour
{
    public RectTransform fill;
    float shown;

    public float Value
    {
        get { return shown; }
        set
        {
            shown = Mathf.Clamp01(value);
            if (fill != null) fill.anchorMax = new Vector2(shown, 1f);
        }
    }
}
