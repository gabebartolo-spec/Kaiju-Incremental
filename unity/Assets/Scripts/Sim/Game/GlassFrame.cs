// Generated from sim/glass_frame.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class GlassFrame : RefCounted
    {
        public static implicit operator GlassFrame(Variant v) => (GlassFrame)v.Obj;

        // A glass building's structural frame (D-094 WP3). Its curtain wall is all fixtures, which carry
        // nothing, so columns one cell inside the glass (at each corner and every column_bay cells,
        // ground to roof) and a beam behind the transom row ground the slabs, the roof and the
        // transoms through structure. One layout for BuildingCells and BuildingVoxels.
        public static readonly GArray<Vector2i> SIDES = new GArray<Vector2i> { new Vector2i(-1, 0), new Vector2i(1, 0), new Vector2i(0, -1), new Vector2i(0, 1) };
        // Building-local cell -> material name ("pillar" or "frame") for a w x d cell footprint, h cells
        // tall, res cells per floor.

        public static GDict Cells(long w, long d, long h, long res)
        {
            long bay = Gd.Maxi(1, Num.I(Content.Section("destruction").Get("column_bay", 0)));
            GDict @out = new GDict();
            foreach (Vector2i side in SIDES)
            {
                long length = (side.x != 0 ? d : w);
                foreach (long p in Gd.Range(1, length - 1))
                {
                    var column = (p == 1 || p == length - 2 || p % bay == 0);
                    foreach (long y in Gd.Range(h))
                    {
                        if ((column || (y >= res && y % res == 4)))
                        {
                            @out[_FaceCell(side, p, y, new Vector2i(w, d))] = (column ? "pillar" : "frame");
                        }
                    }
                }
            }
            return @out;
        }
        // The cell one layer inside face `side` at p along it, y up, for a size.x x size.y footprint.

        public static Vector3i _FaceCell(Vector2i side, long p, long y, Vector2i size)
        {
            // layer 1 of the -x face
            var cell = new Vector3i(1, y, p);
            if (side.x > 0)
            {
                cell = new Vector3i(size.x - 2, y, p);
            }
            else if (side.y < 0)
            {
                cell = new Vector3i(p, y, 1);
            }
            else if (side.y > 0)
            {
                cell = new Vector3i(p, y, size.y - 2);
            }
            return cell;
        }

        void _InitFields()
        {
        }
        public GlassFrame() { _InitFields(); }
    }
}
