// Generated from sim/endless.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Endless : RefCounted
    {
        public static implicit operator Endless(Variant v) => (Endless)v.Obj;

        // The demo's Endless mode (D-156): a separate mode, unlocked by the final upgrade, in which the
        // city regrows slowly while the military escalates without end and no clock or fall ends the
        // run; only the kaiju's defeat or End Rampage does. Its tunables are their own rows
        // (data/tuning.json "demo.endless"): this class is only ever created for an endless run, so
        // normal mode never reads them (the balance is decided by normal mode, DESIGN.md).
        // Buildings regrown so far (the view and the tests read it).
        public long regrown = 0;
        public double _timer;
        public long _cursor = 0;
        // buildings earned back by the share-a-minute rule, not yet regrown
        public double _owed = 0.0;

        public Endless()
        {
            _InitFields();
            _timer = Num.F(Cfg()["regrow_interval"]);
        }

        public static GDict Cfg()
        {
            return Content.Section("demo")["endless"];
        }
        // Extra chunks' worth of escalation an endless `sim` has built up by its elapsed time: a share of
        // the city's chunk total (start_share), growing by share_per_second of it, with no cap, so the
        // army keeps worsening past the full ruin however big the city is. 0 in a normal run.

        public static long Escalation(RampageSim sim)
        {
            if (sim.endless == null)
            {
                return 0;
            }
            GDict c = Cfg();
            double share = Num.F(c["start_share"]) + Num.F(c["share_per_second"]) * sim.elapsed;
            return Gd.Floori(Num.F(sim.chunksTotal) * share);
        }
        // True when the army may not field another tank (endless caps those alive at once; a toppled
        // one is out of the fight and does not count, TankFlight).

        public static bool TanksFull(RampageSim sim)
        {
            if (sim.endless == null)
            {
                return false;
            }
            var fighting = sim.tanks.Filter(new Callable(a_ =>
            {
                RampageSim.Tank t = a_[0];
                return !t.toppled;
            }));
            return fighting.Size() >= Num.I(Cfg()["max_tanks"]);
        }
        // Why `sim` ends now, or "": endless ignores the clock and the city's fall.

        public static string OverReason(RampageSim sim)
        {
            if (sim.endless == null && sim.chunksDestroyed >= sim.chunksTotal)
            {
                return "city_fallen";
            }
            if (sim.hp <= 0.0)
            {
                return "defeated";
            }
            return (sim.endless == null && sim.timeLeft <= 0.0 ? "time" : "");
        }
        // One step of an endless run (nothing in a normal one): the regrowth clock.

        public static void Step(RampageSim sim, double dt)
        {
            if (sim.endless != null)
            {
                sim.endless.RegrowStep(sim, dt);
            }
        }
        // Every regrow_interval seconds, regrow_share_per_minute of the flattened buildings come back
        // (the fractions carry over), so there is always something new to wreck at any city size.

        public void RegrowStep(RampageSim sim, double dt)
        {
            _timer -= dt;
            if (_timer > 0.0)
            {
                return;
            }
            double every = Num.F(Cfg()["regrow_interval"]);
            _timer = every;
            _owed += (sim.collapse.DestroyedBuildings() * Num.F(Cfg()["regrow_share_per_minute"]) * every / 60.0);
            long left = Gd.Floori(_owed);
            long n = sim.buildings.Size();
            foreach (long k in Gd.Range(n))
            {
                long i = (_cursor + k) % n;
                if (left > 0 && Regrowable(sim, i))
                {
                    Regrow(sim, i);
                    left -= 1;
                    _owed -= 1.0;
                    _cursor = i + 1;
                }
            }
        }
        // True when building `i` is gone (every chunk, the sim's ruin rule), plain, in the arena, with
        // nothing falling from it and the kaiju well clear.

        public bool Regrowable(RampageSim sim, long i)
        {
            var b = sim.buildings[i];
            if ((b.landmark != "" || b.IsSpan() || !b.inArena || b.frame.aliveCount > 0))
            {
                return false;
            }
            foreach (RampageSim.Fall f in sim.falls)
            {
                if (f.building == i)
                {
                    return false;
                }
            }
            return new Vector2(b.x, b.z).DistanceTo(sim.kaijuPos) > Num.F(Cfg()["regrow_clear"]);
        }
        // Stands building `i` whole again: a fresh chunk structure, no fine grid, the destroyed count
        // taken back, and no fire, pay or topple state left from its first life. The view rebuilds it on
        // the "building_regrown" event.

        public void Regrow(RampageSim sim, long i)
        {
            var b = sim.buildings[i];
            b.frame = new Structure(b.w, b.d, b.height, b.frame.maxHp);
            // a pool building keeps only its model's chunks (Landmarks.building)
            if (b.model != "")
            {
                GDict row = ModelVariant.RowOf(b.model);
                if (!row.IsEmpty())
                {
                    b.frame.Keep(ModelVariant.Chunks(row, b.variant));
                }
            }
            sim.carving.grids.Erase(i);
            sim.carving.promoter.Forget(i);
            sim.chunksDestroyed = Gd.Maxi(0, sim.chunksDestroyed - b.startChunks);
            sim.powers.fire.ResetBuilding(i);
            sim.collapse.ForgetTopple(i);
            regrown += 1;
            sim.events.Append(new GDict { { "type", "building_regrown" }, { "building", i } });
        }

        void _InitFields()
        {
        }
    }
}
