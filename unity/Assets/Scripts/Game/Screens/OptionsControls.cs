// Settings > CONTROLS (scenes/controls_menu.gd, D-259): each action's keyboard-and-mouse and pad binding as a
// button; press one, then the key, mouse button or pad button to use (Esc keeps the old one). KeyBinds binds
// it, takes it off any other action, and saves. RESET brings the game's own bindings back. The rows nobody
// rebinds (fullscreen, menu confirm and back) are listed under them.
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;

public sealed class OptionsControls : MonoBehaviour
{
    // Bindings made, refused and resets so far, for a proof line.
    public static int Binds, Refused, Resets;

    // The binding waiting for its input (null: none is).
    string waitAction, waitSlot;
    // A mouse button was the new binding: its release must not press the button under it.
    bool swallowClick;
    // The frame the wait began: the pad A that opened it is not a press during it.
    int waitFrame = -1;

    public static OptionsPage Open(Transform host, Selectable opener)
    {
        OptionsPage page = OptionsPage.Open("Controls", "CONTROLS", host, opener);
        OptionsControls c = page.gameObject.AddComponent<OptionsControls>();
        page.Row("", page.Note("Keyboard"), page.Note("Pad"));
        int rebindable = 0, shown = 0;
        foreach (OptionsRows.ControlRow row in OptionsRows.Controls())
        {
            shown++;
            if (row.Action == null)
            {
                page.Row(row.Name, page.Note(row.Keys), page.Note(row.Pad));
                continue;
            }
            rebindable++;
            string action = row.Action;
            Component pad = row.PadButton ? (Component)c.Cell(page, action, KeyBinds.PAD) : page.Note(row.Pad);
            // The keys button is made second and put first, so the row reads keyboard then pad.
            page.Row(row.Name, c.Cell(page, action, KeyBinds.KEYS), pad);
        }
        page.Foot("RESET", c.ResetAll);
        page.Finish();
        Debug.Log($"flow: settings controls shown, {shown} rows, {rebindable} rebindable");
        return page;
    }

    KitButton Cell(OptionsPage page, string action, string slot)
    {
        KitButton b = page.Choice(() => Wait(action, slot));
        page.Labels.Add(b, () => OptionsRows.Cell(action, slot, waitAction, waitSlot));
        return b;
    }

    void Wait(string action, string slot)
    {
        if (TakeSwallow()) return;
        waitAction = action;
        waitSlot = slot;
        waitFrame = Time.frameCount;
        Inputs.BeginCapture(slot);
    }

    void ResetAll()
    {
        if (TakeSwallow()) return;
        StopWaiting();
        KeyBinds.Reset();
        Resets++;
        Debug.Log($"flow: settings controls reset, {Resets} resets");
    }

    bool TakeSwallow()
    {
        if (!swallowClick) return false;
        swallowClick = false;
        return true;
    }

    void StopWaiting()
    {
        waitAction = waitSlot = null;
        Inputs.EndCapture();
    }

    // While a binding waits, the next press of its kind is the new binding; Esc keeps the old one.
    void Update()
    {
        if (swallowClick && !Input.GetMouseButton(0) && !Input.GetMouseButtonUp(0)) swallowClick = false;
        if (waitAction == null) return;
        // A pad press is not a keyboard cell's binding (controls_menu.gd _input leaves it to the page): B backs
        // out as ui_cancel does (options_page.gd _unhandled_input), any other ends the wait so the pad is never stuck.
        if (waitSlot == KeyBinds.KEYS && Time.frameCount > waitFrame && PadPressed())
        {
            bool back = Inputs.PadDown(XInput.B);
            StopWaiting();
            if (back) GetComponent<OptionsPage>().Close();
            return;
        }
        string input = Inputs.NextPress(out bool isPad);
        if (input == "") return;
        switch (OptionsRows.Take(waitSlot, input, isPad))
        {
            case OptionsRows.Press.Ignore:
                Inputs.BeginCapture(waitSlot);
                return;
            case OptionsRows.Press.Bind:
                bool bound = KeyBinds.Bind(waitAction, waitSlot, input);
                if (bound) Binds++;
                else Refused++;
                swallowClick = input == KeyCode.Mouse0.ToString();
                Debug.Log($"flow: settings bind {waitAction} {waitSlot} {input} {(bound ? "bound" : "refused")}, now {KeyBinds.Text(waitAction, waitSlot)}");
                break;
        }
        StopWaiting();
    }

    static readonly int[] PAD_BITS =
    {
        XInput.A, XInput.B, XInput.X, XInput.Y, XInput.DPAD_UP, XInput.DPAD_DOWN, XInput.DPAD_LEFT, XInput.DPAD_RIGHT,
        XInput.START, XInput.BACK, XInput.LB, XInput.RB, XInput.L3, XInput.R3, XInput.LT, XInput.RT,
    };

    static bool PadPressed()
    {
        foreach (int bit in PAD_BITS) if (Inputs.PadDown(bit)) return true;
        return false;
    }

    void OnDestroy()
    {
        if (waitAction != null) Inputs.EndCapture();
    }
}
