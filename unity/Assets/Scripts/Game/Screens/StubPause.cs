// Stand-in pause menu until the real one is built (scenes/pause_menu.gd): RESUME and END RAMPAGE over the
// stopped rampage. No settings, photo mode, report or "are you sure".
using System;
using UnityEngine;

public static class StubPause
{
    const float CARD_WIDTH = 600f;

    // Buttons: Resume and End; cancel (Esc, pad B) resumes.
    public static RectTransform Show(Action onResume, Action onEnd)
    {
        RectTransform screen = UiKit.Screen("Pause");
        RectTransform card = UiKit.Panel(UiKit.SafeArea(screen));
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, "PAUSED", UiKit.SIZE_HEAD);
        KitButton resume = UiKit.Button(card, "RESUME", onResume);
        resume.name = "Resume";
        KitButton end = UiKit.Button(card, "END RAMPAGE", onEnd, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
        end.name = "End";
        UiKit.Label(card, "You keep the biomass", UiKit.SIZE_BODY, UiKit.MUTED);
        UiFocus.Column(resume, end);
        UiFocus.OnCancel(screen.gameObject, onResume);
        UiKit.Focus(resume);
        return screen;
    }
}
