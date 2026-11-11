// Photo mode (scenes/photo_mode.gd; director 2026-10-26, D-259 "Photo mode: Yes, simple"), opened from the pause
// menu. The run stays paused (RampageGame.Paused), so the sim never steps and the world holds still; the pause
// menu hides, the HUD stays hidden (it is while paused) and RampageGame stops placing its camera and ticking the
// HUD (so the breath's aim and the VIP headline go) while Photo is set. A free camera flies round the kaiju:
// never further from his feet than tuning photo_mode's radius (a multiple of the gameplay camera's distance, so
// it grows with him) and never below its min_height over the street. It flies on the player's own move keys
// (D-259 rebinds), rises and sinks on E / Q (RB / LB), turns with a mouse drag or the right stick. A small card
// names the controls; H / X hides it for a clean picture. Esc / B (or Pause) puts the gameplay camera back
// exactly where it was and returns to the pause menu. The rules are plain C# (GameLogic/PhotoRules.cs).
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using Kaiju.Game;
using S = Kaiju.Sim;

public sealed class PhotoMode : MonoBehaviour
{
    // Godot's card layout (px at 1080p): the column gap, the grid's column and row gaps.
    const float CARD_GAP = 8f, GRID_H_GAP = 28f, GRID_V_GAP = 4f;

    // The photo mode on show (null when none): one at a time.
    public static PhotoMode Current { get; private set; }

    // The allowed space, speeds and turn rates for this opening.
    public PhotoRules Rules => rules;
    // The controls card (H / X hides it).
    public GameObject Hint => hint;
    // The kaiju's feet in Unity's axes: the centre of the allowed sphere.
    public Vector3 Centre => new Vector3((float)rules.cx, (float)rules.cy, (float)rules.cz);
    public Camera View => cam;
    // Where the gameplay camera stood when photo mode opened (it goes back there on close).
    public Vector3 SavedEye => savedPos;

    RampageGame game;
    Camera cam;
    Action closed;
    PhotoRules rules;
    GameObject hint;
    Vector3 savedPos;
    Quaternion savedRot;
    // Unity's yaw (degrees, clockwise seen from above) and pitch (degrees, up positive).
    float yaw, pitch;
    int openedFrame;
    bool done;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Boot()
    {
        Current = null;
    }

    // pause_menu.gd _open_photo + rampage.gd photo_mode(): flies `game`'s camera free; `onClosed` runs once Esc / B
    // put it back. Null when one is already up or the run has no camera.
    public static PhotoMode Open(RampageGame game, Action onClosed)
    {
        if (Current != null || game == null || game.GameCamera == null || game.Sim == null) return null;
        RectTransform screen = UiKit.Screen("PhotoMode");
        PhotoMode mode = screen.gameObject.AddComponent<PhotoMode>();
        mode.Begin(game, onClosed);
        return mode;
    }

    void Begin(RampageGame owner, Action onClosed)
    {
        Current = this;
        game = owner;
        cam = owner.GameCamera;
        closed = onClosed;
        openedFrame = Time.frameCount;
        savedPos = cam.transform.position;
        savedRot = cam.transform.rotation;
        Vector3 feet = owner.KaijuAt;
        double rest = PhotoRules.Rest(S.Content.Section("camera"), owner.Sim.BodyScale());
        rules = new PhotoRules(S.Content.Section("photo_mode"), feet.x, feet.y, feet.z, rest);
        Vector3 ahead = cam.transform.forward;
        yaw = Mathf.Atan2(ahead.x, ahead.z) * Mathf.Rad2Deg;
        pitch = Mathf.Asin(Mathf.Clamp(ahead.y, -1f, 1f)) * Mathf.Rad2Deg;
        owner.Photo = this;
        BuildHint();
        // Esc / B are this screen's while it is up, never the hidden pause card's.
        UiFocus.OnCancel(gameObject, Close);
        Debug.Log($"photo: opened, radius {rules.radius:F1}, floor {rules.floorY:F1}, speed {rules.speed:F1}, centre {Centre}");
    }

    void Update()
    {
        if (done) return;
        if (game == null || cam == null)
        {
            Close();
            return;
        }
        // The press that opened it (a click or A on PHOTO MODE) does nothing here.
        if (Time.frameCount != openedFrame)
        {
            if (Inputs.Cancel() || Inputs.Down("pause"))
            {
                Close();
                return;
            }
            if (Inputs.Down("photo_hint"))
            {
                hint.SetActive(!hint.activeSelf);
                Debug.Log($"photo: controls card {(hint.activeSelf ? "shown" : "hidden")}");
            }
        }
        float dt = Time.unscaledDeltaTime;
        // A drag turns (any mouse button held); the cursor stays the player's.
        bool dragging = Time.frameCount != openedFrame && (Input.GetMouseButton(0) || Input.GetMouseButton(1) || Input.GetMouseButton(2));
        Vector2 mouse = dragging ? Input.mousePositionDelta : Vector2.zero;
        Vector2 look = Inputs.Look();
        float stickTurn = (float)rules.lookDegPerS * dt, mouseTurn = (float)rules.mouseDegPerPx;
        yaw += look.x * stickTurn + mouse.x * mouseTurn;
        pitch = (float)rules.ClampPitch(pitch + look.y * stickTurn + mouse.y * mouseTurn);
        Vector2 move = Inputs.Move();
        Vector3 go = Quaternion.Euler(0f, yaw, 0f) * new Vector3(move.x, 0f, move.y);
        go.y = (Inputs.Held("photo_rise") ? 1f : 0f) - (Inputs.Held("photo_sink") ? 1f : 0f);
        Fly(go * (float)rules.speed * dt);
    }

    // Moves the camera by `by` (Unity axes), kept inside the allowed space, and turns it to this yaw and pitch;
    // returns where it is now. Also the -flow-smoke run's flight.
    public Vector3 Fly(Vector3 by)
    {
        Vector3 p = cam.transform.position + by;
        double x = p.x, y = p.y, z = p.z;
        rules.Clamp(ref x, ref y, ref z);
        Vector3 eye = new Vector3((float)x, (float)y, (float)z);
        cam.transform.SetPositionAndRotation(eye, Quaternion.Euler(-pitch, yaw, 0f));
        return eye;
    }

    // Puts the gameplay camera back and returns to the pause menu (Esc / B / Pause).
    public void Close()
    {
        if (done) return;
        Restore();
        // Off at once, so it owns no cancel in the frame it is destroyed.
        gameObject.SetActive(false);
        Destroy(gameObject);
        Debug.Log("photo: closed, the gameplay camera back where it was");
        Action then = closed;
        closed = null;
        then?.Invoke();
    }

    void Restore()
    {
        if (done) return;
        done = true;
        if (cam != null) cam.transform.SetPositionAndRotation(savedPos, savedRot);
        if (game != null && game.Photo == this) game.Photo = null;
        if (Current == this) Current = null;
    }

    // Leaving with the rampage (quit to title) must not leave the run without its camera (photo_mode.gd _exit_tree).
    void OnDestroy()
    {
        Restore();
    }

    // The controls card, bottom left inside the TV's title-safe margin (keyboard and pad; the move row shows the
    // player's own keys). It never takes the mouse.
    void BuildHint()
    {
        RectTransform safe = UiKit.SafeArea(transform);
        RectTransform card = UiKit.Panel(safe, null, CARD_GAP);
        card.name = "PhotoHint";
        card.GetComponent<Graphic>().raycastTarget = false;
        card.anchorMin = card.anchorMax = card.pivot = Vector2.zero;
        card.anchoredPosition = Vector2.zero;
        UiKit.Header(card, "PHOTO MODE", UiKit.SIZE_HEAD);
        // Godot's three-column grid as three columns side by side.
        RectTransform grid = UiKit.Row(card, GRID_H_GAP, "Grid");
        grid.GetComponent<HorizontalLayoutGroup>().childAlignment = TextAnchor.UpperLeft;
        RectTransform names = UiKit.Column(grid, GRID_V_GAP, "Names");
        RectTransform keys = UiKit.Column(grid, GRID_V_GAP, "Keyboard");
        RectTransform pad = UiKit.Column(grid, GRID_V_GAP, "Pad");
        List<string[]> rows = PhotoRules.HintRows();
        // UiKit.Label puts each text in the player's language (photo_mode.gd _shown).
        foreach (string[] row in rows)
        {
            UiKit.Label(names, row[0], UiKit.SIZE_BODY, UiKit.TEXT);
            UiKit.Label(keys, row[1], UiKit.SIZE_BODY, UiKit.MUTED);
            UiKit.Label(pad, row[2], UiKit.SIZE_BODY, UiKit.MUTED);
        }
        hint = card.gameObject;
    }
}
