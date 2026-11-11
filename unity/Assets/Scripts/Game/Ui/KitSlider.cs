// The kit's slider (ui_kit.gd slider_look on an HSlider): a white-edged black track filled hazard yellow and
// a square yellow grabber whose edge turns white when the slider has focus. Left and right always change the
// value by one step (they never leave the slider); the mouse snaps to the same steps.
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public sealed class KitSlider : Slider
{
    // The grabber's side and edge, and the track's height inside the row (px at 1080p).
    public const float GRABBER = 28f;
    public const float GRABBER_EDGE = 4f;
    public const float TRACK = 12f;

    public float step = 1f;
    public HazardBox grabber;

    float Snap(float v)
    {
        if (step <= 0f) return v;
        return Mathf.Clamp(minValue + Mathf.Round((v - minValue) / step) * step, minValue, maxValue);
    }

    protected override void Set(float input, bool sendCallback = true)
    {
        base.Set(Snap(input), sendCallback);
    }

    public override void OnMove(AxisEventData eventData)
    {
        if (!IsActive() || !IsInteractable())
        {
            base.OnMove(eventData);
            return;
        }
        float by = step > 0f ? step : (maxValue - minValue) * 0.1f;
        if (eventData.moveDir == MoveDirection.Left) value -= by;
        else if (eventData.moveDir == MoveDirection.Right) value += by;
        else base.OnMove(eventData);
    }

    // The mouse and the keyboard share one highlight, as on the buttons.
    public override void OnPointerEnter(PointerEventData eventData)
    {
        base.OnPointerEnter(eventData);
        if (IsActive() && IsInteractable() && EventSystem.current != null && EventSystem.current.currentSelectedGameObject != gameObject)
            EventSystem.current.SetSelectedGameObject(gameObject);
    }

    protected override void DoStateTransition(SelectionState state, bool instant)
    {
        if (grabber == null) return;
        bool lit = state == SelectionState.Selected || state == SelectionState.Pressed;
        grabber.edge = lit ? Color.white : UiKit.BG;
        grabber.Redraw();
    }
}
