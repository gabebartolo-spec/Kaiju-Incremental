// The one UI kit (scenes/ui_kit.gd): palette, type sizes and widget builders in uGUI, all made in code. Every
// screen builds its controls here so text stays readable on a TV (24 px base at 1080p) and the look stays one
// look: the director's pick A, "emergency broadcast". Hazard yellow on near-black, alert red, square edges, tape.
// Sizes are px on the 1920x1080 canvas; the canvas scales to the window times the player's UI scale.
using System;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;
using Opt = Kaiju.Game.PlayerSettings;

public static class UiKit
{
    public static readonly Color BG = Hex(0x0b0b0d);
    public static readonly Color PANEL = Hex(0x16161a);
    public static readonly Color PANEL_EDGE = Hex(0x3a3a40);
    public static readonly Color TEXT = Hex(0xf2efe6);
    public static readonly Color MUTED = Hex(0xb9b4a6);
    // Hazard yellow: titles, the primary button, focus.
    public static readonly Color ACCENT = Hex(0xffcc00);
    // Alert red: evolutions, the clock running out.
    public static readonly Color ALERT = Hex(0xff3b30);
    // The news crawl's strip: alert red dark enough that white 24 px text reads at 5:1.
    public static readonly Color CRAWL_RED = Hex(0xd42a1f);
    public static readonly Color ORANGE = Hex(0xff8a1f);
    public static readonly Color GOOD = Hex(0x7dff6a);
    public static readonly Color WARN = Hex(0xffd84a);
    public static readonly Color BAD = Hex(0xff3b30);
    public static readonly Color LOCKED = Hex(0x7c7c84);
    // Text on a fill this bright or brighter is dark (BG), else light.
    public const float BRIGHT_FILL = 0.45f;
    // The hazard band along a button's edges and a panel's top (px at 1080p).
    public const float BUTTON_BAND = 22f;
    public const float PANEL_BAND = 14f;
    // A box's content sits this far inside it; a card's this far inside its corner brackets.
    public const float BOX_MARGIN = 14f;
    public const float CARD_PAD = 12f;
    // Scanlines over a backdrop: one line every SCANLINE_STEP px, this faint.
    public const float SCANLINE_STEP = 4f;
    public const float SCANLINE_ALPHA = 0.035f;

    public const int SIZE_BODY = 24;
    public const int SIZE_SMALL = 20;
    public const int SIZE_HEAD = 36;
    public const int SIZE_TITLE = 72;
    // The architecture's short names for the same sizes.
    public const int BODY = SIZE_BODY, SMALL = SIZE_SMALL, HEAD = SIZE_HEAD, TITLE = SIZE_TITLE;
    // Headings at this size and above use the display face (Kaiju Claw); below it the claw gashes turn to noise.
    public const int DISPLAY_MIN_SIZE = SIZE_HEAD;
    // The faces under Resources/Fonts (the build copies assets/fonts/*.ttf there).
    public const string BODY_FONT = "Fonts/kaiju_block";
    public const string DISPLAY_FONT = "Fonts/kaiju_claw";
    const string FALLBACK_FONT = "LegacyRuntime.ttf";

    // The canvas every screen is drawn on, and how far above the game it sorts.
    public const float CANVAS_WIDTH = 1920f, CANVAS_HEIGHT = 1080f;
    const int SORT_ORDER = 100;
    // An options row (options_page.gd, settings_menu.gd): the name's column, the controls' column, the gaps,
    // a choice button's height and label room, a slider's height and its value text's column.
    public const float NAME_WIDTH = 380f;
    public const float SPAN = 420f;
    public const float BUTTON_GAP = 20f;
    public const float CHOICE_HEIGHT = 48f;
    public const float CHOICE_MARGIN = 8f;
    public const float SLIDER_HEIGHT = 28f;
    public const float VALUE_WIDTH = 90f;
    // A column's own gap between rows (the settings card's).
    public const float COLUMN_GAP = 6f;
    const float TRACK_ALPHA = 0.75f;

    static Canvas canvas;
    static CanvasScaler scaler;
    static Font bodyFont, displayFont, fallbackFont;
    static bool fontWarned;

    // ---- the canvas -------------------------------------------------------------------------------------

    // The one Canvas: screen-space overlay, 1920x1080 reference, expand; made on first use.
    public static Canvas Root
    {
        get
        {
            EnsureRoot();
            return canvas;
        }
    }

    public static void EnsureRoot()
    {
        if (canvas != null) return;
        GameObject go = new GameObject("Ui");
        canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = SORT_ORDER;
        scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.Expand;
        go.AddComponent<GraphicRaycaster>();
        go.AddComponent<UiFocus>();
        EventSystem events = EventSystem.current;
        if (events == null)
        {
            GameObject eg = new GameObject("EventSystem");
            eg.transform.SetParent(go.transform, false);
            events = eg.AddComponent<EventSystem>();
            eg.AddComponent<StandaloneInputModule>();
        }
        // The input module keeps the mouse; UiFocus moves the focus (keys and the XInput pad), so the two
        // never both answer one press.
        events.sendNavigationEvents = false;
        Opt.Changed -= ApplyScale;
        Opt.Changed += ApplyScale;
        ApplyScale();
    }

    // The player's UI scale (100 / 115 / 125 %): a smaller reference makes everything larger.
    public static void ApplyScale()
    {
        if (scaler == null) return;
        float scale = Mathf.Max((float)Opt.UiScale, 0.01f);
        scaler.referenceResolution = new Vector2(CANVAS_WIDTH, CANVAS_HEIGHT) / scale;
    }

    // A new full-screen layer on the canvas, above the ones before it. Destroy its GameObject to close it.
    public static RectTransform Screen(string name)
    {
        EnsureRoot();
        RectTransform rt = Box(canvas.transform, name);
        FullRect(rt);
        return rt;
    }

    // An empty rect under `parent`.
    public static RectTransform Box(Transform parent, string name)
    {
        GameObject go = new GameObject(name, typeof(RectTransform));
        RectTransform rt = (RectTransform)go.transform;
        rt.SetParent(parent, false);
        return rt;
    }

    public static void FullRect(RectTransform rt)
    {
        rt.anchorMin = Vector2.zero;
        rt.anchorMax = Vector2.one;
        rt.offsetMin = Vector2.zero;
        rt.offsetMax = Vector2.zero;
    }

    // A flat colour filling its parent (a dim, a strip). It does not take the mouse.
    public static Image Fill(Transform parent, Color colour, string name = "Fill")
    {
        RectTransform rt = Box(parent, name);
        FullRect(rt);
        Image image = rt.gameObject.AddComponent<Image>();
        image.color = colour;
        image.raycastTarget = false;
        return image;
    }

    // Gives a control a least size in a row or column (Godot's custom_minimum_size); 0 leaves that side alone.
    public static LayoutElement Size(Component control, float width, float height)
    {
        LayoutElement e = control.GetComponent<LayoutElement>();
        if (e == null) e = control.gameObject.AddComponent<LayoutElement>();
        if (width > 0f) e.minWidth = e.preferredWidth = width;
        if (height > 0f) e.minHeight = e.preferredHeight = height;
        return e;
    }

    // A control that is not in a row or column takes its content's size (a free-standing label or panel).
    public static void Fit(Component control)
    {
        ContentSizeFitter f = control.GetComponent<ContentSizeFitter>();
        if (f == null) f = control.gameObject.AddComponent<ContentSizeFitter>();
        f.horizontalFit = ContentSizeFitter.FitMode.PreferredSize;
        f.verticalFit = ContentSizeFitter.FitMode.PreferredSize;
    }

    // A column of controls, top to bottom, `gap` px apart, each as wide as the column.
    public static RectTransform Column(Transform parent, float gap = COLUMN_GAP, string name = "Column")
    {
        RectTransform rt = Box(parent, name);
        VerticalLayoutGroup g = rt.gameObject.AddComponent<VerticalLayoutGroup>();
        g.spacing = gap;
        g.childAlignment = TextAnchor.UpperCenter;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = true;
        g.childForceExpandHeight = false;
        return rt;
    }

    // A row of controls, left to right, `gap` px apart, centred on the row's height.
    public static RectTransform Row(Transform parent, float gap = BUTTON_GAP, string name = "Row")
    {
        RectTransform rt = Box(parent, name);
        HorizontalLayoutGroup g = rt.gameObject.AddComponent<HorizontalLayoutGroup>();
        g.spacing = gap;
        g.childAlignment = TextAnchor.MiddleLeft;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = false;
        g.childForceExpandHeight = false;
        return rt;
    }

    // ---- text -------------------------------------------------------------------------------------------

    // Kaiju Claw for headings at or above DISPLAY_MIN_SIZE, else Kaiju Block, each falling back to the Chinese
    // subset (CjkFont). A missing face falls back to the engine's built-in one and says so once.
    public static UnityEngine.Font Font(int size)
    {
        bool display = size >= DISPLAY_MIN_SIZE;
        if (display && displayFont == null) displayFont = CjkFont.Attach(Resources.Load<UnityEngine.Font>(DISPLAY_FONT));
        if (!display && bodyFont == null) bodyFont = CjkFont.Attach(Resources.Load<UnityEngine.Font>(BODY_FONT));
        UnityEngine.Font font = display ? displayFont : bodyFont;
        if (font != null) return font;
        if (!fontWarned)
        {
            fontWarned = true;
            Debug.LogWarning("ui: font " + (display ? DISPLAY_FONT : BODY_FONT) + " missing from Resources, using " + FALLBACK_FONT);
        }
        if (fallbackFont == null) fallbackFont = Resources.GetBuiltinResource<UnityEngine.Font>(FALLBACK_FONT);
        return fallbackFont;
    }

    // True when both of our own faces loaded (the gallery's proof line).
    public static bool FontsFound()
    {
        Font(SIZE_BODY);
        Font(SIZE_HEAD);
        return bodyFont != null && displayFont != null;
    }

    // A line of text in the kit's outlined style. `text` is looked up in the text table (as a Godot Label
    // did by itself); text set on the label later is shown as given, so pass that through Tr.T.
    public static Text Label(Transform parent, string text, int size = SIZE_BODY, Color? colour = null)
    {
        Text t = PlainText(parent, text, size, colour ?? TEXT);
        TextStyle(t, size);
        return t;
    }

    // The same without the outline and shadow (a button's own label).
    static Text PlainText(Transform parent, string text, int size, Color colour)
    {
        RectTransform rt = Box(parent, "Label");
        Text t = rt.gameObject.AddComponent<Text>();
        t.font = Font(size);
        t.fontSize = size;
        t.color = colour;
        t.alignment = TextAnchor.UpperLeft;
        t.horizontalOverflow = HorizontalWrapMode.Overflow;
        t.verticalOverflow = VerticalWrapMode.Overflow;
        t.supportRichText = false;
        t.raycastTarget = false;
        t.text = Tr.T(text ?? "");
        return t;
    }

    // Body text that wraps inside its width and grows down to fit (ui_kit.gd rich, without inline images).
    public static Text Paragraph(Transform parent, string text, int size = SIZE_BODY, Color? colour = null)
    {
        Text t = Label(parent, text, size, colour);
        t.horizontalOverflow = HorizontalWrapMode.Wrap;
        return t;
    }

    // The one outlined text style: a near-black outline about a fifth of the size and a soft drop shadow
    // (tuning ui.text), so the outline, not the scene, is what the letters sit on.
    public static void TextStyle(Text t, int size)
    {
        S.GDict cfg = Ui()["text"];
        KitText style = t.GetComponent<KitText>();
        if (style == null) style = t.gameObject.AddComponent<KitText>();
        style.outline = OutlinePx(size);
        style.outlineColor = OutlineColor();
        style.shadow = (float)S.Num.F(cfg["shadow_px"]);
        style.shadowColor = new Color(0f, 0f, 0f, (float)S.Num.F(cfg["shadow_alpha"]));
        t.SetVerticesDirty();
    }

    // The text outline's width at `size` (px at 1080p).
    public static int OutlinePx(int size)
    {
        S.GDict cfg = Ui()["text"];
        // Godot's roundi rounds a half away from zero.
        int share = (int)Math.Round(size * S.Num.F(cfg["outline_share"]), MidpointRounding.AwayFromZero);
        return Math.Max((int)S.Num.I(cfg["outline_min"]), share);
    }

    public static Color OutlineColor()
    {
        S.GDict cfg = Ui()["text"];
        return new Color(BG.r, BG.g, BG.b, (float)S.Num.F(cfg["outline_alpha"]));
    }

    // tuning "ui": margins, the text style, the HUD's sizes and timings.
    public static S.GDict Ui()
    {
        return S.Content.Section("ui");
    }

    // The TV title-safe margin (px at 1080p, x then y): nothing the player reads sits outside it.
    public static Vector2 SafeMargin()
    {
        S.GArray<S.Variant> m = Ui()["safe_margin"];
        return new Vector2((float)S.Num.F(m[0]), (float)S.Num.F(m[1]));
    }

    // A rect inset from `parent` to the title-safe area.
    public static RectTransform SafeArea(Transform parent)
    {
        Vector2 m = SafeMargin();
        RectTransform rt = Box(parent, "SafeArea");
        rt.anchorMin = Vector2.zero;
        rt.anchorMax = Vector2.one;
        rt.offsetMin = new Vector2(Mathf.Round(m.x), Mathf.Round(m.y));
        rt.offsetMax = new Vector2(-Mathf.Round(m.x), -Mathf.Round(m.y));
        return rt;
    }

    // ---- colour -----------------------------------------------------------------------------------------

    static Color Hex(int rgb)
    {
        return new Color32((byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb, 0xff);
    }

    // Godot's Color.lightened / darkened / get_luminance, on the colour's own (sRGB) numbers.
    public static Color Lightened(Color c, float by)
    {
        return new Color(c.r + (1f - c.r) * by, c.g + (1f - c.g) * by, c.b + (1f - c.b) * by, c.a);
    }

    public static Color Darkened(Color c, float by)
    {
        return new Color(c.r * (1f - by), c.g * (1f - by), c.b * (1f - by), c.a);
    }

    public static float Luminance(Color c)
    {
        return 0.2126f * c.r + 0.7152f * c.g + 0.0722f * c.b;
    }

    // WCAG contrast ratio of two colours (1..21); body text wants 4.5 or more.
    public static float Contrast(Color a, Color b)
    {
        float la = Luminance(a.linear), lb = Luminance(b.linear);
        return (Mathf.Max(la, lb) + 0.05f) / (Mathf.Min(la, lb) + 0.05f);
    }

    // Dark text on bright fills, light text on dark ones.
    public static Color Ink(Color fill)
    {
        return Luminance(fill) >= BRIGHT_FILL ? BG : TEXT;
    }

    // ---- boxes ------------------------------------------------------------------------------------------

    // A broadcast box under `parent`: square, `edge` `border` px thick, hazard tape on `band`'s side.
    public static HazardBox Hazard(Transform parent, Color fill, Color edge, float border = 2f, HazardBox.Band band = HazardBox.Band.None, string name = "Box")
    {
        HazardBox s = Box(parent, name).gameObject.AddComponent<HazardBox>();
        s.fill = fill;
        s.edge = edge;
        s.border = border;
        s.band = band;
        s.bandSize = band == HazardBox.Band.Left || band == HazardBox.Band.Sides ? BUTTON_BAND : PANEL_BAND;
        s.raycastTarget = false;
        return s;
    }

    // How far a card's content sits inside its edge on the sides and bottom (px).
    public static float PanelInset()
    {
        return HazardBox.CORNER_GAP + HazardBox.CORNER_WIDTH + 3f + CARD_PAD;
    }

    // A card: hazard tape across the top, a yellow edge, brackets in the lower corners. It is a column: what
    // is added to it stacks top to bottom inside the card's margins, and the card grows to fit, centred on
    // its parent (UiKit.Size gives it a least width). It stops the mouse reaching what is behind it.
    public static RectTransform Panel(Transform parent, Color? colour = null, float gap = COLUMN_GAP)
    {
        HazardBox s = Hazard(parent, colour ?? PANEL, ACCENT, 3f, HazardBox.Band.Top, "Panel");
        s.corners = true;
        s.raycastTarget = true;
        int inset = Mathf.RoundToInt(PanelInset());
        VerticalLayoutGroup g = s.gameObject.AddComponent<VerticalLayoutGroup>();
        g.padding = new RectOffset(inset, inset, Mathf.RoundToInt(PANEL_BAND + BOX_MARGIN), inset);
        g.spacing = gap;
        g.childAlignment = TextAnchor.UpperCenter;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = true;
        g.childForceExpandHeight = false;
        Fit(s);
        return s.rectTransform;
    }

    // A header's margins (left, top, right, bottom) by size, measured on Godot 4K captures so the ink sat
    // dead centre in that engine. UNPROVEN for Unity's text: to be re-measured after the port (D-476).
    static RectOffset HeaderMargins(int size)
    {
        return size == SIZE_HEAD ? new RectOffset(7, 10, 3, 1) : new RectOffset(16, 20, 10, 2);
    }

    // A card's alert header: a red broadcast strip with the heading in white Kaiju Claw, centred.
    public static RectTransform Header(Transform parent, string text, int size = SIZE_TITLE)
    {
        HazardBox s = Hazard(parent, CRAWL_RED, CRAWL_RED, 0f, HazardBox.Band.None, "Header");
        HorizontalLayoutGroup g = s.gameObject.AddComponent<HorizontalLayoutGroup>();
        g.padding = HeaderMargins(size);
        g.childAlignment = TextAnchor.MiddleCenter;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = g.childForceExpandHeight = true;
        Text l = Label(s.transform, text, size, Color.white);
        l.alignment = TextAnchor.MiddleCenter;
        return s.rectTransform;
    }

    // ---- controls ---------------------------------------------------------------------------------------

    // A button with hazard tape down both edges; `onPress` runs on confirm or a click. Focus (and hover)
    // lights a dark button up in hazard yellow and outlines it, so the pad always shows where you are.
    public static KitButton Button(Transform parent, string text, Action onPress, int size = SIZE_BODY, Color? fill = null, bool taped = true)
    {
        HazardBox plate = Hazard(parent, fill ?? ACCENT, fill ?? ACCENT, 2f, taped ? HazardBox.Band.Sides : HazardBox.Band.None, "Button");
        plate.plated = true;
        plate.raycastTarget = true;
        HorizontalLayoutGroup g = plate.gameObject.AddComponent<HorizontalLayoutGroup>();
        g.childAlignment = TextAnchor.MiddleCenter;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = g.childForceExpandHeight = true;
        Text label = PlainText(plate.transform, text, size, BG);
        label.alignment = TextAnchor.MiddleCenter;
        KitButton b = plate.gameObject.AddComponent<KitButton>();
        b.targetGraphic = plate;
        b.Setup(plate, label, fill ?? ACCENT, taped);
        if (onPress != null) b.onClick.AddListener(() => onPress());
        return b;
    }

    // An options button (options_page.gd choice): dark, lower, no focus pointer, sharing its row's span.
    public static KitButton Choice(Transform parent, string text, Action onPress)
    {
        KitButton b = Button(parent, text, onPress, SIZE_BODY, PANEL_EDGE);
        LayoutElement e = b.gameObject.AddComponent<LayoutElement>();
        e.minHeight = CHOICE_HEIGHT;
        e.flexibleWidth = 1f;
        b.DropPointer();
        b.TrimHeight(CHOICE_MARGIN);
        return b;
    }

    // An option that steps through its values: a choice button reading "< value >". `onPress` steps to the
    // next value; show it with SetCycle.
    public static KitButton Cycle(Transform parent, string value, Action onPress)
    {
        KitButton b = Choice(parent, "", onPress);
        SetCycle(b, value);
        return b;
    }

    public static void SetCycle(KitButton button, string value)
    {
        button.text = CycleText(value);
    }

    public static string CycleText(string value)
    {
        return "< " + Tr.T(value) + " >";
    }

    // A slider in the broadcast look, `min` to `max` in steps of `step`; `onChange` hears each new value.
    public static KitSlider Slider(Transform parent, float min, float max, float step, float value, Action<float> onChange)
    {
        RectTransform root = Box(parent, "Slider");
        Size(root, SPAN, SLIDER_HEIGHT);
        HazardBox track = Hazard(root, new Color(0f, 0f, 0f, TRACK_ALPHA), TEXT, 2f, HazardBox.Band.None, "Track");
        Strip(track.rectTransform, KitSlider.TRACK);
        track.raycastTarget = true;
        RectTransform fillArea = Box(root, "Fill Area");
        Strip(fillArea, KitSlider.TRACK);
        Image fill = Fill(fillArea, ACCENT);
        RectTransform slide = Box(root, "Handle Slide Area");
        FullRect(slide);
        slide.offsetMin = new Vector2(KitSlider.GRABBER / 2f, 0f);
        slide.offsetMax = new Vector2(-KitSlider.GRABBER / 2f, 0f);
        HazardBox grabber = Hazard(slide, ACCENT, BG, KitSlider.GRABBER_EDGE, HazardBox.Band.None, "Handle");
        grabber.raycastTarget = true;
        grabber.rectTransform.anchorMin = new Vector2(0f, 0.5f);
        grabber.rectTransform.anchorMax = new Vector2(0f, 0.5f);
        grabber.rectTransform.sizeDelta = new Vector2(KitSlider.GRABBER, KitSlider.GRABBER);
        KitSlider s = root.gameObject.AddComponent<KitSlider>();
        s.transition = Selectable.Transition.None;
        s.targetGraphic = grabber;
        s.grabber = grabber;
        s.fillRect = fill.rectTransform;
        s.handleRect = grabber.rectTransform;
        s.direction = UnityEngine.UI.Slider.Direction.LeftToRight;
        s.minValue = min;
        s.maxValue = max;
        s.step = step;
        s.SetValueWithoutNotify(value);
        if (onChange != null) s.onValueChanged.AddListener(v => onChange(v));
        return s;
    }

    // Stretched across its parent, `height` tall, centred on the parent's height.
    static void Strip(RectTransform rt, float height)
    {
        rt.anchorMin = new Vector2(0f, 0.5f);
        rt.anchorMax = new Vector2(1f, 0.5f);
        rt.sizeDelta = new Vector2(0f, height);
        rt.anchoredPosition = Vector2.zero;
    }

    // An options row (options_page.gd row): `name` and, in the span beside it, `items` in equal parts.
    public static RectTransform OptionRow(Transform parent, string name, params Component[] items)
    {
        RectTransform line = Row(parent, BUTTON_GAP, "OptionRow");
        Text label = Label(line, name, SIZE_BODY);
        label.alignment = TextAnchor.MiddleLeft;
        Size(label, NAME_WIDTH, 0f);
        RectTransform span = Row(line, BUTTON_GAP, "Span");
        span.GetComponent<HorizontalLayoutGroup>().childForceExpandWidth = true;
        Size(span, SPAN, 0f);
        foreach (Component item in items)
        {
            if (item == null) continue;
            item.transform.SetParent(span, false);
            LayoutElement e = item.GetComponent<LayoutElement>();
            if (e == null) e = item.gameObject.AddComponent<LayoutElement>();
            e.flexibleWidth = 1f;
        }
        return line;
    }

    // A slider row (settings_menu.gd): the name, the slider, and a value text the caller fills (`shown`).
    public static KitSlider SliderRow(Transform parent, string name, float min, float max, float step, float value, Action<float> onChange, out Text shown)
    {
        RectTransform line = Row(parent, BUTTON_GAP, "SliderRow");
        Text label = Label(line, name, SIZE_BODY);
        label.alignment = TextAnchor.MiddleLeft;
        Size(label, NAME_WIDTH, 0f);
        KitSlider s = Slider(line, min, max, step, value, onChange);
        shown = Label(line, "", SIZE_BODY);
        shown.alignment = TextAnchor.MiddleLeft;
        Size(shown, VALUE_WIDTH, 0f);
        return s;
    }

    // A meter: square, white-edged on black, `height` tall. `taped` fills it with hazard tape in `fill`;
    // `ticks` marks every tenth. Set its Value (0..1).
    public static KitBar Bar(Transform parent, Color fill, float height = 26f, bool taped = false, bool ticks = true)
    {
        HazardBox back = Hazard(parent, new Color(0f, 0f, 0f, TRACK_ALPHA), TEXT, height < 12f ? 1f : 2f, HazardBox.Band.None, "Bar");
        Size(back, 0f, height);
        HazardBox inner = Hazard(back.transform, fill, fill, 0f, HazardBox.Band.None, "Fill");
        if (taped)
        {
            inner.band = HazardBox.Band.Top;
            inner.bandSize = height;
            inner.tapeOn = fill;
            inner.tapeOff = Darkened(fill, 0.2f);
        }
        FullRect(inner.rectTransform);
        // The frame is drawn over the fill's ends, as the edge of Godot's background box was.
        HazardBox frame = Hazard(back.transform, Color.clear, TEXT, back.border, HazardBox.Band.None, "Edge");
        FullRect(frame.rectTransform);
        back.border = 0f;
        if (ticks)
        {
            UiTicks marks = Box(back.transform, "Ticks").gameObject.AddComponent<UiTicks>();
            marks.raycastTarget = false;
            FullRect(marks.rectTransform);
        }
        KitBar bar = back.gameObject.AddComponent<KitBar>();
        bar.fill = inner.rectTransform;
        bar.Value = 0f;
        return bar;
    }

    // A stat meter of whole cells, `filled` of `cells` lit.
    public static UiCells Cells(Transform parent, int cells, int filled, float minCell = UiCells.MIN_CELL, float height = 26f)
    {
        UiCells c = Box(parent, "Cells").gameObject.AddComponent<UiCells>();
        c.raycastTarget = false;
        c.Set(cells, filled);
        Size(c, cells * minCell + (cells - 1) * UiCells.GAP, height);
        return c;
    }

    // A full-width strip of hazard tape, `height` tall (screen edges, dividers).
    public static UiTape Tape(Transform parent, float height = PANEL_BAND)
    {
        UiTape t = Box(parent, "Tape").gameObject.AddComponent<UiTape>();
        t.raycastTarget = false;
        Size(t, 0f, height);
        return t;
    }

    // The settings gear, `side` px square, in `colour`.
    public static GearIcon Gear(Transform parent, float side, Color? colour = null)
    {
        GearIcon g = Box(parent, "Gear").gameObject.AddComponent<GearIcon>();
        g.color = colour ?? Color.white;
        g.rectTransform.sizeDelta = new Vector2(side, side);
        Size(g, side, side);
        return g;
    }

    // The screen behind a menu: near-black with faint broadcast scanlines. It stops the mouse reaching the
    // game behind it.
    public static Image Backdrop(Transform parent)
    {
        Image r = Fill(parent, BG, "Backdrop");
        r.raycastTarget = true;
        UiScanlines lines = Box(r.transform, "Scanlines").gameObject.AddComponent<UiScanlines>();
        lines.raycastTarget = false;
        FullRect(lines.rectTransform);
        return r;
    }

    // Gives `first` the focus when a screen opens.
    public static void Focus(Selectable first)
    {
        UiFocus.Grab(first);
    }
}
