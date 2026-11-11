// The world view, first version (D-474, D-476): Godot draws a 3D hologram globe (scenes/globe_view.gd); this is the
// same Tellus Nova mask laid flat, 2:1, coloured per continent as scenes/globe_land.gdshader colours it (locked:
// grey coastline only; available: yellow fill; conquered: green fill; the pointed-at one brighter), with the same
// hit test (GlobeMath.IdAtUv), markers at the same anchors and the same pick rules: a locked continent neither
// lights nor opens; a click on the sea or off the map lets go of the selection.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using S = Kaiju.Sim;

public sealed class GlobeMap : MonoBehaviour, IPointerMoveHandler, IPointerExitHandler, IPointerClickHandler
{
    public const string MASK = "assets/overworld/tellus_nova_mask.png";
    // globe_land.gdshader: how bright each kind of land is, and the coastline's width in mask texels.
    const float FILL = 0.22f;
    const float AVAILABLE_FILL = 0.45f;
    const float HOVER_FILL = 0.6f;
    const float COAST = 1f;
    const int COAST_TEXELS = 2;
    // The drawn texture holds every this-many-th mask texel: recolouring it on a hover stays cheap.
    const int TEXTURE_STEP = 2;

    static bool warned;

    // The continent picked ("" none) and the one under the pointer ("" none, the sea or a locked one).
    public string Selected { get; private set; } = "";
    public string Hovered { get; private set; } = "";
    // A continent was picked (its id) or let go ("").
    public Action<string> Picked;
    // The open mission panel: a marker under it is hidden (globe_view.gd _place_markers).
    public RectTransform Panel;
    // False when the mask file is missing: a flat panel shows and the keys still pick.
    public bool Found => mask != null;
    public int MaskWidth => maskW;
    public int MaskHeight => maskH;
    public int Markers => markers.Count;

    RectTransform land;
    RawImage image;
    Texture2D texture;
    byte[] mask, cells, coast;
    Color32[] pixels;
    int maskW, maskH, texW, texH;
    readonly List<string> ids = new List<string>();
    readonly List<GlobeMarker> markers = new List<GlobeMarker>();
    S.GDict states = new S.GDict();
    long[] perValue = new long[1];
    static readonly Vector3[] corners = new Vector3[4];

    // A map filling `parent` (it takes the pointer everywhere, so a click off the land lets go), the land
    // itself `width` px wide and half as high, centred.
    public static GlobeMap Make(Transform parent, float width)
    {
        RectTransform rt = UiKit.Box(parent, "Map");
        UiKit.FullRect(rt);
        Image catcher = rt.gameObject.AddComponent<Image>();
        catcher.color = Color.clear;
        catcher.raycastTarget = true;
        GlobeMap map = rt.gameObject.AddComponent<GlobeMap>();
        map.land = UiKit.Box(rt, "Land");
        map.land.anchorMin = map.land.anchorMax = map.land.pivot = new Vector2(0.5f, 0.5f);
        map.land.sizeDelta = new Vector2(width, width / 2f);
        map.Load();
        foreach (S.GDict def in S.Content.Continents()) map.ids.Add(S.Gd.Str(def["id"]));
        double[][] anchors = map.mask != null ? GlobeMath.AnchorUvs(map.mask, map.maskW, map.maskH, map.ids.Count) : new double[map.ids.Count + 1][];
        for (int n = 0; n < map.ids.Count; n++)
        {
            S.GDict def = S.Content.Continents()[n];
            GlobeMarker marker = GlobeMarker.Make(map.land, S.Gd.Str(def.Get("name", def["id"])));
            RectTransform m = marker.rectTransform;
            m.anchorMin = m.anchorMax = new Vector2(0f, 1f);
            // No anchor (no mask, or no inland sample): the markers stand in a row so each can still be read.
            double[] uv = anchors[n + 1] ?? new[] { (n + 0.5) / map.ids.Count, 0.5 };
            m.anchoredPosition = new Vector2((float)uv[0] * width, -(float)uv[1] * width / 2f);
            map.markers.Add(marker);
        }
        return map;
    }

    // The mask's bytes, row 0 at the top; a missing or unreadable file says so once and leaves a flat panel.
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
            {
                int from = (maskH - 1 - y) * maskW, to = y * maskW;
                for (int x = 0; x < maskW; x++) mask[to + x] = read[from + x].r;
            }
        }
        catch (Exception e)
        {
            mask = null;
            if (!warned) Debug.LogWarning($"globe: mask {file} not shown ({e.Message})");
            warned = true;
        }
        if (src != null) Destroy(src);
        if (mask == null)
        {
            UiKit.Fill(land, UiKit.PANEL, "NoMask");
            return;
        }
        texW = maskW / TEXTURE_STEP;
        texH = maskH / TEXTURE_STEP;
        cells = new byte[texW * texH];
        coast = new byte[texW * texH];
        for (int y = 0; y < texH; y++)
        {
            for (int x = 0; x < texW; x++)
            {
                int mx = x * TEXTURE_STEP, my = y * TEXTURE_STEP;
                byte id = mask[my * maskW + mx];
                cells[y * texW + x] = id;
                coast[y * texW + x] = (byte)(id != 0 && GlobeMath.Coast(mask, maskW, maskH, mx, my, COAST_TEXELS) ? 1 : 0);
            }
        }
        pixels = new Color32[texW * texH];
        texture = new Texture2D(texW, texH, TextureFormat.RGBA32, false);
        texture.filterMode = FilterMode.Point;  // the shader reads the mask filter_nearest
        texture.wrapMode = TextureWrapMode.Clamp;
        RectTransform rt = UiKit.Box(land, "Texture");
        UiKit.FullRect(rt);
        image = rt.gameObject.AddComponent<RawImage>();
        image.texture = texture;
        image.raycastTarget = false;
    }

    void OnDestroy()
    {
        if (texture != null) Destroy(texture);
    }

    // Each continent's look from its Campaign.State by id (globe_view.gd set_states).
    public void SetStates(S.GDict now)
    {
        states = now;
        perValue = GlobeMissions.StatesByValue(now);
        for (int n = 0; n < markers.Count; n++) markers[n].SetLocked(perValue[n + 1] == S.Campaign.State.LOCKED);
        if (Hovered != "" && GlobeMissions.Locked(states, Hovered)) Hovered = "";
        Paint();
    }

    // The texture in the land shader's colours. The shader's scan lines and the available fill's slow pulse
    // are left out of this first version.
    void Paint()
    {
        if (texture == null) return;
        int hover = ids.IndexOf(Hovered) + 1;
        Color32[] body = new Color32[perValue.Length], edge = new Color32[perValue.Length];
        for (int v = 1; v < perValue.Length; v++)
        {
            long state = perValue[v];
            Color tint = state == S.Campaign.State.LOCKED ? UiKit.LOCKED : (state == S.Campaign.State.CONQUERED ? UiKit.GOOD : UiKit.ACCENT);
            float fill = v == hover ? HOVER_FILL : (state == S.Campaign.State.AVAILABLE ? AVAILABLE_FILL : FILL);
            // blend_add over the backdrop: the land only ever brightens it. A locked continent's inside is not drawn.
            body[v] = state == S.Campaign.State.LOCKED ? new Color32(0, 0, 0, 0) : (Color32)Lit(tint, fill);
            edge[v] = Lit(tint, COAST);
        }
        Color32 sea = new Color32(0, 0, 0, 0);
        for (int y = 0; y < texH; y++)
        {
            int from = y * texW, to = (texH - 1 - y) * texW;  // a texture's first row is its bottom one
            for (int x = 0; x < texW; x++)
            {
                int v = cells[from + x];
                pixels[to + x] = v == 0 || v >= perValue.Length ? sea : (coast[from + x] != 0 ? edge[v] : body[v]);
            }
        }
        texture.SetPixels32(pixels);
        texture.Apply(false);
    }

    static Color Lit(Color tint, float by)
    {
        Color bg = UiKit.BG;
        return new Color(Mathf.Min(1f, bg.r + tint.r * by), Mathf.Min(1f, bg.g + tint.g * by), Mathf.Min(1f, bg.b + tint.b * by), 1f);
    }

    // The continent under a screen point, or "" over sea, off the map or on a locked continent
    // (globe_view.gd _open_at).
    public string OpenAt(Vector2 screenPoint, Camera eventCamera)
    {
        if (mask == null) return "";
        if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(land, screenPoint, eventCamera, out Vector2 local)) return "";
        Rect r = land.rect;
        double u = (local.x - r.xMin) / r.width, v = (r.yMax - local.y) / r.height;
        if (u < 0.0 || u >= 1.0 || v < 0.0 || v >= 1.0) return "";
        int value = GlobeMath.IdAtUv(mask, maskW, maskH, u, v);
        string id = value >= 1 && value <= ids.Count ? ids[value - 1] : "";
        return GlobeMissions.Locked(states, id) ? "" : id;
    }

    // The screen point of a continent's marker (its anchor): what a test or the smoke would click.
    public Vector2 MarkerPoint(string id)
    {
        int n = ids.IndexOf(id);
        return n < 0 ? Vector2.zero : (Vector2)markers[n].rectTransform.position;
    }

    void SetHovered(string id)
    {
        if (id == Hovered) return;
        Hovered = id;
        Paint();
    }

    // globe_view.gd _click: an open continent is picked; the sea, a locked one or off the map lets go.
    public void Click(string id)
    {
        if (id != "")
        {
            Selected = id;
            Picked?.Invoke(id);
        }
        else if (Selected != "") Deselect();
    }

    // globe_view.gd fly_out (ui_cancel, or a click on nothing).
    public void Deselect()
    {
        if (Selected == "") return;
        Selected = "";
        Picked?.Invoke("");
    }

    public void OnPointerMove(PointerEventData e)
    {
        SetHovered(OpenAt(e.position, e.enterEventCamera));
    }

    public void OnPointerExit(PointerEventData e)
    {
        SetHovered("");
    }

    public void OnPointerClick(PointerEventData e)
    {
        if (e.button != PointerEventData.InputButton.Left) return;
        Click(OpenAt(e.position, e.pressEventCamera));
    }

    // Keys and pad (Godot's globe is mouse only): left and right step through the open continents in data
    // order, and the light follows the pick as the pointer's would.
    void Update()
    {
        if (UiFocus.Paused || Inputs.Capturing) return;
        int step = 0;
        if (Input.GetKeyDown(KeyCode.RightArrow) || Inputs.PadDown(XInput.DPAD_RIGHT) || Inputs.Down("move_right")) step = 1;
        else if (Input.GetKeyDown(KeyCode.LeftArrow) || Inputs.PadDown(XInput.DPAD_LEFT) || Inputs.Down("move_left")) step = -1;
        if (step == 0) return;
        string next = GlobeMissions.Step(states, Selected, step);
        if (next == "") return;
        SetHovered(next);
        Click(next);
    }

    // A name under the open mission panel would show clipped: hide it instead (globe_view.gd _place_markers).
    void LateUpdate()
    {
        bool open = Panel != null && Panel.gameObject.activeInHierarchy;
        Rect card = default;
        if (open)
        {
            Panel.GetWorldCorners(corners);
            Vector2 a = land.InverseTransformPoint(corners[0]), b = land.InverseTransformPoint(corners[2]);
            card = Rect.MinMaxRect(Mathf.Min(a.x, b.x), Mathf.Min(a.y, b.y), Mathf.Max(a.x, b.x), Mathf.Max(a.y, b.y));
        }
        foreach (GlobeMarker m in markers)
        {
            bool show = true;
            if (open)
            {
                Rect f = m.Footprint();  // y down from the diamond's centre
                Vector2 at = land.InverseTransformPoint(m.rectTransform.position);
                Rect foot = new Rect(at.x + f.xMin, at.y - f.yMax, f.width, f.height);
                show = !card.Overlaps(foot);
            }
            if (m.gameObject.activeSelf != show) m.gameObject.SetActive(show);
        }
    }
}
