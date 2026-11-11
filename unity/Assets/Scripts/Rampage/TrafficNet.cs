using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The street network under Traffic (scenes/traffic_net.gd, line for line): the crossings, the lanes out of each and
// the streets they touch, built from the street plan (CityGen.Map). Side streets are one-way, alternating by street;
// avenues and the diagonal carry a lane each way; alleys carry no cars. No UnityEngine here: unity/SimTests
// compiles this file (TrafficCheck).
public sealed class TrafficNet
{
    // One lane out of a crossing: the crossing it leads to and its offset to the right of the centre line.
    public struct Lane
    {
        public int to;
        public double lane;
    }

    public readonly List<S.Vector2> nodes = new List<S.Vector2>();
    // Per crossing: the lanes out of it, and the crossings every street it touches leads to (a fleeing car may
    // drive any of them).
    public readonly List<List<Lane>> lanes = new List<List<Lane>>();
    public readonly List<List<int>> links = new List<List<int>>();
    // Every lane as (from, to), for spawning.
    public readonly List<(int a, int b)> ends = new List<(int a, int b)>();

    readonly double half, twoWayLane, citySlack;

    public TrafficNet(double half, S.GDict cfg)
    {
        this.half = half;
        twoWayLane = S.Num.F(cfg["car_two_way_lane"]);
        citySlack = S.Num.F(cfg["car_city_slack"]);
    }

    // The drivable network inside the playable city: alleys carry no cars.
    public void BuildLanes(S.GDict plan)
    {
        S.GArray<S.Vector2> planNodes = plan["nodes"];
        foreach (S.Vector2 n in planNodes)
        {
            nodes.Add(n);
            lanes.Add(new List<Lane>());
            links.Add(new List<int>());
        }
        S.GArray<double> xs = plan["xs"];
        S.GArray<double> zs = plan["zs"];
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            string kind = S.Gd.Str(street["kind"]);
            int a = (int)S.Num.I(street["from"]);
            int b = (int)S.Num.I(street["to"]);
            if (kind == S.CityGen.ALLEY || !(Inside(nodes[a]) && Inside(nodes[b]))) continue;
            links[a].Add(b);
            links[b].Add(a);
            if (kind != S.CityGen.STREET)
            {
                AddLane(a, b, twoWayLane);
                AddLane(b, a, twoWayLane);
                continue;
            }
            OneWay(a, b, xs, zs);
        }
    }

    // One-way, alternating with the street's index along its axis.
    void OneWay(int a, int b, S.GArray<double> xs, S.GArray<double> zs)
    {
        S.Vector2 d = nodes[b] - nodes[a];
        bool vertical = Math.Abs(d.y) > Math.Abs(d.x);
        long index = vertical ? xs.Find(nodes[a].x) : zs.Find(nodes[a].y);
        bool forward = (vertical ? d.y : d.x) > 0.0;
        if ((S.Gd.Posmod(index, 2) == 0) == forward)
            AddLane(a, b, 0.0);
        else
            AddLane(b, a, 0.0);
    }

    void AddLane(int a, int b, double lane)
    {
        lanes[a].Add(new Lane { to = b, lane = lane });
        ends.Add((a, b));
    }

    internal bool Inside(S.Vector2 p) => Math.Max(Math.Abs(p.x), Math.Abs(p.y)) <= half + citySlack;

    public S.Vector2 Crossing(int n) => nodes[n];

    // Crossings inside the city that cars can reach (the police pick blockade spots from these).
    public List<int> Crossings()
    {
        var output = new List<int>();
        for (int n = 0; n < nodes.Count; n++)
            if (links[n].Count > 0) output.Add(n);
        return output;
    }

    // Unit directions of the streets leaving crossing n.
    public List<S.Vector2> StreetDirs(int n)
    {
        var output = new List<S.Vector2>();
        foreach (int other in links[n]) output.Add((nodes[other] - nodes[n]).Normalized());
        return output;
    }
}
