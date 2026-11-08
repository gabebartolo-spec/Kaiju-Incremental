// Generated from sim/water_basin.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class WaterBasin : RefCounted
    {
        public static implicit operator WaterBasin(Variant v) => (WaterBasin)v.Obj;

        // One body of water for WaterSim (the bay, the river): a grid of columns, each a bed, its water,
        // the kaiju's body standing in it and four outflows.
        // world (x, z) of cell (0, 0)'s corner
        public Vector2 origin;
        public double cell = 1.0;
        public long nx = 0;
        public long nz = 0;
        // the still surface (world y)
        public double rest = 0.0;
        // each column's bed (world y)
        public PackedFloat32Array floorY = new PackedFloat32Array();
        // its water (m)
        public PackedFloat32Array depth = new PackedFloat32Array();
        // metres of the kaiju's body standing in it
        public PackedFloat32Array body = new PackedFloat32Array();
        // 4 per column: outflow right, left, down (+z), up (-z), m^2/s
        public PackedFloat32Array flow = new PackedFloat32Array();
        // the stepped columns (empty: all at rest)
        public Rect2i active = new Rect2i();
        // the columns the kaiju's body stands in (empty: none)
        public Rect2i held = new Rect2i();
        // row 0 is open sea (the bay's mouth): a wave runs out of it
        public bool open = false;

        public WaterBasin(Vector2 pOrigin, double pCell, Vector2i pN, double pRest)
        {
            _InitFields();
            origin = pOrigin;
            cell = pCell;
            nx = pN.x;
            nz = pN.y;
            rest = pRest;
            floorY.Resize(nx * nz);
            depth.Resize(nx * nz);
            body.Resize(nx * nz);
            flow.Resize(nx * nz * 4);
        }
        // The surface's height over the still water at column k (under the bed when dry).

        public double Lift(long k)
        {
            return floorY[k] + depth[k] + body[k] - rest;
        }

        public Vector2i At(Vector2 p)
        {
            return new Vector2i(Gd.Floori((p.x - origin.x) / cell), Gd.Floori((p.y - origin.y) / cell));
        }

        public Vector2 Centre(Vector2i c)
        {
            return origin + (new Vector2(c) + new Vector2(0.5, 0.5)) * cell;
        }

        public Vector2 Size()
        {
            return new Vector2(nx, nz) * cell;
        }

        public void Wake(Rect2i rect)
        {
            var r = rect.Intersection(new Rect2i(0, 0, nx, nz));
            if (r.HasArea())
            {
                active = (!active.HasArea() ? r : active.Merge(r));
            }
        }
        // The deepest water in `r`, a row at a time (max() runs natively: a column at a time cost ms).

        public double Deepest(Rect2i r)
        {
            float[] d = depth.Raw;
            float most = 0f;
            for (long j = r.position.y; j < r.end.y; j++)
            {
                long end = j * nx + r.end.x;
                for (long k = j * nx + r.position.x; k < end; k++)
                {
                    if (d[k] > most) most = d[k];
                }
            }
            return most;
        }
        // Grows `held` to take in column `c` (one the body stands in).

        public void Hold(Vector2i c)
        {
            held = (held.HasArea() ? held.Merge(new Rect2i(c, Vector2i.ONE)) : new Rect2i(c, Vector2i.ONE));
        }

        void _InitFields()
        {
        }
    }
}
