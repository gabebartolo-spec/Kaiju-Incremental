// Generated from sim/collapse.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Collapse : RefCounted
    {
        public static implicit operator Collapse(Variant v) => (Collapse)v.Obj;

        // What happens after a building loses support: parts that drop straight down, towers that
        // topple over an edge, and what they smash when they land (the floors below, or a strip of
        // street, buildings and tanks). Part of RampageSim; split out to keep files small.
        public RampageSim sim;
        // Buildings that toppled over sideways (each counted once) and the tallest of them, in floors:
        // the results screen's biggest collapse.
        public long toppled = 0;
        public long tallestTopple = 0;
        public GDict _toppledIds = new GDict();
        // b2-5 (D-387): the odds a topple goes toward its cut side, to either side of it, or away from
        // it (tuning destruction.fall_dirs), drawn from the run's own stream so a replay matches.
        public PackedFloat32Array _odds = new PackedFloat32Array(Gd.Arr(1.0, 0.0, 0.0, 0.0));
        public RandomNumberGenerator _rng;
        // tuning fall_contact (FallContact); empty: falls pass through
        public GDict _contact = new GDict();
        // tuning topple_fx: the tilt curve the view draws
        public GDict _toppleCfg = new GDict();

        public Collapse(RampageSim pSim, GDict tuning, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            _rng = rng;
            _contact = tuning.Get("fall_contact", new GDict());
            _toppleCfg = tuning.Get("topple_fx", new GDict());
            GDict cfg = tuning.Get("destruction", new GDict());
            GDict dirs = cfg.Get("fall_dirs", new GDict());
            if (!dirs.IsEmpty())
            {
                double side = Num.F(dirs["side"]);
                _odds = new PackedFloat32Array(Gd.Arr(Num.F(dirs["cut"]), side, side, Num.F(dirs["away"])));
            }
        }
        // Every topple goes to its cut side (D-099's rule): for checks that measure something other
        // than the fall's direction (what a fall smashes, a walk's clearing, a ring's reach).

        public void CutOnly()
        {
            _odds = new PackedFloat32Array(Gd.Arr(1.0, 0.0, 0.0, 0.0));
        }
        // Buildings in the arena with every chunk gone (the thanks screen's "buildings destroyed").

        public long DestroyedBuildings()
        {
            long n = 0;
            foreach (RampageSim.Building b in sim.buildings)
            {
                // the sim's own ruin rule (the chunk mirror)
                if (b.inArena && b.frame.aliveCount == 0)
                {
                    n += 1;
                }
            }
            return n;
        }
        // A regrown tower may topple (and count) again.

        public void ForgetTopple(long index)
        {
            _toppledIds.Erase(index);
        }
        // Turns every part of building `index` that lost support into a Fall. A carved building's
        // parts (Carving.settle) also carry their fine cells, which the fall_start event passes on.

        public void Settle(long index)
        {
            var b = sim.buildings[index];
            double g = Num.F(sim.city["fall_gravity"]);
            var parts = (sim.carving.Promoted(index) ? sim.carving.Settle(index) : b.frame.Settle());
            foreach (GDict part in parts)
            {
                var f = _StartFall(index, b, part, g);
                sim.falls.Append(f);
                sim.events.Append(_FallEvent(f, part, index));
            }
        }
        // One falling part of a building: its cells, kind and size, and how it will move (a topple turns
        // on a pivot, a drop falls straight down).

        public RampageSim.Fall _StartFall(long index, RampageSim.Building b, GDict part, double g)
        {
            var f = new RampageSim.Fall();
            f.id = sim.nextFallId;
            sim.nextFallId += 1;
            f.building = index;
            f.cells = part["cells"];
            f.kind = Gd.Str(part["kind"]);
            long lowest = 9999;
            long highest = 0;
            foreach (Vector3i c in f.cells)
            {
                lowest = Gd.Mini(lowest, c.y);
                highest = Gd.Maxi(highest, c.y);
            }
            f.height = highest - lowest + 1;
            double low = Gd.Float(lowest);
            var carved = part.Has("index");
            // its size from its fine cells
            if (carved)
            {
                low = Num.F(part["low"]);
                f.height = Num.F(part["height"]);
                f.width = Num.F(part["width"]);
            }
            bool gutted = ((carved ? part.Get("gutted", false) : _Gutted(b, f.cells, lowest, Gd.Int(f.height))));
            if (f.kind == "drop" && b.landmark == "" && gutted)
            {
                // its whole base went at once: it goes over, it never pops
                f.kind = "topple";
                // Nothing under its hinge: it falls the gap below as it goes over, never turns in mid-air.
                f.drop = (part.Has("drop") ? Num.F(part["drop"]) : _DropDistance(b, f, low));
            }
            if (f.kind == "topple")
            {
                _StartTopple(f, b, part, low);
                f.duration = Gd.Maxf(Gd.Sqrt(2.0 * f.height / g) * 1.8, Gd.Sqrt(2.0 * f.drop / g));
            }
            else
            {
                f.drop = (part.Has("drop") ? Num.F(part["drop"]) : _DropDistance(b, f, low));
                f.pivot = b.LocalToWorld(new Vector3(b.w * 0.5, low, b.d * 0.5));
                f.duration = Gd.Sqrt(2.0 * f.drop / g);
            }
            return f;
        }
        // A toppling part's count and aim.

        public void _StartTopple(RampageSim.Fall f, RampageSim.Building b, GDict part, double low)
        {
            if (!f.cells.IsEmpty() && !_toppledIds.Has(f.building))
            {
                _toppledIds[f.building] = true;
                toppled += 1;
            }
            _AimTopple(f, b, part, low);
        }
        // Sets a toppling part's direction and pivot.

        public void _AimTopple(RampageSim.Fall f, RampageSim.Building b, GDict part, double low)
        {
            Vector2i dir = part["dir"];
            Vector3 pivot = part["pivot"];
            // D-099: its cut side is the side that was cut away (the support rule's dir). A gutted drop
            // has no rule dir: its whole base went, and the chew came from the kaiju's side. b2-5
            // (D-387): a landmark falls to its cut side; any other part draws cut, side or away.
            var cut = dir;
            var carved = part.Has("index");
            Rect2 @base = (carved ? part["base"] : _Base(f.cells, Gd.Roundi(low)));
            if (cut == Vector2i.ZERO)
            {
                var centre = b.LocalToWorld(new Vector3(@base.GetCenter().x, low, @base.GetCenter().y));
                cut = _Toward(new Vector2(centre.x, centre.z) - sim.kaijuPos);
            }
            dir = (b.landmark != "" ? cut : _Vary(cut));
            if (dir != part["dir"])
            {
                pivot = _Edge(@base, low, dir);
                if (carved)
                {
                    f.width = (dir.x != 0 ? @base.size.y : @base.size.x);
                }
            }
            f.dir = new Vector2(dir);
            f.pivot = b.LocalToWorld(pivot);
        }
        // The fall_start event of a part.

        public GDict _FallEvent(RampageSim.Fall f, GDict part, long index)
        {
            Vector2i ruleDir = part["dir"];
            GDict @event = new GDict { { "type", "fall_start" }, { "id", f.id }, { "building", index }, { "cells", f.cells }, { "kind", f.kind }, { "pivot", f.pivot }, { "dir", f.dir }, { "cut_dir", new Vector2(ruleDir) }, { "drop", f.drop }, { "duration", f.duration } };
            if (part.Has("index"))
            {
                @event["index"] = part["index"];
                @event["mats"] = part["mats"];
                // what held it at the settle
                @event["under"] = part.Get("under", false);
                @event["support"] = part.Get("support", -1);
            }
            // where it will land, so the street knows who is under it
            if (f.kind == "topple")
            {
                GArray<Variant> strip = _Strip(f);
                @event["to"] = strip[1];
                @event["width"] = Num.F(strip[2]) * 2.0;
            }
            return @event;
        }
        // A part with nothing under it that is taller than it is deep (its narrower side at its lowest
        // floor): a tower whose base the kaiju ate in one go. It topples instead of dropping a few floors
        // and vanishing whole (PR #89 review, capture 39277970463 frames 505-506).

        public static bool _Gutted(RampageSim.Building b, GArray<Vector3i> cells, long lowest, long height)
        {
            var lo = new Vector2i(9999, 9999);
            var hi = new Vector2i(-1, -1);
            foreach (Vector3i c in cells)
            {
                if (c.y != lowest)
                {
                    continue;
                }
                if (b.frame.TopBelow(c.x, c.z, c.y) >= 0)
                {
                    return false;
                }
                lo = new Vector2i(Gd.Mini(lo.x, c.x), Gd.Mini(lo.y, c.z));
                hi = new Vector2i(Gd.Maxi(hi.x, c.x), Gd.Maxi(hi.y, c.z));
            }
            return height > Gd.Mini(hi.x - lo.x, hi.y - lo.y) + 1;
        }
        // The footprint (local x, z) of a part's lowest floor.

        public static Rect2 _Base(GArray<Vector3i> cells, long lowest)
        {
            var lo = new Vector2(Gd.INF, Gd.INF);
            var hi = new Vector2(-Gd.INF, -Gd.INF);
            foreach (Vector3i c in cells)
            {
                if (c.y == lowest)
                {
                    lo = new Vector2(Gd.Minf(lo.x, c.x), Gd.Minf(lo.y, c.z));
                    hi = new Vector2(Gd.Maxf(hi.x, c.x + 1), Gd.Maxf(hi.y, c.z + 1));
                }
            }
            return new Rect2(lo, hi - lo);
        }
        // b2-5 (D-387): a topple's direction drawn from `cut` by the odds: cut, its left, its right or
        // away (one draw per topple, in the order the sim starts them).

        public Vector2i _Vary(Vector2i cut)
        {
            double roll = _rng.Randf();
            GArray<Vector2i> options = new GArray<Vector2i> { cut, new Vector2i(-cut.y, cut.x), new Vector2i(cut.y, -cut.x), -cut };
            foreach (long k in Gd.Range(options.Size()))
            {
                roll -= _odds[k];
                if (roll < 0.0)
                {
                    return options[k];
                }
            }
            return cut;
        }
        // The level direction (one of the four, like Structure's) from the tower's base to the kaiju;
        // north when the kaiju stands on the base's centre.

        public static Vector2i _Toward(Vector2 toBase)
        {
            if (toBase.IsZeroApprox())
            {
                return new Vector2i(0, -1);
            }
            if (Gd.Absf(toBase.x) > Gd.Absf(toBase.y))
            {
                return new Vector2i(-Gd.Signi(Gd.Roundi(toBase.x * 100.0)), 0);
            }
            return new Vector2i(0, -Gd.Signi(Gd.Roundi(toBase.y * 100.0)));
        }
        // The pivot edge (local frame) a part tips over going `dir`: the far side of its base (the
        // footprint of its lowest floor, at height `low`), centred across the fall.

        public static Vector3 _Edge(Rect2 @base, double low, Vector2i dir)
        {
            var lo = @base.position;
            var hi = @base.end;
            var mid = @base.GetCenter();
            return new Vector3((dir.x > 0 ? hi.x : ((dir.x < 0 ? lo.x : mid.x))), low, (dir.y > 0 ? hi.y : ((dir.y < 0 ? lo.y : mid.y))));
        }
        // How far a loose part drops before it meets what still stands below it (or the ground).

        public double _DropDistance(RampageSim.Building b, RampageSim.Fall f, double lowest)
        {
            double drop = lowest;
            foreach (Vector3i c in f.cells)
            {
                long below = b.frame.TopBelow(c.x, c.z, c.y);
                drop = Gd.Minf(drop, c.y - below - 1);
            }
            return Gd.Maxf(0.5, drop);
        }

        public void Step(double dt)
        {
            GArray<RampageSim.Fall> landed = new GArray<RampageSim.Fall>();
            bool on = _contact.Get("on", false) == true && !_toppleCfg.IsEmpty();
            // a carve may start new falls
            foreach (RampageSim.Fall f in sim.falls.Duplicate())
            {
                f.t += dt;
                if (f.t >= f.duration)
                {
                    landed.Append(f);
                }
                else if (on)
                {
                    GDict hit = FallContact.Step(sim, f, _contact, _toppleCfg, dt);
                    if (!hit.IsEmpty())
                    {
                        f.contact = Gd.Str(hit["contact"]);
                        landed.Append(f);
                    }
                }
            }
            foreach (RampageSim.Fall f in landed)
            {
                sim.falls.Erase(f);
                _Land(f);
            }
            // one stage of getting the next building ready for its first hit
            sim.carving.Warm();
        }
        // A falling part hits: its chunks become rubble (a bonus for toppled towers) and it smashes
        // what it lands on: the floors below a drop, or a strip of street and buildings for a topple.

        public void _Land(RampageSim.Fall f)
        {
            var b = sim.buildings[f.building];
            double bonus = (f.kind == "topple" ? Num.F(sim.city["topple_bonus"]) : 1.0);
            sim.Pay(b, f.cells.Size(), bonus);
            double impact = Num.F(sim.city["impact_damage"]);
            GDict @event = new GDict { { "type", "fall_land" }, { "id", f.id }, { "kind", f.kind }, { "building", f.building } };
            // A carved scrap (less than a chunk's worth, "scrap"): it lands, and smashes nothing.
            var scrap = f.cells.IsEmpty();
            @event["scrap"] = scrap;
            // it broke up against a neighbour or the kaiju before it came down
            if (f.contact != "")
            {
                @event["contact"] = f.contact;
            }
            if (f.kind == "topple")
            {
                GArray<Variant> strip = _Strip(f);
                Vector2 start = strip[0];
                Vector2 finish = strip[1];
                double halfWidth = Num.F(strip[2]);
                @event["from"] = start;
                @event["to"] = finish;
                @event["width"] = halfWidth * 2.0;
                sim.events.Append(@event);
                if (!scrap)
                {
                    tallestTopple = Gd.Maxi(tallestTopple, Gd.Roundi(f.height));
                    _CrushStrip(start, finish, halfWidth, f.building);
                }
            }
            else
            {
                sim.events.Append(@event);
                // stopped on the kaiju's hide: the floors below take no blow
                if ((scrap || f.contact != ""))
                {
                    return;
                }
                GArray<Vector3i> hit = new GArray<Vector3i>();
                foreach (Vector3i c in f.cells)
                {
                    long below = b.frame.TopBelow(c.x, c.z, c.y);
                    if (below >= 0 && !(hit.Has(new Vector3i(c.x, below, c.z))))
                    {
                        hit.Append(new Vector3i(c.x, below, c.z));
                    }
                }
                sim.DamageChunks(f.building, hit, impact);
            }
        }
        // A topple's landing strip: [from, to, half width] (street level, world).

        public GArray<Variant> _Strip(RampageSim.Fall f)
        {
            var start = new Vector2(f.pivot.x, f.pivot.z);
            var across = new Vector2(-f.dir.y, f.dir.x);
            var b = sim.buildings[f.building];
            double width = (f.width >= 0.0 ? f.width : _WidthAcross(b, f.cells, across));
            // one stopped by what it hit reaches only as far as it leant
            double reach = f.height;
            if (f.contact != "" && f.t < f.duration)
            {
                reach = f.height * Gd.Sin(FallContact.Tilt(_toppleCfg, f.t, f.duration));
            }
            return Gd.Arr(start, start + f.dir * reach, width * 0.5 + 0.5);
        }

        public double _WidthAcross(RampageSim.Building b, GArray<Vector3i> cells, Vector2 across)
        {
            double lo = Gd.INF;
            double hi = -Gd.INF;
            foreach (Vector3i c in cells)
            {
                var p = b.ChunkWorld(c);
                double t = new Vector2(p.x, p.z).Dot(across);
                lo = Gd.Minf(lo, t);
                hi = Gd.Maxf(hi, t);
            }
            return hi - lo + 1.0;
        }
        // The buildings that may reach the strip, in index order (BuildingGrid, D-254: never the whole
        // city).

        public PackedInt32Array _NearStrip(Vector2 start, Vector2 finish, double halfWidth)
        {
            var reach = Vector2.ONE * (halfWidth + sim.grid.pad);
            var lo = new Vector2(Gd.Minf(start.x, finish.x), Gd.Minf(start.y, finish.y)) - reach;
            var hi = new Vector2(Gd.Maxf(start.x, finish.x), Gd.Maxf(start.y, finish.y)) + reach;
            return sim.grid.InRect(lo, hi);
        }
        // Everything inside the strip a toppled tower lands on is smashed: chunks of other buildings
        // up to a few floors high, tanks and walking mechs.

        public void _CrushStrip(Vector2 start, Vector2 finish, double halfWidth, long own)
        {
            double impact = Num.F(sim.city["impact_damage"]);
            var along = (finish - start).Normalized();
            double length = start.DistanceTo(finish);
            var inStrip = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                var rel = p - start;
                double t = rel.Dot(along);
                double side = Gd.Absf(rel.Dot(new Vector2(-along.y, along.x)));
                return t >= -r && t <= length + r && side <= halfWidth + r;
            });
            foreach (long i in _NearStrip(start, finish, halfWidth))
            {
                if (i == own)
                {
                    continue;
                }
                var b = sim.buildings[i];
                bool near = inStrip.Call(new Vector2(b.x, b.z), new Vector2(b.w, b.d).Length() * 0.5);
                if (!near)
                {
                    continue;
                }
                var cells = _StripCells(b, inStrip, halfWidth);
                sim.DamageChunks(i, cells, impact);
            }
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                bool struck = inStrip.Call(tank.pos, 0.6);
                if (struck)
                {
                    tank.wrecked = true;
                }
            }
            sim.armyUnits.ClearDead();
            sim.armyUnits.taskforce.mechs.Crush(inStrip);
        }
        // The standing chunks of b a few floors up that lie inside the strip (in_strip: Callable(p, r)).

        public GArray<Vector3i> _StripCells(RampageSim.Building b, Callable inStrip, double halfWidth)
        {
            GArray<Vector3i> cells = new GArray<Vector3i>();
            foreach (long y in Gd.Range(Gd.Mini(Gd.Ceili(halfWidth * 2.0) + 1, b.height)))
            {
                foreach (long x in Gd.Range(b.w))
                {
                    foreach (long z in Gd.Range(b.d))
                    {
                        var c = new Vector3i(x, y, z);
                        var p = b.ChunkWorld(c);
                        bool struck = inStrip.Call(new Vector2(p.x, p.z), 0.5);
                        if (b.frame.Alive(c) && struck)
                        {
                            cells.Append(c);
                        }
                    }
                }
            }
            return cells;
        }

        void _InitFields()
        {
        }
    }
}
