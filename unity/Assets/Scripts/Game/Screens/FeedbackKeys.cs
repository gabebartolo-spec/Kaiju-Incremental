// The feedback panel's state and keys (feedback_panel.gd): the picture taken before it opens, SEND, OPEN FOLDER,
// close, and the box's keys. While the box has the caret the menu focus is held off (UiFocus.Paused), so typed keys
// (Enter, Space, the move keys) stay in the box; Esc or pad B still closes, and a pad's down or A hands focus to SEND
// (feedback_panel.gd _pad_leaves_box; never a keyboard's, where Enter is a new line).
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public sealed class FeedbackKeys : MonoBehaviour
{
    // A stick counts as a push down past this (UiFocus's own push).
    const float PUSH = 0.5f;

    // Opens a folder on the player's desktop (a local file: URI, no network); a test swaps it for a recorder.
    public static Action<string> Opener = path => Application.OpenURL(new Uri(path).AbsoluteUri);

    public S.RampageSim sim;
    public string speciesId = "";
    public Action onClosed;
    public GameObject[] hideForShot;
    public InputField box;
    public HazardBox frame;
    public KitButton send, cancel, open, done;
    public GameObject prompt, writeRow, doneRow;
    public Text status;
    // The picture (PNG bytes, null when none could be taken), the facts, and what SEND wrote.
    public byte[] shot;
    public List<KeyValuePair<string, string>> details;
    public FeedbackResult result;
    public string reportPath = "";

    int leftBoxFrame = -1;
    bool stickDown, closed;

    // pause_menu.gd _open_report: the dim off for one drawn frame, the picture, the dim back, then the panel.
    public IEnumerator Open()
    {
        foreach (GameObject g in hideForShot) if (g != null) g.SetActive(false);
        yield return new WaitForEndOfFrame();
        Texture2D grab = null;
        try
        {
            grab = ScreenCapture.CaptureScreenshotAsTexture();
            shot = grab != null ? grab.EncodeToPNG() : null;
        }
        catch (Exception e)
        {
            Debug.LogWarning("flow: feedback picture failed: " + e.Message);
            shot = null;
        }
        int shotW = grab != null ? grab.width : 0, shotH = grab != null ? grab.height : 0;
        if (grab != null) Destroy(grab);
        foreach (GameObject g in hideForShot) if (g != null) g.SetActive(true);
        if (closed) yield break;
        Vector2 canvas = ((RectTransform)UiKit.Root.transform).rect.size;
        details = sim != null
            ? FeedbackReport.Facts(sim, speciesId, SystemInfo.operatingSystem, SystemInfo.graphicsDeviceName,
                Screen.width, Screen.height, (int)canvas.x, (int)canvas.y)
            : new List<KeyValuePair<string, string>>();
        FeedbackPanel.Build(this);
        Debug.Log($"flow: feedback panel shown, picture {shotW}x{shotH}, {details.Count} facts, focus in the box");
    }

    void Update()
    {
        if (box == null || closed) return;
        GameObject at = EventSystem.current != null ? EventSystem.current.currentSelectedGameObject : null;
        bool inBox = box.gameObject.activeInHierarchy && at == box.gameObject;
        // Held one more frame after a pad leaves the box, so the A that left is not also SEND's press.
        UiFocus.Paused = inBox || Time.frameCount == leftBoxFrame;
        Color edge = inBox ? UiKit.ACCENT : UiKit.PANEL_EDGE;
        if (frame != null && frame.edge != edge)
        {
            frame.edge = edge;
            frame.Redraw();
        }
        bool stick = !Input.anyKey && Inputs.Move().y < -PUSH;
        bool stickPushed = stick && !stickDown;
        stickDown = stick;
        if (!inBox) return;
        if (Inputs.Cancel())
        {
            Close();
            return;
        }
        if (Inputs.PadDown(XInput.DPAD_DOWN) || Inputs.PadDown(XInput.A) || stickPushed)
        {
            leftBoxFrame = Time.frameCount;
            box.DeactivateInputField();
            UiFocus.Grab(send);
        }
    }

    // SEND: writes the report folder and says where it went (or why not); OPEN FOLDER (or DONE) takes the focus.
    public void Send()
    {
        if (closed || result != null) return;
        S.GDict cfg = FeedbackReport.Cfg();
        result = FeedbackReport.Write(box.text, details ?? new List<KeyValuePair<string, string>>(), shot, FeedbackReport.StampNow());
        reportPath = result.path;
        status.text = result.ok
            ? Tr.T(S.Gd.Str(cfg["saved"])).Replace("{path}", reportPath)
            : Tr.T(S.Gd.Str(cfg["failed"])).Replace("{error}", result.error);
        status.color = result.ok ? UiKit.GOOD : UiKit.BAD;
        status.gameObject.SetActive(true);
        box.gameObject.SetActive(false);
        prompt.SetActive(false);
        writeRow.SetActive(false);
        doneRow.SetActive(true);
        open.gameObject.SetActive(result.ok);
        UiFocus.Paused = false;
        UiKit.Focus(result.ok ? (Selectable)open : done);
        string problems = result.ok ? string.Join("; ", FeedbackReport.Problems(reportPath, box.text.Trim())) : result.error;
        Debug.Log($"flow: feedback sent, ok {result.ok}, path {reportPath}, {box.text.Trim().Length} chars, picture {(shot != null ? "taken" : "placeholder")}, problems [{problems}]");
    }

    public void OpenFolder()
    {
        if (string.IsNullOrEmpty(reportPath)) return;
        Debug.Log("flow: feedback opens folder " + reportPath);
        Opener(reportPath);
    }

    // CANCEL, DONE, Esc or pad B: the panel goes, writing nothing more; the caller brings its menu back.
    public void Close()
    {
        if (closed) return;
        closed = true;
        UiFocus.Paused = false;
        // Off at once, so it no longer owns cancel in the frame it is destroyed.
        gameObject.SetActive(false);
        Destroy(gameObject);
        Debug.Log($"flow: feedback panel closed, {(result != null && result.ok ? "report written" : "nothing written")}");
        onClosed?.Invoke();
    }

    void OnDestroy()
    {
        // A panel destroyed with its pause screen (the run ended under it) must not leave the menus deaf.
        if (!closed) UiFocus.Paused = false;
    }
}
