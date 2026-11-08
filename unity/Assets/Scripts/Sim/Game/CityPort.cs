// Generated from sim/city_port.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityPort : RefCounted
    {
        public static implicit operator CityPort(Variant v) => (CityPort)v.Obj;

        // The working port's buildings (D-381; the director's port board picks 2026-10-29: A2
        // ship-to-shore cranes, B1 container stacks, C1 quay sheds): pool models of district "port", role
        // "fixed" (tools/port/build_port.py), stood at the same spots in every city (city "harbour"
        // "port"), never drawn by CityPool. Like every block they stand only inside the real band
        // (CityBand.real). Pure.
        // The port's layout entries for this stage (CityPool's entry shape, palette 0, "fixed": true);
        // [] with no front, no port list or the pool off.

        public static GArray<GDict> Entries(GDict plan, GDict cfg)
        {
            GArray<GDict> @out = new GArray<GDict>();
            GDict pool = CityPool.Rows(cfg);
            if ((!plan.Has("harbour") || pool.IsEmpty()))
            {
                return @out;
            }
            GDict h = cfg["harbour"];
            GDict port = h.Get("port", new GDict());
            foreach (GArray<Variant> spec in Gd.Iter(port.Get("at", Gd.Arr())))
            {
                GDict row = pool.Get(Gd.Str(spec[0]), new GDict());
                if (!row.Has("w"))
                {
                    continue;
                }
                GDict v = new GDict { { "facing", Num.I(spec[3]) }, { "mirror", spec[4] == true }, { "stretch", 0 } };
                var dims = ModelVariant.Size(row, v);
                var at = new Vector2(Num.F(spec[1]), Num.F(spec[2]));
                var size = new Vector2(dims.x, dims.z);
                if (!(CityBand.Real(new Rect2(at - size * 0.5, size), cfg)))
                {
                    continue;
                }
                @out.Append(new GDict { { "x", at.x }, { "z", at.y }, { "w", dims.x }, { "d", dims.z }, { "h", dims.y }, { "tier", CityGen.TierForHeight(dims.y, cfg) }, { "style", 0 }, { "model", Gd.Str(spec[0]) }, { "facing", v["facing"] }, { "mirror", v["mirror"] }, { "stretch", 0 }, { "palette", 0 }, { "fixed", true } });
            }
            return @out;
        }

        void _InitFields()
        {
        }
        public CityPort() { _InitFields(); }
    }
}
