using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

// scenes/threat_bar.gd: the army's threat level as five segments under the clock, red from level four.
public sealed class HudThreat : MaskableGraphic
{
    long level = 1;
    double progress;
    float barWidth, barHeight, gap, emptyAlpha, partialAlpha;
    long segments, alertFrom;

    public long Level => level;

    public static HudThreat Create(Transform parent)
    {
        S.GDict cfg = UiKit.Ui()["threat_bar"];
        S.GDict hud = UiKit.Ui()["hud"];
        S.GArray<S.Variant> size = hud["meter_size"];
        HudThreat bar = UiKit.Box(parent, "Threat").gameObject.AddComponent<HudThreat>();
        bar.raycastTarget = false;
        bar.barWidth = (float)S.Num.F(size[0]);
        bar.barHeight = (float)S.Num.F(size[1]);
        bar.segments = S.Num.I(cfg["segments"]);
        bar.alertFrom = S.Num.I(cfg["alert_from"]);
        bar.gap = (float)S.Num.F(cfg["gap"]);
        bar.emptyAlpha = (float)S.Num.F(cfg["empty_alpha"]);
        bar.partialAlpha = (float)S.Num.F(cfg["partial_alpha"]);
        UiKit.Size(bar, bar.barWidth, bar.barHeight);
        return bar;
    }

    // The HUD's bar never pops (hud_clock.gd passes rose = false).
    public void ShowLevel(long n, double part)
    {
        if (n == level && part == progress) return;
        level = n;
        progress = part;
        SetVerticesDirty();
    }

    protected override void OnPopulateMesh(VertexHelper vh)
    {
        vh.Clear();
        Rect area = GetPixelAdjustedRect();
        UiPen pen = new UiPen(vh, area);
        // The column may be wider than the bar: the bar stays its own width, centred.
        float left = (area.width - barWidth) * 0.5f;
        float w = (float)HudText.ThreatSegment(barWidth, gap, segments);
        Color on = (HudText.ThreatAlert(level, alertFrom) ? UiKit.ALERT : Color.white) * color;
        Color empty = new Color(1f, 1f, 1f, emptyAlpha) * color;
        long filled = HudText.ThreatFilled(level, segments);
        double partial = HudText.ThreatPartial(level, segments, progress);
        for (int i = 0; i < segments; i++)
        {
            Rect r = new Rect(left + i * (w + gap), 0f, w, barHeight);
            if (i < filled) { pen.Box(r, on); continue; }
            pen.Frame(r, empty, 1f, false);
            if (i == filled && partial > 0.0)
                pen.Box(new Rect(r.x, r.y, w * (float)partial, barHeight), new Color(on.r, on.g, on.b, on.a * partialAlpha));
        }
    }
}
