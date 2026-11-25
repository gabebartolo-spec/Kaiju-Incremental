// Where the kaiju's walk ends (scenes/arena_edge.gd, director 2026-10-20: "the edge of the play area needs to be
// indicated somehow (not too loud) so players dont continuously try to destroy indestructible buildings"): a row of
// small orange bollards on the pavement just past the arena's edge (sim.arenaHalf + "out"), the city cordoning off
// the kaiju; none over the river's water, on a street that crosses the edge or in a street tree's trunk. Godot axes.
// Plain C# so SimTests/ArenaEdgeCheck.cs walks it against Godot's own output (golden/arena_edge.txt). Cosmetic;
// tuning "arena_edge".
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // A street near the bollard line: its ends and how far either side of its middle a bollard keeps off it.
    public struct EdgeRoad
    {
        public S.Vector2 from, to;
        public double reach;
    }

    public static class ArenaEdge
    {
        // arena_edge.gd:13: how far either side of the bollard line a street, tree or water counts (m).
        public const double BAND = 4.0;
        // arena_edge.gd:88: a street's box grown this much before it is tested against the band.
        const double STREET_GROW = 0.5;
        // arena_edge.gd:90: past a street's half width, a bollard keeps this much further off it.
        const double ROAD_CLEAR = 0.4;

        // arena_edge.gd:44-70 spots: every "spacing" m round the square at arenaHalf + "out", minus any over the water,
        // on a street or within "tree_clear" of a trunk. Pure.
        public static List<S.Vector3> Spots(S.RampageSim sim, IReadOnlyList<S.Vector2> trees)
        {
            S.GDict cfg = S.Content.Tuning()["arena_edge"];
            double half = sim.arenaHalf + S.Num.F(cfg["out"]);
            double step = S.Num.F(cfg["spacing"]);
            double clear = S.Num.F(cfg["tree_clear"]);
            S.GDict plan = S.CityGen.Map(sim.city);
            var water = new List<S.Rect2>();
            foreach (S.Rect2 r in S.CityRiver.Channels(plan, sim.city)) water.Add(r);
            foreach (S.Rect2 r in S.CityHarbour.Basin(plan)) water.Add(r);
            List<EdgeRoad> roads = Roads(plan, sim.city, half);
            var near = new List<S.Vector2>();
            foreach (S.Vector2 tr in trees)
                if (Math.Abs(Ring(tr) - half) < BAND) near.Add(tr);
            var output = new List<S.Vector3>();
            for (int side = 0; side < 4; side++)
            {
                S.Vector3 along = side % 2 == 0 ? new S.Vector3(1, 0, 0) : new S.Vector3(0, 0, 1);
                double sign = side < 2 ? 1.0 : -1.0;
                S.Vector3 edge = side % 2 == 0 ? new S.Vector3(0, 0, half * sign) : new S.Vector3(half * sign, 0, 0);
                double t = -half;
                while (t <= half)
                {
                    S.Vector3 at = edge + along * t;
                    t += step;
                    var ground = new S.Vector2(at.x, at.z);
                    if (!Blocked(ground, water, roads, near, clear)) output.Add(at);
                }
            }
            return output;
        }

        // Over the water, on a street or within "clear" of a trunk.
        static bool Blocked(S.Vector2 p, List<S.Rect2> water, List<EdgeRoad> roads, List<S.Vector2> trees, double clear)
        {
            return Wet(p, water) || OnRoad(p, roads) || NearTree(p, trees, clear);
        }

        static bool Wet(S.Vector2 p, List<S.Rect2> water)
        {
            foreach (S.Rect2 r in water)
                if (r.HasPoint(p)) return true;
            return false;
        }

        static bool NearTree(S.Vector2 p, List<S.Vector2> trees, double clear)
        {
            foreach (S.Vector2 tr in trees)
                if (tr.DistanceTo(p) < clear) return true;
            return false;
        }

        // arena_edge.gd:80-91 _roads: the streets near the bollard line (alleys too: a bollard never blocks one).
        public static List<EdgeRoad> Roads(S.GDict plan, S.GDict city, double half)
        {
            S.GArray<S.Vector2> nodes = plan["nodes"];
            var outer = new S.Rect2(-half - BAND, -half - BAND, (half + BAND) * 2.0, (half + BAND) * 2.0);
            S.Rect2 inner = outer.Grow(-BAND * 2.0);
            var output = new List<EdgeRoad>();
            S.GArray<S.GDict> streets = plan["streets"];
            foreach (S.GDict street in streets)
            {
                S.Vector2 from = nodes[S.Num.I(street["from"])];
                S.Vector2 to = nodes[S.Num.I(street["to"])];
                S.Rect2 box = new S.Rect2(from, new S.Vector2(0, 0)).Expand(to).Grow(STREET_GROW);
                if (outer.Intersects(box) && !inner.Encloses(box))
                    output.Add(new EdgeRoad { from = from, to = to, reach = S.CityGen.WidthOf(S.Gd.Str(street["kind"]), city) * 0.5 + ROAD_CLEAR });
            }
            return output;
        }

        // arena_edge.gd:94-100 on_road.
        public static bool OnRoad(S.Vector2 p, List<EdgeRoad> roads)
        {
            foreach (EdgeRoad road in roads)
                if (S.Geometry2D.GetClosestPointToSegment(p, road.from, road.to).DistanceTo(p) < road.reach) return true;
            return false;
        }

        // arena_edge.gd:103 _ring: how far out a point lies on the square rings round the centre.
        public static double Ring(S.Vector2 p) => Math.Max(Math.Abs(p.x), Math.Abs(p.y));
    }
}
