// Generated from sim/party_walls.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class PartyWalls : RefCounted
    {
        public static implicit operator PartyWalls(Variant v) => (PartyWalls)v.Obj;

        // Which sides of each building a touching neighbour covers, and how many floors up (no sign
        // hangs off a covered side): the same answer for BuildingCells (sim) and BuildingVoxels (view),
        // so the sim's fine grid and the drawn building agree. Moved out of BuildingView for the
        // gameplay port (WP7): the sim promotes a building to its fine grid on its first hit and needs
        // the same answer. Pure.
        // The bucket grid's cell size (sim units): a little over a typical lot.
        public const double CELL = 8.0;
        // Building pairs the last of() call compared (tests check it grows about linearly).
        public static long pairChecks = 0;
        // For each building, side (BuildingCells.SIDES) -> how many floors of it a touching
        // neighbour covers (the tallest one, where several share the side). Buildings are bucketed in
        // a coarse grid first, so each is compared only with those in its own cells: about linear in
        // the building count (the adult city is thousands of buildings; all pairs would be millions).

        public static GArray<GDict> Of(GArray<RampageSim.Building> buildings)
        {
            GDict grid = _Grid(buildings);
            GArray<GDict> @out = new GArray<GDict>();
            pairChecks = 0;
            foreach (long n in Gd.Range(buildings.Size()))
            {
                @out.Append(_Sides(buildings, n, grid));
            }
            return @out;
        }
        // The bucket grid: cell -> the indices of the buildings whose footprint touches it.

        public static GDict _Grid(GArray<RampageSim.Building> buildings)
        {
            GDict grid = new GDict();
            foreach (long n in Gd.Range(buildings.Size()))
            {
                foreach (Vector2i cell in _Cells(buildings[n]))
                {
                    if (!grid.Has(cell))
                    {
                        grid[cell] = ((GArray<long>)Gd.Arr());
                    }
                    GArray<long> bucket = grid[cell];
                    bucket.Append(n);
                }
            }
            return grid;
        }
        // Building n's covered sides: side -> floors of it the tallest touching neighbour covers.

        public static GDict _Sides(GArray<RampageSim.Building> buildings, long n, GDict grid)
        {
            var a = buildings[n];
            GDict sides = new GDict();
            GDict seen = new GDict();
            foreach (Vector2i cell in _Cells(a))
            {
                GArray<long> bucket = grid[cell];
                foreach (long m in bucket)
                {
                    if ((m == n || seen.Has(m)))
                    {
                        continue;
                    }
                    seen[m] = true;
                    pairChecks += 1;
                    var other = buildings[m];
                    var side = _SideToward(a, other);
                    if (side != Vector2i.ZERO)
                    {
                        sides[side] = Gd.Maxi(Num.I(sides.Get(side, 0)), other.height);
                    }
                }
            }
            return sides;
        }
        // The side of `a` along which `other` shares a wall (touching, and overlapping along it), or zero.

        public static Vector2i _SideToward(RampageSim.Building a, RampageSim.Building other)
        {
            double gapX = Gd.Absf(a.x - other.x) - (a.w + other.w) * 0.5;
            double gapZ = Gd.Absf(a.z - other.z) - (a.d + other.d) * 0.5;
            if (Gd.Absf(gapX) < 0.01 && gapZ < -0.01)
            {
                return new Vector2i((other.x > a.x ? 1 : -1), 0);
            }
            if (Gd.Absf(gapZ) < 0.01 && gapX < -0.01)
            {
                return new Vector2i(0, (other.z > a.z ? 1 : -1));
            }
            return Vector2i.ZERO;
        }
        // The grid cells a building's footprint touches, grown a little so touching walls share one.

        public static GArray<Vector2i> _Cells(RampageSim.Building b)
        {
            GArray<Vector2i> @out = new GArray<Vector2i>();
            // a viaduct or a bridge shares no wall: it is in no bucket
            if (b.IsSpan())
            {
                return @out;
            }
            var lo = new Vector2i(Gd.Floori((b.x - b.w * 0.5 - 0.1) / CELL), Gd.Floori((b.z - b.d * 0.5 - 0.1) / CELL));
            var hi = new Vector2i(Gd.Floori((b.x + b.w * 0.5 + 0.1) / CELL), Gd.Floori((b.z + b.d * 0.5 + 0.1) / CELL));
            foreach (long cx in Gd.Range(lo.x, hi.x + 1))
            {
                foreach (long cz in Gd.Range(lo.y, hi.y + 1))
                {
                    @out.Append(new Vector2i(cx, cz));
                }
            }
            return @out;
        }

        void _InitFields()
        {
        }
        public PartyWalls() { _InitFields(); }
    }
}
