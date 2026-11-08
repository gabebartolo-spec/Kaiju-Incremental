// Generated from sim/city_plaza.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityPlaza : RefCounted
    {
        public static implicit operator CityPlaza(Variant v) => (CityPlaza)v.Obj;

        // The plaza where two diagonal avenues meet (Carthago, D-435; part of CityGen.map, split out to
        // keep files small). With city.diagonal_count 2 and city.diagonal_plaza (metres) above 0, the
        // grid cells round the diagonals' crossing out to that reach become one open site: the streets
        // inside it are never laid (CitySites.cuts), so both diagonals end at its kerb and traffic goes
        // round it, and its block is a "plaza". No inner avenue is drawn through it (CityLines) and a
        // landmark site that overlaps it is dropped. Pure: the same city config always gives the same
        // plaza.
        // Adds the plaza site to plan["sites"] (after CitySites.find). avenues: [along x, along z],
        // each {line index: true}.

        public static void Add(GDict plan, GArray<Variant> avenues, GDict cfg)
        {
            GArray<GDict> diags = plan["diagonals"];
            double reach = Num.F(cfg["diagonal_plaza"]);
            if ((diags.Size() < 2 || reach <= 0.0))
            {
                return;
            }
            Vector2 at = diags[0]["at"];
            GArray<double> xs = plan["xs"];
            GArray<double> zs = plan["zs"];
            var i = _Span(xs, at.x, reach);
            var j = _Span(zs, at.y, reach);
            if ((i.x < 0 || j.x < 0))
            {
                return;
            }
            var outer = new Rect2(xs[i.x], zs[j.x], xs[i.y + 1] - xs[i.x], zs[j.y + 1] - zs[j.x]);
            GDict avX = avenues[0];
            GDict avZ = avenues[1];
            double x0 = xs[i.x] + _Inset(avX, i.x, cfg);
            double z0 = zs[j.x] + _Inset(avZ, j.x, cfg);
            double x1 = xs[i.y + 1] - _Inset(avX, i.y + 1, cfg);
            double z1 = zs[j.y + 1] - _Inset(avZ, j.y + 1, cfg);
            var rect = new Rect2(x0, z0, x1 - x0, z1 - z0);
            GArray<GDict> kept = new GArray<GDict>();
            foreach (GDict site in Gd.Iter(plan["sites"]))
            {
                Rect2 other = site["outer"];
                if (!(other.Grow(-0.01).Intersects(outer)))
                {
                    kept.Append(site);
                }
            }
            kept.Append(_Site(i, j, outer, rect, cfg));
            plan["sites"] = kept;
        }
        // The plaza's site: grid spans i and j, its outer edge and its kerbed rect.

        public static GDict _Site(Vector2i i, Vector2i j, Rect2 outer, Rect2 rect, GDict cfg)
        {
            return new GDict { { "id", "plaza" }, { "plaza", true }, { "spec", new GDict { { "id", "plaza" } } }, { "shape", new GDict() }, { "i", i }, { "j", j }, { "outer", outer }, { "rect", rect }, { "district", CityGen.DistrictOf(rect, cfg) } };
        }
        // True when street line k lies inside the plaza round centre (the diagonals' crossing on that
        // axis): CityLines keeps the inner avenues off it.

        public static bool Swallows(GArray<double> lines, long k, double centre, GDict cfg)
        {
            if (Num.I(cfg["diagonal_count"]) < 2)
            {
                return false;
            }
            return Gd.Absf(lines[k] - centre) < Num.F(cfg["diagonal_plaza"]);
        }
        // The grid cells (first, last) the plaza takes along one axis: every line within reach of c
        // lies inside it; with none, the one cell holding c. (-1, -1) when it would run off the grid.

        public static Vector2i _Span(GArray<double> lines, double c, double reach)
        {
            long first = -1;
            long last = -1;
            foreach (long k in Gd.Range(lines.Size()))
            {
                if (Gd.Absf(lines[k] - c) < reach)
                {
                    if (first < 0)
                    {
                        first = k;
                    }
                    last = k;
                }
            }
            if (first < 0)
            {
                foreach (long k in Gd.Range(lines.Size() - 1))
                {
                    if (c >= lines[k] && c < lines[k + 1])
                    {
                        return new Vector2i(k, k);
                    }
                }
                return new Vector2i(-1, -1);
            }
            if ((first < 1 || last + 1 >= lines.Size()))
            {
                return new Vector2i(-1, -1);
            }
            return new Vector2i(first - 1, last);
        }
        // How far the plaza's edge sits in from street line k: half that street's (or avenue's) width.

        public static double _Inset(GDict avenues, long k, GDict cfg)
        {
            var kind = (avenues.Has(k) ? CityGen.AVENUE : CityGen.STREET);
            return CityGen.WidthOf(kind, cfg) * 0.5;
        }

        void _InitFields()
        {
        }
        public CityPlaza() { _InitFields(); }
    }
}
