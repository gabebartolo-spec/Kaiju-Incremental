using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// Cars parked along both kerbs of the diagonal avenue, turned to it (scenes/diagonal_parking.gd, line for line), as
// far as grid parking reaches (the arena and city.view_beyond past its edge). They are Traffic's cars, parked for
// good, flattened by a stomp or a tank like any other. city.diagonal_parked_lane from the centre line keeps them off
// the traffic lanes; city.parked_chance and city.parked_gap as on the grid. Never in a grid street, by a crossing,
// in the river or within city.street_tree_car_clear of a street decor prop. Own seed stream; presentation only.
// The prop bases come in as a list (Godot walked the scene tree for CityDecor). No UnityEngine here.
public static class DiagonalParking
{
    // scenes/city_decor.gd CROSSING_CLEAR and CAR_HALF, as StreetDecor holds them (that file needs UnityEngine).
    internal const double CROSSING_CLEAR = 3.0, CAR_HALF_ACROSS = 0.375, CAR_HALF_ALONG = 0.75;

    struct Kerb
    {
        public S.Vector2 start, along, facing;  // its crossing out at the parking lane, its way, its lane's way
        public double length;
    }

    // Parks the row into `traffic` (after its moving cars spawned), drawn along each kerb.
    public static void Park(Traffic traffic, S.RampageSim sim, List<S.Vector2> props)
    {
        S.RandomNumberGenerator rng = S.Seeds.Make("diagonal_parking", 0);
        S.GDict cfg = sim.city;
        S.GDict plan = S.CityGen.Map(cfg);
        S.GArray<S.Rect2> water = S.CityRiver.Channels(plan, cfg);
        double reachTo = sim.arenaHalf + S.Num.F(cfg["view_beyond"]);
        double reach = S.Num.F(cfg["street_tree_car_clear"]);
        S.GDict streetCfg = S.Content.Section("street");
        double jitter = S.Num.F(streetCfg["diagonal_start_jitter"]);
        double waterClear = S.Num.F(streetCfg["diagonal_water_clear"]);
        bool Fits(S.Vector2 p, S.Vector2 dir) =>
            Math.Max(Math.Abs(p.x), Math.Abs(p.y)) <= reachTo && Clear(plan, p, water, waterClear) && OffProps(props, p, dir, reach);
        double chance = S.Num.F(cfg["parked_chance"]);
        S.GArray<S.Variant> gap = cfg["parked_gap"];
        foreach (Kerb kerb in Kerbs(plan, cfg))
        {
            double t = CROSSING_CLEAR + rng.RandfRange(0.0, jitter);
            while (t < kerb.length - CROSSING_CLEAR)
            {
                S.Vector2 p = kerb.start + kerb.along * t;
                if (rng.Randf() < chance && Fits(p, kerb.along)) Add(traffic, rng, p, kerb.facing);
                t += rng.RandfRange(S.Num.F(gap[0]), S.Num.F(gap[1]));
            }
        }
    }

    // Each kerb of each diagonal block.
    static List<Kerb> Kerbs(S.GDict plan, S.GDict cfg)
    {
        var output = new List<Kerb>();
        S.GArray<S.Vector2> nodes = plan["nodes"];
        double lane = S.Num.F(cfg["diagonal_parked_lane"]);
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) != S.CityGen.DIAGONAL) continue;
            S.Vector2 a = nodes[S.Num.I(street["from"])];
            S.Vector2 b = nodes[S.Num.I(street["to"])];
            S.Vector2 dir = (b - a).Normalized();
            foreach (double side in new[] { -1.0, 1.0 })
                output.Add(new Kerb { start = a + dir.Orthogonal() * side * lane, along = dir, length = a.DistanceTo(b), facing = -dir * side });
        }
        return output;
    }

    // Whether a car at p stands clear of the water and of every grid street (its carriageway and half a car more).
    static bool Clear(S.GDict plan, S.Vector2 p, S.GArray<S.Rect2> water, double waterClear)
    {
        foreach (S.Rect2 channel in water)
            if (channel.Grow(CAR_HALF_ALONG + waterClear).HasPoint(p)) return false;
        S.GArray<S.Vector2> nodes = plan["nodes"];
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            if (S.Gd.Str(street["kind"]) == S.CityGen.DIAGONAL) continue;
            S.Vector2 a = nodes[S.Num.I(street["from"])];
            S.Vector2 b = nodes[S.Num.I(street["to"])];
            S.Vector2 q = S.Geometry2D.GetClosestPointToSegment(p, a, b);
            double reach = S.Num.F(street["width"]) * 0.5 + CAR_HALF_ALONG;
            if (q.DistanceTo(p) < reach) return false;
        }
        return true;
    }

    // Whether a car at p along dir keeps `reach` between its body and every prop base.
    static bool OffProps(List<S.Vector2> props, S.Vector2 p, S.Vector2 dir, double reach)
    {
        foreach (S.Vector2 at in props)
        {
            S.Vector2 d = at - p;
            var gap = new S.Vector2(
                Math.Max(0.0, Math.Abs(d.Dot(dir)) - CAR_HALF_ALONG),
                Math.Max(0.0, Math.Abs(d.Cross(dir)) - CAR_HALF_ACROSS));
            if (gap.Length() < reach) return false;
        }
        return true;
    }

    static void Add(Traffic traffic, S.RandomNumberGenerator rng, S.Vector2 p, S.Vector2 facing)
    {
        Traffic.Car car = traffic.Make((int)rng.RandiRange(0, traffic.paints - 1), false);
        car.pos = p;
        car.dir = facing;
        car.arriveFacing = facing;
        car.parked = true;
        traffic.Place(car, 1.0);
    }
}
