// Generated from sim/fall_contact.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class FallContact : RefCounted
    {
        public static implicit operator FallContact(Variant v) => (FallContact)v.Obj;

        // What a falling part runs into on its way down (director 2026-11-03: a falling building never
        // passes through a standing neighbour or the kaiju). Each tick the part's chunks are placed where
        // the view draws them (the topple's tilt curve, ToppleFx, and the drop's fall) and sampled (centre
        // and corners, inset) against two volumes:
        // - a standing neighbour's live chunks: the part carves them (city impact_damage, a landing's
        // blow); a chunk that survives the blow stops the part there, and it breaks up against it;
        // - the kaiju's hide (a rigid capsule round his body, never deformed): the part breaks up
        // against him at once and its fragments fall off him (KaijuHide in the view).
        // Tuning: fall_contact. Part of Collapse; deterministic, no randomness.
        // The tilt (radians) t seconds into a topple the sim times at `duration` (tuning topple_fx): a
        // shudder that creeps to lean_deg, then a lean that accelerates (sinh) to 90 deg at `duration`.
        // `wobble` false: the shudder's lean alone (what contact reads, below).

        public static double Tilt(GDict cfg, double t, double duration, bool wobbleOn = true)
        {
            double shudder = Gd.Minf(Num.F(cfg["shudder_s"]), duration * Num.F(cfg["shudder_max_share"]));
            double lean = Gd.DegToRad(Num.F(cfg["lean_deg"]));
            if (t < shudder)
            {
                double k = t / shudder;
                if (!wobbleOn)
                {
                    return lean * k * k;
                }
                double wobble = (Gd.Sin(t * Gd.TAU * Num.F(cfg["shudder_hz"])) * Gd.DegToRad(Num.F(cfg["shudder_deg"])));
                return lean * k * k + wobble * (1.0 - k * 0.5);
            }
            double u = Gd.Clampf((t - shudder) / Gd.Maxf(0.001, duration - shudder), 0.0, 1.0);
            double c = Num.F(cfg["lean_curve"]);
            return lean + (Gd.PI * 0.5 - lean) * Gd.Sinh(c * u) / Gd.Sinh(c);
        }
        // The part's pose at t: world = pose * (chunk centre - pivot). A topple turns about the level
        // axis across its direction (FallMotion's); both kinds fall their drop with the square of time.
        // Contact reads it without the shudder's wobble (`wobble` false): its +-shudder_deg throes
        // against a wall the tower shares are not a fall into it, and would stop it on its first tick.

        public static Transform3D Pose(RampageSim.Fall f, double t, GDict toppleCfg, bool wobble = true)
        {
            double k = Gd.Clampf(t / Gd.Maxf(0.05, f.duration), 0.0, 1.0);
            var origin = f.pivot - new Vector3(0, f.drop * k * k, 0);
            if (f.kind != "topple")
            {
                return new Transform3D(Basis.IDENTITY, origin);
            }
            var axis = new Vector3(f.dir.y, 0, -f.dir.x);
            if (axis.IsZeroApprox())
            {
                axis = Vector3.RIGHT;
            }
            return new Transform3D(new Basis(axis.Normalized(), Tilt(toppleCfg, t, f.duration, wobble)), origin);
        }
        // The kaiju's hide: [foot centre, head centre, radius] (a capsule, world).

        public static GArray<Variant> Hide(RampageSim sim, GDict cfg)
        {
            double r = Num.F(sim.powersCfg["body_radius"]) * sim.BodyScale() * Num.F(cfg["hide_radius"]);
            double tall = Gd.Maxf(sim.ReachHeight() * Num.F(cfg["hide_height"]), 2.0 * r);
            var foot = new Vector3(sim.kaijuPos.x, sim.standY + r, sim.kaijuPos.y);
            return Gd.Arr(foot, foot + new Vector3(0, tall - 2.0 * r, 0), r);
        }
        // How deep point p is inside capsule `cap` (hide()); <= 0 outside.

        public static double HideDepth(Vector3 p, GArray<Variant> cap)
        {
            Vector3 a = cap[0];
            Vector3 b = cap[1];
            var on = a + (b - a) * Gd.Clampf((p - a).Dot(b - a) / Gd.Maxf(1e-6, (b - a).LengthSquared()), 0, 1);
            return Num.F(cap[2]) - p.DistanceTo(on);
        }
        // How deep point p is inside a live chunk of building b; <= 0 outside every one.

        public static double ChunkDepth(RampageSim.Building b, Vector3 p)
        {
            var local = new Vector3(p.x - (b.x - b.w * 0.5), p.y - b.@base, p.z - (b.z - b.d * 0.5));
            var c = new Vector3i(Gd.Floori(local.x), Gd.Floori(local.y), Gd.Floori(local.z));
            if ((c.x < 0 || c.y < 0 || c.z < 0 || c.x >= b.w || c.y >= b.height || c.z >= b.d))
            {
                return 0.0;
            }
            if (!b.frame.Alive(c))
            {
                return 0.0;
            }
            var f = local - new Vector3(c);
            return Gd.Minf(Gd.Minf(Gd.Minf(f.x, 1.0 - f.x), Gd.Minf(f.y, 1.0 - f.y)), Gd.Minf(f.z, 1.0 - f.z));
        }
        // The sample points of a part's chunks at `xf` (centre and 8 corners pulled in by `inset`),
        // only of chunks whose centre lies inside `within` (what it may touch, grown by a chunk):
        // [points, the same points where the fall began] (no tilt, no drop). What a point already
        // touched as it began (the base he chewed, a wall it leant on) never counts as running into it.

        public static GArray<PackedVector3Array> Samples(RampageSim.Fall f, RampageSim.Building b, Transform3D xf, double inset, AABB within)
        {
            var @out = new PackedVector3Array();
            var was = new PackedVector3Array();
            var start = new Transform3D(Basis.IDENTITY, f.pivot);
            double h = 0.5 - inset;
            foreach (Vector3i c in f.cells)
            {
                var rel = b.ChunkWorld(c) - f.pivot;
                if (!within.HasPoint(xf * rel))
                {
                    continue;
                }
                foreach (long k in Gd.Range(9))
                {
                    var off = Vector3.ZERO;
                    if (k < 8)
                    {
                        off = new Vector3((Gd.Truthy((k & 1)) ? h : -h), (Gd.Truthy((k & 2)) ? h : -h), (Gd.Truthy((k & 4)) ? h : -h));
                    }
                    @out.Append(xf * (rel + off));
                    was.Append(start * (rel + off));
                }
            }
            return new GArray<PackedVector3Array> { @out, was };
        }
        // What part f runs into this tick (f.t already advanced by dt): {} for nothing, else
        // {"contact": "kaiju"} or {"contact": "building"} (a chunk survived its blow). Neighbour chunks
        // it reaches are carved on the way. On a contact f.t is set back to the moment of first touch
        // (bisected over the tick, bisect steps), so it stops on the surface, not a tick's sweep inside.

        public static GDict Step(RampageSim sim, RampageSim.Fall f, GDict cfg, GDict toppleCfg, double dt)
        {
            if (f.cells.IsEmpty())
            {
                return new GDict();
            }
            GDict hit = Probe(sim, f, f.t, cfg, toppleCfg, true);
            if (hit.IsEmpty())
            {
                return hit;
            }
            double lo = Gd.Maxf(0.0, f.t - dt);
            double hi = f.t;
            foreach (long _k in Gd.Range(Num.I(cfg["bisect"])))
            {
                double mid = (lo + hi) * 0.5;
                if (Probe(sim, f, mid, cfg, toppleCfg, false).IsEmpty())
                {
                    lo = mid;
                }
                else
                {
                    hi = mid;
                }
            }
            // the last pose clear of it: the view shatters the part there
            f.t = lo;
            return hit;
        }
        // What f touches at time t (`carve`: neighbour chunks it reaches take a landing's blow first).

        public static GDict Probe(RampageSim sim, RampageSim.Fall f, double t, GDict cfg, GDict toppleCfg, bool carve)
        {
            var own = sim.buildings[f.building];
            var xf = Pose(f, t, toppleCfg, false);
            // its whole box first: most ticks touch nothing and stop here
            var box = xf * _Span(f, own);
            var lo = box.position;
            var hi = box.end;
            GArray<Variant> cap = Hide(sim, cfg);
            Vector3 a = cap[0];
            Vector3 b = cap[1];
            double r = Num.F(cap[2]);
            var nearKaiju = (lo.x < a.x + r && hi.x > a.x - r && lo.z < a.z + r && hi.z > a.z - r && lo.y < b.y + r && hi.y > a.y - r);
            GArray<long> near = new GArray<long>();
            // Neighbours from the first tick: the shudder creeps to lean_deg, which on a tall tower puts
            // its upper floors more than a chunk into a neighbour beside it (read without the wobble, and
            // a point that began inside a wall it shares never counts).
            if (f.kind == "topple")
            {
                foreach (long i in sim.grid.InRect(new Vector2(lo.x, lo.z), new Vector2(hi.x, hi.z)))
                {
                    var nb = sim.buildings[i];
                    if ((i == f.building || lo.y > nb.@base + nb.height))
                    {
                        continue;
                    }
                    if ((hi.x < nb.x - nb.w * 0.5 || lo.x > nb.x + nb.w * 0.5))
                    {
                        continue;
                    }
                    if ((hi.z < nb.z - nb.d * 0.5 || lo.z > nb.z + nb.d * 0.5))
                    {
                        continue;
                    }
                    near.Append(i);
                }
            }
            if (!nearKaiju && near.IsEmpty())
            {
                return new GDict();
            }
            var within = new AABB();
            var first = true;
            if (nearKaiju)
            {
                within = new AABB(new Vector3(a.x - r, a.y - r, a.z - r), new Vector3(2 * r, b.y - a.y + 2 * r, 2 * r));
                first = false;
            }
            foreach (long i in near)
            {
                var nb = sim.buildings[i];
                var nbox = new AABB(new Vector3(nb.x - nb.w * 0.5, nb.@base, nb.z - nb.d * 0.5), new Vector3(nb.w, nb.height, nb.d));
                within = (first ? nbox : within.Merge(nbox));
                first = false;
            }
            var both = Samples(f, own, xf, Num.F(cfg["inset"]), within.Grow(0.9));
            var pts = both[0];
            var was = both[1];
            if (nearKaiju)
            {
                foreach (long n in Gd.Range(pts.Size()))
                {
                    if (HideDepth(pts[n], cap) > 0.0 && HideDepth(was[n], cap) <= 0.0)
                    {
                        return new GDict { { "contact", "kaiju" } };
                    }
                }
            }
            double blow = Num.F(sim.city["impact_damage"]);
            foreach (long i in near)
            {
                var nb = sim.buildings[i];
                GArray<Vector3i> hit = new GArray<Vector3i>();
                foreach (long n in Gd.Range(pts.Size()))
                {
                    var p = pts[n];
                    if (ChunkDepth(nb, p) > 0.0 && ChunkDepth(nb, was[n]) <= 0.0)
                    {
                        var c = new Vector3i(Gd.Floori(p.x - (nb.x - nb.w * 0.5)), Gd.Floori(p.y - nb.@base), Gd.Floori(p.z - (nb.z - nb.d * 0.5)));
                        if (!hit.Has(c))
                        {
                            hit.Append(c);
                        }
                    }
                }
                if (hit.IsEmpty())
                {
                    continue;
                }
                if (carve)
                {
                    sim.DamageChunks(i, hit, blow);
                }
                foreach (Vector3i c in hit)
                {
                    if (nb.frame.Alive(c))
                    {
                        return new GDict { { "contact", "building" }, { "with", i } };
                    }
                }
            }
            return new GDict();
        }
        // The local box (relative to the pivot, sim units) round all of f's chunks.

        public static AABB _Span(RampageSim.Fall f, RampageSim.Building b)
        {
            var lo = new Vector3(Gd.INF, Gd.INF, Gd.INF);
            var hi = -lo;
            foreach (Vector3i c in f.cells)
            {
                var p = b.ChunkWorld(c) - f.pivot;
                lo = lo.Min(p);
                hi = hi.Max(p);
            }
            return new AABB(lo - Vector3.ONE * 0.5, hi - lo + Vector3.ONE);
        }

        void _InitFields()
        {
        }
        public FallContact() { _InitFields(); }
    }
}
