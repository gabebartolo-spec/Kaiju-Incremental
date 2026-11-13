// The campaign's hologram globe of Tellus Nova (scenes/globe_view.gd, D-418): GlobeStage draws the shell and the land
// sphere; GlobeOrbit (GameLogic) spins it idly, turns it on a left-drag and flies the camera to a picked continent and
// back. The pointer is hit-tested against the mask through the camera ray: the open continent under it lights up,
// and a click that did not drag picks it (Picked, then the fly-to); a click on the sea or cancel flies back out. Each
// continent's marker (GlobeMarker) stands at its anchor projected to the screen, faded toward the globe's edge and
// hidden on the far side or under the open mission panel. A locked continent neither lights up nor answers a click.
// Keys and pad step through the open continents (Godot's globe is mouse only). All screen maths run in the canvas's
// own units, as Godot's run in its 1080p-base canvas.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class GlobeHologram : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IPointerMoveHandler, IPointerExitHandler
{
    public const string MASK = "assets/overworld/tellus_nova_mask.png";

    static bool warned;
    static readonly Vector3[] corners = new Vector3[4];

    public string Selected => orbit.Selected;
    public string Hovered { get; private set; } = "";
    // A continent was picked (its id) or let go ("").
    public Action<string> Picked;
    // The open mission panel: a marker under it is hidden.
    public RectTransform Panel;
    // False while a mission plays over the globe (globe_missions.gd _launch): it still spins but takes no pointer.
    public bool Interactive = true;
    public int MaskWidth => maskW;
    public int MaskHeight => maskH;
    public int Markers => markers.Count;
    public GlobeOrbit Orbit => orbit;

    readonly GlobeOrbit orbit = new GlobeOrbit();
    RectTransform area;
    GlobeStage stage;
    byte[] mask;
    int maskW, maskH;
    readonly List<string> ids = new List<string>();
    readonly List<GlobeMarker> markers = new List<GlobeMarker>();
    readonly List<CanvasGroup> fades = new List<CanvasGroup>();
    double[][] anchors = new double[1][];  // per mask value, a unit point in the globe's frame (null: none)
    S.GDict states = new S.GDict();
    Vector2 last;

    // The globe filling `parent`: it takes the pointer everywhere, so a click off the land lets go.
    public static GlobeHologram Make(Transform parent)
    {
        RectTransform rt = UiKit.Box(parent, "Globe3D");
        UiKit.FullRect(rt);
        Image catcher = rt.gameObject.AddComponent<Image>();
        catcher.color = Color.clear;
        catcher.raycastTarget = true;
        GlobeHologram g = rt.gameObject.AddComponent<GlobeHologram>();
        g.area = rt;
        g.Load();
        g.stage = GlobeStage.Build(g.mask, g.maskW, g.maskH);
        if (g.stage == null) UiKit.Backdrop(rt).raycastTarget = false;
        foreach (S.GDict def in S.Content.Continents()) g.ids.Add(S.Gd.Str(def["id"]));
        g.Anchors();
        for (int n = 0; n < g.ids.Count; n++)
        {
            S.GDict def = S.Content.Continents()[n];
            GlobeMarker marker = GlobeMarker.Make(rt, S.Gd.Str(def.Get("name", def["id"])));
            RectTransform m = marker.rectTransform;
            m.anchorMin = m.anchorMax = new Vector2(0f, 1f);
            g.markers.Add(marker);
            g.fades.Add(marker.gameObject.AddComponent<CanvasGroup>());
        }
        g.Fit();
        g.stage?.Pose(g.orbit, Time.time);
        return g;
    }

    // The mask's bytes, row 0 at the top; a missing or unreadable file says so once and the globe draws no land.
    void Load()
    {
        string file = Path.Combine(S.FileAccess.Root ?? "", MASK);
        Texture2D src = null;
        try
        {
            if (!File.Exists(file)) throw new FileNotFoundException("no such file");
            src = new Texture2D(2, 2, TextureFormat.RGB24, false);
            if (!src.LoadImage(File.ReadAllBytes(file), false)) throw new InvalidDataException("not an image");
            maskW = src.width;
            maskH = src.height;
            Color32[] read = src.GetPixels32();
            mask = new byte[maskW * maskH];
            for (int y = 0; y < maskH; y++)
                for (int x = 0; x < maskW; x++) mask[y * maskW + x] = read[(maskH - 1 - y) * maskW + x].r;
        }
        catch (Exception e)
        {
            mask = null;
            if (!warned) Debug.LogWarning($"globe: mask {file} not shown ({e.Message})");
            warned = true;
        }
        if (src != null) Destroy(src);
    }

    // globe_view.gd _ready: each continent's anchor (globe_anchors.gd) as a unit point.
    void Anchors()
    {
        double[][] uvs = mask != null ? GlobeMath.AnchorUvs(mask, maskW, maskH, ids.Count) : new double[ids.Count + 1][];
        anchors = new double[uvs.Length][];
        for (int v = 1; v < uvs.Length; v++)
        {
            if (uvs[v] == null) continue;
            GlobeMath.PointOf(uvs[v][0], uvs[v][1], out double x, out double y, out double z);
            anchors[v] = new[] { x, y, z };
        }
    }

    // The orbit's view is the canvas rect the globe fills (the camera sees the whole screen at the same aspect).
    void Fit()
    {
        Rect r = area.rect;
        orbit.Width = Math.Max(1.0, r.width);
        orbit.Height = Math.Max(1.0, r.height);
    }

    void OnEnable() => stage?.Show(true);

    void OnDisable() => stage?.Show(false);

    void OnDestroy() => stage?.Close();

    // Each continent's look from its Campaign.State by id (globe_view.gd set_states).
    public void SetStates(S.GDict now)
    {
        states = now;
        long[] perValue = GlobeMissions.StatesByValue(now);
        for (int n = 0; n < markers.Count; n++) markers[n].SetLocked(perValue[n + 1] == S.Campaign.State.LOCKED);
        stage?.SetStates(perValue);
        if (Hovered != "" && GlobeMissions.Locked(states, Hovered)) SetHovered("");
    }

    // The point in the orbit's px (top-left origin, y down) under a screen point.
    Vector2 ViewPoint(Vector2 screenPoint, Camera eventCamera)
    {
        RectTransformUtility.ScreenPointToLocalPointInRectangle(area, screenPoint, eventCamera, out Vector2 local);
        Rect r = area.rect;
        return new Vector2(local.x - r.xMin, r.yMax - local.y);
    }

    // globe_view.gd _open_at: the continent under a view point, or "" over sea, off the globe or on a locked one.
    public string OpenAt(Vector2 view)
    {
        if (mask == null) return "";
        int value = orbit.ValueAt(mask, maskW, maskH, view.x, view.y);
        string id = value >= 1 && value <= ids.Count ? ids[value - 1] : "";
        return GlobeMissions.Locked(states, id) ? "" : id;
    }

    // The view point of a continent's marker (its anchor projected now): what a test or the smoke would click.
    public Vector2 MarkerPoint(string id)
    {
        double[] a = Anchor(id);
        if (a == null || !orbit.Marker(a[0], a[1], a[2], out double sx, out double sy, out _)) return -Vector2.one;
        return new Vector2((float)sx, (float)sy);
    }

    double[] Anchor(string id)
    {
        int value = ids.IndexOf(id) + 1;
        return value > 0 && value < anchors.Length ? anchors[value] : null;
    }

    void SetHovered(string id)
    {
        if (id == Hovered) return;
        Hovered = id;
        stage?.SetHover(ids.IndexOf(id) + 1);
    }

    // globe_view.gd _click: an open continent is picked and flown to; the sea, a locked one or off the globe flies out.
    public void Click(string id)
    {
        if (id != "")
        {
            double[] a = Anchor(id) ?? new double[3];  // Godot's anchor_of is ZERO for a continent with none
            orbit.FlyTo(id, a[0], a[1], a[2]);
            Picked?.Invoke(id);
        }
        else if (orbit.Selected != "") Deselect();
    }

    // globe_view.gd fly_out (ui_cancel, or a click on nothing).
    public void Deselect()
    {
        if (orbit.Selected == "") return;
        orbit.FlyOut();
        Picked?.Invoke("");
    }

    public void OnPointerDown(PointerEventData e)
    {
        if (!Interactive || e.button != PointerEventData.InputButton.Left) return;
        last = ViewPoint(e.position, e.pressEventCamera);
        orbit.Press();
    }

    public void OnPointerUp(PointerEventData e)
    {
        if (e.button != PointerEventData.InputButton.Left) return;
        bool click = orbit.Release();
        if (click && Interactive) Click(OpenAt(ViewPoint(e.position, e.pressEventCamera)));
    }

    // globe_view.gd _unhandled_input's motion: a drag turns the globe, then the light follows the pointer.
    public void OnPointerMove(PointerEventData e)
    {
        if (!Interactive) return;
        Vector2 now = ViewPoint(e.position, e.enterEventCamera);
        orbit.Move(now.x - last.x, now.y - last.y);
        last = now;
        SetHovered(OpenAt(now));
    }

    public void OnPointerExit(PointerEventData e) => SetHovered("");

    void Update()
    {
        Fit();
        orbit.Step(Time.deltaTime);
        stage?.Pose(orbit, Time.time);
        if (!Interactive || UiFocus.Paused || Inputs.Capturing) return;
        int step = 0;
        if (Input.GetKeyDown(KeyCode.RightArrow) || Inputs.PadDown(XInput.DPAD_RIGHT) || Inputs.Down("move_right")) step = 1;
        else if (Input.GetKeyDown(KeyCode.LeftArrow) || Inputs.PadDown(XInput.DPAD_LEFT) || Inputs.Down("move_left")) step = -1;
        if (step == 0) return;
        string next = GlobeMissions.Step(states, Selected, step);
        if (next == "") return;
        SetHovered(next);
        Click(next);
    }

    // globe_view.gd _place_markers: each marker at its anchor on the screen, faded toward the globe's edge, hidden on
    // the far side and under the open mission panel (a name there would show clipped).
    void LateUpdate()
    {
        Rect card = PanelRect(out bool open);
        for (int n = 0; n < markers.Count; n++)
        {
            GlobeMarker m = markers[n];
            double[] a = anchors.Length > n + 1 ? anchors[n + 1] : null;
            bool show = a != null && orbit.Marker(a[0], a[1], a[2], out double sx, out double sy, out double alpha)
                && Place(m, n, sx, sy, alpha, open, card);
            if (m.gameObject.activeSelf != show) m.gameObject.SetActive(show);
        }
    }

    bool Place(GlobeMarker m, int n, double sx, double sy, double alpha, bool open, Rect card)
    {
        m.rectTransform.anchoredPosition = new Vector2((float)sx, -(float)sy);
        fades[n].alpha = (float)alpha;
        if (!open) return true;
        Rect f = m.Footprint();  // y down from the diamond's centre
        Rect foot = new Rect((float)sx + f.xMin, (float)sy + f.yMin, f.width, f.height);
        return !card.Overlaps(foot);
    }

    // The open panel's rect in the orbit's px (top-left origin, y down).
    Rect PanelRect(out bool open)
    {
        open = Panel != null && Panel.gameObject.activeInHierarchy;
        if (!open) return default;
        Panel.GetWorldCorners(corners);
        Rect r = area.rect;
        Vector2 a = area.InverseTransformPoint(corners[0]), b = area.InverseTransformPoint(corners[2]);
        float x0 = Mathf.Min(a.x, b.x) - r.xMin, x1 = Mathf.Max(a.x, b.x) - r.xMin;
        float y0 = r.yMax - Mathf.Max(a.y, b.y), y1 = r.yMax - Mathf.Min(a.y, b.y);
        return Rect.MinMaxRect(x0, y0, x1, y1);
    }
}
