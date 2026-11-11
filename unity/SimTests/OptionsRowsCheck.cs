// The settings screens' logic (GameLogic/OptionsRows.cs) against scenes/settings_menu.gd, access_menu.gd and
// controls_menu.gd: every row's value text, each stepper moving its text, the language re-labelling them, the
// controls page's rows, and a waiting binding taking, passing over or cancelling a press.
using System;
using System.Collections.Generic;
using System.IO;
using Kaiju.Game;
using S = Kaiju.Sim;
using Opt = Kaiju.Game.PlayerSettings;

public static class OptionsRowsCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL options rows: " + what);
    }

    static void Same(string got, string want, string what)
    {
        Check(got == want, what + ": got \"" + got + "\", want \"" + want + "\"");
    }

    public static int Run(string repoRoot)
    {
        checks = failed = 0;
        string oldRoot = UserDir.Root, oldLanguage = Tr.Language;
        string temp = Path.Combine(Path.GetTempPath(), "kaiju_options_rows_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);
        try
        {
            S.FileAccess.Root = repoRoot;
            UserDir.Root = temp;
            Tr.Load(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
            Opt.ResetDefaults();
            KeyBinds.Clear();
            Tr.Language = "en";

            // Sliders: a share is a whole percent in steps of ten, and back.
            Check(OptionsRows.Percent(0.8) == 80, "0.8 is 80");
            Check(OptionsRows.Percent(0.3) == 30, "0.3 is 30 (not 29)");
            Check(OptionsRows.Percent(1.15) == 115, "1.15 is 115");
            Check(Math.Abs(OptionsRows.Share(70) - 0.7) < 1e-9, "70 is 0.7");
            Same(OptionsRows.PercentText(80), "80%", "percent text");
            for (int p = 0; p <= OptionsRows.PERCENT_MAX; p += OptionsRows.VOLUME_STEP)
            {
                Opt.SetVolume(OptionsRows.Share(p));
                Check(OptionsRows.Percent(Opt.Volume) == p, "volume " + p + " round trip");
            }

            // Stepping buttons read "< value >".
            Opt.SetFullscreen(false);
            Same(OptionsRows.Fullscreen(), "< OFF >", "fullscreen off");
            Opt.SetFullscreen(true);
            Same(OptionsRows.Fullscreen(), "< ON >", "fullscreen on");
            Opt.SetFullscreen(false);
            Same(OptionsRows.UiScale(), "< 100% >", "ui scale");
            Opt.NextUiScale();
            Same(OptionsRows.UiScale(), "< 115% >", "ui scale stepped");
            Opt.NextUiScale();
            Same(OptionsRows.UiScale(), "< 125% >", "ui scale stepped twice");
            Opt.NextUiScale();
            Same(OptionsRows.UiScale(), "< 100% >", "ui scale wraps");
            Same(OptionsRows.FpsText(0), "UNLIMITED", "no cap");
            Same(OptionsRows.FpsText(120), "120 FPS", "cap");
            HashSet<string> caps = new HashSet<string>();
            for (int i = 0; i < Opt.Caps().Count; i++)
            {
                caps.Add(OptionsRows.Fps());
                Opt.NextFpsCap();
            }
            Check(caps.Count == Opt.Caps().Count, "every cap has its own text");
            Check(caps.Contains("< UNLIMITED >") && caps.Contains("< 60 FPS >"), "the caps read 60 FPS and UNLIMITED");
            List<string> levels = new List<string>();
            for (int i = 0; i < Opt.Levels().Count; i++)
            {
                levels.Add(OptionsRows.Graphics());
                Opt.NextGraphics();
            }
            foreach (string want in new[] { "POTATO", "LOW", "MEDIUM", "HIGH", "MAX" })
            {
                Check(levels.Contains("< " + want + " >"), "graphics steps through " + want);
            }
            Same(OptionsRows.Graphics(), levels[0], "graphics wraps round");
            Same(OptionsRows.PreviewText("high", 59.6), "HIGH · 60 FPS", "preview line");

            // Time of day and weather: the sim's label, in capitals; each press changes it or wraps.
            Same(OptionsRows.TimeOfDay(), "< " + S.TimeOfDay.Label(Opt.TimeOfDay).ToUpperInvariant() + " >", "time of day");
            Same(OptionsRows.Weather(), "< " + S.Weather.Label(Opt.Weather).ToUpperInvariant() + " >", "weather");
            string firstWeather = OptionsRows.Weather();
            Opt.NextWeather();
            Check(OptionsRows.Weather() != firstWeather, "weather steps");
            int guard = 0;
            while (OptionsRows.Weather() != firstWeather && guard++ < 20) Opt.NextWeather();
            Check(guard < 20, "weather wraps round");

            // Accessibility.
            Same(OptionsRows.Held(), "< HOLD >", "held moves default");
            Opt.ToggleHold();
            Same(OptionsRows.Held(), "< TOGGLE >", "held moves toggled");
            Opt.ToggleHold();
            Same(OptionsRows.OnOff(Opt.ReduceFlashing), "< OFF >", "reduce flashing default");
            Same(OptionsRows.OnOff(Opt.Rumble), "< ON >", "rumble default");
            Same(OptionsRows.Gore(), "< ON >", "gore default");
            Opt.ToggleGore();
            Same(OptionsRows.Gore(), "< REDUCED >", "gore reduced");
            Opt.ToggleGore();

            // The language cycle re-labels: every text the pages show is read again in the new language.
            string start = Tr.Language;
            Same(OptionsRows.Language(), "< " + Opt.LanguageName() + " >", "language name");
            HashSet<string> names = new HashSet<string>();
            int languages = Opt.LANGUAGES.Length;
            for (int i = 0; i < languages; i++)
            {
                names.Add(OptionsRows.Language());
                if (Tr.Language == "es")
                {
                    Same(OptionsRows.Fullscreen(), "< NO >", "Spanish OFF");
                    Same(Tr.T("SETTINGS"), "AJUSTES", "Spanish title");
                    Same(Tr.T("BACK"), "VOLVER", "Spanish BACK");
                    Same(KeyBinds.Shown("Left stick"), "Stick izquierdo", "Spanish left stick");
                    Check(OptionsRows.Cell("dash", KeyBinds.KEYS, "dash", KeyBinds.KEYS) == Tr.T("PRESS A KEY")
                        && Tr.T("PRESS A KEY") != "PRESS A KEY", "Spanish wait text");
                }
                if (Tr.Language == "fr") Same(OptionsRows.FpsText(60), "60 IPS", "French FPS");
                Opt.NextLanguage();
            }
            Check(names.Count == languages, "every language shows its own name, " + names.Count + " of " + languages);
            Same(Tr.Language, start, "the language cycle wraps round");
            Tr.Language = "en";

            // The controls page: the rebindable actions, then the fixed rows.
            List<OptionsRows.ControlRow> rows = OptionsRows.Controls();
            int actions = KeyBinds.Actions().Length;
            Check(rows.Count == actions + OptionsRows.FIXED.Length, "controls rows: " + rows.Count);
            for (int i = 0; i < actions; i++)
            {
                Check(rows[i].Action == KeyBinds.Actions()[i].Action, "row " + i + " is its action");
                Check(rows[i].PadButton || rows[i].Pad == "Left stick", "a move row shows the left stick");
            }
            for (int i = 0; i < OptionsRows.FIXED.Length; i++)
            {
                OptionsRows.ControlRow fixedRow = rows[actions + i];
                Check(fixedRow.Action == null && fixedRow.Name == OptionsRows.FIXED[i], "fixed row " + OptionsRows.FIXED[i]);
            }
            Same(rows[actions].Keys, "F11", "fullscreen key");
            Same(rows[actions + 2].Pad, "B", "back button");

            // A cell reads its binding, or the wait text while it is the one waiting.
            Same(OptionsRows.Cell("dash", KeyBinds.KEYS, null, null), KeyBinds.Text("dash", KeyBinds.KEYS), "cell shows the binding");
            Same(OptionsRows.Cell("dash", KeyBinds.KEYS, "dash", KeyBinds.KEYS), "PRESS A KEY", "keys cell waits");
            Same(OptionsRows.Cell("dash", KeyBinds.PAD, "dash", KeyBinds.PAD), "PRESS A BUTTON", "pad cell waits");
            Same(OptionsRows.Cell("dash", KeyBinds.PAD, "dash", KeyBinds.KEYS), KeyBinds.Text("dash", KeyBinds.PAD), "the other slot does not wait");
            Same(OptionsRows.Cell("breath", KeyBinds.KEYS, "dash", KeyBinds.KEYS), KeyBinds.Text("breath", KeyBinds.KEYS), "another action does not wait");

            // A press on a waiting binding.
            Check(OptionsRows.Take(KeyBinds.KEYS, "", false) == OptionsRows.Press.Ignore, "no press");
            Check(OptionsRows.Take(KeyBinds.KEYS, "Escape", false) == OptionsRows.Press.Cancel, "Esc cancels a key wait");
            Check(OptionsRows.Take(KeyBinds.PAD, "Escape", false) == OptionsRows.Press.Cancel, "Esc cancels a pad wait");
            Check(OptionsRows.Take(KeyBinds.KEYS, "F", false) == OptionsRows.Press.Bind, "a key fills the keys slot");
            Check(OptionsRows.Take(KeyBinds.KEYS, "Mouse1", false) == OptionsRows.Press.Bind, "a mouse button fills the keys slot");
            Check(OptionsRows.Take(KeyBinds.PAD, "F", false) == OptionsRows.Press.Ignore, "a key is passed over by a pad wait");
            Check(OptionsRows.Take(KeyBinds.KEYS, "B", true) == OptionsRows.Press.Ignore, "a pad button is passed over by a key wait");
            Check(OptionsRows.Take(KeyBinds.PAD, "B", true) == OptionsRows.Press.Bind, "a pad button fills the pad slot");

            // The page's whole path on the real table: bind steals, a reserved key is refused, RESET restores.
            string dashBefore = KeyBinds.Text("dash", KeyBinds.KEYS), breathBefore = KeyBinds.Text("breath", KeyBinds.KEYS);
            string breathKey = KeyBinds.Events("breath", KeyBinds.KEYS)[0];
            Check(KeyBinds.Bind("dash", KeyBinds.KEYS, breathKey), "dash takes the breath key");
            Same(OptionsRows.Cell("dash", KeyBinds.KEYS, null, null), breathBefore, "dash shows the stolen key");
            Check(!KeyBinds.Events("breath", KeyBinds.KEYS).Contains(breathKey), "breath lost the key");
            Check(!KeyBinds.Bind("dash", KeyBinds.KEYS, "F11"), "F11 is refused");
            Same(OptionsRows.Cell("dash", KeyBinds.KEYS, null, null), breathBefore, "a refused bind changes nothing");
            string padBefore = KeyBinds.Text("dash", KeyBinds.PAD);
            string otherPad = KeyBinds.Events("signature", KeyBinds.PAD)[0];
            Check(KeyBinds.Bind("dash", KeyBinds.PAD, otherPad), "dash takes the signature button");
            Same(KeyBinds.Text("signature", KeyBinds.PAD), "-", "signature shows no button");
            KeyBinds.Reset();
            Same(OptionsRows.Cell("dash", KeyBinds.KEYS, null, null), dashBefore, "RESET restores dash");
            Same(OptionsRows.Cell("breath", KeyBinds.KEYS, null, null), breathBefore, "RESET restores breath");
            Same(OptionsRows.Cell("dash", KeyBinds.PAD, null, null), padBefore, "RESET restores the pad");

            // Every change was saved: a fresh read gives the same screen.
            Opt.SetVolume(0.4);
            Opt.NextGraphics();
            string graphics = OptionsRows.Graphics();
            Opt.ResetDefaults();
            Opt.LoadSaved(false);
            Check(OptionsRows.Percent(Opt.Volume) == 40, "volume read back");
            Same(OptionsRows.Graphics(), graphics, "graphics read back");
        }
        catch (Exception e)
        {
            failed++;
            Console.WriteLine("  FAIL options rows: threw " + e);
        }
        finally
        {
            Opt.ResetDefaults();
            KeyBinds.Clear();
            Tr.Language = oldLanguage;
            UserDir.Root = oldRoot;
            try { Directory.Delete(temp, true); } catch (IOException) { }
        }
        Console.WriteLine("options rows: " + checks + " checks, " + failed + " failed");
        return failed;
    }
}
