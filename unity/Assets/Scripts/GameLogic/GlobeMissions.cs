// The globe's campaign rules and words (scenes/globe_missions.gd, mission_panel.gd, stub_mission.gd,
// threat_readout.gd): each continent's state, the mission panel's lines, what LAUNCH starts, and how a mission
// ends. The win rule is Godot's unruled stand-in: the player presses WIN or LOSE. Plain C#.
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    // How a continent's mission stands or ended (globe_missions.gd _back_to_globe, _won, _lost).
    public sealed class MissionOutcome
    {
        // A WIN / LOSE choice is owed (the stand-in mission is to be shown); false once it is made, or when
        // the rampage was not a continent's mission at all.
        public bool pending;
        public bool won, lost;
        // The continent (Content.continents() row) and its id; null and "" when there was no mission.
        public GDict def;
        public string id = "";
        // The words under the continent's name on the WIN / LOSE screen (a text key).
        public string line = "";
        // The bonus the player kept; "" for the capital (it offers none) and for a loss.
        public string bonusId = "";
        // The save: as banked while pending, after Campaign.conquer once won, unchanged once lost.
        public GDict save;
        // The save's Threat Level after the outcome.
        public double threat;
        // The save's demo_done. The globe never sets it (main.gd _on_bought does, when the tree is all owned).
        public bool demoDone;
    }

    // One line of the mission panel: its words, already in the player's language, and the kit colour it wears.
    public struct PanelLine
    {
        public string text;
        // "HEADER", or a palette name: MUTED, TEXT, ALERT, or "THREAT" (the ramp's colour at `threat`).
        public string colour;
        public double threat;
    }

    // A colour on the Threat ramp: `t` of the way from palette colour `from` to `to`.
    public struct ThreatTint
    {
        public string from, to;
        public double t;
    }

    public static class GlobeMissions
    {
        // mission_panel.gd PERCENT.
        const double PERCENT = 100.0;
        // stub_mission.gd start() default line, and globe_missions.gd _back_to_globe's.
        public const string STAND_IN_LINE = "Stand-in mission: the city comes later";
        public const string OVER_LINE = "The rampage is over";

        // globe_missions.gd states(): each continent's Campaign.State by id.
        public static GDict States(GDict save)
        {
            return Campaign.States(Content.Continents(), save.Get("conquered", Gd.Arr()));
        }

        public static long StateOf(GDict states, string id)
        {
            return Num.I(states.Get(id, Campaign.State.LOCKED));
        }

        // globe_view.gd locked(): true for a continent the campaign has not opened yet (and for the sea's "").
        public static bool Locked(GDict states, string id)
        {
            return StateOf(states, id) == Campaign.State.LOCKED;
        }

        // Per mask value (0 the sea, n + 1 the n-th continent), its state: globe_view.gd set_states.
        public static long[] StatesByValue(GDict states)
        {
            GArray<GDict> continents = Content.Continents();
            long[] per = new long[continents.Size() + 1];
            for (int n = 0; n < continents.Size(); n++) per[n + 1] = StateOf(states, Gd.Str(continents[n]["id"]));
            return per;
        }

        // The continents the player may pick (not locked), in data order: what a click may open.
        public static List<string> Open(GDict states)
        {
            List<string> open = new List<string>();
            foreach (GDict def in Content.Continents())
            {
                string id = Gd.Str(def["id"]);
                if (!Locked(states, id)) open.Add(id);
            }
            return open;
        }

        // The first available continent whose city is real, or "": the selection -flow-smoke starts on.
        public static string FirstRealCity(GDict save)
        {
            GDict states = States(save);
            foreach (GDict def in Content.Continents())
            {
                string id = Gd.Str(def["id"]);
                if (StateOf(states, id) == Campaign.State.AVAILABLE && Campaign.RealCity(def)) return id;
            }
            return "";
        }

        // The open continent `step` places on from `selected` (keys and pad), wrapping; "" when none is open.
        public static string Step(GDict states, string selected, int step)
        {
            List<string> open = Open(states);
            if (open.Count == 0) return "";
            int at = open.IndexOf(selected);
            if (at < 0) return step >= 0 ? open[0] : open[open.Count - 1];
            return open[((at + step) % open.Count + open.Count) % open.Count];
        }

        // globe_missions.gd show_panel: the Threat Level this continent's conquest would leave.
        public static double ThreatAfter(GDict save, GDict def)
        {
            return Num.F(Campaign.Conquer(save, def, "")["threat"]);
        }

        // mission_panel.gd show_for: the panel's lines top to bottom (LAUNCH comes under them).
        public static List<PanelLine> PanelLines(GDict save, GDict def)
        {
            double after = ThreatAfter(save, def);
            List<PanelLine> lines = new List<PanelLine>();
            lines.Add(new PanelLine { text = Tr.T(Gd.Str(def["name"])).ToUpperInvariant(), colour = "HEADER" });
            lines.Add(new PanelLine { text = Tr.T(Content.StageWord(Num.I(def["stage"]))), colour = "MUTED" });
            string threat = Tr.F("Threat +%d%%", Gd.Roundi(Num.F(def["threat"])));
            if (after >= 0.0) threat += Tr.F(" (to %d%%)", Gd.Floori(after));
            lines.Add(new PanelLine { text = threat, colour = after >= 0.0 ? "THREAT" : "ALERT", threat = after });
            GArray<Variant> offered = def["bonuses"];
            foreach (Variant pick in offered) lines.Add(new PanelLine { text = BonusText(pick), colour = "TEXT" });
            return lines;
        }

        // mission_panel.gd bonus_text: a bonus in plain words from data ("Moves 10% faster"); one the
        // director has not picked yet (no scale) says so.
        public static string BonusText(GDict pick)
        {
            GDict scale = pick["scale"];
            List<string> parts = new List<string>();
            foreach (Variant stat in scale)
            {
                string line = Content.BonusLine(Gd.Str(stat));
                if (line != "") parts.Add(Tr.F(line, Gd.Roundi(Num.F(scale[stat]) * PERCENT)));
            }
            return parts.Count == 0 ? Tr.T("Bonus to be designed") : string.Join(", ", parts);
        }

        // threat_readout.gd show_level: the value as shown, a whole percent, truncated ("22%").
        public static string ThreatText(double threat)
        {
            return Tr.Format("%d%%", Gd.Floori(threat));
        }

        // threat_readout.gd: the cap the plate counts to ("/ 100%").
        public static string ThreatCapText()
        {
            return Tr.Format("/ %d%%", Gd.Roundi(Campaign.THREAT_FULL));
        }

        // threat_readout.gd colour_for: the ramp's stops (tuning ui.threat_readout.ramp) blended, clamped at the ends.
        public static ThreatTint ThreatColour(double threat)
        {
            GDict cfg = Content.Section("ui")["threat_readout"];
            GArray<Variant> ramp = cfg["ramp"];
            GArray<Variant> first = ramp[0];
            string name = Gd.Str(first[1]);
            ThreatTint tint = new ThreatTint { from = name, to = name, t = 0.0 };
            if (threat <= Num.F(first[0])) return tint;
            for (int n = 1; n < ramp.Size(); n++)
            {
                GArray<Variant> stop = ramp[n], prev = ramp[n - 1];
                double lo = Num.F(prev[0]), hi = Num.F(stop[0]);
                string colour = Gd.Str(stop[1]);
                if (threat >= hi)
                {
                    tint = new ThreatTint { from = colour, to = colour, t = 0.0 };
                    continue;
                }
                return new ThreatTint { from = Gd.Str(prev[1]), to = colour, t = (threat - lo) / (hi - lo) };
            }
            return tint;
        }

        // globe_missions.gd _launch: true when LAUNCH starts the continent's real city (a rampage); false when
        // it opens the stand-in WIN / LOSE mission at once.
        public static bool StartsCity(GDict def)
        {
            return Campaign.RealCity(def);
        }

        // A stand-in mission opened straight from LAUNCH (globe_missions.gd _launch: mission.start(def)).
        public static MissionOutcome StandIn(GDict save, GDict def)
        {
            return Pending(save, def, STAND_IN_LINE);
        }

        // After a rampage's results are read (globe_missions.gd _city_over then _back_to_globe; the save is
        // already banked): a continent's city owes its WIN / LOSE choice, "The rampage is over" under its name.
        // Godot has no rule yet for what wins a city, so nothing in `result` decides it: the player does
        // (Win / Lose below). A rampage with no continent, or Endless, owes nothing.
        public static MissionOutcome AfterRun(GDict save, RunRequest request, GDict result)
        {
            if (request == null || request.continent == "" || request.endless) return Settled(new MissionOutcome(), save);
            GDict def = Content.Continent(request.continent);
            if (def.IsEmpty()) return Settled(new MissionOutcome(), save);
            return Pending(save, def, OVER_LINE);
        }

        static MissionOutcome Pending(GDict save, GDict def, string line)
        {
            MissionOutcome o = new MissionOutcome { pending = true, def = def, id = Gd.Str(def["id"]), line = line };
            return Settled(o, save);
        }

        // stub_mission.gd _pick: the bonuses WIN offers, in data order; none for the capital, which WIN
        // conquers at once.
        public static GArray<Variant> Offered(MissionOutcome pending)
        {
            return pending.def != null ? (GArray<Variant>)pending.def["bonuses"] : Gd.Arr();
        }

        // globe_missions.gd _won: the continent is conquered with the bonus kept (Campaign.conquer).
        public static MissionOutcome Win(MissionOutcome pending, string bonusId)
        {
            MissionOutcome o = new MissionOutcome { won = true, def = pending.def, id = pending.id, line = pending.line, bonusId = bonusId ?? "" };
            return Settled(o, Campaign.Conquer(pending.save, pending.def, o.bonusId));
        }

        // globe_missions.gd _lost: nothing changes.
        public static MissionOutcome Lose(MissionOutcome pending)
        {
            MissionOutcome o = new MissionOutcome { lost = true, def = pending.def, id = pending.id, line = pending.line };
            return Settled(o, pending.save);
        }

        static MissionOutcome Settled(MissionOutcome o, GDict save)
        {
            o.save = save;
            o.threat = Num.F(save.Get("threat", 0.0));
            o.demoDone = save.Get("demo_done", false) == true;
            return o;
        }
    }
}
