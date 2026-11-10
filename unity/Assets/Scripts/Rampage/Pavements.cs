using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The pavement graph the street's people walk (scenes/pavements.gd, line for line): four corner nodes round every
// block of the playable city, linked round the block and across the streets to the nearest corner opposite. A corner
// in the diagonal avenue's carriageway has no links. No UnityEngine here: unity/SimTests compiles this file.
public sealed class Pavements
{
    // scenes/pavements.gd CORNERS, PAVEMENT, CROSSWALK, CROSS_CHANCE.
    static readonly double[] CornerX = { -1, 1, 1, -1 }, CornerY = { -1, -1, 1, 1 };
    const double PAVEMENT = 0.45, CROSSWALK = 9.5, CROSS_CHANCE = 0.3;

    public readonly List<S.Vector2> nodes = new List<S.Vector2>();
    public readonly List<List<int>> links = new List<List<int>>();
    public readonly List<bool> inRoad = new List<bool>();
    // The walkers' stream (StreetPeople's), for NextCorner.
    public S.RandomNumberGenerator rng;
    // Within this of the kaiju no walker turns toward it (StreetPeople sets it each frame).
    public double wary;

    public Pavements(S.RampageSim sim)
    {
        S.GDict city = sim.city;
        double half = S.CityGen.HalfExtent(city);
        S.GDict plan = S.CityGen.Map(city);
        S.GArray<S.Vector2> crossings = plan["nodes"];
        var avenue = new List<S.GDict>();  // only the diagonal runs through a block
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict road in streets)
            if (S.Gd.Str(road["kind"]) == S.CityGen.DIAGONAL) avenue.Add(road);
        double reach = S.CityGen.WidthOf(S.CityGen.DIAGONAL, city) * 0.5;
        double sidewalk = S.Num.F(city["sidewalk"]);
        S.GArray<S.GDict> blocks = plan["blocks"];
        foreach (S.GDict block in blocks)
        {
            S.Rect2 rect = block["rect"];
            string use = S.Gd.Str(block["use"]);
            S.Vector2 end = rect.end;
            if (use == "outer" || use == "river" || use == "harbour" || use == "shore" || Math.Max(Math.Abs(end.x), Math.Abs(end.y)) > half)
                continue;  // past the edge, the river, the sea bay or the fjord: no one walks on the water
            S.Rect2 ring = S.CityGen.Pavement(block, city).Grow(PAVEMENT - sidewalk);
            S.Vector2 size = ring.size * 0.5;
            S.Vector2 centre = ring.GetCenter();
            bool cut = S.CityGen.DiagonalDistance(plan, centre) < size.Length() + reach;
            int first = nodes.Count;
            for (int c = 0; c < 4; c++)
            {
                S.Vector2 at = centre + new S.Vector2(CornerX[c], CornerY[c]) * size;
                nodes.Add(at);
                links.Add(new List<int>());
                inRoad.Add(cut && RoadAt(crossings, avenue, at));
            }
            for (int c = 0; c < 4; c++)
            {
                int a = first + c, b = first + (c + 1) % 4;
                if (!inRoad[a] && !inRoad[b]) Link(a, b);
            }
        }
        CrossStreets();
    }

    // Whether a street's carriageway holds p, between its two crossings (pavements.gd _road_at).
    static bool RoadAt(S.GArray<S.Vector2> crossings, List<S.GDict> streets, S.Vector2 p)
    {
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) == S.CityGen.ALLEY) continue;
            S.Vector2 from = crossings[S.Num.I(street["from"])], to = crossings[S.Num.I(street["to"])];
            S.Vector2 dir = (to - from).Normalized();
            double along = (p - from).Dot(dir);
            double halfWidth = S.Num.F(street["width"]) * 0.5;
            if (along > 0.0 && along < from.DistanceTo(to) && Math.Abs((p - from).Cross(dir)) < halfWidth) return true;
        }
        return false;
    }

    void CrossStreets()
    {
        for (int a = 0; a < nodes.Count; a++)
        {
            if (inRoad[a]) continue;
            for (int axis = 0; axis < 2; axis++)
            {
                int best = NearestAcross(a, axis);
                if (best >= 0 && !links[a].Contains(best)) Link(a, best);
            }
        }
    }

    // The nearest corner of another block across a street from corner a along `axis` (0: x), or -1.
    int NearestAcross(int a, int axis)
    {
        int best = -1;
        for (int b = 0; b < nodes.Count; b++)
        {
            if (a >> 2 == b >> 2 || inRoad[b]) continue;
            S.Vector2 d = nodes[b] - nodes[a];
            double along = axis == 0 ? Math.Abs(d.x) : Math.Abs(d.y);
            double off = axis == 0 ? Math.Abs(d.y) : Math.Abs(d.x);
            if (off > 1.0 || along > CROSSWALK) continue;
            if (best < 0 || along < nodes[best].DistanceTo(nodes[a])) best = b;
        }
        return best;
    }

    // The corners people can walk between (4 per block, minus the ones in the road).
    public List<S.Vector2> RingNodes()
    {
        var o = new List<S.Vector2>();
        for (int n = 0; n < nodes.Count; n++)
            if (links[n].Count > 0) o.Add(nodes[n]);
        return o;
    }

    // Where a walker placed at block `lot`'s `corner` starts: the first corner from there on with a pavement line.
    public int LineStart(int lot, int corner)
    {
        int blocks = nodes.Count >> 2;
        for (int attempt = 0; attempt < blocks * 4; attempt++)
        {
            int from = (lot % blocks) * 4 + corner;
            if (links[from].Contains((from & ~3) + ((from + 1) & 3))) break;
            corner = (corner + 1) % 4;
            lot += corner == 0 ? 1 : 0;
        }
        return (lot % blocks) * 4 + corner;
    }

    // A fleeing walker's next corner: of the linked corners that lead away from the kaiju, the furthest; else `here`.
    public int FleeCorner(int here, S.Vector2 kaiju)
    {
        S.Vector2 at = nodes[here];
        S.Vector2 away = at - kaiju;
        int best = here;
        double far = -1.0;
        foreach (int n in links[here])
        {
            if ((nodes[n] - at).Dot(away) <= 0.0) continue;
            double d = nodes[n].DistanceSquaredTo(kaiju);
            if (d > far)
            {
                far = d;
                best = n;
            }
        }
        return best;
    }

    // The corner a walker at `here` (come from `from`) heads for next (draws from rng in Godot's order).
    public int NextCorner(int here, int from, S.Vector2 kaiju, bool fleeing)
    {
        if (fleeing) return FleeCorner(here, kaiju);
        var crossings = new List<int>();
        var roundLot = new List<int>();
        int lot = here >> 2;
        foreach (int n in links[here])
        {
            if (n == from || !NotToward(here, n, kaiju)) continue;
            if (n >> 2 == lot) roundLot.Add(n);
            else crossings.Add(n);
        }
        if (roundLot.Count == 0 && crossings.Count == 0) return NotToward(here, from, kaiju) ? from : here;
        List<int> pick = roundLot;
        if (roundLot.Count == 0 || (crossings.Count > 0 && rng.Randf() < CROSS_CHANCE)) pick = crossings;
        return pick[(int)rng.RandiRange(0, pick.Count - 1)];
    }

    // Outside `wary` any pavement is allowed; within it only one whose first step does not lead toward the kaiju.
    bool NotToward(int here, int n, S.Vector2 kaiju)
    {
        S.Vector2 at = nodes[here];
        if (at.DistanceSquaredTo(kaiju) >= wary * wary) return true;
        return (nodes[n] - at).Dot(at - kaiju) >= 0.0;
    }

    void Link(int a, int b)
    {
        links[a].Add(b);
        links[b].Add(a);
    }
}
