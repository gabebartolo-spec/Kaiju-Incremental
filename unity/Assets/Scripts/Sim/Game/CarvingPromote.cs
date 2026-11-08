// Generated from sim/carving_promote.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CarvingPromote : RefCounted
    {
        public static implicit operator CarvingPromote(Variant v) => (CarvingPromote)v.Obj;

        // Promotes a building to its fine carving grid on its first hit (Carving): the grid that maps
        // its fine cells to chunks, and the cells_promoted event for the view.
        // Building n's generated cells (made once; promotion takes them).

        public static CellGrid CellsOf(Carving c, long n)
        {
            if (c._party.IsEmpty())
            {
                c._party = PartyWalls.Of(c.sim.buildings);
            }
            return c.promoter.OnHit(n, c.sim.buildings[n], c._party[n]);
        }
        // Building n's grid, made on its first hit (a cells_promoted event for the view).

        public static Carving.Grid Promote(Carving c, long n)
        {
            if (c.grids.Has(n))
            {
                return c.grids[n];
            }
            var b = c.sim.buildings[n];
            var cells = CellsOf(c, n);
            var g = new Carving.Grid();
            var f = new VoxelFrame(new Vector3i(b.w, b.height, b.d), cells.res, c._materials);
            f.Adopt(cells.dims, cells.offset, cells.cells);
            g.frame = f;
            if (Gd.Is<LandmarkCells>(cells) && ((cells as LandmarkCells)).arcs != null)
            {
                g.ring = (LandmarkCells)(cells);
            }
            g.bw = b.w;
            g.bd = b.d;
            g.floors = b.height;
            g.hp = b.frame.maxHp;
            g.cx = _Owners(f.w, f.offset.x, f.res, b.w);
            g.cz = _Owners(f.d, f.offset.z, f.res, b.d);
            g.fy = _Owners(f.h, f.offset.y, f.res, b.height);
            g.wear.Resize(f.w * f.d * b.height);
            long chunks = b.w * b.d * b.height;
            g.full = CarvingCells.Counts(g, chunks);
            g.dead.Resize(chunks);
            g.live = g.full.Duplicate();
            foreach (long ci in Gd.Range(chunks))
            {
                g.dead[ci] = Gd.Int(!(b.frame.Alive(Carving._ChunkCell(g, ci))));
            }
            c.grids[n] = g;
            _Announce(c, n, cells, f);
            return g;
        }
        // The cells_promoted event: the view builds the building's fine cells from it.

        public static void _Announce(Carving c, long n, CellGrid cells, VoxelFrame f)
        {
            c.sim.events.Append(new GDict { { "type", "cells_promoted" }, { "building", n }, { "dims", cells.dims }, { "offset", cells.offset }, { "cells", f.aliveCount } });
        }
        // Grid coordinate along one axis -> the chunk that owns it (clamped to the building).

        public static PackedInt32Array _Owners(long size, long offset, long res, long count)
        {
            var @out = new PackedInt32Array();
            @out.Resize(size);
            foreach (long g in Gd.Range(size))
            {
                @out[g] = Gd.Clampi(Gd.Floori(Gd.Float(g + offset) / res), 0, count - 1);
            }
            return @out;
        }

        void _InitFields()
        {
        }
        public CarvingPromote() { _InitFields(); }
    }
}
