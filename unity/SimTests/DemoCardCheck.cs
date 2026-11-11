// The demo's thanks card as plain C# (GameLogic/DemoCard.cs) against scenes/demo_end.gd and tests/lib/flow_demo.gd
// _thanks_card / _feedback_inputs: the data's title and line, the six totals in Demo.rows order and format, the
// reptilian adult it stages, the three buttons in order with the focus on Try Endless mode, the one feedback link,
// and the labels in the player's language.
using System;
using System.IO;
using Kaiju.Game;
using Kaiju.Sim;

public static class DemoCardCheck
{
    static int checks, failed;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL demo card: " + what);
    }

    static string Rows(DemoCardModel m) => string.Join(", ", m.rows.ConvertAll(r => r.label + "=" + r.value));

    public static int Run(string repoRoot)
    {
        checks = 0;
        failed = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        string oldLanguage = Tr.Language;
        Tr.Load(File.ReadAllText(Path.Combine(repoRoot, "data", "i18n", "strings.csv")));
        Tr.Language = "en";
        try
        {
            Cases();
        }
        finally
        {
            Tr.Language = oldLanguage;
        }
        Console.WriteLine("demo card: " + checks + " checks, " + failed + " failed");
        return failed;
    }

    static void Cases()
    {
        GDict demo = Content.Section("demo");
        GDict totals = new GDict
        {
            { "buildings", 41L }, { "eaten", 7L }, { "fled", 3L }, { "military", 14L }, { "seconds", 125L }, { "biomass", 9001L },
        };
        GDict save = new GDict { { "species", "reptilian" }, { "totals", totals }, { "demo_done", true } };
        DemoCardModel m = DemoCard.Build(save);

        // The words come from data.
        Check(m.title == Gd.Str(demo["end_title"]) && m.title == "THANKS FOR PLAYING", "the title is the data's end_title: " + m.title);
        Check(m.line == Gd.Str(demo["end_line"]) && m.line == "Nothing is left to evolve", "the line is the data's end_line: " + m.line);

        // The six totals, in Demo.rows order and format (flow_demo.gd: "it lists the six rampage totals").
        Check(m.rows.Count == 6, "six rows: " + m.rows.Count);
        Check(Rows(m) == "Buildings destroyed=41, People eaten=7, People fled=3, Military destroyed=14, Time played=2:05, Biomass earned=9001",
            "rows in Godot's order and format: " + Rows(m));
        GArray<PackedStringArray> sim = Demo.Rows(totals);
        bool same = sim.Size() == m.rows.Count;
        for (int i = 0; same && i < m.rows.Count; i++) same = m.rows[i].key == sim[i][0] && m.rows[i].value == sim[i][1];
        Check(same, "every row is the sim's Demo.Rows, label and figure");

        // An hour and a second: minutes run on, seconds stay two digits.
        totals["seconds"] = 3601L;
        Check(DemoCard.Build(save).rows[4].value == "60:01", "time played past an hour: " + DemoCard.Build(save).rows[4].value);

        // A save with no totals (a fresh demo save): six zero rows, not an error.
        DemoCardModel empty = DemoCard.Build(new GDict { { "species", "reptilian" } });
        Check(Rows(empty) == "Buildings destroyed=0, People eaten=0, People fled=0, Military destroyed=0, Time played=0:00, Biomass earned=0",
            "no totals yet shows zeros: " + Rows(empty));
        Check(DemoCard.Build(null).rows.Count == 6, "no save still lists the six rows");

        // What it stages: the save's species at the data's thanks size (flow_demo.gd: the reptilian adult).
        Check(m.speciesId == "reptilian" && m.size == Num.I(demo["thanks_size"]) && m.stage == "adult",
            "it stages the reptilian adult: " + m.speciesId + " " + m.stage + " (size " + m.size + ")");

        // The buttons, left to right, and the focus.
        string buttons = string.Join(",", m.buttons.ConvertAll(b => b.id + ":" + b.label));
        Check(buttons == "Feedback:LEAVE FEEDBACK,Endless:TRY ENDLESS MODE,Keep:KEEP PLAYING", "buttons in Godot's order: " + buttons);
        Check(m.focus == DemoCard.ENDLESS, "focus starts on Try Endless mode: " + m.focus);

        // The feedback link is the one data string.
        Check(m.feedbackUrl == Gd.Str(demo["feedback_url"]) && m.feedbackUrl.StartsWith("https://"),
            "the link is the data's feedback_url: " + m.feedbackUrl);

        // The card reads the save and never writes it.
        Check(save.Size() == 3 && save.Get("demo_done", false) == true, "the save is untouched");

        // In another language: the words, the row labels and the buttons are translated, the figures are not.
        Tr.Language = "es";
        DemoCardModel es = DemoCard.Build(save);
        Tr.Language = "en";
        Check(es.title == "GRACIAS POR JUGAR" && es.line == "No queda nada por evolucionar", "Spanish words: " + es.title + " / " + es.line);
        Check(es.rows[0].label == "Edificios destruidos" && es.rows[0].key == "Buildings destroyed" && es.rows[0].value == "41",
            "Spanish row label, English key, same figure: " + es.rows[0].label);
        Check(es.buttons[0].label == "DAR OPINIÓN" && es.buttons[0].id == DemoCard.FEEDBACK, "Spanish feedback button: " + es.buttons[0].label);
    }
}
