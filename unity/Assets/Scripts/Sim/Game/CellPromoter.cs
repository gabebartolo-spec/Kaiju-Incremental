// Generated from sim/cell_promoter.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class CellPromoter : RefCounted
    {
        public static implicit operator CellPromoter(Variant v) => (CellPromoter)v.Obj;

        // Lazy promotion to the fine destruction grid (D-094): a building stays on its chunk Structure
        // until its first hit; then its BuildingCells grid is made, once, with every chunk the
        // Structure has already lost emptied, and kept for every later hit. A whole city of fine grids
        // would be ~100 MB (docs/research/DESTRUCTION_SPIKE.md), so only buildings the kaiju touches
        // pay for one. A landmark or a pool building (CityPool) gets a LandmarkCells grid (its baked
        // model, and the arcs of a ring); a red-barrel site a HazardCells; a building a BuildingCells.
        // RampageSim promotes through Carving (WP7).
        // How many buildings past the one warming have their cells made ahead on workers (tuning
        // warm_ahead; WarmOrder.ahead).
        public long ahead = 0;
        // Building index -> BuildingCells, LandmarkCells or HazardCells, for the buildings hit so far.
        public GDict grids = new GDict();
        // Cells made ahead of their first use (prepare), by building; dropped (drop_ready) once they
        // could go stale. Not in `grids`, so nothing that asks what is promoted sees them.
        public GDict ready = new GDict();
        // Building index -> [WorkerThreadPool task, [its BuildingCells]], for cells started ahead (start).
        public GDict _jobs = new GDict();

        public bool Promoted(long n)
        {
            return grids.Has(n);
        }
        // The fine grid of building n, or null while it has not been hit.

        public CellGrid Grid(long n)
        {
            return grids.Get(n, default(Variant));
        }
        // Makes building n's cells now (the work on_hit would do) and keeps them for its first on_hit.

        public void Prepare(long n, RampageSim.Building b, GDict party)
        {
            if ((grids.Has(n) || ready.Has(n)))
            {
                return;
            }
            ready[n] = OnHit(n, b, party);
            grids.Erase(n);
        }
        public void Prepare(long n, RampageSim.Building b) => Prepare(n, b, new GDict());
        // Starts building n's cells on a worker thread (Carving.warm's look-ahead); its first on_hit
        // waits for them. Only a plain building's: their making reads nothing the run changes (its
        // shape, style and party walls; the native generator holds no state), and the chunks it has
        // lost are cleared on the main thread when they are taken, so they come out the same as made
        // then. A landmark or hazard (its arcs, its own models) is made on the main thread as before.

        public void Start(long n, RampageSim.Building b, GDict party)
        {
            if ((grids.Has(n) || ready.Has(n) || _jobs.Has(n)))
            {
                return;
            }
            if ((b.landmark != "" || b.model != "" || b.hazard != ""))
            {
                return;
            }
            // the shared generator is made here, on the main thread
            VoxelSupport.Native();
            GArray<Variant> @out = Gd.Arr(default(Variant));
            var job = new Callable(a_ =>
            {
                @out[0] = new BuildingCells(b, party);
                return default(Variant);
            });
            long task = WorkerWait.Add(WorkerThreadPool.AddTask(job, true));
            _jobs[n] = Gd.Arr(task, @out);
        }
        // Building n changed under its cells (Endless regrows it): waits out and drops what was made.

        public void Forget(long n)
        {
            if (_jobs.Has(n))
            {
                _Take(n);
            }
            grids.Erase(n);
            ready.Erase(n);
        }

        public BuildingCells _Take(long n)
        {
            GArray<Variant> job = _jobs[n];
            _jobs.Erase(n);
            WorkerWait.Wait(Num.I(job[0]));
            GArray<Variant> @out = job[1];
            return @out[0];
        }
        // Forgets every prepared grid not yet used (the buildings may change from here on).

        public void DropReady()
        {
            ready.Clear();
        }
        // Building n (b) was hit: its fine grid, made now if this is the first hit. party: as
        // BuildingCells' (a landmark takes none; the floors a neighbour covers per side).

        public CellGrid OnHit(long n, RampageSim.Building b, GDict party)
        {
            if (grids.Has(n))
            {
                return grids[n];
            }
            // made at load (prepare): the same cells, nothing has touched it since
            if (ready.Has(n))
            {
                grids[n] = ready[n];
                ready.Erase(n);
                return grids[n];
            }
            var cells = _Make(n, b, party);
            if (b.frame != null)
            {
                foreach (long y in Gd.Range(b.frame.h))
                {
                    foreach (long z in Gd.Range(b.frame.d))
                    {
                        foreach (long x in Gd.Range(b.frame.w))
                        {
                            if (!(b.frame.Alive(new Vector3i(x, y, z))))
                            {
                                cells.ClearChunk(new Vector3i(x, y, z));
                            }
                        }
                    }
                }
            }
            // sections the chunks already shed are not new losses
            if (Gd.Is<LandmarkCells>(cells))
            {
                ((cells as LandmarkCells)).Rebase();
            }
            grids[n] = cells;
            return cells;
        }
        public CellGrid OnHit(long n, RampageSim.Building b) => OnHit(n, b, new GDict());
        // Building n's fresh grid: its own kind's cells, or the ones started ahead on a worker.

        public CellGrid _Make(long n, RampageSim.Building b, GDict party)
        {
            // a landmark or a pool building (D-253)
            if ((b.landmark != "" || b.model != ""))
            {
                return new LandmarkCells(b);
            }
            if (b.hazard != "")
            {
                // a red barrel: its own model (HazardShape)
                return new HazardCells(b);
            }
            // started ahead on a worker (start)
            if (_jobs.Has(n))
            {
                return _Take(n);
            }
            return new BuildingCells(b, party);
        }

        void _InitFields()
        {
        }
        public CellPromoter() { _InitFields(); }
    }
}
