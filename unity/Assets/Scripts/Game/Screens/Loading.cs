// What the player sees while a rampage builds its city (scenes/loading_overlay.gd): the broadcast backdrop, one
// still of a real dusk rampage (random, never the same twice running), the INCOMING header on a dark band low
// on the screen, and a headline from tuning "ui" loading_news.
// The Unity rampage builds on the main thread right after a scene reload, so nothing can move while it does:
// the screen is on a canvas of its own that outlives the reload, is drawn before the reload is asked for
// (ShowThen), and goes once the rampage has drawn (HideWhenDrawn). For the same reason there is no meter (it
// could not move) and the headline is held still, the next one each load, instead of crawling.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using Opt = Kaiju.Game.PlayerSettings;
using S = Kaiju.Sim;

public static class Loading
{
    // Above the kit's canvas (UiKit sorts at 100) by Godot's LoadingOverlay.LAYER (60).
    const int SORT_ORDER = 160;
    // loading_overlay.gd: the band's colour, its padding above and below, its lift over the crawl, and the gap
    // between the lines in it (px at 1080p).
    static readonly Color BAND = new Color(0.043f, 0.043f, 0.051f, 0.72f);
    const float BAND_PAD = 28f;
    const float BAND_LIFT = 40f;
    const float GAP = 24f;
    // Frames the screen is on show before the load is asked for, and frames of the rampage drawn under it
    // before it goes (the rampage's first frames are its slowest).
    public const int GO_FRAMES = 2;
    public const int HIDE_FRAMES = 2;

    // The continent's name under the header. Godot's screen has no such line; false leaves it out.
    public static bool PlaceLine = true;

    static LoadingHost host;
    static RectTransform root;
    static Texture2D still;
    static readonly System.Random rng = new System.Random();
    // The still shown last, so the next load picks another; and the loads shown so far.
    static int last = -1;
    static int shows;
    static float shownAt;
    static readonly HashSet<string> warned = new HashSet<string>();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        host = null;
        root = null;
        still = null;
        last = -1;
        shows = 0;
    }

    // True from Show until Hide.
    public static bool Shown => host != null;

    // Shows the loading screen for `request` (null: no place line) and returns it. Shown twice it is the same one.
    public static RectTransform Show(RunRequest request)
    {
        if (host != null) return root;
        GameObject go = new GameObject("Loading");
        UnityEngine.Object.DontDestroyOnLoad(go);
        Canvas canvas = go.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = SORT_ORDER;
        CanvasScaler scaler = go.AddComponent<CanvasScaler>();
        scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.Expand;
        scaler.referenceResolution = new Vector2(UiKit.CANVAS_WIDTH, UiKit.CANVAS_HEIGHT) / Mathf.Max((float)Opt.UiScale, 0.01f);
        // The backdrop takes the mouse, so nothing under the screen is clicked while it is up.
        go.AddComponent<GraphicRaycaster>();
        host = go.AddComponent<LoadingHost>();
        root = UiKit.Box(go.transform, "Screen");
        UiKit.FullRect(root);

        UiKit.Backdrop(root);
        int pick = LoadingCard.Pick(rng.Next(LoadingCard.STILLS.Length), last, LoadingCard.STILLS.Length);
        last = pick;
        bool drawn = Still(root, LoadingCard.STILLS[pick]);

        RectTransform band = Band(root);
        UiKit.Header(band, "INCOMING");
        string place = PlaceLine ? LoadingCard.Place(request) : "";
        if (place != "") UiKit.Label(band, place).alignment = TextAnchor.MiddleCenter;

        List<string> news = LoadingCard.News(UiKit.Ui());
        int tip = LoadingCard.Tip(shows, news.Count);
        shows++;
        // Held still: a crawl would stop dead when the load starts and look like a hung game.
        if (tip >= 0) NewsTicker.Create(root, new[] { Tr.T(news[tip]) }, false);

        shownAt = Time.realtimeSinceStartup;
        Debug.Log($"flow: loading shown, tip {(tip >= 0 ? tip.ToString(CultureInfo.InvariantCulture) : "none")} of {news.Count}, still {pick} {Path.GetFileName(LoadingCard.STILLS[pick])}{(drawn ? "" : " (missing)")}, place {(place != "" ? place : "none")}");
        return root;
    }

    // Shows the screen, lets it be drawn (GO_FRAMES frames), then calls `go`, which starts the load. A second
    // call while one waits is dropped: the button under the screen was pressed twice.
    public static void ShowThen(RunRequest request, Action go)
    {
        if (host != null && host.go != null)
        {
            Debug.LogWarning("flow: loading already waits to start a rampage, the second ask is dropped");
            return;
        }
        Show(request);
        // No key or pad press reaches the menu under the screen while it waits.
        UiFocus.Paused = true;
        host.go = go;
        host.goAt = Time.frameCount + GO_FRAMES;
    }

    // The load is over: the screen goes once HIDE_FRAMES frames of the rampage are drawn under it.
    public static void HideWhenDrawn()
    {
        if (host == null) return;
        host.hideAt = Time.frameCount + HIDE_FRAMES;
    }

    // The screen goes now.
    public static void Hide()
    {
        if (host == null) return;
        float seconds = Time.realtimeSinceStartup - shownAt;
        UiFocus.Paused = false;
        UnityEngine.Object.Destroy(host.gameObject);
        if (still != null) UnityEngine.Object.Destroy(still);
        host = null;
        root = null;
        still = null;
        Debug.Log("flow: loading hidden after " + seconds.ToString("F1", CultureInfo.InvariantCulture) + " s");
    }

    // The still at `path` (under the data root), filling the screen: cropped, never stretched. False when the
    // file is missing or not an image; the backdrop alone shows then.
    static bool Still(Transform parent, string path)
    {
        string file = Path.Combine(S.FileAccess.Root ?? "", path);
        try
        {
            if (!File.Exists(file)) throw new FileNotFoundException("no such file");
            Texture2D tex = new Texture2D(2, 2, TextureFormat.RGB24, false);
            if (!tex.LoadImage(File.ReadAllBytes(file), true))
            {
                UnityEngine.Object.Destroy(tex);
                throw new InvalidDataException("not an image");
            }
            tex.wrapMode = TextureWrapMode.Clamp;
            still = tex;
        }
        catch (Exception e)
        {
            if (warned.Add(path)) Debug.LogWarning($"loading: still {file} not shown ({e.Message})");
            return false;
        }
        RectTransform rt = UiKit.Box(parent, "Still");
        UiKit.FullRect(rt);
        RawImage image = rt.gameObject.AddComponent<RawImage>();
        image.texture = still;
        image.raycastTarget = false;
        // Godot's STRETCH_KEEP_ASPECT_COVERED.
        AspectRatioFitter cover = rt.gameObject.AddComponent<AspectRatioFitter>();
        cover.aspectMode = AspectRatioFitter.AspectMode.EnvelopeParent;
        cover.aspectRatio = (float)still.width / Mathf.Max(still.height, 1);
        return true;
    }

    // The dark band low on the screen, just above the headline strip, so the kaiju in the middle of the still
    // stays in view (D-140). It is a column, centred, as tall as what it holds.
    static RectTransform Band(Transform parent)
    {
        RectTransform band = UiKit.Box(parent, "Band");
        band.anchorMin = new Vector2(0f, 0f);
        band.anchorMax = new Vector2(1f, 0f);
        band.pivot = new Vector2(0.5f, 0f);
        band.sizeDelta = Vector2.zero;
        band.anchoredPosition = new Vector2(0f, NewsTicker.HEIGHT + BAND_LIFT);
        Image fill = band.gameObject.AddComponent<Image>();
        fill.color = BAND;
        fill.raycastTarget = false;
        VerticalLayoutGroup g = band.gameObject.AddComponent<VerticalLayoutGroup>();
        g.padding = new RectOffset(0, 0, Mathf.RoundToInt(BAND_PAD), Mathf.RoundToInt(BAND_PAD));
        g.spacing = GAP;
        g.childAlignment = TextAnchor.MiddleCenter;
        g.childControlWidth = g.childControlHeight = true;
        g.childForceExpandWidth = g.childForceExpandHeight = false;
        ContentSizeFitter fit = band.gameObject.AddComponent<ContentSizeFitter>();
        fit.verticalFit = ContentSizeFitter.FitMode.PreferredSize;
        return band;
    }
}
