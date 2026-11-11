// The results screen's count-up (results_screen.gd _process, _show_frame, _stamp): each row counts to its
// value in turn, lands, shows its best or its NEW RECORD stamp; then the verdict shows and SKIP becomes the
// way on. Godot counted frames at 60 a second; this counts the same frames from real time, so it runs at any
// frame rate and while the game's time is stopped.
using System;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;

public sealed class ResultsCount : MonoBehaviour
{
    public ResultsModel model;
    public string goLabel = "";
    public Action onContinue;
    public KitButton go;
    public CanvasGroup verdict;
    // Per row, in the model's order (ResultsScreen fills them).
    public Text[] values = new Text[ResultsRows.ROWS.Length];
    public CanvasGroup[] badges = new CanvasGroup[ResultsRows.ROWS.Length];
    public Text[] badgeTexts = new Text[ResultsRows.ROWS.Length];
    public HazardBox[] frames = new HazardBox[ResultsRows.ROWS.Length];
    public RectTransform[] tilts = new RectTransform[ResultsRows.ROWS.Length];
    // Frames counted so far (60 a second).
    public double frame;

    bool[] stamped = new bool[ResultsRows.ROWS.Length];
    bool said;

    public bool Counting => model != null && model.Counting(frame);

    void Update()
    {
        if (model == null) return;
        if (Counting) frame = Math.Min(frame + Time.unscaledDeltaTime * ResultsRows.FRAME_RATE, model.TotalFrames);
        ShowFrame();
    }

    // Finishes the count at once (confirm pressed early).
    public void Skip()
    {
        if (model == null) return;
        frame = model.TotalFrames;
        ShowFrame();
    }

    // The button: SKIP while the rows count, then the way on.
    public void Press()
    {
        if (Counting)
        {
            Skip();
            Debug.Log("flow: results count skipped");
            return;
        }
        Debug.Log("flow: results continued");
        onContinue?.Invoke();
    }

    public void ShowFrame()
    {
        if (model == null) return;
        for (int n = 0; n < model.rows.Count; n++)
        {
            ResultsRow row = model.rows[n];
            if (values[n] == null) continue;
            string shown = model.ShownAt(n, frame);
            if (values[n].text != shown) values[n].text = shown;
            bool landed = model.Landed(n, frame);
            values[n].color = landed && row.newBest ? UiKit.GOOD : UiKit.TEXT;
            badges[n].alpha = landed ? 1f : 0f;
            if (landed && row.stamp && !stamped[n]) Stamp(n);
        }
        bool counting = Counting;
        if (verdict != null) verdict.alpha = counting ? 0f : 1f;
        if (go != null)
        {
            string label = counting ? Tr.T(ResultsRows.SKIP_LABEL) : goLabel;
            if (go.text != label) go.text = label;
        }
        if (!counting && !said)
        {
            said = true;
            Debug.Log("flow: results count done, stamps " + model.records.Count + " (" + string.Join(",", model.records) + ")");
        }
    }

    // Turns a row's best badge into the NEW RECORD stamp: alert red, boxed, tilted.
    void Stamp(int n)
    {
        stamped[n] = true;
        badgeTexts[n].text = Tr.T(ResultsRows.STAMP_TEXT);
        badgeTexts[n].alignment = TextAnchor.MiddleCenter;
        badgeTexts[n].color = UiKit.ALERT;
        frames[n].enabled = true;
        tilts[n].localEulerAngles = new Vector3(0f, 0f, ResultsScreen.STAMP_TILT);
    }
}
