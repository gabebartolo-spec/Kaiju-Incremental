// Stand-in thanks screen until the real one is built (scenes/demo_end.gd): the demo's totals, Endless mode or
// back to the tree. No kaiju on show and no feedback link.
using System;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public static class StubDemoEnd
{
    const float CARD_WIDTH = 760f;

    // Buttons: Endless and Keep.
    public static RectTransform Show(S.GDict save, Action onEndless, Action onKeep)
    {
        RectTransform screen = UiKit.Screen("DemoEnd");
        UiKit.Backdrop(screen);
        RectTransform card = UiKit.Panel(UiKit.SafeArea(screen));
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, "THANKS FOR PLAYING", UiKit.SIZE_HEAD);
        S.GDict totals = save.Get("totals", new S.GDict());
        foreach (S.PackedStringArray row in S.Demo.Rows(totals))
        {
            UiKit.Label(card, Tr.T(row[0]) + "   " + row[1], UiKit.SIZE_SMALL);
        }
        KitButton endless = UiKit.Button(card, "TRY ENDLESS MODE", onEndless);
        endless.name = "Endless";
        KitButton keep = UiKit.Button(card, "KEEP PLAYING", onKeep, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
        keep.name = "Keep";
        UiFocus.Column(endless, keep);
        UiFocus.OnCancel(screen.gameObject, onKeep);
        UiKit.Focus(endless);
        return screen;
    }
}
