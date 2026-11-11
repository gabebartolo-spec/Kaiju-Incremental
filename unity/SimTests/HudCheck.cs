// The rampage HUD's rules (GameLogic/HudText.cs and HudState.cs, after scenes/rampage_hud.gd, hud_clock.gd,
// hud_counts.gd, threat_bar.gd, hud_ring.gd, hurt_vignette.gd, rampage_news.gd, controls_card.gd, breath_aim.gd,
// pad_rumble.gd, input_latch.gd and held_button.gd) are plain C#, so they are held here: every text is Godot's,
// every threshold flips where Godot's does, and the numbers are tuning's.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;

static class HudCheck
{
    static int checks, failed;

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        S.FileAccess.Root = repoRoot;
        string oldLanguage = Tr.Language;
        Tr.Load(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
        Tr.Language = "en";
        // A binding saves the settings, so the player's folder is a throwaway one.
        string oldRoot = UserDir.Root;
        string dir = Path.Combine(Path.GetTempPath(), "kaiju_hud_check_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(dir);
        UserDir.Root = dir;
        try
        {
            S.GDict tuning = S.JSON.ParseString(File.ReadAllText(Path.Combine(repoRoot, "data", "tuning.json")));
            S.GDict ui = tuning["ui"];
            Headlines();
            Clock(ui["hud"]);
            Biomass(ui["hud"]);
            Rings(ui["hud"], repoRoot);
            Threat(ui["threat_bar"]);
            Layout(ui);
            Vignette(ui["hurt"]);
            News(tuning, ui["news_live"]);
            Card(ui["controls_card"]);
            Rumble(tuning["rumble"]);
            Aim();
            Latch(tuning);
        }
        finally
        {
            KeyBinds.Clear();
            Tr.Language = oldLanguage;
            UserDir.Root = oldRoot;
            try { Directory.Delete(dir, true); } catch (IOException) { }
        }
        Console.WriteLine($"hud: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("hud: FAILED " + what);
    }

    static void Near(double got, double want, double within, string what)
    {
        Check(Math.Abs(got - want) <= within, $"{what}: got {got.ToString("0.####", CultureInfo.InvariantCulture)}, want {want.ToString("0.####", CultureInfo.InvariantCulture)}");
    }

    static double F(S.GDict d, string key) { return S.Num.F(d[key]); }

    static void Headlines()
    {
        Check(HudText.Headline("defeated")[0] == "BROUGHT DOWN" && HudText.Headline("defeated")[1] == "The army got you this time", "defeated reads BROUGHT DOWN");
        Check(HudText.Headline("time")[0] == "AIRSTRIKE" && HudText.Headline("time")[1] == "The army ran out of patience", "time up reads AIRSTRIKE");
        Check(HudText.Headline("city_fallen")[0] == "THE CITY HAS FALLEN" && HudText.Headline("city_fallen")[1] == "Nothing left standing", "a fallen city reads so");
        Check(HudText.Headline("ended")[0] == "RAMPAGE ENDED" && HudText.Headline("ended")[1] == "You called it off", "a run called off reads so");
        Check(HudText.Headline("anything")[0] == "RAMPAGE OVER" && HudText.Headline(null)[1] == "", "an unknown reason reads RAMPAGE OVER");
        Tr.Language = "es";
        Check(HudText.Headline("defeated")[0] == "DERRIBADO", "the headline is in the player's language");
        Tr.Language = "en";
        Near(HudText.BEAT_SECONDS, 2.5, 1e-9, "the beat lasts 150 frames");
        Near(HudText.BEAT_MIN_SECONDS, 40.0 / 60.0, 1e-9, "the beat can be skipped after 40 frames");
        Check(HudText.BEAT_SIZE == 128 && HudText.BEAT_TOP == 64.0, "the headline's size and top margin are Godot's");
    }

    static void Clock(S.GDict hud)
    {
        double hurry = F(hud, "hurry_seconds");
        Check(HudText.Clock(59.01, 0, false) == "60" && HudText.Clock(59.0, 0, false) == "59", "the clock shows whole seconds left, rounded up");
        Check(HudText.Clock(0.0, 0, false) == "0" && HudText.Clock(-3.0, 0, false) == "0", "the clock stops at 0");
        Check(HudText.Clock(5.0, 0.0, true) == "0:00" && HudText.Clock(5.0, 59.9, true) == "0:59" && HudText.Clock(5.0, 125.4, true) == "2:05", "Endless shows minutes and seconds survived");
        Check(hurry == 10.0, "the hurry starts at tuning's 10 s");
        Check(!HudText.Hurry(hurry, false, hurry) && HudText.Hurry(hurry - 0.01, false, hurry), "the clock hurries under 10 s, not at it");
        Check(!HudText.Hurry(1.0, true, hurry), "Endless never hurries");
        Check(HudText.HurryPulse(true, 9, 10, false), "a new second of the hurry thumps");
        Check(!HudText.HurryPulse(true, 9, 9, false) && !HudText.HurryPulse(true, 9, -1, false) && !HudText.HurryPulse(true, 9, 10, true) && !HudText.HurryPulse(false, 9, 10, false), "no thump inside a second, on the first frame, after the end or out of the hurry");
        Check(S.Num.I(hud["clock_size"]) == 44 && F(hud, "hurry_pulse_scale") == 1.15 && F(hud, "hurry_pulse_s") == 0.3, "the clock's size and thump are tuning's");
        Near(HudText.Linear(1.15, 1.0, 0.15, 0.3), 1.075, 1e-9, "the thump eases off in a line");
    }

    static void Biomass(S.GDict hud)
    {
        double rate = F(hud, "biomass_roll_rate");
        Check(HudText.Biomass(0.0) == "0" && HudText.Biomass(12.99) == "12" && HudText.Biomass(1234.0) == "1234", "the figure is whole biomass, rounded down");
        Near(HudText.Roll(0.0, 100.0, rate, 0.1), 100.0 * (1.0 - Math.Exp(-rate * 0.1)), 1e-9, "the figure rolls toward the total at tuning's rate");
        Check(HudText.Roll(99.6, 100.0, rate, 0.016) == 100.0, "the figure snaps when within half a point");
        double shown = 0.0;
        for (int i = 0; i < 120; i++) shown = HudText.Roll(shown, 50.0, rate, 1.0 / 60.0);
        Check(shown == 50.0, "the figure reaches the total");
        double pop = F(hud, "biomass_pop_gain");
        Check(HudText.Pops(pop, pop) && !HudText.Pops(pop - 0.01, pop), "a gain of tuning's 3 or more pops the figure");
        Near(HudText.BackOut(1.3, 1.0, 0.0, 0.25), 1.3, 1e-9, "the pop starts at its scale");
        Near(HudText.BackOut(1.3, 1.0, 0.25, 0.25), 1.0, 1e-9, "the pop ends at rest");
        Check(HudText.BackOut(1.3, 1.0, 0.2, 0.25) < 1.0, "the pop overshoots before it rests, as Godot's back ease does");
    }

    static void Rings(S.GDict hud, string repoRoot)
    {
        Check(HudText.Ratio(0.0, 4.0, 0.5) == 1.0 && HudText.Ratio(4.0, 4.0, 0.5) == 0.0, "a ring is full when ready and empty when just used");
        Near(HudText.Ratio(1.0, 4.0, 0.5), 0.75, 1e-9, "a ring fills with the cooldown");
        Near(HudText.Ratio(0.25, 0.1, 0.5), 0.5, 1e-9, "a tiny cooldown is floored");
        Check(HudText.Ratio(9.0, 4.0, 0.5) == 0.0, "a ring never goes under empty");
        Check(HudText.BreathIn("lash", 2.0, 5.0) == 2.0 && HudText.BreathIn("cone", 2.0, 5.0) == 5.0, "the breath ring follows the breath's own cooldown on a lash body");
        double radius = F(hud, "ring_radius"), width = F(hud, "ring_width");
        Near(HudText.RingSide(radius, width), 2.0 * (19.25 + 1.5 + 1.0 + 1.0), 1e-9, "a ring's box holds its outline");
        Near(HudText.IconHalf(radius, width), (19.25 - 1.5) * 0.9, 1e-9, "the icon fills 0.9 of the ring's inside");
        Check(F(hud, "ring_gap") == 14.0 && F(hud, "ring_ready_scale") == 1.3 && F(hud, "ring_ready_s") == 0.45, "the rings' gap and ready pop are tuning's");
        S.GDict icons = hud["icons"];
        foreach (string id in new[] { "breath", "dash", "ultimate" })
        {
            string path = ((string)icons[id]).Replace("res://", "");
            Check(File.Exists(Path.Combine(repoRoot, path)), $"the {id} ring's icon is in the repo");
        }
        KeyBinds.Clear();
        Check(HudText.Prompt("breath", false) == "Q" && HudText.Prompt("breath", true) == "X", "the breath's prompt is Q on keys and X on a pad");
        Check(HudText.Prompt("dash", true) == "B" && HudText.Prompt("ultimate", false) == "E" && HudText.Prompt("ultimate", true) == "Y", "the leap and ultimate prompts are the bindings'");
    }

    static void Threat(S.GDict bar)
    {
        long n = S.Num.I(bar["segments"]), alert = S.Num.I(bar["alert_from"]);
        Check(n == 5 && alert == 4, "the threat bar has tuning's 5 segments, red from 4");
        Check(HudText.ThreatFilled(1, n) == 0 && HudText.ThreatFilled(4, n) == 3 && HudText.ThreatFilled(5, n) == 5, "levels below the top fill one less; the top fills all");
        Check(HudText.ThreatPartial(2, n, 0.4) == 0.4 && HudText.ThreatPartial(5, n, 0.4) == 0.0, "the top level has no part segment");
        Check(!HudText.ThreatAlert(3, alert) && HudText.ThreatAlert(4, alert), "the bar turns red at level 4");
        Near(HudText.ThreatSegment(220.0, F(bar, "gap"), n), (220.0 - 12.0) / 5.0, 1e-9, "the segments share the bar's width less the gaps");
    }

    static void Layout(S.GDict ui)
    {
        S.GDict hud = ui["hud"];
        S.GArray<S.Variant> safe = ui["safe_margin"];
        double bottom = F(hud, "bottom_margin"), safeY = S.Num.F(safe[1]);
        Check(S.Num.F(safe[0]) == 96.0 && safeY == 54.0, "the safe margin is tuning's 96 by 54");
        Check(HudText.Lift(bottom, safeY) == 6.0, "the rings sit 6 px above the safe floor (60 from the screen's)");
        Check(HudText.Lift(bottom, safeY, 2.4) == 4.0, "the figure's lift drops by the gap under its glyphs");
        Check(HudText.Lift(10.0, safeY) == 0.0, "a lift is never negative");
        S.GArray<S.Variant> meter = hud["meter_size"];
        Check(S.Num.F(meter[0]) == 220.0 && S.Num.F(meter[1]) == 6.0 && F(hud, "meter_gap") == 2.0, "the threat bar is 220 by 6, 2 under the clock");
        Check(S.Num.I(hud["biomass_size"]) == 28, "the biomass figure's size is tuning's");
    }

    static void Vignette(S.GDict hurt)
    {
        double widthMax = F(hurt, "width_max"), alphaMax = F(hurt, "alpha_max"), ease = F(hurt, "ease_rate");
        double below = F(hurt, "heartbeat_below"), hz = F(hurt, "heartbeat_hz"), depth = F(hurt, "heartbeat_depth");
        double flashS = F(hurt, "flash_s"), flashAlpha = F(hurt, "flash_alpha");
        Check(HudText.Hurt(100, 100) == 0.0 && HudText.Hurt(25, 100) == 0.75 && HudText.Hurt(-5, 100) == 1.0 && HudText.Hurt(5, 0) == 0.0, "hurt is the health lost, 0 to 1");
        Check(!HudText.Beating(30, 100, below) && HudText.Beating(29.9, 100, below) && !HudText.Beating(0, 0, below), "the heartbeat starts under tuning's 0.3 of health");
        HudHurt full = new HudHurt();
        for (int i = 0; i < 60; i++) full.Step(100, 100, 1.0 / 60.0, widthMax, alphaMax, ease, below, hz, depth, flashS, flashAlpha);
        Check(full.Width == 0.0 && full.Strength == 0.0, "full health shows no red");
        HudHurt hit = new HudHurt();
        hit.Step(100, 100, 1.0 / 60.0, widthMax, alphaMax, ease, below, hz, depth, flashS, flashAlpha);
        hit.Step(90, 100, 1.0 / 60.0, widthMax, alphaMax, ease, below, hz, depth, flashS, flashAlpha);
        Check(hit.Width >= widthMax * 0.5 - 1e-9 && hit.Strength > flashAlpha * 0.9, "a hit flashes the edge at half reach");
        for (int i = 0; i < 600; i++) hit.Step(90, 100, 1.0 / 60.0, widthMax, alphaMax, ease, below, hz, depth, flashS, flashAlpha);
        Near(hit.Width, widthMax * 0.1, 1e-6, "the red's reach settles at the health lost");
        Near(hit.Strength, alphaMax * Math.Sqrt(0.1), 1e-6, "the red's strength settles at the root of the health lost");
        HudHurt low = new HudHurt();
        double least = 1.0, most = 0.0;
        for (int i = 0; i < 900; i++)
        {
            low.Step(10, 100, 1.0 / 60.0, widthMax, alphaMax, ease, below, hz, depth, flashS, flashAlpha);
            if (i < 600) continue;
            least = Math.Min(least, low.Strength);
            most = Math.Max(most, low.Strength);
        }
        Near(most, alphaMax * Math.Sqrt(0.9), 2e-3, "a low kaiju's red peaks on the thump");
        Near(least, alphaMax * Math.Sqrt(0.9) * (1.0 - depth), 2e-3, "and dips by tuning's depth between thumps");
        Check(HudText.VignetteAlpha(0.5, 0.5, 0.55, 1.0) == 0.0, "the screen's middle is clear");
        Near(HudText.VignetteAlpha(0.0, 0.0, 0.55, 0.28), 0.28, 1e-4, "the corner takes the full strength");
        Check(HudText.VignetteAlpha(0.0, 0.5, 0.55, 1.0) > HudText.VignetteAlpha(0.2, 0.5, 0.55, 1.0), "the red fades in from the edge");
        Check(HudText.VignetteAlpha(0.0, 0.5, 0.0, 1.0) == 0.0, "no reach, no red");
    }

    static void News(S.GDict tuning, S.GDict cfg)
    {
        S.GDict news = tuning["news"];
        S.GDict live = news["live"];
        Check(HudText.NewsLine(new S.GDict { { "type", "landmark_felled" }, { "landmark", "wheel" } }, live) == "BIG WHEEL GOES FOR A ROLL", "a felled wheel has its own headline");
        Check(HudText.NewsLine(new S.GDict { { "type", "landmark_felled" }, { "landmark", "nothing" } }, live) == "ANOTHER LANDMARK OFF THE MAP", "an unnamed landmark has the fallback");
        Check(HudText.NewsLine(new S.GDict { { "type", "towers_toppled" }, { "count", 5.0 } }, live) == "5 TOWERS DOWN AND COUNTING", "the towers headline carries the count");
        Check(HudText.NewsLine(new S.GDict { { "type", "vip_spawned" } }, live) == "VIP SPOTTED FLEEING BY CHOPPER", "a VIP sighting is news");
        Check(HudText.NewsLine(new S.GDict { { "type", "vip_killed" } }, live) == "VIP FLIGHT CANCELLED - PERMANENTLY" && HudText.NewsLine(new S.GDict { { "type", "vip_escaped" } }, live) == "VIP ESCAPES - DENIES BEING HERE", "a VIP's end is news");
        Check(HudText.NewsLine(new S.GDict { { "type", "ability" } }, live) == "", "other events are not news");
        Tr.Language = "es";
        Check(HudText.NewsLine(new S.GDict { { "type", "towers_toppled" }, { "count", 7L } }, live) == "7 TORRES CAÍDAS Y SUMANDO", "the news is in the player's language");
        Tr.Language = "en";

        double slide = F(cfg, "slide_s"), read = F(cfg, "read_s"), min = F(cfg, "min_s");
        int max = (int)S.Num.I(cfg["queue"]);
        Check(slide == 0.25 && read == 0.5 && min == 3.0 && max == 3, "the strip's timings are tuning's");
        Near(HudText.NewsSeconds(120.0, 120.0, read, min), 3.0, 1e-9, "a short crawl stays the minimum");
        Near(HudText.NewsSeconds(1200.0, 120.0, read, min), 10.5, 1e-9, "a long crawl stays its width over the speed, plus the read time");

        HudNewsQueue q = new HudNewsQueue(max, slide);
        Check(!q.Visible && q.Tick(0.1) == HudNewsQueue.Step.None, "an empty strip is hidden");
        q.Add("");
        Check(q.Waiting == 0, "an empty line is not queued");
        foreach (string line in new[] { "A", "B", "C", "D" }) q.Add(line);
        Check(q.Waiting == 3, "the queue keeps tuning's 3, dropping the oldest");
        Check(q.Tick(0.1) == HudNewsQueue.Step.SlideIn && q.Current == "B" && q.Visible, "the oldest kept line slides in");
        q.Stay(3.0);
        Check(q.Tick(2.9) == HudNewsQueue.Step.None && q.Current == "B", "the crawl stays its time");
        Check(q.Tick(0.2) == HudNewsQueue.Step.SlideOut && q.Current == null && q.Visible, "then slides out, still on show");
        Check(q.Tick(0.1) == HudNewsQueue.Step.None && q.Visible, "the slide out takes tuning's 0.25 s");
        Check(q.Tick(0.2) == HudNewsQueue.Step.Gone && !q.Visible, "and the strip hides");
        Check(q.Tick(0.1) == HudNewsQueue.Step.SlideIn && q.Current == "C", "the next line follows");
        q.Stay(3.0);
        q.Muted = true;
        Check(!q.Visible && q.Tick(10.0) == HudNewsQueue.Step.None && q.Current == "C", "a muted strip is hidden and still");
        Check(q.Shown.Count == 2 && q.Shown[0] == "B" && q.Shown[1] == "C", "every headline shown is recorded");
    }

    static void Card(S.GDict card)
    {
        KeyBinds.Clear();
        List<string[]> first = HudText.ControlRows(true);
        Check(first.Count == 3 && first[0][0] == "Move" && first[1][0] == "Signature attack" && first[2][0] == "Leap", "the first-run card has Move, Signature attack and Leap");
        Check(first[0][1] == "WASD / arrows" && first[0][2] == "Left stick" && first[1][1] == "Space" && first[1][2] == "A" && first[2][1] == "Shift" && first[2][2] == "B", "with Godot's keys and buttons");
        List<string[]> all = HudText.ControlRows(false);
        int want = 0;
        foreach (string[] entry in PlayerSettings.CONTROLS) if (entry.Length <= 3 || S.Demo.Allows(entry[3])) want++;
        Check(all.Count == want && all.Count >= 8, "the full card has every row this build's species use");
        bool breath = false;
        foreach (string[] row in all) if (row[0] == "Breath (croc)") breath = true;
        Check(breath == S.Demo.Allows("reptilian"), "the breath's row shows only with the croc in the build");
        Check(KeyBinds.Bind("dash", KeyBinds.KEYS, "F"), "the leap can be rebound");
        Check(HudText.ControlRows(true)[2][1] == "F", "the card shows the player's binding");
        KeyBinds.Clear();
        Check(F(card, "seconds") == 9.0 && F(card, "fade_s") == 0.6 && F(card, "first_run_width") == 620.0 && F(card, "first_run_lift") == 90.0, "the card's time, fade, width and lift are tuning's");
        Check(HudText.CARD_MIN_SHOWN == 0.6, "the card ignores presses for 0.6 s");
    }

    static void Rumble(S.GDict cfg)
    {
        S.GDict small = HudText.StagedRumble(cfg, "footfall", 1), big = HudText.StagedRumble(cfg, "footfall", 3);
        Check(F(small, "weak") == 0.05 && F(small, "strong") == 0.0 && F(small, "seconds") == 0.08, "the young croc's footfall is the first row");
        Check(F(big, "weak") == 0.15 && F(big, "strong") == 0.3 && F(big, "seconds") == 0.12, "the Colossus's footfall is the third");
        Check(F(HudText.StagedRumble(cfg, "stomp", 9), "strong") == 0.75 && F(HudText.StagedRumble(cfg, "stomp", 0), "strong") == 0.2, "a size tier off the list takes the nearest row");
        S.GDict topple = HudText.EventRumble(cfg, new S.GDict { { "type", "fall_land" }, { "kind", "topple" } });
        Check(topple != null && F(topple, "strong") == 0.6 && F(topple, "seconds") == 0.5, "a toppled tower landing rumbles the collapse");
        Check(HudText.EventRumble(cfg, new S.GDict { { "type", "fall_land" }, { "kind", "crumble" } }) == null, "other landings do not");
        S.GDict cone = HudText.EventRumble(cfg, new S.GDict { { "type", "ability" }, { "kind", "cone" } });
        Check(cone != null && F(cone, "weak") == 0.35 && F(cone, "seconds") == 0.9, "the breath rumbles");
        Check(HudText.EventRumble(cfg, new S.GDict { { "type", "ability" }, { "kind", "leap" } }) == null, "a leap's ability event does not");
        S.GDict beam = HudText.EventRumble(cfg, new S.GDict { { "type", "beam_start" }, { "seconds", 2.5 } });
        Check(beam != null && F(beam, "seconds") == 2.5 && F(beam, "weak") == 0.35, "the beam rumbles for as long as it burns");
        Check(F(HudText.EventRumble(cfg, new S.GDict { { "type", "beam_start" } }), "seconds") == 0.9, "or the breath's time when the event has none");
        Check(HudText.EventRumble(cfg, new S.GDict { { "type", "kaiju_emerged" } }) == null, "other events do not rumble");
    }

    static void Aim()
    {
        Check(HudText.AimShowing("lash", 0.0, 3.0, false, false), "a lash body aims its breath when the breath is ready");
        Check(!HudText.AimShowing("lash", 0.5, 0.0, false, false), "not while the breath cools");
        Check(HudText.AimShowing("cone", 9.0, 0.0, false, false) && !HudText.AimShowing("cone", 0.0, 0.1, false, false), "a cone body aims by its signature's cooldown");
        Check(!HudText.AimShowing("ring", 0.0, 0.0, false, false), "a body with no breath has no marker");
        Check(!HudText.AimShowing("lash", 0.0, 0.0, true, false) && !HudText.AimShowing("lash", 0.0, 0.0, false, true), "no marker after the end or during the rise");
        Near(HudText.AimAlpha(0.0, 1.0), 0.95, 1e-9, "the marker's alpha rests at 0.95");
        Near(HudText.AimAlpha(0.25 / 1.2, 1.0), 1.0, 1e-9, "and pulses by 0.05");
        Check(HudText.AimAlpha(1.0, 0.0) == 0.0, "a marker not yet faded in is clear");
        List<double[]> tris = HudText.Wedge(10.0, 0.5);
        Check(tris.Count == 24 * 3 + (24 + 3) * 6, "the wedge is 24 fill triangles and 27 strips");
        double far = 0.0, widest = 0.0;
        bool fills = true;
        foreach (double[] p in tris)
        {
            far = Math.Max(far, Math.Sqrt(p[0] * p[0] + p[1] * p[1]));
            widest = Math.Max(widest, Math.Abs(Math.Atan2(p[0], p[1])));
            if (p[2] == 0.0 && Math.Sqrt(p[0] * p[0] + p[1] * p[1]) > 10.0 + 1e-9) fills = false;
        }
        Check(fills, "the fill ends at the reach");
        Near(far, 10.0 + 10.0 * 0.04 * 0.5, 1e-3, "the edge line is 0.04 of the reach wide, half of it past the reach");
        Check(tris[1][0] < 0.0 && Math.Abs(Math.Atan2(tris[1][0], tris[1][1]) + 0.5) < 1e-9, "the arc starts at minus the half angle");
        double[] tip = tris[tris.Count - 2];
        Near(tip[1], 10.0, 1e-9, "the middle line runs to the reach along the facing");
        Near(Math.Abs(tip[0]), 10.0 * 0.04 * 0.6 * 0.5, 1e-9, "and is 0.6 of the edge's width");
    }

    static void Latch(S.GDict tuning)
    {
        S.GDict emerge = tuning["emerge"];
        double window = F(emerge, "input_latch_seconds");
        Check(window == 0.2, "the latch window is tuning's 0.2 s");
        HudLatch latch = new HudLatch(window);
        Dictionary<string, bool> none = new Dictionary<string, bool> { { "signature", false }, { "ultimate", false }, { "breath", false }, { "dash", false } };
        Dictionary<string, bool> sig = new Dictionary<string, bool>(none) { ["signature"] = true };
        Check(latch.Through(true, sig, 1.0 / 60.0)["signature"], "a press during the rise passes through unchanged");
        latch.Through(true, none, 0.1);
        Dictionary<string, bool> o = latch.Through(false, none, 1.0 / 60.0);
        Check(o["signature"] && !o["dash"], "a press 0.1 s before the rise ended fires on the first free frame");
        Check(!latch.Through(false, none, 1.0 / 60.0)["signature"], "and only once");
        latch.Through(true, new Dictionary<string, bool>(none) { ["dash"] = true }, 1.0 / 60.0);
        latch.Through(true, none, 0.3);
        Check(!latch.Through(false, none, 1.0 / 60.0)["dash"], "a press older than the window is dropped");
        latch.Through(true, sig, 1.0 / 60.0);
        latch.Through(true, none, 0.2);
        Check(latch.Through(false, none, 1.0 / 60.0)["signature"], "a press exactly the window old still fires");

        HudHeld held = new HudHeld();
        Check(held.Read(true, true, false) && !held.Read(false, false, false), "held is the button while hold-to-toggle is off");
        Check(held.Read(true, true, true) && held.Read(false, false, true), "with the toggle on, a press latches it");
        Check(!held.Read(true, true, true) && !held.Read(true, false, true), "and the next press lets go");
        held.Read(true, true, true);
        Check(!held.Read(false, false, false), "turning the toggle off lets go");
    }
}
