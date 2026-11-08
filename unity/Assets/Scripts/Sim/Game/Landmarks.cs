// Generated from sim/landmarks.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Landmarks : RefCounted
    {
        public static implicit operator Landmarks(Variant v) => (Landmarks)v.Obj;

        // Builds a rampage's buildings from the city layout's entries (CityGen). An entry with a
        // "landmark" id is a landmark: its Structure keeps only the chunks its baked model fills
        // ("chunks", from data/landmarks.json via tools/landmarks/bake.py), so it stands and breaks in
        // its own shape, and its chunks pay "rubble_bonus" times the usual rubble. A ring landmark's
        // "arcs" (Arcs) make a breach bring down a whole section of it. Pure sim.
        // A building from one layout entry: x, z (centre), w, d, h, tier, style, and for a landmark
        // landmark, chunks, rubble_bonus; for a pool building (CityPool) model, facing, mirror, stretch,
        // palette. Its chunks are chunk_hp x tier tough.

        public static RampageSim.Building Building(GDict entry, double chunkHp)
        {
            var b = new RampageSim.Building();
            b.x = Num.F(entry["x"]);
            b.z = Num.F(entry["z"]);
            b.w = Num.I(entry["w"]);
            b.d = Num.I(entry["d"]);
            b.height = Num.I(entry["h"]);
            b.tier = Num.I(entry["tier"]);
            b.style = Num.I(entry["style"]);
            b.frame = new Structure(b.w, b.d, b.height, chunkHp * b.tier);
            b.landmark = Gd.Str(entry.Get("landmark", ""));
            b.rubbleBonus = Num.F(entry.Get("rubble_bonus", 1.0));
            b.hazard = Gd.Str(entry.Get("hazard", ""));
            // a pool building: its baked model's chunks, turned as placed
            if (entry.Has("model"))
            {
                b.model = Gd.Str(entry["model"]);
                b.variant = ModelVariant.Of(entry);
                b.palette = Num.I(entry.Get("palette", 0));
                GDict row = ModelVariant.RowOf(b.model);
                if (!row.IsEmpty())
                {
                    b.frame.Keep(ModelVariant.Chunks(row, b.variant));
                }
            }
            else if (entry.Has("chunks"))
            {
                GArray<Variant> shape = entry["chunks"];
                b.frame.Keep(shape);
            }
            if (entry.Has("arcs"))
            {
                GDict arcs = entry["arcs"];
                b.frame.arcs = Arcs.Build(b.frame, arcs);
            }
            return b;
        }

        void _InitFields()
        {
        }
        public Landmarks() { _InitFields(); }
    }
}
