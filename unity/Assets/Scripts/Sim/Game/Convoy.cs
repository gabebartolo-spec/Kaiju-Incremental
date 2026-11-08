// Generated from sim/convoy.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Convoy : RefCounted
    {
        public static implicit operator Convoy(Variant v) => (Convoy)v.Obj;

        // How the tanks move (D-066): like an army, not a swarm. They enter by road and drive the street
        // plan (RoadGraph: never an alley, a lot or a building) in columns that keep their gap, pivoting
        // at turns. Each takes a firing post on a road at standoff with a clear line of fire, spread on
        // an arc (FiringPosts), holds it while good, bounds to a new one when the kaiju moves (one tank
        // of a column at a time), backs off inside the danger radius, re-routes round a tank or a toppled
        // tower in its way, and gives way to an older tank. Pure and seeded; Army owns spawning, firing
        // and damage. Numbers: army.convoy in data/tuning.json.
        public RampageSim sim;
        public GDict cfg = new GDict();
        public RoadGraph graph;
        public RoadSearch search;
        public FiringPosts posts;
        public TankSpacing spacing;
        public ConvoyHull hull;
        // tank id -> ConvoyRoute
        public GDict routes = new GDict();
        // how the kaiju walks (m/s), from its last step
        public Vector2 kaijuVel = Vector2.ZERO;
        public Vector2 _kaijuWas = new Vector2(Gd.INF, Gd.INF);
        public long _plansLeft = 0;
        // One tank's next stretch for a step (Convoy._aim): the way, the distance to the waypoint, the way
        // its hull goes (backwards when reversing), the hull's front and the step it takes.

        public class Leg : RefCounted
        {
            public static implicit operator Leg(Variant v) => (Leg)v.Obj;

            public Vector2 dir = Vector2.ZERO;
            public double dist = 0.0;
            public Vector2 want = Vector2.ZERO;
            public Vector2 front = Vector2.ZERO;
            public double move = 0.0;
            public Vector2 next = Vector2.ZERO;

            void _InitFields()
            {
            }
            public Leg() { _InitFields(); }
        }

        public Convoy(RampageSim pSim, GDict pCfg)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            graph = new RoadGraph(sim, cfg);
            search = new RoadSearch(graph, cfg);
            posts = new FiringPosts(this);
            spacing = new TankSpacing(this);
            hull = new ConvoyHull(this);
        }
        // Full reach for the kaiju as it is now, measured from its body line (FiringPosts.aim_point),
        // never so short that the firing band ends inside the keep-away (band_depth past it).

        public double Reach()
        {
            GArray<Variant> band = cfg["band"];
            double least = (posts.KeepAway() + Num.F(cfg["band_depth"])) / Num.F(band[1]);
            return Gd.Maxf(Num.F(sim.army["range"]) + sim.StompRadius(), least);
        }
        // The danger radius, from the body line: the keep-away (FiringPosts.keep_away), or the danger
        // share of reach when that is further.

        public double Danger()
        {
            return Gd.Maxf(Reach() * Num.F(cfg["danger"]), posts.KeepAway());
        }
        // Is the line of fire from `from` to `to` clear (FiringPosts.clear_line)?

        public bool ClearLine(Vector2 from, Vector2 to)
        {
            return posts.ClearLine(from, to);
        }
        // Where tank `id`'s hull points (ZERO before it has a route): the view draws exactly this.

        public Vector2 Front(long id)
        {
            ConvoyRoute r = routes.Get(id);
            return (r != null ? r.front : Vector2.ZERO);
        }
        // Where a new tank enters at `node` (pick_entry): records its route and returns where it
        // starts, or INF when that way in is still taken by the tank before it.

        public Vector2 Enter(long id, long column, long node)
        {
            if ((node < 0 || graph.links[node].IsEmpty()))
            {
                return new Vector2(Gd.INF, Gd.INF);
            }
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                if (tank.pos.DistanceTo(graph.nodes[node]) < Num.F(cfg["follow"]))
                {
                    return new Vector2(Gd.INF, Gd.INF);
                }
            }
            long e = graph.links[node][0];
            long far = (graph.edgeA[e] == node ? graph.edgeB[e] : graph.edgeA[e]);
            // facing into its road
            var into = (graph.nodes[far] - graph.nodes[node]).Normalized();
            // a stub too short for the hull
            if (!graph.Drivable(graph.nodes[node], into))
            {
                return new Vector2(Gd.INF, Gd.INF);
            }
            var r = new ConvoyRoute();
            r.column = column;
            r.edge = e;
            r.heading = into;
            r.front = into;
            routes[id] = r;
            return graph.nodes[node];
        }
        // The way in for a column on `bearing` (RoadGraph.pick_entry): never inside the danger line.

        public long PickEntry(double bearing)
        {
            return graph.PickEntry(bearing, sim.kaijuPos, Num.F(sim.army["spawn_radius"]), Danger());
        }
        // One step for every tank: read what fell across the roads, re-plan where needed (at most
        // plans_per_step, the urgent ones always), then drive.

        public void Step(double dt)
        {
            if (dt > 0.0)
            {
                kaijuVel = (_kaijuWas.x != Gd.INF ? (sim.kaijuPos - _kaijuWas) / dt : Vector2.ZERO);
                _kaijuWas = sim.kaijuPos;
            }
            posts.heldBody = posts.Body();
            _ReadRubble();
            double near = Danger();
            _RefreshCosts(near);
            _plansLeft = Num.I(cfg["plans_per_step"]);
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                // in the air, or on its roof (TankFlight)
                if (!tank.flying && !tank.toppled)
                {
                    _Tend(tank, near, dt);
                }
            }
            foreach (long id in routes.Keys())
            {
                if (!(sim.tanks.Any(new Callable(a_ =>
                {
                    RampageSim.Tank t = a_[0];
                    return t.id == id;
                }))))
                {
                    routes.Erase(id);
                }
            }
            posts.heldBody = new PackedVector2Array();
        }
        // One tank's step: its route, a re-plan where its post has gone bad or the kaiju is on top of it,
        // then the drive.

        public void _Tend(RampageSim.Tank tank, double near, double dt)
        {
            ConvoyRoute r = routes.Get(tank.id);
            if (r == null)
            {
                r = new ConvoyRoute();
                routes[tank.id] = r;
            }
            r.replanT -= dt;
            var urgent = posts.ToBody(tank.pos) < near;
            if (!urgent && r.path.IsEmpty())
            {
                r.retreating = false;
            }
            if (urgent && !r.retreating)
            {
                _Plan(tank, r, true);
            }
            else if (r.replanT <= 0.0 && ((_plansLeft > 0 || urgent)))
            {
                _Review(tank, r, urgent);
            }
            _Drive(tank, r, dt);
        }
        // Time to look at the post again: re-plan when it is no good and nothing covers it.

        public void _Review(RampageSim.Tank tank, ConvoyRoute r, bool urgent)
        {
            r.replanT = Num.F(cfg["replan"]);
            if (!_GoalGood(r) && ((urgent || !_Covering(tank, r))))
            {
                _plansLeft -= 1;
                _Plan(tank, r, urgent);
            }
        }
        // The search costs this step: roads by the kaiju's feet, held at a post, and driven (which way).

        public void _RefreshCosts(double near)
        {
            search.nearKaiju = posts.RoadsByBody(near);
            search.held = new GDict();
            search.driven = new GDict();
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                ConvoyRoute o = routes.Get(tank.id);
                if (o == null)
                {
                    continue;
                }
                if (o.path.IsEmpty() && o.edge >= 0)
                {
                    search.held[o.edge] = true;
                }
                var from = tank.pos;
                foreach (long i in Gd.Range(o.path.Size()))
                {
                    if (o.edges[i] >= 0)
                    {
                        search.driven[o.edges[i]] = o.path[i] - from;
                    }
                    from = o.path[i];
                }
            }
        }
        // A post is good while in the band between danger and full reach with a clear shot (on the way
        // to it, while no further than commit x reach: a tank does not turn back at every kaiju step).

        public bool _GoalGood(ConvoyRoute r)
        {
            if (r.goal.x == Gd.INF)
            {
                return false;
            }
            double d = r.goal.DistanceTo(sim.kaijuPos);
            // clear of the body, head to tail root
            var clear = posts.ToBody(r.goal) >= Danger();
            // on its way it commits to the post, unless the kaiju drew off
            if (!r.path.IsEmpty())
            {
                return clear && d <= Reach() * Num.F(cfg["commit"]);
            }
            return clear && d <= Reach() && ClearLine(r.goal, sim.kaijuPos);
        }
        // Bounding overwatch: a tank at its post waits for its column's moving tank to settle first.

        public bool _Covering(RampageSim.Tank tank, ConvoyRoute r)
        {
            if ((!r.path.IsEmpty() || r.goal.x == Gd.INF || r.column < 0))
            {
                return false;
            }
            // out of range: it cannot cover anyone
            if (r.goal.DistanceTo(sim.kaijuPos) > Reach())
            {
                return false;
            }
            foreach (RampageSim.Tank other in sim.tanks)
            {
                ConvoyRoute o = routes.Get(other.id);
                if (other.id != tank.id && o != null && o.column == r.column && !o.path.IsEmpty())
                {
                    r.replanT = Num.F(cfg["replan"]) * 0.25;
                    return true;
                }
            }
            return false;
        }
        // Picks a post (FiringPosts) and the road route to it; urgent: the kaiju is on top of it.

        public void _Plan(RampageSim.Tank tank, ConvoyRoute r, bool urgent)
        {
            r.stuckT = 0.0;
            r.replanT = Num.F(cfg["replan"]);
            GDict start = search.Origin(tank.pos, r);
            var rings = posts.ReserveRings();
            double widest = rings.Max();
            double disc = Gd.Maxf(tank.pos.DistanceTo(sim.kaijuPos), widest) + Num.F(cfg["search_margin"]);
            GDict from = start["from"];
            GDict found = search.Search(from, r.skip, sim.kaijuPos, disc);
            if (graph.OnEdge(tank.pos, Num.I(start["edge"])))
            {
                r.edge = Num.I(start["edge"]);
            }
            GDict goal = posts.Choose(tank, r, found, urgent);
            // every post taken and the kaiju on top of it: back off anyway
            if (goal.IsEmpty() && urgent)
            {
                var away = posts.RingPosts(tank, r, found, ((GArray<double>)Gd.Arr(rings[0])));
                if (!away.IsEmpty())
                {
                    goal = away[0];
                    goal["reserve"] = true;
                }
            }
            r.skip = new GDict();
            if (goal.IsEmpty())
            {
                // nowhere to go: try again at the next re-plan, not every step
                r.retreating = urgent;
                return;
            }
            GArray<long> chain = new GArray<long>();
            start["node"] = -1;
            if (Num.I(goal["node"]) >= 0)
            {
                GArray<Variant> walk = search.ChainTo(found, Num.I(goal["node"]));
                GArray<Variant> roads = walk[0];
                chain.Assign(roads);
                start["node"] = walk[1];
            }
            GArray<Variant> way = graph.Waypoints(tank.pos, start, chain, goal);
            GArray<Variant> points = way[0];
            // never past the kaiju's feet: back off instead
            if (posts.CrossesDanger(tank.pos, points))
            {
                way = posts.FallBack(tank, r);
                points = way[0];
                goal["at"] = (!points.IsEmpty() ? points[0] : new Vector2(Gd.INF, Gd.INF));
            }
            GArray<Variant> legs = way[1];
            r.path.Assign(points);
            r.edges.Assign(legs);
            r.goal = goal["at"];
            r.reserve = goal.Get("reserve", false);
            r.retreating = urgent && !r.path.IsEmpty();
        }
        // Drives along the route at speed (reversing slower, front still to the kaiju, when it backs
        // off), hull on the carriageway and clear of others, `follow` behind one ahead in its lane. It
        // drives only along its hull: a turn it makes standing at hull_turn first (shuffling a hull's
        // step forward or back where the turn will not fit). Held up `stuck` seconds, it re-plans
        // round what held it.

        public void _Drive(RampageSim.Tank tank, ConvoyRoute r, double dt)
        {
            r.reversing = false;
            if (r.yieldT > 0.0)
            {
                spacing.Yielding(tank, r, dt, _Back(dt));
                // giving way mid-pivot: it waits squared to its road
                hull.Settle(tank, r, _Rate(dt));
                return;
            }
            // backed off its path: set off again from where it stands
            if (r.yieldAll > 0.0)
            {
                r.yieldAll = 0.0;
                _Plan(tank, r, r.retreating);
            }
            if (r.path.IsEmpty())
            {
                hull.Settle(tank, r, _Rate(dt));
                // the kaiju moved and a gun swung over a neighbour
                spacing.OpenUp(tank, r, _Back(dt));
                return;
            }
            var leg = _Aim(tank, r, dt);
            if (leg != null)
            {
                _Take(tank, r, leg, dt);
            }
        }
        // How far a tank backs in a step, and how far its hull turns.

        public double _Back(double dt)
        {
            return Num.F(sim.army["speed"]) * Num.F(cfg["reverse"]) * dt;
        }

        public double _Rate(double dt)
        {
            return Gd.DegToRad(Num.F(cfg["hull_turn"])) * dt;
        }
        // The next stretch of the route as this step would drive it, or null when the tank arrives at the
        // waypoint or brakes short of the standoff line instead (nothing more to do this step).

        public Convoy.Leg _Aim(RampageSim.Tank tank, ConvoyRoute r, double dt)
        {
            double rate = _Rate(dt);
            // never down a diagonal
            r.path[0] = graph.SquareLeg(tank.pos, r.path[0], r.edges[0]);
            // nor crabbing where it could not square
            r.path[0] = hull.OntoAxis(tank.pos, r.path[0], r.edge);
            var leg = new Leg();
            var to = r.path[0] - tank.pos;
            leg.dist = to.Length();
            leg.dir = (leg.dist > 0.0001 ? to / leg.dist : r.front);
            double speed = _Speed(tank, r, leg.dir);
            leg.want = (r.reversing ? -leg.dir : leg.dir);
            r.front = (r.front == Vector2.ZERO ? leg.want : r.front);
            double turn = r.front.AngleTo(leg.want);
            // the last metre is not worth a turn: it is there
            if (leg.dist <= 1.0 && Gd.Absf(turn) > rate)
            {
                _Arrive(r);
                return null;
            }
            leg.front = r.front.Rotated(Gd.Clampf(turn, -rate, rate));
            // squared first, then on
            leg.move = (Gd.Absf(turn) > rate ? 0.0 : Gd.Minf(leg.dist, speed * dt));
            leg.next = tank.pos + leg.dir * leg.move;
            if (!r.retreating && leg.move > 0.0 && posts.ToBody(leg.next) < Danger())
            {
                // brake short of the standoff line: never across it
                r.path.Clear();
                r.edges.Clear();
                return null;
            }
            return leg;
        }
        // The speed along `dir`: backing up rather than turning about in the road (setting r.reversing),
        // and out fast, then slow, when it is backing off the kaiju's body: fast until retreat_clear past
        // the danger line, so a kaiju following never pins it astride the line.

        public double _Speed(RampageSim.Tank tank, ConvoyRoute r, Vector2 dir)
        {
            double speed = Num.F(sim.army["speed"]);
            // back off, never turn tail
            var behind = r.front.Dot(dir) < ((r.retreating ? 0.0 : -0.5));
            double outTo = Danger() + Num.F(cfg["retreat_clear"]);
            // out fast, then slow
            var clearOf = r.retreating && posts.ToBody(tank.pos) < outTo;
            // and back up rather than turn about in the road
            if (behind && r.front != Vector2.ZERO)
            {
                r.reversing = true;
                return (clearOf ? Num.F(cfg["retreat_speed"]) : speed * Num.F(cfg["reverse"]));
            }
            return (clearOf ? Gd.Maxf(speed, Num.F(cfg["retreat_speed"])) : speed);
        }
        // Takes the leg when the hull fits there, shuffles to make room to turn, or waits held up.

        public void _Take(RampageSim.Tank tank, ConvoyRoute r, Convoy.Leg leg, double dt)
        {
            var blocker = spacing.Blocker(tank, leg.next, leg.front);
            var fits = (graph.Drivable(leg.next, leg.front) && ((leg.move > 0.0 || hull.SweepFits(tank, tank.pos, leg.want))));
            if (blocker == null && !fits && graph.Drivable(tank.pos, r.front))
            {
                if (leg.move == 0.0 && hull.Shuffle(tank, r, leg.want, _Back(dt)))
                {
                    return;
                }
                // the hull would leave the road, or the turn has no room: held up
                blocker = tank;
            }
            if (blocker != null)
            {
                _Wait(tank, r, blocker, dt);
            }
            else
            {
                _Commit(tank, r, leg);
            }
        }
        // The hull fits: it drives the leg, and arrives at the waypoint when it reaches it.

        public void _Commit(RampageSim.Tank tank, ConvoyRoute r, Convoy.Leg leg)
        {
            r.stuckT = 0.0;
            r.heading = leg.dir;
            r.front = leg.front;
            tank.pos = leg.next;
            if (!r.edges.IsEmpty() && r.edges[0] >= 0)
            {
                r.edge = r.edges[0];
            }
            if ((leg.move > 0.0 && leg.move >= leg.dist - 0.0001 || leg.dist <= 0.0001))
            {
                _Arrive(r);
            }
        }
        // Held up, or no room to turn: it waits squared to its road, gives way, and re-plans when stuck.

        public void _Wait(RampageSim.Tank tank, ConvoyRoute r, RampageSim.Tank blocker, double dt)
        {
            hull.Settle(tank, r, _Rate(dt));
            // standing held up, a gun can swing over it too
            spacing.OpenUp(tank, r, _Back(dt));
            r.stuckT += dt;
            spacing.GiveWay(tank, blocker, _Back(dt));
            // falling back: sooner
            if (r.stuckT >= Num.F(cfg["stuck"]) * ((r.retreating ? 0.5 : 1.0)))
            {
                _HeldUp(tank, r, blocker);
            }
        }
        // At its next waypoint: on to the one after.

        public void _Arrive(ConvoyRoute r)
        {
            r.path.RemoveAt(0);
            r.edges.RemoveAt(0);
            r.retreating = r.retreating && !r.path.IsEmpty();
        }
        // Held up too long: re-plan off this road, and round the roads under the tank in its way.

        public void _HeldUp(RampageSim.Tank tank, ConvoyRoute r, RampageSim.Tank blocker)
        {
            if (!r.edges.IsEmpty() && r.edges[0] >= 0)
            {
                r.skip[r.edges[0]] = true;
            }
            if (blocker != tank)
            {
                foreach (long e in graph.RoadsAt(graph.CellOf(blocker.pos)))
                {
                    if (e != r.edge && graph.OnEdge(blocker.pos, e))
                    {
                        r.skip[e] = true;
                    }
                }
            }
            _Plan(tank, r, r.retreating);
        }
        // Toppled towers close their roads: a tank routed through one drops it and re-plans.

        public void _ReadRubble()
        {
            if (!graph.ReadRubble(sim.events))
            {
                return;
            }
            foreach (RampageSim.Tank tank in sim.tanks)
            {
                ConvoyRoute r = routes.Get(tank.id);
                if (r != null && r.edges.Any(new Callable(a_ =>
                {
                    long e = a_[0];
                    return e >= 0 && graph.blocked[e] != 0;
                })))
                {
                    // never on through the rubble, even with no way round yet
                    r.path.Clear();
                    r.edges.Clear();
                    _Plan(tank, r, r.retreating);
                }
            }
        }

        void _InitFields()
        {
        }
    }
}
