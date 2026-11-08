// Generated from sim/standing_chunks.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class StandingChunks : RefCounted
    {
        public static implicit operator StandingChunks(Variant v) => (StandingChunks)v.Obj;

        // Split from RampageSim (its 400-line cap): where the standing city is nearest.
        // Nearest standing ground-floor chunk in the arena to `from` (an attacker's goal), or INF.

        public static Vector2 Nearest(RampageSim sim, Vector2 from)
        {
            var best = new Vector2(Gd.INF, Gd.INF);
            double bestD = Gd.INF;
            foreach (RampageSim.Building b in sim.buildings)
            {
                if ((b.frame.aliveCount == 0 || !b.inArena))
                {
                    continue;
                }
                foreach (long x in Gd.Range(b.w))
                {
                    foreach (long z in Gd.Range(b.d))
                    {
                        if (b.frame.Alive(new Vector3i(x, 0, z)))
                        {
                            var p = b.ChunkWorld(new Vector3i(x, 0, z));
                            double d = from.DistanceSquaredTo(new Vector2(p.x, p.z));
                            if (d < bestD)
                            {
                                bestD = d;
                                best = new Vector2(p.x, p.z);
                            }
                        }
                    }
                }
            }
            return best;
        }

        void _InitFields()
        {
        }
        public StandingChunks() { _InitFields(); }
    }
}
