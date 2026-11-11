// Stand-in globe until the real one is built (scenes/globe_view.gd, globe_missions.gd): the first open continent
// with a real city, and LAUNCH. No globe, panel, Threat readout or WIN / LOSE mission.
using System;
using UnityEngine;
using S = Kaiju.Sim;

public static class StubGlobe
{
    const float CARD_WIDTH = 760f;

    // The continent LAUNCH plays: the first one open (Campaign.states) whose city is real; null when none is.
    public static S.GDict Target(S.GDict save)
    {
        S.GArray<S.GDict> continents = S.Content.Continents();
        S.GDict states = S.Campaign.States(continents, save.Get("conquered", S.Gd.Arr()));
        foreach (S.GDict def in continents)
        {
            if (S.Num.I(states[def["id"]]) == S.Campaign.State.AVAILABLE && S.Campaign.RealCity(def)) return def;
        }
        return null;
    }

    // The button is named Launch.
    public static RectTransform Show(S.GDict save, Action<S.GDict> onLaunch)
    {
        RectTransform screen = UiKit.Screen("Globe");
        UiKit.Backdrop(screen);
        RectTransform card = UiKit.Panel(UiKit.SafeArea(screen));
        UiKit.Size(card, CARD_WIDTH, 0f);
        S.GDict target = Target(save);
        UiKit.Header(card, target != null ? S.Gd.Str(target.Get("name", target["id"])) : "GLOBE", UiKit.SIZE_HEAD);
        KitButton launch = UiKit.Button(card, "LAUNCH", () => onLaunch(target), UiKit.SIZE_HEAD);
        launch.name = "Launch";
        launch.interactable = target != null;
        UiKit.Focus(launch);
        return screen;
    }
}
