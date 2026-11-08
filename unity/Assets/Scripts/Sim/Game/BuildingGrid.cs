// Generated from sim/building_grid.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BuildingGrid : RefCounted
    {
        public static implicit operator BuildingGrid(Variant v) => (BuildingGrid)v.Obj;

        // A ground grid over the rampage's buildings, so a question about one spot (what the body
        // touches, whether a street is blocked, the column under the kaiju) looks at the few buildings
        // near it instead of the whole city (D-254: the 1.5x city has twice the buildings, and these
        // run every step). Buildings never move, so it is filled once. Answers list building indices in
        // ascending order, the order a pass over sim.buildings meets them, so every caller decides
        // exactly as before. Pure sim.
        // Side of a grid cell (m): about a block, so a body's reach spans a few cells.
        public const double CELL = 16.0;
        // The largest half-diagonal of any footprint (m): a building whose centre lies within r of a spot
        // is always among around(spot, r + pad).
        public double pad = 0.0;
        // Vector2i -> PackedInt32Array of building indices, ascending
        public GDict _cells = new GDict();

        public BuildingGrid(GArray<Variant> buildings)
        {
            _InitFields();
            foreach (long i in Gd.Range(buildings.Size()))
            {
                RampageSim.Building b = buildings[i];
                pad = Gd.Maxf(pad, new Vector2(b.w, b.d).Length() * 0.5);
                var lo = _Cell(new Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5));
                var hi = _Cell(new Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5));
                foreach (long cx in Gd.Range(lo.x, hi.x + 1))
                {
                    foreach (long cz in Gd.Range(lo.y, hi.y + 1))
                    {
                        var key = new Vector2i(cx, cz);
                        if (!_cells.Has(key))
                        {
                            _cells[key] = new PackedInt32Array();
                        }
                        PackedInt32Array list = _cells[key];
                        list.Append(i);
                        _cells[key] = list;
                    }
                }
            }
        }
        // Every building whose footprint may reach the rect lo..hi (ground x, z), ascending, once each.

        public PackedInt32Array InRect(Vector2 lo, Vector2 hi)
        {
            var a = _Cell(lo);
            var b = _Cell(hi);
            if (a == b)
            {
                return _cells.Get(a, new PackedInt32Array());
            }
            GDict seen = new GDict();
            foreach (long cx in Gd.Range(a.x, b.x + 1))
            {
                foreach (long cz in Gd.Range(a.y, b.y + 1))
                {
                    foreach (long i in Gd.Iter(_cells.Get(new Vector2i(cx, cz), new PackedInt32Array())))
                    {
                        seen[i] = true;
                    }
                }
            }
            var @out = new PackedInt32Array(seen.Keys());
            @out.Sort();
            return @out;
        }
        // Every building whose footprint may reach within `radius` of p.

        public PackedInt32Array Around(Vector2 p, double radius)
        {
            return InRect(p - Vector2.ONE * radius, p + Vector2.ONE * radius);
        }

        public Vector2i _Cell(Vector2 p)
        {
            return new Vector2i(Gd.Floori(p.x / CELL), Gd.Floori(p.y / CELL));
        }

        void _InitFields()
        {
        }
    }
}
