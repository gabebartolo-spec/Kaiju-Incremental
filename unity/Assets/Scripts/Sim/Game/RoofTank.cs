// Generated from sim/roof_tank.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class RoofTank : RefCounted
    {
        public static implicit operator RoofTank(Variant v) => (RoofTank)v.Obj;

        // The rooftop water tank on a BRICK roof (director 2026-10-27, D-348, D-352), laid into a
        // BuildingLayout's cells: one roof in WOODEN_ONE_IN (by a hash of the building) a wooden water
        // tower, the rest a white solar water heater, both on the same spot. In cells (RES 8: a storey
        // is 8). Keys are materials (data/materials.json); a cell past the footprint is not laid.
        public const long WOODEN_ONE_IN = 4;
        // The tower is 12 tall (1.5 storeys): TOWER_LEGS steel legs TOWER_LEG_AT cells from its axis
        // under a platform, a barrel of straight staves taller than wide (TOWER_BARREL layers, squared
        // radius TOWER_BARREL_R2) with a flush hoop at each TOWER_HOOPS layer above its foot (the ring
        // outside squared radius TOWER_HOOP_INNER_R2), and a cone roof at TOWER_ROOF_R2 (one squared
        // radius per layer, the eave first, to a point).
        public const long TOWER_LEGS = 2;
        public const long TOWER_LEG_AT = 2;
        public const long TOWER_PLATFORM_R2 = 8;
        public const long TOWER_BARREL = 6;
        public const long TOWER_BARREL_R2 = 5;
        public static readonly GArray<long> TOWER_HOOPS = new GArray<long> { 1, 4 };
        public const long TOWER_HOOP_INNER_R2 = 2;
        public static readonly GArray<long> TOWER_ROOF_R2 = new GArray<long> { 10, 2, 0 };
        public const long TOWER_REACH = 3;
        // The heater: 9 cells along its tank and 8 deep, the tank lying on its side (2 cells across, 7
        // long with its silver end caps) above the top edge of two panels that fall away in front of it
        // in steps (a silver frame rail at each side and between them, a silver seam across).
        public const long HEATER_W = 9;
        public const long HEATER_D = 8;
        public const long HEATER_ROWS = 7;
        public GDict _cells = new GDict();
        public long _w;
        public long _d;

        public RoofTank(GDict cells, long w, long d)
        {
            _InitFields();
            _cells = cells;
            _w = w;
            _d = d;
        }
        // Whether a BRICK roof carries the wooden tower (else the solar heater).

        public static bool Wooden(RampageSim.Building of)
        {
            return WoodenAt(of.x, of.z);
        }
        // The same roll for a roof centred at (x, z): the far skyline's stand-ins use it, so the whole city
        // shares one mix.

        public static bool WoodenAt(double x, double z)
        {
            long seed = Gd.Roundi(x * 13.0 + z);
            return Gd.Absi(Gd.Hash(new Vector4i(4, 6, 8, seed))) % WOODEN_ONE_IN == 0;
        }
        // The tank for building `of`, standing on a roof whose first free layer is `top`.

        public void Lay(RampageSim.Building of, long top)
        {
            if (Wooden(of))
            {
                _Tower(top);
            }
            else
            {
                _Heater(top);
            }
        }
        // A wooden water tower (D-348; D-352 shrank it to 12 cells): a barrel of straight staves on four
        // steel legs and a platform, two iron hoops round it, a cone roof to a point. Round in plan.

        public void _Tower(long top)
        {
            var at = new Vector3i(Gd.Roundi(_w * 0.65), top, Gd.Roundi(_d * 0.4));
            foreach (long lz in Gd.Arr(-TOWER_LEG_AT, TOWER_LEG_AT))
            {
                foreach (long lx in Gd.Arr(-TOWER_LEG_AT, TOWER_LEG_AT))
                {
                    foreach (long y in Gd.Range(TOWER_LEGS))
                    {
                        _Disc(at + new Vector3i(lx, y, lz), "gear", 0);
                    }
                }
            }
            _Disc(at + new Vector3i(0, TOWER_LEGS, 0), "gear", TOWER_PLATFORM_R2);
            var @base = at + new Vector3i(0, TOWER_LEGS + 1, 0);
            foreach (long y in Gd.Range(TOWER_BARREL))
            {
                _Disc(@base + new Vector3i(0, y, 0), "tank", TOWER_BARREL_R2);
            }
            // flush with the staves, the ring round the core
            foreach (long y in TOWER_HOOPS)
            {
                _Disc(@base + new Vector3i(0, y, 0), "vent", TOWER_BARREL_R2, TOWER_HOOP_INNER_R2);
            }
            // the eave first, then ever narrower to the tip
            foreach (long k in Gd.Range(TOWER_ROOF_R2.Size()))
            {
                _Disc(@base + new Vector3i(0, TOWER_BARREL + k, 0), "tank", TOWER_ROOF_R2[k]);
            }
        }
        // The cells of layer `at.y` round `at` (x, z) whose squared distance from it is over `inner2` and
        // at most `outer2` (`outer2` 0 is the one cell under `at`).

        public void _Disc(Vector3i at, string key, long outer2, long inner2 = -1)
        {
            foreach (long dx in Gd.Range(-TOWER_REACH, TOWER_REACH + 1))
            {
                foreach (long dz in Gd.Range(-TOWER_REACH, TOWER_REACH + 1))
                {
                    long d2 = dx * dx + dz * dz;
                    if (d2 > inner2 && d2 <= outer2)
                    {
                        _Put(at + new Vector3i(dx, 0, dz), key);
                    }
                }
            }
        }
        // A white solar water heater (D-352, from the director's photo): two dark panels in silver frames
        // that rise in steps from the roof toward the back (row hz 0 to 6, a step every second row, a
        // frame rail at hx 0, 4 and 8, a seam across at hz 3), and above the panels' top edge the white
        // tank lying on its side (hx 1 to 7 and hz 6 to 7, two cells across, silver end caps, a highlight
        // along its top). A cross-member beneath each step joins the stairs face to face; the top edge
        // stands on legs at the rails.

        public void _Heater(long top)
        {
            long x0 = Gd.Clampi(Gd.Roundi(_w * 0.65) - 4, 1, Gd.Maxi(1, _w - HEATER_W - 1));
            long z0 = Gd.Clampi(Gd.Roundi(_d * 0.4) - 4, 1, Gd.Maxi(1, _d - HEATER_D - 1));
            _HeaterPanels(top, x0, z0);
            foreach (long hx in Gd.Range(1, HEATER_W - 1))
            {
                var cap = (hx == 1 || hx == HEATER_W - 2);
                foreach (long hz in Gd.Range(HEATER_ROWS - 1, HEATER_D))
                {
                    _Put(new Vector3i(x0 + hx, top + 4, z0 + hz), (cap ? "gear" : "heater"));
                    _Put(new Vector3i(x0 + hx, top + 5, z0 + hz), (cap ? "gear" : "heater_hi"));
                }
            }
        }
        // The heater's two stepped panels with their rails, seams, cross-members and legs.

        public void _HeaterPanels(long top, long x0, long z0)
        {
            foreach (long hx in Gd.Range(HEATER_W))
            {
                var rail = hx % 4 == 0;
                foreach (long hz in Gd.Range(HEATER_ROWS))
                {
                    long y = top + ((hz >> (int)(1)));
                    var frame = (rail || hz == 0 || hz == 3 || hz == HEATER_ROWS - 1);
                    _Put(new Vector3i(x0 + hx, y, z0 + hz), (frame ? "gear" : "solar"));
                    // a step: the cross-member beneath it
                    if (hz > 0 && hz % 2 == 0)
                    {
                        _Put(new Vector3i(x0 + hx, y - 1, z0 + hz), "gear");
                    }
                }
                // the legs under the top edge
                if (rail)
                {
                    foreach (long y in Gd.Range(3))
                    {
                        _Put(new Vector3i(x0 + hx, top + y, z0 + HEATER_ROWS - 1), "gear");
                    }
                }
            }
        }

        public void _Put(Vector3i cell, string key)
        {
            if (cell.x >= 0 && cell.x < _w && cell.z >= 0 && cell.z < _d)
            {
                _cells[cell] = key;
            }
        }

        void _InitFields()
        {
        }
    }
}
