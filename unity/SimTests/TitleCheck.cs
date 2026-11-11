// The title's rules (GameLogic/TitleMenu.cs, after scenes/title_screen.gd, slot_list.gd and title_colossus.gd)
// are plain C#, so they are held here: the numbers and texts are Godot's, a plate says what Godot's says, the
// right plates are off, the questions name the kaiju, the focus starts where Godot's does, the news is tuning's,
// a row is shared 3 to 1, and the title art lands where the title camera puts it.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;
using Kaiju.Game;
using S = Kaiju.Sim;

static class TitleCheck
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
        try
        {
            Numbers(repoRoot);
            Plates();
            Questions();
            Focus();
            News();
            Rows();
            Art(repoRoot);
            Tr.Language = "es";
            Check(TitleMenu.PlateText(Slot(2, false)) == "RANURA 2\nEMPTY", "a plate's head is in the player's language");
            Check(TitleMenu.Who(Unreadable(1)) == "partida ilegible", "an unreadable save is named in the player's language");
        }
        finally
        {
            Tr.Language = oldLanguage;
        }
        Console.WriteLine($"title: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("title: FAILED " + what);
    }

    static void Near(double got, double want, double within, string what)
    {
        Check(Math.Abs(got - want) <= within, $"{what}: got {got.ToString("0.####", CultureInfo.InvariantCulture)}, want {want.ToString("0.####", CultureInfo.InvariantCulture)}");
    }

    static SlotInfo Slot(int n, bool taken, bool continues = true, string species = "Reptilian", long runs = 3)
    {
        SlotInfo info = new SlotInfo { Slot = n, Taken = taken, Readable = taken };
        if (!taken) return info;
        info.Continues = continues;
        info.Specimen = "SPECIMEN K-0" + n;
        info.Species = species;
        info.Summary = continues ? species + ", " + runs + " rampages, 120 biomass" : "";
        return info;
    }

    static SlotInfo Unreadable(int n)
    {
        return new SlotInfo { Slot = n, Taken = true, Readable = false };
    }

    // A const's value as the Godot script writes it.
    static string Gd(string script, string name)
    {
        Match m = Regex.Match(script, @"^const " + name + @" := ""?([^""\r\n]*)""?", RegexOptions.Multiline);
        return m.Success ? m.Groups[1].Value.Trim() : "(missing)";
    }

    static void Number(string script, string name, double mine)
    {
        string text = Gd(script, name);
        bool read = double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out double godot);
        Check(read && godot == mine, $"{name} is Godot's {text}, mine {mine.ToString(CultureInfo.InvariantCulture)}");
    }

    static void Numbers(string repoRoot)
    {
        string title = File.ReadAllText(Path.Combine(repoRoot, "scenes", "title_screen.gd"));
        string list = File.ReadAllText(Path.Combine(repoRoot, "scenes", "slot_list.gd"));
        Number(title, "ROW_GAP", TitleMenu.ROW_GAP);
        Number(title, "BUTTON_HEIGHT", TitleMenu.BUTTON_HEIGHT);
        Number(title, "ROW_INSET", TitleMenu.ROW_INSET);
        Number(title, "CONTINUE_SHARE", TitleMenu.CONTINUE_SHARE);
        Number(title, "GEAR_SIZE", TitleMenu.GEAR_SIZE);
        Number(title, "GEAR_CORNER", TitleMenu.GEAR_CORNER);
        Number(title, "EXIT_LIFT", TitleMenu.EXIT_LIFT);
        Number(title, "ALONE_SHARE", (double)(decimal)TitleMenu.ALONE_SHARE);
        Number(title, "ALONE_HEIGHT", TitleMenu.ALONE_HEIGHT);
        Number(title, "LOGO_SIZE", TitleMenu.LOGO_SIZE);
        Number(title, "LOGO_GAP", TitleMenu.LOGO_GAP);
        Number(title, "COLUMN_WIDTH", TitleMenu.COLUMN_WIDTH);
        Number(title, "COLUMN_TOP", (double)(decimal)TitleMenu.COLUMN_TOP);
        Number(title, "GLOW_TEXELS", TitleMenu.GLOW_TEXELS);
        Check(Gd(title, "EXIT_TEXT") == TitleMenu.EXIT_TEXT, "EXIT_TEXT is Godot's");
        Check(title.Contains("UiKit.label(\"" + TitleMenu.LOGO + "\", LOGO_SIZE, UiKit.ACCENT)"), "the logo is Godot's");
        Check(title.Contains("* " + TitleMenu.GLOW_ASPECT.ToString(CultureInfo.InvariantCulture)), "the glow's aspect is Godot's");
        Check(title.Contains("icon.offset_left = 8.0") && title.Contains("icon.offset_top = 6.0")
            && title.Contains("icon.offset_right = -12.0") && title.Contains("icon.offset_bottom = -14.0"), "the gear's insets are Godot's");
        Check(TitleMenu.GEAR_LEFT == 8f && TitleMenu.GEAR_TOP == 6f && TitleMenu.GEAR_RIGHT == 12f && TitleMenu.GEAR_BOTTOM == 14f, "the gear's insets");
        Number(list, "ROW_HEIGHT", TitleMenu.ROW_HEIGHT);
        Number(list, "BACK_HEIGHT", TitleMenu.BACK_HEIGHT);
        Number(list, "ROW_GAP", TitleMenu.ROW_GAP);
        Number(list, "SLOT_SHARE", TitleMenu.SLOT_SHARE);
        Number(list, "NOTE_SIZE", TitleMenu.NOTE_SIZE);
        Check(Gd(list, "PICK_CONTINUE") == TitleMenu.PICK_CONTINUE, "PICK_CONTINUE is Godot's");
        Check(Gd(list, "PICK_NEW") == TitleMenu.PICK_NEW, "PICK_NEW is Godot's");
        Check(Gd(list, "EMPTY") == TitleMenu.EMPTY, "EMPTY is Godot's");
        Check(Gd(list, "LOCKED") == TitleMenu.LOCKED, "LOCKED is Godot's");
        Check(Gd(list, "UNREADABLE") == TitleMenu.UNREADABLE, "UNREADABLE is Godot's");
    }

    static void Plates()
    {
        Check(TitleMenu.PlateText(Slot(2, false)) == "SLOT 2\nEMPTY", "an empty slot's plate");
        Check(TitleMenu.PlateText(Unreadable(3)) == "SLOT 3\nUNREADABLE", "an unreadable slot's plate");
        Check(TitleMenu.PlateText(Slot(1, true)) == "SLOT 1 - SPECIMEN K-01\nREPTILIAN, 3 RAMPAGES, 120 BIOMASS", "a save's plate: " + TitleMenu.PlateText(Slot(1, true)));
        Check(TitleMenu.PlateText(Slot(1, true, false)) == "SLOT 1 - SPECIMEN K-01\nNOT IN THIS VERSION", "a save this build cannot continue");

        Check(!TitleMenu.PlateOff(SlotMode.Continue, Slot(1, true)), "Continue: a save can be picked");
        Check(TitleMenu.PlateOff(SlotMode.Continue, Slot(1, false)), "Continue: an empty slot is off");
        Check(TitleMenu.PlateOff(SlotMode.Continue, Slot(1, true, false)), "Continue: a locked save is off");
        Check(TitleMenu.PlateOff(SlotMode.Continue, Unreadable(1)), "Continue: an unreadable save is off");
        Check(!TitleMenu.PlateOff(SlotMode.New, Slot(1, false)) && !TitleMenu.PlateOff(SlotMode.New, Slot(1, true))
            && !TitleMenu.PlateOff(SlotMode.New, Unreadable(1)), "New: every plate can be picked");

        Check(!TitleMenu.NeedsConfirm(SlotMode.Continue, Slot(1, true)), "Continue never asks");
        Check(!TitleMenu.NeedsConfirm(SlotMode.New, Slot(1, false)), "a new kaiju in an empty slot never asks");
        Check(TitleMenu.NeedsConfirm(SlotMode.New, Slot(1, true)), "a new kaiju over a save asks");
        Check(TitleMenu.NeedsConfirm(SlotMode.New, Unreadable(1)), "a new kaiju over an unreadable save asks");

        Check(TitleMenu.AllEmpty(new[] { Slot(1, false), Slot(2, false), Slot(3, false) }), "three empty slots are all empty");
        Check(!TitleMenu.AllEmpty(new[] { Slot(1, false), Unreadable(2), Slot(3, false) }), "an unreadable save is not empty");
        Check(TitleMenu.PickNote(SlotMode.Continue) == "Pick a kaiju to wake." && TitleMenu.PickNote(SlotMode.New) == "Pick a slot for the new kaiju.", "the notes");
    }

    static void Questions()
    {
        Check(TitleMenu.Who(Slot(2, true)) == "Reptilian (SPECIMEN K-02)", "who: species and specimen");
        Check(TitleMenu.Who(Slot(2, true, true, "")) == "SPECIMEN K-02", "who: no species, the specimen alone");
        Check(TitleMenu.Who(Unreadable(2)) == "unreadable save", "who: an unreadable save");
        Check(TitleMenu.StartOverQuestion(Slot(2, true)) == "Start over in slot 2? Your Reptilian (SPECIMEN K-02) and every evolution are lost.", "the start-over question");
        Check(TitleMenu.DeleteQuestion(Unreadable(3)) == "Delete slot 3? Your unreadable save and every evolution are lost.", "the delete question");
        Check(TitleMenu.ContinueLabel("Reptilian, 3 rampages, 120 biomass") == "CONTINUE GAME\nREPTILIAN, 3 RAMPAGES, 120 BIOMASS", "the Continue plate");
    }

    static void Focus()
    {
        SlotInfo[] mixed = { Slot(1, true), Slot(2, false), Slot(3, true) };
        Check(TitleMenu.FocusSlot(SlotMode.Continue, mixed, 3) == 3, "Continue: the newest slot takes the focus");
        Check(TitleMenu.FocusSlot(SlotMode.Continue, mixed, 2) == 1, "Continue: an off slot cannot, so the first that can");
        Check(TitleMenu.FocusSlot(SlotMode.Continue, mixed, 0) == 1, "Continue: no slot named, the first that can");
        Check(TitleMenu.FocusSlot(SlotMode.New, mixed, 2) == 2, "New: an empty slot can take it");
        Check(TitleMenu.FocusSlot(SlotMode.New, mixed, 0) == 1, "New: no slot named, the first");
        SlotInfo[] none = { Slot(1, false), Unreadable(2), Slot(3, true, false) };
        Check(TitleMenu.FocusSlot(SlotMode.Continue, none, 2) == 0, "Continue: nothing to pick, BACK takes it");
        Check(TitleMenu.SummaryOf(mixed, 3) == mixed[2].Summary && TitleMenu.SummaryOf(mixed, 0) == "" && TitleMenu.SummaryOf(mixed, 2) == "", "the summary is the newest slot's");
    }

    static void News()
    {
        S.GDict news = S.Content.Section("news");
        S.GArray<S.Variant> title = news["title"];
        SlotInfo[] slots = { Slot(1, true), Slot(2, false), Slot(3, false) };
        List<string> quiet = TitleMenu.NewsLines(slots, 0, "");
        Check(quiet.Count == title.Size() && quiet.Count == 4, $"no save: tuning's {title.Size()} headlines, got {quiet.Count}");
        Check(quiet[0] == "MONSTER SIGHTED OFFSHORE", "the first headline is tuning's");
        List<string> loud = TitleMenu.NewsLines(slots, 1, slots[0].Summary);
        Check(loud.Count == 5 && loud[0] == "REPTILIAN STILL AT LARGE", "a save: the kaiju is at large, first: " + loud[0]);
        Check(loud[1] == quiet[0], "the headlines follow it");
        slots[0].Species = "";
        Check(TitleMenu.LatestSpecies(slots, 1, "Avian, 1 rampage, 0 biomass") == "Avian", "no species on the slot: the summary's first word");
        Check(TitleMenu.LatestSpecies(slots, 1, "nothing") == "nothing", "a summary without a comma is taken whole");
    }

    static void Rows()
    {
        float[] free = TitleMenu.Shares(800f, 12f, new[] { 3f, 1f }, new[] { 0f, 0f });
        Near(free[0], 591.0, 0.001, "3 to 1 of 800 less a 12 gap, the wide one");
        Near(free[1], 197.0, 0.001, "and the narrow one");
        float[] tight = TitleMenu.Shares(800f, 12f, new[] { 3f, 1f }, new[] { 0f, 300f });
        Near(tight[0], 488.0, 0.001, "a narrow one needing 300 leaves 488");
        Near(tight[1], 300.0, 0.001, "and keeps its 300");
        float[] both = TitleMenu.Shares(800f, 12f, new[] { 3f, 1f }, new[] { 700f, 300f });
        Near(both[0], 700.0, 0.001, "both too wide: each keeps its least, wide");
        Near(both[1], 300.0, 0.001, "and narrow");
        Near(TitleMenu.AloneWidth(700f), 294.0, 0.001, "the lone New Kaiju is 42% of the row");
    }

    static void Art(string repoRoot)
    {
        S.GDict title = S.Content.Section("title");
        string art = Path.Combine(repoRoot, "assets", "title", "colossus_0.png");
        Check(File.Exists(art), "assets/title/colossus_0.png is on disk");
        int w = 0, h = 0;
        if (File.Exists(art))
        {
            // A PNG's size is in its header: big-endian width and height at bytes 16 and 20.
            byte[] head = new byte[24];
            using (FileStream f = File.OpenRead(art)) f.Read(head, 0, 24);
            w = (head[16] << 24) | (head[17] << 16) | (head[18] << 8) | head[19];
            h = (head[20] << 24) | (head[21] << 16) | (head[22] << 8) | head[23];
        }
        Check(w == 1924 && h == 788, $"the silhouette is 1924x788, read {w}x{h}");

        float[] glow = TitleMenu.GlowBox(0.84, 0.3, 0.2);
        Near(glow[0], 0.64, 1e-5, "glow left");
        Near(glow[2], 1.04, 1e-5, "glow right");
        Near(glow[1], 1.0 - (0.3 + 0.2 * 1.78), 1e-5, "glow bottom (y up)");
        Near(glow[3], 1.0 - (0.3 - 0.2 * 1.78), 1e-5, "glow top (y up)");

        // The camera's own look point is the middle of the screen, as far ahead as it is away.
        double[] eye = { -20.0, 11.0, -96.0 }, look = { -20.0, 38.1, -302.0 };
        TitleMenu.Project(eye, look, 50.0, 16.0 / 9.0, look, out double u, out double v, out double depth);
        Near(u, 0.5, 1e-9, "the look point is mid screen across");
        Near(v, 0.5, 1e-9, "and up");
        Near(depth, Math.Sqrt(27.1 * 27.1 + 206.0 * 206.0), 1e-9, "its depth is its distance");
        // A point to the camera's right (+x looking down -z) lands right of centre; one above lands higher.
        TitleMenu.Project(eye, look, 50.0, 16.0 / 9.0, new[] { 30.0, 38.1, -302.0 }, out double ur, out double vr, out _);
        Check(ur > 0.5 && Math.Abs(vr - 0.5) < 1e-9, "+x is to the right");
        TitleMenu.Project(eye, look, 50.0, 16.0 / 9.0, new[] { -20.0, 80.0, -302.0 }, out double uu, out double vu, out _);
        Check(vu > 0.5 && Math.Abs(uu - 0.5) < 1e-9, "+y is up");
        // A level camera: a point at the frustum's top edge is at v = 1, at its right edge u = 1.
        double[] flat = { 0, 0, 0 }, ahead = { 0, 0, -1 };
        double half = Math.Tan(25.0 * Math.PI / 180.0);
        TitleMenu.Project(flat, ahead, 50.0, 2.0, new[] { 100.0 * half * 2.0, 100.0 * half, -100.0 }, out double ue, out double ve, out double de);
        Near(ue, 1.0, 1e-9, "the frustum's right edge");
        Near(ve, 1.0, 1e-9, "the frustum's top edge");
        Near(de, 100.0, 1e-9, "depth is along the view");

        S.GDict cfg = title["colossus"];
        double[] feet = TitleMenu.ColossusFeet(cfg);
        Check(feet[0] == 285.0 && feet[1] == -12.0 && feet[2] == -400.0, "the colossus stands on tuning's start, on the ground");
        Near(TitleMenu.ColossusWidth(cfg, 1924, 788), 185.0 * 1924.0 / 788.0, 1e-9, "the card keeps the picture's shape");
        float[] box = TitleMenu.ColossusBox(title, 16.0 / 9.0, 1924, 788);
        Check(box[0] < box[2] && box[1] < box[3], "the card's box is the right way round");
        Check(box[0] > 0.5 && box[0] < 1.0, $"its left edge is on the right half of a 16:9 screen ({box[0]:0.###})");
        Check(box[3] > 0.7 && box[3] < 1.0, $"its head is whole in frame, D-158 ({box[3]:0.###})");
        Check(box[1] > 0.0 && box[1] < 0.5, $"its feet are below the middle ({box[1]:0.###})");
        float[] at = TitleMenu.ColossusEye(title, 16.0 / 9.0, 1924, 788);
        Check(at[0] > box[0] && at[0] < box[2] && at[1] > box[1] && at[1] < box[3], $"the eye is on the card ({at[0]:0.###}, {at[1]:0.###})");
        Check(at[0] < (box[0] + box[2]) * 0.5 && at[1] > (box[1] + box[3]) * 0.5, "in its top-left, where the head is");
        Check(at[2] > 0.005f && at[2] < 0.05f, $"a small glow ({at[2]:0.####} of the height)");

        S.GDict eyeCfg = cfg["eye"];
        // idle 0.22, pulse 0.35: it swings between 0.22 * 0.65 and 0.22 * 1.35, once every four seconds.
        Near(TitleMenu.EyeAlpha(eyeCfg, 0.0), 0.22, 1e-6, "the eye at rest, t 0");
        Near(TitleMenu.EyeAlpha(eyeCfg, 1.0), 0.22 * 1.35, 1e-6, "the eye's peak, t 1");
        Near(TitleMenu.EyeAlpha(eyeCfg, 3.0), 0.22 * 0.65, 1e-6, "the eye's low, t 3");
    }
}
