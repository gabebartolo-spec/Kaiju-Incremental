// The kit's button (scenes/ui_button.gd): a worn plate with hazard tape down both edges, one look per state
// (normal, hover, focus, pressed, disabled), the label centred on the plate's face, and one highlight shared
// by the mouse and the pad: hovering moves the focus, so two buttons are never lit at once.
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public sealed class KitButton : Button
{
    // A fill darker than this lights up hazard yellow in focus; a brighter one keeps its own colour.
    const float LIT_BELOW = 0.3f;

    public HazardBox plate;
    public Text label;
    public Color fill = UiKit.ACCENT;
    public bool taped = true;
    bool pointer = true;

    Color Lit => UiKit.Luminance(fill) < LIT_BELOW ? UiKit.ACCENT : fill;

    public string text
    {
        get { return label.text; }
        set { if (label.text != value) label.text = value; }
    }

    // UiKit.Button calls this once the plate and the label exist.
    public void Setup(HazardBox box, Text words, Color colour, bool tape)
    {
        plate = box;
        label = words;
        fill = colour;
        taped = tape;
        transition = Transition.None;
        // Every state keeps room inside the right tape for the focus pointer, so focus never shifts the text;
        // the left matches it. The face stands PLATE_SHADOW short of the rect on the right and the bottom.
        float room = taped ? UiKit.BUTTON_BAND + HazardBox.CHEVRON_GAP + HazardBox.CHEVRON_WIDTH + 6f : 10f;
        Pad(room, UiKit.BOX_MARGIN, room + HazardBox.PLATE_SHADOW.x, UiKit.BOX_MARGIN + HazardBox.PLATE_SHADOW.y);
        onClick.AddListener(Click);
        Show(currentSelectionState);
    }

    static void Click()
    {
        Sfx.Ui("ui_click");
    }

    void Pad(float left, float top, float right, float bottom)
    {
        HorizontalLayoutGroup group = GetComponent<HorizontalLayoutGroup>();
        group.padding = new RectOffset(Mathf.RoundToInt(left), Mathf.RoundToInt(right), Mathf.RoundToInt(top), Mathf.RoundToInt(bottom));
    }

    // Takes the focus pointer off (the focus shows in the outline) and closes the room it needed, so a narrow
    // button keeps its text (hazard_box.gd drop_pointer).
    public void DropPointer()
    {
        pointer = false;
        RectOffset p = GetComponent<HorizontalLayoutGroup>().padding;
        float side = plate.bandSize + HazardBox.POINTERLESS_ROOM;
        Pad(side, p.top, side + HazardBox.PLATE_SHADOW.x, p.bottom);
        Show(currentSelectionState);
    }

    // Trims the room above and below the label to `margin` px, so the plate stands lower (trim_height).
    public void TrimHeight(float margin)
    {
        RectOffset p = GetComponent<HorizontalLayoutGroup>().padding;
        Pad(p.left, margin, p.right, margin + HazardBox.PLATE_SHADOW.y);
    }

    // The mouse and the keyboard share one highlight: hovering moves the focus.
    public override void OnPointerEnter(PointerEventData eventData)
    {
        base.OnPointerEnter(eventData);
        if (IsActive() && IsInteractable() && EventSystem.current != null && EventSystem.current.currentSelectedGameObject != gameObject)
            EventSystem.current.SetSelectedGameObject(gameObject);
    }

    protected override void DoStateTransition(SelectionState state, bool instant)
    {
        Show(state);
    }

    void Show(SelectionState state)
    {
        if (plate == null || label == null) return;
        Color lit = Lit, ink;
        plate.tapeOn = UiKit.ACCENT;
        plate.ring = false;
        plate.chevron = false;
        plate.press = 0f;
        switch (state)
        {
            case SelectionState.Disabled:
                plate.fill = UiKit.PANEL;
                plate.edge = UiKit.LOCKED;
                plate.tapeOn = UiKit.LOCKED;
                ink = UiKit.Lightened(UiKit.LOCKED, 0.3f);
                break;
            case SelectionState.Pressed:
                plate.fill = UiKit.Darkened(lit, 0.25f);
                plate.edge = lit;
                plate.ring = true;
                plate.press = 1f;
                ink = UiKit.Ink(plate.fill);
                break;
            case SelectionState.Selected:
                plate.fill = lit;
                plate.edge = lit;
                plate.ring = true;
                plate.chevron = taped && pointer;
                ink = UiKit.Ink(lit);
                break;
            case SelectionState.Highlighted:
                plate.fill = lit;
                plate.edge = lit;
                plate.chevron = taped && pointer;
                ink = UiKit.Ink(lit);
                break;
            default:
                plate.fill = fill;
                plate.edge = UiKit.Lightened(fill, 0.15f);
                ink = UiKit.Ink(fill);
                break;
        }
        plate.ringColor = UiKit.Ink(plate.fill);
        plate.Redraw();
        label.color = ink;
    }
}
