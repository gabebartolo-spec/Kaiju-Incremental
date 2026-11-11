// The genome rack of Kaiju Creation (scenes/creation_rack.gd, D-207): every titan in tuning "creation" "titans",
// in order. A titan is unlocked if data starts a new player with it or the save's titans_unlocked list holds it;
// it can be picked only when unlocked, with a species to play that this build allows (the demo).
// Pure: reads Content and the save it is given, writes nothing.
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class CreationTitan
    {
        public string Id = "", Name = "", Species = "";
        // The genome's colour as data writes it ("6f8a3e").
        public string Genome = "";
        public bool Locked, Selectable;
    }

    public static class CreationRack
    {
        // creation_rack.gd titans(save).
        public static List<CreationTitan> Titans(GDict save)
        {
            GDict cfg = Content.Section("creation");
            GArray<Variant> opened = (save ?? new GDict()).Get(Gd.Str(cfg["save_key"]), Gd.Arr());
            GArray<Variant> rows = cfg["titans"];
            var titans = new List<CreationTitan>();
            foreach (GDict row in rows)
            {
                string id = Gd.Str(row["id"]);
                string species = Gd.Str(row["species"]);
                bool unlocked = row["unlocked"] == true || opened.Has(id);
                bool playable = species != "" && Demo.Allows(species) && Exists(species);
                titans.Add(new CreationTitan
                {
                    Id = id,
                    Name = Gd.Str(row["name"]),
                    Species = species,
                    Genome = Gd.Str(row["genome"]),
                    Locked = !unlocked,
                    Selectable = unlocked && playable,
                });
            }
            return titans;
        }

        // The titans the rack shows (D-454): only those unlocked and playable; the rest stay hidden, vial and button.
        public static List<CreationTitan> Shown(GDict save)
        {
            return Titans(save).FindAll(t => t.Selectable);
        }

        static bool Exists(string species)
        {
            foreach (GDict def in Content.Species())
                if (Gd.Str(def["id"]) == species) return true;
            return false;
        }
    }
}
