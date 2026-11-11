// The stand-in mission (scenes/stub_mission.gd; director 2026-11-01: "Win/Lose stub + pick"): a plain screen with
// WIN and LOSE under the continent's name. WIN shows the continent's bonuses and the player keeps one (D-421),
// which ends it won; the capital offers none and is won at once; LOSE ends it lost and nothing changes. Godot has
// no rule yet for what wins a city, so this press is the rule, after a real city's rampage too.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public static class MissionResult
{
    const float GAP = 24f;  // stub_mission.gd GAP: px between the screen's lines

    // `outcome`: a pending one (GlobeMissions.AfterRun or StandIn). `onDone(outcome)`: the choice is made;
    // its `won` or `lost` is set and its `save` is the save to keep (conquered on a win). The screen stays up
    // until its owner destroys it. Buttons are named Win, Lose, then Bonus0, Bonus1, ...
    // `parent`: null for a screen of its own, else the screen it covers.
    public static RectTransform Show(MissionOutcome outcome, Action<MissionOutcome> onDone, Transform parent = null)
    {
        RectTransform screen;
        if (parent == null) screen = UiKit.Screen("Mission");
        else
        {
            screen = UiKit.Box(parent, "Mission");
            UiKit.FullRect(screen);
        }
        UiKit.Backdrop(screen);
        RectTransform column = UiKit.Column(screen, GAP);
        column.anchorMin = column.anchorMax = column.pivot = new Vector2(0.5f, 0.5f);
        UiKit.Fit(column);
        string name = Tr.T(S.Gd.Str(outcome.def["name"])).ToUpperInvariant();
        bool[] over = { false };
        Action<MissionOutcome> finish = done =>
        {
            if (over[0]) return;  // one answer only, however fast the presses come
            over[0] = true;
            Debug.Log(done.won
                ? $"flow: mission won, continent {done.id}, bonus {(done.bonusId != "" ? done.bonusId : "none")}, threat {GlobeMissions.ThreatText(done.threat)}"
                : $"flow: mission lost, continent {done.id}, threat {GlobeMissions.ThreatText(done.threat)}");
            onDone?.Invoke(done);
        };

        // stub_mission.gd start: the WIN / LOSE choice.
        UiKit.Header(column, name, UiKit.SIZE_TITLE);
        Text line = UiKit.Label(column, outcome.line != "" ? outcome.line : GlobeMissions.STAND_IN_LINE, UiKit.SIZE_BODY, UiKit.MUTED);
        line.alignment = TextAnchor.MiddleCenter;
        KitButton win = UiKit.Button(column, "WIN", () =>
        {
            // stub_mission.gd _pick: one button per bonus offered; pressing one keeps it.
            S.GArray<S.Variant> offered = GlobeMissions.Offered(outcome);
            if (offered.IsEmpty())  // the capital offers none (D-422): WIN conquers it at once
            {
                finish(GlobeMissions.Win(outcome, ""));
                return;
            }
            for (int i = column.childCount - 1; i >= 0; i--)
            {
                GameObject old = column.GetChild(i).gameObject;
                old.SetActive(false);
                UnityEngine.Object.Destroy(old);
            }
            UiKit.Header(column, name, UiKit.SIZE_TITLE);
            List<Selectable> picks = new List<Selectable>();
            for (int i = 0; i < offered.Size(); i++)
            {
                S.GDict pick = offered[i];
                string bonusId = S.Gd.Str(pick["id"]);
                KitButton b = UiKit.Button(column, GlobeMissions.BonusText(pick), () => finish(GlobeMissions.Win(outcome, bonusId)), UiKit.SIZE_BODY);
                b.name = "Bonus" + i;
                picks.Add(b);
            }
            UiFocus.Column(picks.ToArray());
            UiKit.Focus(picks[0]);
        }, UiKit.SIZE_HEAD);
        win.name = "Win";
        KitButton lose = UiKit.Button(column, "LOSE", () => finish(GlobeMissions.Lose(outcome)), UiKit.SIZE_HEAD, UiKit.ALERT);
        lose.name = "Lose";
        UiFocus.Column(win, lose);
        UiKit.Focus(win);
        Debug.Log($"flow: mission shown, continent {outcome.id}, {GlobeMissions.Offered(outcome).Size()} bonuses, line '{line.text}'");
        return screen;
    }
}
