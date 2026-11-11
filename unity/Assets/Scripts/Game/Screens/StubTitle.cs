// Stand-in title until the real one is built (scenes/title_screen.gd): the slots as SaveFile reads them, CONTINUE
// on the newest save, NEW KAIJU in the first empty slot, QUIT. No slot list, delete, settings or art.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;

public static class StubTitle
{
    const float CARD_WIDTH = 760f;

    // `latest` is the slot CONTINUE resumes (0: none). The buttons are named Continue, NewKaiju and Quit.
    public static RectTransform Show(List<SlotInfo> slots, int latest, Action<int> onContinue, Action<int> onNew, Action onQuit)
    {
        RectTransform screen = UiKit.Screen("Title");
        UiKit.Backdrop(screen);
        RectTransform card = UiKit.Panel(UiKit.SafeArea(screen));
        UiKit.Size(card, CARD_WIDTH, 0f);
        UiKit.Header(card, "KAIJU INCREMENTAL");
        int empty = 0;
        string summary = "";
        foreach (SlotInfo info in slots)
        {
            string held = !info.Taken ? Tr.T("EMPTY") : !info.Readable ? Tr.T("unreadable save") : info.Specimen + "  " + info.Summary;
            UiKit.Label(card, Tr.F("SLOT %d", info.Slot) + "   " + held, UiKit.SIZE_SMALL, info.Taken ? UiKit.TEXT : UiKit.MUTED);
            if (!info.Taken && empty == 0) empty = info.Slot;
            if (info.Slot == latest) summary = info.Summary;
        }
        KitButton resume = UiKit.Button(card, Tr.F("CONTINUE GAME\n%s", summary.ToUpperInvariant()), () => onContinue(latest));
        resume.name = "Continue";
        resume.interactable = latest > 0;
        // The real title asks which slot (and whether to start over); the stand-in never overwrites a kaiju.
        KitButton fresh = UiKit.Button(card, "NEW KAIJU", () => onNew(empty), UiKit.SIZE_BODY, latest > 0 ? UiKit.PANEL_EDGE : UiKit.ACCENT);
        fresh.name = "NewKaiju";
        fresh.interactable = empty > 0;
        KitButton quit = UiKit.Button(card, "QUIT", onQuit, UiKit.SIZE_BODY, UiKit.PANEL_EDGE);
        quit.name = "Quit";
        UiFocus.Column(resume, fresh, quit);
        UiKit.Focus(latest > 0 ? resume : empty > 0 ? fresh : quit);
        return screen;
    }
}
