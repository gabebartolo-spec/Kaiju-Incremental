// The globe (scenes/globe_view.gd, globe_missions.gd, mission_panel.gd, threat_readout.gd): the world's continents
// in their campaign states, the Threat Level plate at the title-safe corner, the mission panel down the right
// margin for the continent picked, and LAUNCH. The world is the 3D hologram globe (GlobeHologram).
using System;
using System.Collections.Generic;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.UI;
using S = Kaiju.Sim;

public static class Globe
{
    const float GAP = 16f;  // mission_panel.gd GAP: px between the panel's lines

    // `onLaunch(continent row)`: LAUNCH on a continent whose city is real (start its rampage).
    // `onReturned(outcome)`: a stand-in mission opened by LAUNCH on any other continent ended, won or lost;
    // outcome.save is the save to keep. `preselect` (the smoke): the first available real city starts picked.
    // The LAUNCH button is named Launch.
    public static RectTransform Show(S.GDict save, Action<S.GDict> onLaunch, Action<MissionOutcome> onReturned, bool preselect = false)
    {
        RectTransform screen = UiKit.Screen("Globe");
        Vector2 safe = UiKit.SafeMargin();
        S.GDict[] held = { save };
        S.GDict states = GlobeMissions.States(save);
        // globe_view.gd: no backdrop, the globe's own near-black background behind the spheres.
        GlobeHologram map = GlobeHologram.Make(screen);
        map.SetStates(states);
        Text threat = ThreatPlate(screen, safe);
        ShowThreat(threat, S.Num.F(save.Get("threat", 0.0)));

        // mission_panel.gd _init: a card sized to its text, centred down the right margin.
        RectTransform panel = UiKit.Panel(screen, null, GAP);
        panel.anchorMin = panel.anchorMax = panel.pivot = new Vector2(1f, 0.5f);
        panel.anchoredPosition = new Vector2(-safe.x, 0f);
        RectTransform lines = UiKit.Column(panel, GAP, "Lines");
        KitButton launch = UiKit.Button(panel, "LAUNCH", () =>
        {
            S.GDict def = S.Content.Continent(map.Selected);
            if (def.IsEmpty() || !map.Interactive) return;
            // globe_missions.gd _launch: a real city plays; any other continent opens the stand-in mission.
            if (GlobeMissions.StartsCity(def))
            {
                onLaunch?.Invoke(def);
                return;
            }
            map.Interactive = false;
            RectTransform[] over = new RectTransform[1];
            over[0] = MissionResult.Show(GlobeMissions.StandIn(held[0], def), done =>
            {
                UnityEngine.Object.Destroy(over[0].gameObject);
                // globe_missions.gd _won / _lost: the states and the Threat plate follow the save, the pick is let go.
                held[0] = done.save;
                map.Interactive = true;
                map.SetStates(GlobeMissions.States(done.save));
                ShowThreat(threat, done.threat);
                map.Deselect();
                onReturned?.Invoke(done);
            }, screen);
        }, UiKit.SIZE_HEAD);
        launch.name = "Launch";
        panel.gameObject.SetActive(false);
        map.Panel = panel;
        map.Picked = id =>
        {
            if (id == "")
            {
                panel.gameObject.SetActive(false);  // mission_panel.gd hide_panel
                return;
            }
            Fill(lines, held[0], S.Content.Continent(id));
            panel.gameObject.SetActive(true);
            UiKit.Focus(launch);
        };
        // globe_view.gd _unhandled_input: cancel lets go of the pick; with none it does nothing here.
        UiFocus.OnCancel(screen.gameObject, () => { if (map.Interactive) map.Deselect(); });
        if (preselect)
        {
            string first = GlobeMissions.FirstRealCity(save);
            if (first != "") map.Click(first);
        }
        int open = GlobeMissions.Open(states).Count, conquered = 0;
        foreach (long state in GlobeMissions.StatesByValue(states)) if (state == S.Campaign.State.CONQUERED) conquered++;
        Debug.Log($"flow: globe shown, {S.Content.Continents().Size()} continents, {open} open, {conquered} conquered, threat {GlobeMissions.ThreatText(S.Num.F(save.Get("threat", 0.0)))}, selected {(map.Selected != "" ? map.Selected : "none")}, {map.Markers} markers, mask {map.MaskWidth}x{map.MaskHeight}");
        return screen;
    }

    // mission_panel.gd show_for: the panel's lines for one continent, replacing the ones before.
    static void Fill(RectTransform lines, S.GDict save, S.GDict def)
    {
        for (int i = lines.childCount - 1; i >= 0; i--)
        {
            GameObject old = lines.GetChild(i).gameObject;
            old.SetActive(false);  // out of the layout now; destroyed at the frame's end
            UnityEngine.Object.Destroy(old);
        }
        List<PanelLine> rows = GlobeMissions.PanelLines(save, def);
        foreach (PanelLine row in rows)
        {
            if (row.colour == "HEADER") UiKit.Header(lines, row.text, UiKit.SIZE_HEAD);
            else UiKit.Label(lines, row.text, UiKit.SIZE_BODY, row.colour == "THREAT" ? ThreatColour(row.threat) : Palette(row.colour));
        }
        Debug.Log($"flow: globe panel, {S.Gd.Str(def["id"])}, {rows.Count} lines, {rows[2].text}");
    }

    // threat_readout.gd PALETTE: the names the ramp (and a panel line) may use.
    public static Color Palette(string name)
    {
        switch (name)
        {
            case "GOOD": return UiKit.GOOD;
            case "WARN": return UiKit.WARN;
            case "ORANGE": return UiKit.ORANGE;
            case "ALERT": return UiKit.ALERT;
            case "ACCENT": return UiKit.ACCENT;
            case "MUTED": return UiKit.MUTED;
            default: return UiKit.TEXT;
        }
    }

    // threat_readout.gd colour_for: the value's colour at a Threat Level.
    public static Color ThreatColour(double threat)
    {
        ThreatTint tint = GlobeMissions.ThreatColour(threat);
        return Color.Lerp(Palette(tint.from), Palette(tint.to), (float)tint.t);
    }

    // threat_readout.gd _init: a thin bordered plate at the title-safe corner: THREAT in hazard yellow, the
    // value, and the cap it counts to. Its size and edge are data (tuning ui.threat_readout). Returns the value.
    static Text ThreatPlate(Transform parent, Vector2 safe)
    {
        S.GDict cfg = UiKit.Ui()["threat_readout"];
        HazardBox plate = UiKit.Hazard(parent, UiKit.PANEL, UiKit.ACCENT, (float)S.Num.F(cfg["border"]), HazardBox.Band.None, "Threat");
        RectTransform rt = plate.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0f, 1f);
        rt.anchoredPosition = new Vector2(safe.x, -safe.y);
        HorizontalLayoutGroup row = plate.gameObject.AddComponent<HorizontalLayoutGroup>();
        int pad = (int)S.Num.I(cfg["pad"]);
        row.padding = new RectOffset(pad, pad, 0, 0);
        row.spacing = (float)S.Num.F(cfg["gap"]);
        row.childAlignment = TextAnchor.MiddleCenter;
        row.childControlWidth = row.childControlHeight = true;
        row.childForceExpandWidth = row.childForceExpandHeight = false;
        UiKit.Size(plate, 0f, (float)S.Num.F(cfg["height"]));
        UiKit.Fit(plate);
        int size = (int)S.Num.I(cfg["font"]);
        Plain(UiKit.Label(rt, "THREAT", size, UiKit.ACCENT));
        Text value = Plain(UiKit.Label(rt, "", size));
        // Fixed to the widest reading so the plate's edge never jumps as the number changes.
        value.text = "100%";
        UiKit.Size(value, Mathf.Ceil(value.preferredWidth), 0f);
        value.alignment = TextAnchor.MiddleCenter;
        Plain(UiKit.Label(rt, GlobeMissions.ThreatCapText(), size, UiKit.MUTED));
        return value;
    }

    // The plate's text sits flat on its plate: no drop shadow to spill past the border.
    static Text Plain(Text label)
    {
        KitText style = label.GetComponent<KitText>();
        if (style != null) style.shadow = 0f;
        label.alignment = TextAnchor.MiddleLeft;
        return label;
    }

    // threat_readout.gd show_level.
    static void ShowThreat(Text value, double threat)
    {
        value.text = GlobeMissions.ThreatText(threat);
        value.color = ThreatColour(threat);
    }
}
