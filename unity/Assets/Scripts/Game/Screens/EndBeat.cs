// The end beat (scenes/hud_end_beat.gd, rampage_hud.gd): the reason the rampage ended slams onto the screen
// while the city keeps falling at normal speed, between the sim's run_over and the results. The words and the
// timing are plain C# (GameLogic/ResultsRows.cs ResultsBeat); EndBeatRun runs the flash, the slam and the wait.
using System;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public static class EndBeat
{
    // Godot's numbers: the headline's size and how far under the screen's top it sits (px at 1080p), the
    // flash's colour and strength, how big the headline starts, and the two tweens' lengths (seconds).
    public const int BEAT_SIZE = 128;
    public const float BEAT_TOP = 64f;
    public static readonly Color FLASH = new Color(1f, 0.55f, 0.25f, 0.45f);
    public const float SLAM_SCALE = 2.4f;
    public const float SLAM_SECONDS = 0.35f;
    public const float FLASH_SECONDS = 0.6f;

    // Shows why the rampage ended (the sim's end reason), then closes itself and hands `result` to onDone:
    // after 2.5 s, or on confirm once 0.667 s have shown (so a held attack cannot skip it by accident).
    public static RectTransform Show(string reason, S.GDict result, Action<S.GDict> onDone)
    {
        string[] lines = ResultsBeat.Lines(reason);
        RectTransform screen = UiKit.Screen("EndBeat");
        // Reduce flashing scales the flash down to nothing.
        Color tint = FLASH;
        tint.a *= SettingsApply.FlashScale;
        Image flash = UiKit.Fill(screen, tint, "Flash");
        RectTransform col = UiKit.Column(screen, 0f, "Top");
        col.anchorMin = col.anchorMax = new Vector2(0.5f, 1f);
        col.pivot = new Vector2(0.5f, 1f);
        col.anchoredPosition = new Vector2(0f, -BEAT_TOP);
        UiKit.Fit(col);
        Text headline = UiKit.Label(col, lines[0], BEAT_SIZE, UiKit.ACCENT);
        headline.alignment = TextAnchor.MiddleCenter;
        Text sub = UiKit.Label(col, lines[1], UiKit.SIZE_HEAD, UiKit.TEXT);
        sub.alignment = TextAnchor.MiddleCenter;
        EndBeatRun run = screen.gameObject.AddComponent<EndBeatRun>();
        run.flash = flash;
        run.flashAlpha = tint.a;
        run.headline = headline.rectTransform;
        run.result = result;
        run.onDone = onDone;
        run.Apply();
        Debug.Log("flow: end beat shown, reason " + reason + ", headline '" + lines[0] + "', line '" + lines[1] + "', "
            + ResultsBeat.Seconds.ToString("0.00") + " s, skippable after " + ResultsBeat.MinSeconds.ToString("0.00")
            + " s, flash " + tint.a.ToString("0.00"));
        return screen;
    }

    // Ends a running beat now (a capture's or the smoke's skip): closes it and calls onDone.
    public static void Finish(RectTransform screen)
    {
        EndBeatRun run = screen != null ? screen.GetComponent<EndBeatRun>() : null;
        if (run != null) run.Finish(true);
    }
}
