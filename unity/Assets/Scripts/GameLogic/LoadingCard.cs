// What the loading screen shows (scenes/loading_overlay.gd), as plain C#: which still, which headline, and
// the place the rampage is in. Loading.cs draws it.
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static class LoadingCard
    {
        // The stills (assets/loading), in Godot's order: each a 4K frame of a real dusk rampage (D-140, D-427).
        public static readonly string[] STILLS =
        {
            "assets/loading/s1_form_side.jpg",
            "assets/loading/s1_lash_hero.jpg",
            "assets/loading/s2_form_hero.jpg",
            "assets/loading/s2_smash_side.jpg",
            "assets/loading/s2_breath_side.jpg",
            "assets/loading/s2_lash_over.jpg",
            "assets/loading/s2_after_pano.jpg",
            "assets/loading/s3_form_side.jpg",
            "assets/loading/s3_breath_side.jpg",
            "assets/loading/s3_lash_over.jpg",
            "assets/loading/s3_beam_over.jpg",
            "assets/loading/s3_beam_pano.jpg",
        };

        // A still other than the last one shown (loading_overlay.gd _still): `roll` is any number from 0 up,
        // `last` the index shown before (-1: none yet), `count` how many stills there are.
        public static int Pick(int roll, int last, int count)
        {
            if (count <= 1) return 0;
            int pick = roll % (count - 1);
            if (pick >= last && last >= 0) pick++;
            return pick;
        }

        // The headlines (tuning "ui" loading_news), as text-table keys.
        public static List<string> News(GDict ui)
        {
            var lines = new List<string>();
            if (ui == null || !ui.Has("loading_news")) return lines;
            GArray<Variant> news = ui["loading_news"];
            foreach (Variant line in news) lines.Add(Gd.Str(line));
            return lines;
        }

        // The headline for the `shown`-th load (0 first): each load shows the next one, round and round.
        // -1 when there are none.
        public static int Tip(int shown, int count)
        {
            return count > 0 ? shown % count : -1;
        }

        // The continent the rampage is in, by its name in data/continents.json (a text-table key); "" for a
        // plain rampage or an id the data does not hold.
        public static string Place(RunRequest request)
        {
            if (request == null || request.continent == "") return "";
            GDict def = Content.Continent(request.continent);
            return def.Has("name") ? Gd.Str(def["name"]) : "";
        }
    }
}
