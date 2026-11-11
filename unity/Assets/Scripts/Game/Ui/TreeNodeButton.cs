// One node of the evolution tree as a glass cell (scenes/upgrade_node.gd): outlined when it can be bought, dim
// when it cannot, a dashed outline when locked, full of Special K violet when maxed; evolutions in alert red,
// the ultimate under hazard tape. The words and the state come from TreeText; this only draws them.
using System;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class TreeNodeButton : Selectable, IPointerClickHandler, ISubmitHandler
{
    // upgrade_node.gd: the text's room inside the box, the font's range, the evolution's fill.
    public const float PAD = 2f;
    public const int FONT_MIN = 18, FONT_MAX = 30;
    static readonly Color EVOLVE_FILL = new Color32(0x3a, 0x0d, 0x0b, 0xff);

    public string id;
    public string role = "plain";
    public string state = "locked";
    public bool shapeOnly;
    public Action<string> pressed, focused, hovered;
    HazardBox box;
    Text label;
    Color fill, edge;
    float width;
    bool verb;

    // The thickest border each kind of node draws (focused): its text keeps clear of it.
    static float MaxBorder(string role)
    {
        return role == "ultimate" ? 8f : 5f;
    }

    // A colour of the tree's skin (tuning "tree" "skin": "plate", or "fill" "buy").
    public static Color Skin(string key, string state = null)
    {
        S.GDict skin = S.Content.Section("tree")["skin"];
        string hex = state == null ? S.Gd.Str(skin[key]) : S.Gd.Str(((S.GDict)skin[key])[state]);
        return ColorUtility.TryParseHtmlString("#" + hex, out Color c) ? c : Color.magenta;
    }

    public static TreeNodeButton Make(Transform parent, string id, string role, string kind, Vector2 size)
    {
        HazardBox plate = UiKit.Hazard(parent, Color.black, Color.white, 3f, HazardBox.Band.None, "Node_" + id);
        plate.raycastTarget = true;
        RectTransform rt = plate.rectTransform;
        // Placed from the area's top left, as Godot places a Control.
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0f, 1f);
        rt.sizeDelta = size;
        RectTransform words = UiKit.Box(rt, "Label");
        UiKit.FullRect(words);
        float inset = PAD + MaxBorder(role) + 1f;
        words.offsetMin = new Vector2(inset, inset);
        words.offsetMax = new Vector2(-inset, -inset);
        Text t = words.gameObject.AddComponent<Text>();
        t.font = UiKit.Font(UiKit.SIZE_BODY);
        t.fontSize = FONT_MAX;
        t.alignment = TextAnchor.MiddleCenter;
        t.horizontalOverflow = HorizontalWrapMode.Wrap;
        t.verticalOverflow = VerticalWrapMode.Truncate;
        // Godot picks the largest size at which the name fits; uGUI's best fit does the same job here.
        t.resizeTextForBestFit = true;
        t.resizeTextMinSize = FONT_MIN;
        t.resizeTextMaxSize = FONT_MAX;
        t.supportRichText = false;
        t.raycastTarget = false;
        TreeNodeButton b = plate.gameObject.AddComponent<TreeNodeButton>();
        b.id = id;
        b.role = role;
        b.verb = kind == "verb";
        b.box = plate;
        b.label = t;
        b.targetGraphic = plate;
        b.transition = Transition.None;
        return b;
    }

    // The node's state and words now (upgrade_node.gd show_state). A hidden node is not shown at all.
    public void ShowState(S.UpgradeTree tree, long rubble)
    {
        gameObject.SetActive(!TreeText.Hidden(tree, id));
        shapeOnly = TreeText.ShapeOnly(tree, id);
        state = TreeText.StateOf(tree, id, rubble);
        label.text = TreeText.NodeText(tree, id, rubble);
        fill = Skin("fill", state);
        edge = Skin("edge", state);
        width = verb ? 5f : 3f;
        bool locked = state == "locked";
        box.band = HazardBox.Band.None;
        if (role == "evolve" && state != "maxed")
        {
            edge = locked ? UiKit.Darkened(UiKit.ALERT, 0.45f) : UiKit.ALERT;
            if (!locked) fill = EVOLVE_FILL;
            width = 5f;
        }
        else if (role == "ultimate")
        {
            edge = locked ? UiKit.Darkened(UiKit.ACCENT, 0.55f) : UiKit.ACCENT;
            width = 6f;
            box.band = HazardBox.Band.Top;
            box.bandSize = 8f;
            box.tapeOn = locked ? UiKit.LOCKED : UiKit.ACCENT;
        }
        box.liquid = (float)TreeText.Liquid(tree, id);
        box.liquidColor = Skin("liquid");
        box.liquidTop = Skin("liquid_top");
        label.color = state == "buy" || state == "maxed" ? UiKit.TEXT : UiKit.Lightened(UiKit.MUTED, 0.25f);
        Look(currentSelectionState);
    }

    // The mouse over a node shows it in the side panel; it does not take the focus (tree_area.gd).
    public override void OnPointerEnter(PointerEventData eventData)
    {
        base.OnPointerEnter(eventData);
        hovered?.Invoke(id);
    }

    public override void OnSelect(BaseEventData eventData)
    {
        base.OnSelect(eventData);
        focused?.Invoke(id);
    }

    public void OnPointerClick(PointerEventData eventData)
    {
        if (eventData.button != PointerEventData.InputButton.Left || eventData.dragging) return;
        pressed?.Invoke(id);
    }

    public void OnSubmit(BaseEventData eventData)
    {
        pressed?.Invoke(id);
    }

    protected override void DoStateTransition(SelectionState s, bool instant)
    {
        Look(s);
    }

    // The box one look of the button draws (upgrade_node.gd _look).
    void Look(SelectionState s)
    {
        if (box == null) return;
        bool normal = s == SelectionState.Normal || s == SelectionState.Disabled;
        box.fill = normal ? fill : s == SelectionState.Pressed ? UiKit.Darkened(fill, 0.2f) : UiKit.Lightened(fill, 0.15f);
        box.edge = normal ? edge : Color.white;
        // Plain nodes thicken when focused; evolutions and the ultimate are thick already.
        box.border = s == SelectionState.Selected && width < 5f ? width + 2f : width;
        box.dashed = normal && state == "locked";
        box.Redraw();
    }
}
