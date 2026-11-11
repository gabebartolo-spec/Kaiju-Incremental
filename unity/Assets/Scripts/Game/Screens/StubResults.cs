// Stand-in results until the real screen is built (scenes/results_screen.gd): every row of the result as the
// sim gave it, over the wrecked city, and the way on. No count-up, records or verdict line.
using System;
using UnityEngine;
using S = Kaiju.Sim;

public static class StubResults
{
    const float CARD_WIDTH = 760f;

    // `previous` is the best before this rampage (SaveFile.Bank), for the real screen. The button is named Go.
    public static RectTransform Show(S.GDict result, S.GDict previous, string goLabel, Action onContinue)
    {
        RectTransform screen = UiKit.Screen("Results");
        RectTransform card = UiKit.Panel(UiKit.SafeArea(screen));
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, "RAMPAGE REPORT", UiKit.SIZE_HEAD);
        foreach (S.Variant key in result.Keys())
        {
            UiKit.Label(card, S.Gd.Str(key) + "   " + S.Gd.Str(result[key]), UiKit.SIZE_SMALL);
        }
        KitButton go = UiKit.Button(card, goLabel, onContinue, UiKit.SIZE_HEAD);
        go.name = "Go";
        UiKit.Focus(go);
        return screen;
    }
}
