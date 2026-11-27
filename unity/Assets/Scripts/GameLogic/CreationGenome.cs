// What happens in the dish of Kaiju Creation (scenes/creation_genome.gd, D-207): the picked genome, a double
// helix of blocks lying on the agar, and its takeover. On the strike, forked lightning crawls out from the needle
// across the dish (seeded branching paths of glowing blocks, flickering); each genome block it reaches turns dark
// (the kaiju's scales), those under its path burning on as white veins. At the overload the whole dish burns
// white. Step for step as Godot's, on the same seeded stream; the view colours the states. Cells are the set's
// grid (dish space, Godot axes).
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class CreationGenome
    {
        // A helix block: the genome's own glowing colour, the charred scales, or white-hot.
        public const int GENOME = 0, SCALES = 1, HOT = 2;
        // A bolt block: white-hot, its flicker's violet, or Special K's violet at the front.
        public const int BOLT_HOT = 0, BOLT_DIM = 1, BOLT_JUICE = 2;
        // _build_bolt: how far a branch's heading wanders a step, and how far a fork turns off it.
        const float WANDER = 0.3f, FORK_LO = 0.6f, FORK_HI = 1.1f;
        // takeover: the light flickers between FLICKER_LO and 1, and grows to full over a quarter of it.
        const double FLICKER_LO = 0.6, FLICKER_SPAN = 0.4, GROW_RATE = 4.0, GROW_BASE = 0.6;
        // overload: the helix burns white from the middle out by two thirds of it; the light triples.
        const double BURN_RATE = 1.5, OVERLOAD_GAIN = 2.0;
        const int HELIX_ROWS = 2, BOLT_LIFT = 2;

        public readonly List<Vector3i> Helix = new List<Vector3i>(), Bolt = new List<Vector3i>();
        // Each block's state (the constants above), how many show, and the dish light's energy.
        public int[] HelixState, BoltState;
        public int HelixShown, BoltShown;
        public double Light;

        readonly List<int> boltStep = new List<int>();
        float[] turnAt;
        bool[] vein;
        int maxStep = 1, tick;
        readonly RandomNumberGenerator rng;
        readonly GDict cfg;

        public CreationGenome()
        {
            cfg = CreationLab.Cfg();
            GDict dish = cfg["dish"];
            rng = Seeds.Make("creation_bolt", 0);
            int surface = (int)Gd.Roundi(DishToSet(Num.F(dish["surface_y"])));
            BuildHelix(surface);
            GDict glass = dish["glass"];
            BuildBolt(surface, (int)Gd.Floori(DishToSet(Num.F(glass["inner"]))) - 1);
            TimeTakeover();
        }

        // creation_set.gd dish_to_set: the dish's sizes are in the cradle's finer cells.
        double DishToSet(double cells)
        {
            GDict props = cfg["props"];
            GDict cradle = props["cradle"];
            return cells * Num.F(cradle["voxel"]) / Num.F(cfg["voxel"]);
        }

        static long R2(Vector3i c) => c.x * c.x + c.z * c.z;

        // _build_helix: two strands winding round a line across the dish, low over the agar, with rungs between.
        void BuildHelix(int surface)
        {
            GDict h = cfg["helix"];
            int length = (int)Num.I(h["length"]), every = (int)Num.I(h["rung_every"]);
            double radius = Num.F(h["radius"]), turns = Num.F(h["turns"]);
            var seen = new HashSet<Vector3i>();
            var order = new List<Vector3i>();
            void Put(Vector3i c)
            {
                if (seen.Add(c)) order.Add(c);
            }
            for (int i = 0; i < length; i++)
            {
                long x = i - Gd.Floori(length * 0.5);
                double phase = Gd.TAU * turns * i / length;
                foreach (double side in new[] { 0.0, Math.PI })
                {
                    long z = Gd.Roundi(Math.Cos(phase + side) * radius);
                    long y = surface + Gd.Roundi((1.0 + Math.Sin(phase + side)) * radius * 0.25);
                    for (int dy = 0; dy < HELIX_ROWS; dy++) Put(new Vector3i(x, y + dy, z));
                }
                if (i % every != 0) continue;
                long reach = Gd.Roundi(Math.Abs(Math.Cos(phase)) * radius);
                for (long z = -reach; z <= reach; z++) Put(new Vector3i(x, surface + 1, z));
            }
            Vector3i[] cells = order.ToArray();
            GodotSort.Sort(cells, cells.Length, (a, b) => R2(a) < R2(b));
            Helix.AddRange(cells);
            HelixState = new int[Helix.Count];
        }

        // _build_bolt: seeded branching paths from the needle's touch out across the agar, each branch stepping a
        // cell at a time, wandering, sometimes forking, until the dish's edge or the cell budget.
        void BuildBolt(int surface, int radius)
        {
            GDict b = cfg["bolt"];
            double fork = Num.F(b["fork_chance"]), branches = Num.F(b["branches"]);
            int budget = (int)Num.I(b["max_cells"]);
            var tips = new Queue<(Vector2 at, double angle, int step)>();
            for (int k = 0; k < (int)Num.I(b["branches"]); k++)
                tips.Enqueue((Vector2.ZERO, Gd.TAU * k / branches + rng.RandfRange(-WANDER, WANDER), 0));
            var seen = new HashSet<Vector3i>();
            while (tips.Count > 0 && Bolt.Count < budget)
            {
                (Vector2 at, double heading, int last) = tips.Dequeue();
                double angle = heading + rng.RandfRange(-WANDER, WANDER);
                int step = last + 1;
                Vector2 next = at + Vector2.FromAngle(angle);
                if (next.Length() > radius) continue;
                var cell = new Vector3i(Gd.Roundi(next.x), surface + BOLT_LIFT, Gd.Roundi(next.y));
                if (seen.Add(cell))
                {
                    Bolt.Add(cell);
                    boltStep.Add(step);
                    maxStep = Math.Max(maxStep, step);
                }
                tips.Enqueue((next, angle, step));
                if (rng.Randf() < fork)
                    tips.Enqueue((next, angle + rng.RandfRange(FORK_LO, FORK_HI) * Gd.Signf(rng.Randf() - 0.5), step));
            }
            BoltState = new int[Bolt.Count];
        }

        // _time_takeover: each genome block turns when the nearest bolt block within reach is struck (its step),
        // else at the overload (a step past the last); those right under the path burn on as veins.
        void TimeTakeover()
        {
            GDict b = cfg["bolt"];
            int reach = (int)Num.I(b["convert_reach"]), veinReach = (int)Num.I(b["vein_reach"]);
            var grid = new Dictionary<(long, long), int>();
            for (int i = 0; i < Bolt.Count; i++)
            {
                var key = (Bolt[i].x, Bolt[i].z);
                grid[key] = grid.TryGetValue(key, out int s) ? Math.Min(s, boltStep[i]) : boltStep[i];
            }
            turnAt = new float[Helix.Count];
            vein = new bool[Helix.Count];
            for (int i = 0; i < Helix.Count; i++)
            {
                int best = maxStep + 1;
                for (int dx = -reach; dx <= reach; dx++)
                    for (int dz = -reach; dz <= reach; dz++)
                    {
                        if (!grid.TryGetValue((Helix[i].x + dx, Helix[i].z + dz), out int s)) continue;
                        best = Math.Min(best, s);
                        if (Math.Abs(dx) <= veinReach && Math.Abs(dz) <= veinReach) vein[i] = true;
                    }
                turnAt[i] = (float)((double)best / (maxStep + 1));
            }
        }

        // settle: the genome settles into the agar from the centre out (t 0..1).
        public void Settle(double t) => HelixShown = (int)Gd.Roundi(Helix.Count * Gd.Clampf(t, 0.0, 1.0));

        // creation_lab.gd takeover's part for the dish (t 0..1 of the takeover): still through the strike's
        // hit-stop, the lightning up to the overload, nothing through its hit-stop, then the overload.
        public void Step(double t)
        {
            GDict timing = Content.Section("creation")["timing"];
            double freeze = Num.F(cfg["freeze_s"]) / Num.F(timing["takeover_s"]);
            double ov = Num.F(cfg["overload_at"]);
            if (t < freeze) Takeover(0.0);
            else if (t < ov) Takeover((t - freeze) / (ov - freeze));
            else if (t >= ov + freeze) Overload((t - ov - freeze) / (1.0 - ov - freeze));
        }

        // takeover (p 0..1): the bolt reaches out step by step, flickering, its front Special K's violet; each
        // genome block it has reached chars to the scales, those under its path burn on white.
        void Takeover(double p)
        {
            GDict b = cfg["bolt"];
            tick++;
            double now = p * (maxStep + 1);
            int shown = 0;
            while (shown < Bolt.Count && boltStep[shown] <= now) shown++;
            BoltShown = shown;
            if (tick % (int)Num.I(b["flicker_ticks"]) == 0)
            {
                double share = Num.F(b["flicker_share"]);
                for (int i = 0; i < shown; i++) BoltState[i] = rng.Randf() < share ? BOLT_DIM : BOLT_HOT;
            }
            double front = Num.F(b["front_steps"]);
            for (int i = 0; i < shown; i++)
                if (boltStep[i] > now - front) BoltState[i] = BOLT_JUICE;
            for (int i = 0; i < Helix.Count; i++)
                if (p >= turnAt[i]) HelixState[i] = vein[i] ? HOT : SCALES;
            double flicker = FLICKER_LO + FLICKER_SPAN * rng.Randf();
            double grow = Math.Min(p * GROW_RATE, 1.0) * (GROW_BASE + p);
            Light = CreationLab.Energy("bolt") * flicker * grow;
        }

        // overload (o 0..1): every genome and bolt block burns white and the dish floods the lab.
        void Overload(double o)
        {
            BoltShown = Bolt.Count;
            int upto = (int)Gd.Roundi(Helix.Count * Gd.Clampf(o * BURN_RATE, 0.0, 1.0));
            for (int i = 0; i < upto; i++) HelixState[i] = HOT;
            for (int i = 0; i < Bolt.Count; i++) BoltState[i] = BOLT_HOT;
            Light = CreationLab.Energy("bolt") * (1.0 + OVERLOAD_GAIN * o);
        }
    }
}
