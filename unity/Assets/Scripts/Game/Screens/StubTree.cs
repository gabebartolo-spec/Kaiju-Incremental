// Stand-in evolution tree until the real one is built (scenes/upgrade_screen.gd): the biomass banked and the
// way back to a rampage. Nothing can be bought here.
using System;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public static class StubTree
{
    const float CARD_WIDTH = 760f;

    // `onEndless` is null until the demo is done (main.gd endless_unlocked). Buttons: Rampage, Endless, Menu.
    public static RectTransform Show(S.GDict save, Action onRampage, Action onEndless, Action onMenu)
    {
        RectTransform screen = UiKit.Screen("Tree");
        UiKit.Backdrop(screen);
        RectTransform card = UiKit.Panel(UiKit.SafeArea(screen));
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, "EVOLUTION TREE", UiKit.SIZE_HEAD);
        UiKit.Label(card, SaveFile.SpecimenName(save), UiKit.SIZE_SMALL, UiKit.MUTED);
        UiKit.Label(card, Tr.F("BIOMASS  %d", S.Num.I(save.Get("rubble", 0L))), UiKit.SIZE_HEAD, UiKit.ACCENT);
        KitButton go = UiKit.Button(card, "RAMPAGE  >", onRampage, UiKit.SIZE_HEAD);
        go.name = "Rampage";
        KitButton endless = null;
        if (onEndless != null)
        {
            endless = UiKit.Button(card, "ENDLESS MODE", onEndless, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
            endless.name = "Endless";
        }
        KitButton menu = UiKit.Button(card, "MENU", onMenu, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
        menu.name = "Menu";
        UiFocus.Column(go, endless, menu);
        UiFocus.OnCancel(screen.gameObject, onMenu);
        UiKit.Focus(go);
        return screen;
    }
}
