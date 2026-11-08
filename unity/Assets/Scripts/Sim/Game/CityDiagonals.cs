// Generated from sim/city_diagonals.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CityDiagonals : RefCounted
    {
        public static implicit operator CityDiagonals(Variant v) => (CityDiagonals)v.Obj;

        // The city's diagonal avenues as lines (part of CityGen.map, split out to keep files small): each
        // is {at, dir}, a point it passes and its direction (unit, ground plane). Pure.
        // Every diagonal avenue of cfg: the first (city.diagonal_through, city.diagonal_deg), then
        // city.diagonal_count - 1 more through the same point, turned evenly round the half circle
        // (Carthago's spokes, D-435: they meet in the open site there, CityPlaza, which holds its round
        // harbour, CityWater).

        public static GArray<GDict> Of(GDict cfg)
        {
            GArray<Variant> through = cfg["diagonal_through"];
            double angle = Gd.DegToRad(Num.F(cfg["diagonal_deg"]));
            var at = new Vector2(Num.F(through[0]), Num.F(through[1]));
            var dir = new Vector2(Gd.Cos(angle), Gd.Sin(angle));
            GArray<GDict> @out = new GArray<GDict> { new GDict { { "at", at }, { "dir", dir } } };
            long count = Num.I(cfg["diagonal_count"]);
            foreach (long k in Gd.Range(1, count))
            {
                @out.Append(new GDict { { "at", at }, { "dir", dir.Rotated(Gd.PI * k / count) } });
            }
            return @out;
        }
        // Where a diagonal crosses x-line x (its z), and z-line z (its x).

        public static double AtX(GDict diag, double x)
        {
            Vector2 at = diag["at"];
            Vector2 dir = diag["dir"];
            return at.y + (x - at.x) * dir.y / dir.x;
        }

        public static double AtZ(GDict diag, double z)
        {
            Vector2 at = diag["at"];
            Vector2 dir = diag["dir"];
            return at.x + (z - at.y) * dir.x / dir.y;
        }

        void _InitFields()
        {
        }
        public CityDiagonals() { _InitFields(); }
    }
}
