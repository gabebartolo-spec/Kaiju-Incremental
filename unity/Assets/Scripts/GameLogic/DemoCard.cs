// What the demo's thanks card says (scenes/demo_end.gd, without the drawing): the species and stage it stages,
// the title and line from data/tuning.json "demo", the six rampage totals (Demo.Rows, counted by the sim) with
// their labels in the player's language, the feedback link, and the three buttons in Godot's order with the
// focus on Try Endless mode. Reads the save; decides nothing. The view (Game/Screens/DemoEndScreen.cs) only
// draws what this built.
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    // One totals row: the English label (the text table's key), the label shown and the figure.
    public sealed class DemoCardRow
    {
        public string key, label, value;
    }

    // One button: the name the flow presses it by, and its text in the player's language.
    public sealed class DemoCardButton
    {
        public string id, label;
    }

    public sealed class DemoCardModel
    {
        // demo_end.gd species_id and stage (KaijuModel.stage_for at the data's thanks size).
        public string speciesId = "", stage = "";
        public long size;
        public string title = "", line = "", feedbackUrl = "";
        public List<DemoCardRow> rows = new List<DemoCardRow>();
        public List<DemoCardButton> buttons = new List<DemoCardButton>();
        // The button the card opens on (demo_end.gd endless.grab_focus).
        public string focus = DemoCard.ENDLESS;
    }

    public static class DemoCard
    {
        // The buttons' names, left to right as demo_end.gd adds them.
        public const string FEEDBACK = "Feedback", ENDLESS = "Endless", KEEP = "Keep";
        static readonly string[,] BUTTONS = { { FEEDBACK, "LEAVE FEEDBACK" }, { ENDLESS, "TRY ENDLESS MODE" }, { KEEP, "KEEP PLAYING" } };

        // save: the save in play (main.gd _show_demo_end: _species(), _totals()).
        public static DemoCardModel Build(GDict save)
        {
            if (save == null) save = new GDict();
            GDict demo = Content.Section("demo");
            DemoCardModel m = new DemoCardModel();
            m.speciesId = Gd.Str(save.Get("species", ""));
            m.size = Num.I(demo.Get("thanks_size", 1L));
            m.stage = TreeText.StageFor(m.size);
            m.title = Tr.T(Gd.Str(demo.Get("end_title", "")));
            m.line = Tr.T(Gd.Str(demo.Get("end_line", "")));
            m.feedbackUrl = Demo.FeedbackUrl();
            GDict totals = save.Get("totals", default(Variant)).Obj as GDict ?? new GDict();
            foreach (PackedStringArray row in Demo.Rows(totals))
            {
                m.rows.Add(new DemoCardRow { key = row[0], label = Tr.T(row[0]), value = row[1] });
            }
            for (int i = 0; i < BUTTONS.GetLength(0); i++)
            {
                m.buttons.Add(new DemoCardButton { id = BUTTONS[i, 0], label = Tr.T(BUTTONS[i, 1]) });
            }
            return m;
        }
    }
}
