// Generated from sim/warm_order.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class WarmOrder : RefCounted
    {
        public static implicit operator WarmOrder(Variant v) => (WarmOrder)v.Obj;

        // Which building Carving.warm() makes ready next (b2-3), split out to keep carving.gd small.
        // The unpromoted carvable building nearest the kaiju whose nearest edge is within its strike
        // reach plus `margin` (-1: none). Nearest first, ties by building index: the same order for the
        // same run.

        public static long NextCold(Carving carving, GArray<RampageSim.Building> buildings, double margin)
        {
            var sim = carving.sim;
            double reach = Gd.Maxf(2.0 * sim.StompRadius(), sim.AbilityReach()) + margin;
            long best = -1;
            double bestD = Gd.INF;
            foreach (long n in sim.grid.Around(sim.kaijuPos, reach + 2.0 * sim.grid.pad))
            {
                if ((carving.Promoted(n) || !carving.Takes(n)))
                {
                    continue;
                }
                var b = buildings[n];
                double d = new Vector2(b.x, b.z).DistanceTo(sim.kaijuPos);
                if ((d - new Vector2(b.w, b.d).Length() * 0.5 > reach || d >= bestD))
                {
                    continue;
                }
                best = n;
                bestD = d;
            }
            return best;
        }
        // Up to `count` unpromoted carvable buildings within the same reach as next_cold, nearest first
        // (ties by building index).

        public static GArray<long> Cold(Carving carving, GArray<RampageSim.Building> buildings, double margin, long count)
        {
            var sim = carving.sim;
            double reach = Gd.Maxf(2.0 * sim.StompRadius(), sim.AbilityReach()) + margin;
            // (distance, index)
            GArray<Vector2> found = new GArray<Vector2>();
            foreach (long n in sim.grid.Around(sim.kaijuPos, reach + 2.0 * sim.grid.pad))
            {
                if ((carving.Promoted(n) || !carving.Takes(n)))
                {
                    continue;
                }
                var b = buildings[n];
                double d = new Vector2(b.x, b.z).DistanceTo(sim.kaijuPos);
                if (d - new Vector2(b.w, b.d).Length() * 0.5 <= reach)
                {
                    found.Append(new Vector2(d, n));
                }
            }
            found.Sort();
            GArray<long> @out = new GArray<long>();
            foreach (long k in Gd.Range(Gd.Mini(count, found.Size())))
            {
                @out.Append(Gd.Int(found[k].y));
            }
            return @out;
        }
        // Starts the cells of the next promoter.ahead (warm_ahead) buildings warm() will ready (and the
        // one it is on) on worker threads (CellPromoter.start), so a tall tower's never stalls a step.
        // Only when the work runs changes: the cells are the same, and the run waits for them where
        // it needs them.

        public static void Ahead(Carving carving, double margin)
        {
            long count = carving.promoter.ahead;
            if ((count <= 0 || carving._warming < 0))
            {
                return;
            }
            if (carving._party.IsEmpty())
            {
                carving._party = PartyWalls.Of(carving.sim.buildings);
            }
            var party = carving._party;
            foreach (long n in Cold(carving, carving.sim.buildings, margin, count + 1))
            {
                carving.promoter.Start(n, carving.sim.buildings[n], party[n]);
            }
        }

        void _InitFields()
        {
        }
        public WarmOrder() { _InitFields(); }
    }
}
