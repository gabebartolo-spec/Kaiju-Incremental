// Generated from sim/hazard_shape.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class HazardShape : RefCounted
    {
        public static implicit operator HazardShape(Variant v) => (HazardShape)v.Obj;

        // What a red-barrel site (CityHazards, Explosives; director comments #19) is made of, cell by cell
        // on the destruction grid (`res` cells per sim unit, cells local to the footprint as in
        // BuildingVoxels): a fuel silo is one to three round steel tanks on a pad with yellow and black
        // hazard stripes, a ladder and a red lamp on the dome; a fireworks factory is a brick shed with a
        // striped roof, a lit sign of starbursts and stacks of bright crates in its loading yard; a chem
        // lab is a white block with green-lit window bands, green tanks and blue drums on its roof and a
        // hazard-striped parapet. Each fills its whole footprint and every floor, so no structural chunk
        // stands empty. The view (HazardVoxels) and the sim (HazardCells) both draw from this one map,
        // so the carved grid is the drawn model. Keys are data/materials.json names. Pure: no RNG.
        // Stripe period (cells) of the yellow and black hazard bands, and how tall a band is.
        public const long STRIPE = 6;
        public const long BAND = 5;
        // A tank's dome rises this share of its radius.
        public const double DOME = 0.3;
        // Cell -> material name for building `b` at `res` cells per unit.

        public static GDict Cells(RampageSim.Building b, long res)
        {
            GDict @out = new GDict();
            var size = new Vector3i(b.w * res, b.height * res, b.d * res);
            var matched1 = b.hazard;
            if (matched1 == "fuel_silo")
            {
                _Silo(@out, size, res);
            }
            else if (matched1 == "fireworks_factory")
            {
                _Fireworks(@out, size, res);
            }
            else
            {
                _ChemLab(@out, size, res);
            }
            return @out;
        }

        public static void _Box(GDict @out, Vector3i a, Vector3i c, string key)
        {
            foreach (long x in Gd.Range(Gd.Mini(a.x, c.x), Gd.Maxi(a.x, c.x) + 1))
            {
                foreach (long y in Gd.Range(Gd.Mini(a.y, c.y), Gd.Maxi(a.y, c.y) + 1))
                {
                    foreach (long z in Gd.Range(Gd.Mini(a.z, c.z), Gd.Maxi(a.z, c.z) + 1))
                    {
                        @out[new Vector3i(x, y, z)] = key;
                    }
                }
            }
        }
        // A hollow upright tank: wall 1-2 cells thick from y0 to y1 at (cx, cz), radius r, capped by a
        // dome. `paint` (Callable(cell, angle) -> key) colours the wall; the dome is `dome_key`.

        public static void _Tank(GDict @out, Vector2 centre, double r, long y0, long y1, Callable paint, string domeKey)
        {
            var lo = new Vector2i(Gd.Floori(centre.x - r), Gd.Floori(centre.y - r));
            var hi = new Vector2i(Gd.Ceili(centre.x + r), Gd.Ceili(centre.y + r));
            double dome = Gd.Maxf(2.0, r * DOME);
            foreach (long x in Gd.Range(lo.x, hi.x + 1))
            {
                foreach (long z in Gd.Range(lo.y, hi.y + 1))
                {
                    var off = new Vector2(x + 0.5, z + 0.5) - centre;
                    double dist = off.Length();
                    if (dist > r)
                    {
                        continue;
                    }
                    double angle = Gd.Atan2(off.y, off.x);
                    if (dist > r - 1.6)
                    {
                        foreach (long y in Gd.Range(y0, y1 + 1))
                        {
                            var cell = new Vector3i(x, y, z);
                            @out[cell] = paint.Call(cell, angle);
                        }
                    }
                    // The dome: a shell over the top, thick enough to stay closed.
                    long cap = y1 + Gd.Int(dome * Gd.Sqrt(Gd.Maxf(0.0, 1.0 - (dist * dist) / (r * r))));
                    foreach (long y in Gd.Range(Gd.Maxi(y1, cap - 1), cap + 1))
                    {
                        @out[new Vector3i(x, y, z)] = domeKey;
                    }
                }
            }
        }

        public static string _Stripe(Vector3i cell, long along)
        {
            return (Gd.Posmod(along + cell.y, STRIPE) < STRIPE / 2 ? "hz_yellow" : "hz_black");
        }

        public static void _Silo(GDict @out, Vector3i size, long res)
        {
            _Box(@out, new Vector3i(0, 0, 0), new Vector3i(size.x - 1, 0, size.z - 1), "hz_pad");
            long @short = Gd.Mini(size.x, size.z);
            long count = Gd.Clampi(Gd.Maxi(size.x, size.z) / @short, 1, 3);
            double r = @short * 0.5 - 0.5;
            long top = size.y - 1 - Gd.Int(Gd.Maxf(2.0, r * DOME));
            // room for a second band near the top
            var upper = top - BAND >= res + BAND + 6;
            foreach (long k in Gd.Range(count))
            {
                var centre = _SiloCentre(size, (k + 0.5) / count);
                var paint = new Callable(a_ =>
                {
                    Vector3i cell = a_[0];
                    double angle = a_[1];
                    long along = Gd.Roundi(angle * r);
                    // a ladder up the street side
                    if (Gd.Absf(angle - Gd.PI * 0.5) * r < 1.5)
                    {
                        return (cell.y % 3 == 0 ? "hz_black" : "hz_steel");
                    }
                    if (((cell.y >= res && cell.y < res + BAND || upper && cell.y >= top - BAND && cell.y < top)))
                    {
                        return _Stripe(cell, along);
                    }
                    if (cell.y >= res + BAND && cell.y < res + BAND + 2)
                    {
                        return "hz_red";
                    }
                    return "hz_steel";
                });
                _Tank(@out, centre, r, 1, top, paint, "hz_steel");
                var crown = new Vector3i(Gd.Floori(centre.x), size.y - 1, Gd.Floori(centre.y));
                _Box(@out, crown, crown + new Vector3i(0, 1, 0), "hz_lamp");
            }
            if (count > 1)
            {
                _SiloPipe(@out, size, count, res / 2);
            }
        }
        // Where a silo tank stands: `t` (0..1) of the way along the long side, mid-way across.

        public static Vector2 _SiloCentre(Vector3i size, double t)
        {
            if (size.x >= size.z)
            {
                return new Vector2(size.x * t, size.z * 0.5);
            }
            return new Vector2(size.x * 0.5, size.z * t);
        }
        // The pipe that joins a silo's tanks, on low trestles at height y.

        public static void _SiloPipe(GDict @out, Vector3i size, long count, long y)
        {
            var a = new Vector3i(Gd.Roundi(size.x * 0.5 / count), y, (size.z >> (int)(1)));
            var c = new Vector3i(size.x - 1 - Gd.Roundi(size.x * 0.5 / count), y, (size.z >> (int)(1)));
            if (size.x < size.z)
            {
                a = new Vector3i((size.x >> (int)(1)), y, Gd.Roundi(size.z * 0.5 / count));
                c = new Vector3i((size.x >> (int)(1)), y, size.z - 1 - Gd.Roundi(size.z * 0.5 / count));
            }
            _Box(@out, a, c, "pipe");
        }

        public static void _Fireworks(GDict @out, Vector3i size, long res)
        {
            // a loading yard along the -z side
            long yard = Gd.Mini(res, size.z / 3);
            var lo = new Vector3i(0, 0, yard);
            var hi = new Vector3i(size.x - 1, size.y - 1, size.z - 1);
            foreach (long x in Gd.Range(lo.x, hi.x + 1))
            {
                foreach (long z in Gd.Range(lo.z, hi.z + 1))
                {
                    foreach (long y in Gd.Range(0, hi.y + 1))
                    {
                        var wall = (x == lo.x || x == hi.x || z == lo.z || z == hi.z);
                        if (y == hi.y)
                        {
                            @out[new Vector3i(x, y, z)] = (Gd.Posmod(x + z, 8) < 4 ? "hz_red" : "hz_yellow");
                        }
                        else if (wall)
                        {
                            @out[new Vector3i(x, y, z)] = "hz_brick";
                        }
                    }
                }
            }
            // loading doors onto the yard
            foreach (long x in Gd.Range(2, size.x - 2, 6))
            {
                _Box(@out, new Vector3i(x, 1, lo.z), new Vector3i(Gd.Mini(x + 3, size.x - 3), 5, lo.z), "frame");
            }
            _FireworksSign(@out, size, yard);
            _FireworksCrates(@out, size, yard);
        }
        // The sign on the roof: a blue board in a dark frame, starbursts in the four neon colours on both
        // faces.

        public static void _FireworksSign(GDict @out, Vector3i size, long yard)
        {
            long signY = size.y;
            long z0 = yard + 2;
            _Box(@out, new Vector3i(1, signY, z0), new Vector3i(size.x - 2, signY + 8, z0), "sign_frame");
            _Box(@out, new Vector3i(2, signY + 1, z0), new Vector3i(size.x - 3, signY + 7, z0), "hz_blue");
            foreach (long k in Gd.Range(0, size.x - 6, 6))
            {
                var key = Gd.Format("neon%d", (k / 6 % 4));
                foreach (long face in Gd.Arr(z0 - 1, z0 + 1))
                {
                    var c = new Vector3i(3 + k, signY + 4, face);
                    _Box(@out, c + new Vector3i(-1, 0, 0), c + new Vector3i(1, 0, 0), key);
                    _Box(@out, c + new Vector3i(0, -1, 0), c + new Vector3i(0, 1, 0), key);
                    foreach (Vector3i corner in Gd.Arr(new Vector3i(-2, 2, 0), new Vector3i(2, 2, 0), new Vector3i(-2, -2, 0), new Vector3i(2, -2, 0)))
                    {
                        @out[c + corner] = key;
                    }
                }
            }
        }
        // Crates stacked in the yard, two high, in bright fireworks colours with a dark band.

        public static void _FireworksCrates(GDict @out, Vector3i size, long yard)
        {
            GArray<string> colours = new GArray<string> { "hz_red", "hz_blue", "hz_yellow", "hz_green" };
            long n = 0;
            foreach (long x in Gd.Range(0, size.x - 3, 5))
            {
                foreach (long z in Gd.Range(0, Gd.Maxi(1, yard - 3), 5))
                {
                    long tall = (Gd.Posmod(x / 5 + z, 3) != 0 ? 2 : 1);
                    foreach (long level in Gd.Range(tall))
                    {
                        var a = new Vector3i(x, level * 4, z);
                        _Box(@out, a, a + new Vector3i(3, 3, 3), colours[n % colours.Size()]);
                        _Box(@out, a + new Vector3i(0, 1, 0), a + new Vector3i(3, 1, 3), "hz_black");
                        n += 1;
                    }
                }
            }
        }

        public static void _ChemLab(GDict @out, Vector3i size, long res)
        {
            _ChemWalls(@out, size, res);
            _ChemParapet(@out, size);
            _ChemRoof(@out, size);
        }
        // White walls with a glowing band on each floor above the first, a white roof, a hazard-striped
        // parapet.

        public static void _ChemWalls(GDict @out, Vector3i size, long res)
        {
            var hi = size - Vector3i.ONE;
            foreach (long x in Gd.Range(size.x))
            {
                foreach (long z in Gd.Range(size.z))
                {
                    foreach (long y in Gd.Range(size.y))
                    {
                        var wall = (x == 0 || z == 0 || x == hi.x || z == hi.z);
                        if (y == hi.y)
                        {
                            @out[new Vector3i(x, y, z)] = "hz_white";
                        }
                        else if (wall)
                        {
                            var band = Gd.Posmod(y, res) >= 3 && Gd.Posmod(y, res) <= 5 && y >= res;
                            @out[new Vector3i(x, y, z)] = (band ? "hz_glow" : "hz_white");
                        }
                    }
                }
            }
        }

        public static void _ChemParapet(GDict @out, Vector3i size)
        {
            var hi = size - Vector3i.ONE;
            // a hazard-striped parapet
            foreach (long x in Gd.Range(size.x))
            {
                foreach (long z in Gd.Range(size.z))
                {
                    if ((x == 0 || z == 0 || x == hi.x || z == hi.z))
                    {
                        var cell = new Vector3i(x, size.y, z);
                        @out[cell] = _Stripe(cell, x + z);
                    }
                }
            }
        }
        // Green tanks on the roof, banded white, and a blue drum stack beside them.

        public static void _ChemRoof(GDict @out, Vector3i size)
        {
            double r = Gd.Clampf(Gd.Mini(size.x, size.z) * 0.18, 2.5, 5.0);
            var paint = new Callable(a_ =>
            {
                Vector3i cell = a_[0];
                double _angle = a_[1];
                return (Gd.Posmod(cell.y - size.y, 5) == 0 ? "hz_white" : "hz_glow");
            });
            long count = Gd.Clampi(size.x / Gd.Roundi(r * 2.0 + 3.0), 1, 3);
            foreach (long k in Gd.Range(count))
            {
                var centre = new Vector2(r + 2.0 + k * (r * 2.0 + 3.0), size.z * 0.6);
                _Tank(@out, centre, r, size.y, size.y + Gd.Roundi(r * 2.4), paint, "hz_white");
            }
            foreach (long k in Gd.Range(3))
            {
                var a = new Vector3i(size.x - 4 - k * 3, size.y, 2);
                if (a.x > 1)
                {
                    _Box(@out, a, a + new Vector3i(1, 2 + k % 2, 1), "hz_drum");
                }
            }
        }

        void _InitFields()
        {
        }
        public HazardShape() { _InitFields(); }
    }
}
