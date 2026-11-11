// The emergency-broadcast crawl (scenes/news_ticker.gd): a red strip with a black "BREAKING" tag and the
// city's news about you scrolling past. Presentation only. The widget alone: the in-run queue that feeds it
// (rampage_news.gd) belongs to the HUD.
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;

public sealed class NewsTicker : MonoBehaviour
{
    public const float HEIGHT = 56f;
    // Crawl speed in px per second at 1080p (the UI scales with the window).
    public const float SPEED = 120f;
    // The black tag bleeds off the screen's edge with its label centred in it.
    public const float TAG_WIDTH = 350f;
    public const string SEPARATOR = "   ///   ";
    // The strip shows two cycles of headlines; each cycle is padded to at least the strip's width, so a short
    // list never shows a headline twice at once and the loop has no empty stretch.
    public const int REPEAT = 2;
    // A still bulletin sits this many spaces after the tag and between its lines.
    const string STILL_GAP = "  ";
    const string END = "|";

    // The strip behind the text.
    public Image strip;
    // A one-pass strip (the in-run news): the next cycle waits a whole strip behind the headline, so the line
    // crosses once with nothing following it on screen. Set before the first frame, or call Fit() after.
    public bool once;

    Text crawl, tagLabel;
    RectTransform crawlRect;
    string unit = "", headlines = "";
    // False: one headline held still after the tag, not crawled (a live bulletin).
    bool scroll = true;
    float fittedWidth = -1f;
    float x = TAG_WIDTH;

    // lines: the headlines (already in the player's language), read left to right and repeated. The strip
    // comes back stretched along its parent's bottom edge; a layout parent or the caller may place it anew.
    public static NewsTicker Create(Transform parent, IList<string> lines, bool scrolling = true)
    {
        GameObject go = new GameObject("NewsTicker", typeof(RectTransform));
        RectTransform rt = (RectTransform)go.transform;
        rt.SetParent(parent, false);
        rt.anchorMin = new Vector2(0f, 0f);
        rt.anchorMax = new Vector2(1f, 0f);
        rt.pivot = new Vector2(0.5f, 0f);
        rt.sizeDelta = new Vector2(0f, HEIGHT);
        rt.anchoredPosition = Vector2.zero;
        LayoutElement size = go.AddComponent<LayoutElement>();
        size.minHeight = HEIGHT;
        size.preferredHeight = HEIGHT;
        go.AddComponent<RectMask2D>();
        NewsTicker t = go.AddComponent<NewsTicker>();
        t.Build(lines, scrolling);
        return t;
    }

    void Build(IList<string> lines, bool scrolling)
    {
        scroll = scrolling;
        strip = UiKit.Fill(transform, UiKit.CRAWL_RED, "Strip");
        crawl = UiKit.Label(transform, "", UiKit.SIZE_BODY, Color.white);
        crawl.name = "Crawl";
        crawl.alignment = TextAnchor.MiddleLeft;
        crawlRect = crawl.rectTransform;
        // The strip's full height with the text centred in it; Widen() sets the width to the text's.
        crawlRect.anchorMin = new Vector2(0f, 0f);
        crawlRect.anchorMax = new Vector2(0f, 1f);
        crawlRect.pivot = new Vector2(0f, 0.5f);
        crawlRect.sizeDelta = new Vector2(TAG_WIDTH, 0f);
        Image tagBox = UiKit.Fill(transform, UiKit.BG, "Tag");
        RectTransform box = tagBox.rectTransform;
        box.anchorMin = new Vector2(0f, 0f);
        box.anchorMax = new Vector2(0f, 1f);
        box.pivot = new Vector2(0f, 0.5f);
        box.sizeDelta = new Vector2(TAG_WIDTH, 0f);
        box.anchoredPosition = Vector2.zero;
        tagLabel = UiKit.Label(box, Tr.T("BREAKING"), UiKit.SIZE_HEAD, UiKit.ACCENT);
        tagLabel.alignment = TextAnchor.MiddleCenter;
        UiKit.FullRect(tagLabel.rectTransform);
        SetLines(lines);
    }

    // New headlines on the same strip; the crawl starts again from the tag.
    public void SetLines(IList<string> lines)
    {
        headlines = scroll ? string.Join(SEPARATOR, lines) + SEPARATOR : STILL_GAP + string.Join(STILL_GAP, lines);
        unit = headlines;
        x = TAG_WIDTH;
        fittedWidth = -1f;
        crawl.text = scroll ? Repeated(unit) : unit;
        Widen();
        Place();
    }

    void Update()
    {
        if (!scroll) return;
        // The strip's width is known only once it is laid out, and changes with the window.
        if (!Mathf.Approximately(fittedWidth, VisibleWidth())) Fit();
        float loop = UnitWidth();
        if (loop <= 0f) return;
        x -= SPEED * Time.deltaTime;
        if (x < TAG_WIDTH - loop) x += loop;
        Place();
    }

    void Place()
    {
        crawlRect.anchoredPosition = new Vector2(x, 0f);
    }

    // Pads one cycle with spaces until it spans the strip, then shows REPEAT cycles.
    public void Fit()
    {
        fittedWidth = VisibleWidth();
        unit = headlines;
        float space = Width(" ");
        float missing = fittedWidth - Width(unit);
        if (once) missing += HeadlinesWidth() + fittedWidth;  // the next cycle stays a whole strip behind
        if (missing > 0f && space > 0f) unit += new string(' ', Mathf.CeilToInt(missing / space));
        crawl.text = Repeated(unit);
        Widen();
    }

    // The mask culls a graphic by its rect, not its glyphs: a rect narrower than the text would hide the whole
    // headline once the rect had left the strip. So the rect is as wide as its text.
    void Widen()
    {
        crawlRect.sizeDelta = new Vector2(Mathf.Max(TAG_WIDTH, Width(crawl.text) + TAG_WIDTH), 0f);
    }

    static string Repeated(string cycle)
    {
        return string.Concat(System.Linq.Enumerable.Repeat(cycle, REPEAT));
    }

    // The width of one cycle of headlines (px): at least the visible strip.
    public float UnitWidth()
    {
        return Width(unit);
    }

    // The width of the headlines once, without the padding (px).
    public float HeadlinesWidth()
    {
        return Width(headlines);
    }

    // The width of strip the text crawls across (px).
    public float VisibleWidth()
    {
        return ((RectTransform)transform).rect.width - TAG_WIDTH;
    }

    // A string's width as the crawl draws it (px at 1080p). The bar keeps the spaces at the end counted.
    float Width(string s)
    {
        if (crawl.font == null || s.Length == 0) return 0f;
        TextGenerator measure = crawl.cachedTextGeneratorForLayout;
        TextGenerationSettings how = crawl.GetGenerationSettings(Vector2.zero);
        return (measure.GetPreferredWidth(s + END, how) - measure.GetPreferredWidth(END, how)) / crawl.pixelsPerUnit;
    }
}
