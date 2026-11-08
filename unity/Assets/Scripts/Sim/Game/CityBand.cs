// Generated from sim/city_band.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityBand : RefCounted
    {
        public static implicit operator CityBand(Variant v) => (CityBand)v.Obj;

        // The real band past the arena's edge (director, build 2 note 6: "ALL buildings in the play
        // area must be destroyable"). As far past the edge as the game camera shows (city.view_beyond),
        // every block holds real, destroyable buildings, out of the kaiju's walk but not its reach; the
        // painted stand-ins (CitySkyline) only start past it, where the fog takes them. Part of
        // CityGen.map, split out to keep files small. Pure.
        // How far from the centre real buildings stand, measured square (the arena's shape).

        public static double Extent(GDict cfg)
        {
            return CityGen.HalfExtent(cfg) + Num.F(cfg["arena_margin"]) + Num.F(cfg["view_beyond"]);
        }
        // How far a rect's nearest point lies from the centre, measured square.

        public static double NearEdge(Rect2 rect)
        {
            double dx = 0.0;
            if (rect.position.x * rect.end.x > 0.0)
            {
                dx = Gd.Minf(Gd.Absf(rect.position.x), Gd.Absf(rect.end.x));
            }
            double dz = 0.0;
            if (rect.position.y * rect.end.y > 0.0)
            {
                dz = Gd.Minf(Gd.Absf(rect.position.y), Gd.Absf(rect.end.y));
            }
            return Gd.Maxf(dx, dz);
        }
        // True when a footprint centred on (x, z) of `size` reaches inside the square of `half`.

        public static bool Touches(double x, double z, Vector2 size, double half)
        {
            return NearEdge(new Rect2(new Vector2(x, z) - size * 0.5, size)) < half;
        }
        // True when a block at `rect` holds real buildings at this stage: it starts inside the band.

        public static bool Real(Rect2 rect, GDict cfg)
        {
            return NearEdge(rect) < Extent(cfg);
        }
        // The blocks of districts not yet in play (inner: CityGen.map's indices of every block inside
        // the last district) that lie past the band become "outer" stand-ins, keeping the use they will
        // have under "was", so CityGen.generate draws their lots the same at every stage and drops them.

        public static void HoldBack(GDict plan, GArray<long> inner, GDict cfg)
        {
            GArray<GDict> blocks = plan["blocks"];
            foreach (long n in inner)
            {
                GDict block = blocks[n];
                Rect2 rect = block["rect"];
                if ((block.Has("was") || Real(rect, cfg)))
                {
                    // the river's blocks keep their own (CityRiver), the band stays real
                    continue;
                }
                block["was"] = block["use"];
                block["use"] = "outer";
            }
        }

        void _InitFields()
        {
        }
        public CityBand() { _InitFields(); }
    }
}
