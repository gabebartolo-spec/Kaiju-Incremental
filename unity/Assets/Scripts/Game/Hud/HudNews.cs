using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/rampage_news.gd: the in-run news strip along the bottom of the screen. A big moment's headline slides
// up, crawls across once and slides away; the sim's events feed it, one crawl at a time.
public sealed class HudNews : MonoBehaviour
{
    HudNewsQueue queue;
    S.GDict live;
    NewsTicker ticker, leaving;
    float slideS, readS, minS, slideT;

    public HudNewsQueue Queue => queue;

    public static HudNews Create(Transform parent)
    {
        RectTransform rt = UiKit.Box(parent, "News");
        rt.anchorMin = new Vector2(0f, 0f);
        rt.anchorMax = new Vector2(1f, 0f);
        rt.pivot = new Vector2(0.5f, 0f);
        rt.sizeDelta = new Vector2(0f, NewsTicker.HEIGHT);
        rt.anchoredPosition = Vector2.zero;
        rt.gameObject.AddComponent<RectMask2D>();
        HudNews news = rt.gameObject.AddComponent<HudNews>();
        S.GDict cfg = UiKit.Ui()["news_live"];
        news.slideS = (float)S.Num.F(cfg["slide_s"]);
        news.readS = (float)S.Num.F(cfg["read_s"]);
        news.minS = (float)S.Num.F(cfg["min_s"]);
        news.queue = new HudNewsQueue((int)S.Num.I(cfg["queue"]), news.slideS);
        S.GDict all = S.Content.Section("news");
        news.live = all["live"];
        rt.gameObject.SetActive(false);
        return news;
    }

    // One sim event: its headline, if it has one, joins the queue.
    public void OnEvent(S.GDict e)
    {
        queue.Add(HudText.NewsLine(e, live));
    }

    public void Mute()
    {
        queue.Muted = true;
        gameObject.SetActive(false);
    }

    // Called by the HUD each frame (the strip is switched off while hidden, so it cannot tick itself).
    public void Tick(float dt)
    {
        switch (queue.Tick(dt))
        {
            case HudNewsQueue.Step.SlideIn:
                gameObject.SetActive(true);
                ticker = NewsTicker.Create(transform, new List<string> { queue.Current });
                ticker.once = true;
                ticker.Fit();
                queue.Stay(HudText.NewsSeconds(ticker.HeadlinesWidth(), NewsTicker.SPEED, readS, minS));
                slideT = 0f;
                Place(ticker, 1f);
                break;
            case HudNewsQueue.Step.SlideOut:
                leaving = ticker;
                ticker = null;
                break;
            case HudNewsQueue.Step.Gone:
                if (leaving != null) Destroy(leaving.gameObject);
                leaving = null;
                break;
        }
        if (ticker != null && slideT < slideS)
        {
            slideT += dt;
            Place(ticker, 1f - Mathf.Clamp01(slideT / Mathf.Max(slideS, 0.0001f)));
        }
        if (leaving != null) Place(leaving, (float)queue.Leaving);
        if (gameObject.activeSelf != queue.Visible) gameObject.SetActive(queue.Visible);
    }

    // `down`: 0 on show, 1 a whole strip below the screen's edge.
    static void Place(NewsTicker t, float down)
    {
        ((RectTransform)t.transform).anchoredPosition = new Vector2(0f, -NewsTicker.HEIGHT * down);
    }
}
