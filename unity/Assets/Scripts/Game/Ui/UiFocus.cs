// Menu focus, as Godot's GUI gave it: the arrows, the D-pad and the left stick move the focus, confirm presses
// the focused control, cancel backs out, and the focus is never lost to a click on empty space. The pad comes
// through Inputs (XInput), so uGUI's own navigation is switched off (UiKit.Root) and this drives the
// EventSystem instead. One lives on the kit's root canvas. Column and Row wire a screen's neighbours by hand.
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

public sealed class UiFocus : MonoBehaviour
{
    // A stick counts as a push past this; a held direction repeats after the delay, then at the interval
    // (Godot's key echo: half a second, then fast).
    const float PUSH = 0.5f;
    const float REPEAT_DELAY = 0.5f;
    const float REPEAT_EVERY = 0.1f;

    // True while a screen wants the keys for itself (typing in a text field): no moves, confirm or cancel.
    public static bool Paused;
    // Moves, confirms and cancels handled so far, for a proof line.
    public static int Moves, Confirms, Cancels;

    static readonly List<(GameObject owner, Action back)> cancels = new List<(GameObject, Action)>();
    static GameObject last;
    MoveDirection held = MoveDirection.None;
    float nextRepeat;

    // The control in focus, or null.
    public static Selectable Current
    {
        get
        {
            GameObject o = EventSystem.current != null ? EventSystem.current.currentSelectedGameObject : null;
            return o != null ? o.GetComponent<Selectable>() : null;
        }
    }

    // Gives `first` the focus (Godot's grab_focus).
    public static void Grab(Selectable first)
    {
        if (first == null) return;
        UiKit.EnsureRoot();
        last = first.gameObject;
        if (EventSystem.current != null) EventSystem.current.SetSelectedGameObject(first.gameObject);
    }

    // What cancel (Esc, pad B) does while `owner` is alive and shown; the newest live owner wins, so a page
    // opened over a menu takes cancel and hands it back when it is destroyed.
    public static void OnCancel(GameObject owner, Action back)
    {
        cancels.Add((owner, back));
    }

    // Up and down step through `items` in order, top to bottom; their left and right neighbours are kept.
    // No wrap at the ends, as in Godot. Nulls are skipped.
    public static void Column(params Selectable[] items)
    {
        Wire(items, true);
    }

    // Left and right step through `items` in order; their up and down neighbours are kept.
    public static void Row(params Selectable[] items)
    {
        Wire(items, false);
    }

    public static void Column(IList<Selectable> items)
    {
        Wire(items, true);
    }

    public static void Row(IList<Selectable> items)
    {
        Wire(items, false);
    }

    // One neighbour by hand: moving `direction` from `from` lands on `to`.
    public static void Link(Selectable from, MoveDirection direction, Selectable to)
    {
        if (from == null) return;
        Navigation n = Explicit(from);
        if (direction == MoveDirection.Up) n.selectOnUp = to;
        else if (direction == MoveDirection.Down) n.selectOnDown = to;
        else if (direction == MoveDirection.Left) n.selectOnLeft = to;
        else if (direction == MoveDirection.Right) n.selectOnRight = to;
        from.navigation = n;
    }

    static void Wire(IList<Selectable> items, bool vertical)
    {
        List<Selectable> live = new List<Selectable>();
        foreach (Selectable s in items) if (s != null) live.Add(s);
        for (int i = 0; i < live.Count; i++)
        {
            Navigation n = Explicit(live[i]);
            Selectable before = i > 0 ? live[i - 1] : null, after = i < live.Count - 1 ? live[i + 1] : null;
            if (vertical)
            {
                n.selectOnUp = before;
                n.selectOnDown = after;
            }
            else
            {
                n.selectOnLeft = before;
                n.selectOnRight = after;
            }
            live[i].navigation = n;
        }
    }

    // A control's neighbours as a hand-wired set; one still on automatic starts with none.
    static Navigation Explicit(Selectable s)
    {
        Navigation n = s.navigation;
        if (n.mode == Navigation.Mode.Explicit) return n;
        return new Navigation { mode = Navigation.Mode.Explicit };
    }

    void Update()
    {
        EventSystem es = EventSystem.current;
        if (es == null) return;
        Inputs.Poll();
        KeepFocus(es);
        if (Paused || Inputs.Capturing)
        {
            held = MoveDirection.None;
            return;
        }
        MoveDirection push = Pushed();
        if (push != held)
        {
            held = push;
            nextRepeat = Time.unscaledTime + REPEAT_DELAY;
            if (push != MoveDirection.None) Move(es, push);
        }
        else if (push != MoveDirection.None && Time.unscaledTime >= nextRepeat)
        {
            nextRepeat = Time.unscaledTime + REPEAT_EVERY;
            Move(es, push);
        }
        GameObject at = es.currentSelectedGameObject;
        if (Inputs.Confirm() && at != null)
        {
            Confirms++;
            ExecuteEvents.Execute(at, new BaseEventData(es), ExecuteEvents.submitHandler);
        }
        if (Inputs.Cancel())
        {
            Cancels++;
            if (at != null) ExecuteEvents.Execute(at, new BaseEventData(es), ExecuteEvents.cancelHandler);
            Back();
        }
    }

    // A click on empty space, or a focused control going away, must not leave the pad with nothing lit.
    static void KeepFocus(EventSystem es)
    {
        GameObject at = es.currentSelectedGameObject;
        if (at != null && at.activeInHierarchy)
        {
            last = at;
            return;
        }
        if (last == null || !last.activeInHierarchy) return;
        Selectable s = last.GetComponent<Selectable>();
        if (s != null && s.IsInteractable()) es.SetSelectedGameObject(last);
    }

    // The direction held now: the arrows, the D-pad, else the move keys or the left stick.
    static MoveDirection Pushed()
    {
        float x = (Right() ? 1f : 0f) - (Left() ? 1f : 0f);
        float y = (Up() ? 1f : 0f) - (Down() ? 1f : 0f);
        if (x == 0f && y == 0f)
        {
            Vector2 stick = Inputs.Move();
            x = stick.x;
            y = stick.y;
        }
        if (Mathf.Abs(x) < PUSH && Mathf.Abs(y) < PUSH) return MoveDirection.None;
        if (Mathf.Abs(x) > Mathf.Abs(y)) return x > 0f ? MoveDirection.Right : MoveDirection.Left;
        return y > 0f ? MoveDirection.Up : MoveDirection.Down;
    }

    static bool Up() { return Input.GetKey(KeyCode.UpArrow) || Inputs.PadHeld(XInput.DPAD_UP); }
    static bool Down() { return Input.GetKey(KeyCode.DownArrow) || Inputs.PadHeld(XInput.DPAD_DOWN); }
    static bool Left() { return Input.GetKey(KeyCode.LeftArrow) || Inputs.PadHeld(XInput.DPAD_LEFT); }
    static bool Right() { return Input.GetKey(KeyCode.RightArrow) || Inputs.PadHeld(XInput.DPAD_RIGHT); }

    static void Move(EventSystem es, MoveDirection direction)
    {
        GameObject at = es.currentSelectedGameObject;
        if (at == null) return;
        Moves++;
        AxisEventData data = new AxisEventData(es) { moveDir = direction };
        data.moveVector = direction == MoveDirection.Left ? Vector2.left : direction == MoveDirection.Right ? Vector2.right
            : direction == MoveDirection.Up ? Vector2.up : Vector2.down;
        ExecuteEvents.Execute(at, data, ExecuteEvents.moveHandler);
    }

    static void Back()
    {
        for (int i = cancels.Count - 1; i >= 0; i--)
        {
            if (cancels[i].owner == null)
            {
                cancels.RemoveAt(i);
                continue;
            }
            if (!cancels[i].owner.activeInHierarchy) continue;
            cancels[i].back?.Invoke();
            return;
        }
    }

    // A fresh start (the editor keeps statics between plays) begins with no cancel handlers and no focus.
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Boot()
    {
        cancels.Clear();
        last = null;
        Paused = false;
    }
}
