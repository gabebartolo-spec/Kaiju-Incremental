using System;
using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The static street decor (scenes/city_decor.gd _streets, _kerb_lamps, _light_crossing and _blocks' parking, with
// scenes/decor_cars.gd): parked cars on both kerbs out as far as the camera sees, now and then one stopped in the
// lane, cars in the parking lots, and a streetlight at every crossing and down the long blocks. All crushable.
// Not ported yet: the Tripo street props and vehicles (scenes/street_props.gd), the lamps' lights, the street trees'
// parking clearance, the greenery, quays and traffic islands. Presentation only.
public sealed class StreetDecor
{
    // scenes/city_decor.gd PROP_VOXEL, CROSSING_CLEAR, LAMP_EVERY, CAR_HALF and its palette.
    const float PROP_VOXEL = 0.25f;
    const double CROSSING_CLEAR = 3.0, LAMP_EVERY = 13.0, CAR_HALF_ACROSS = 0.375, CAR_HALF_ALONG = 0.75;
    const int GLASS = 0x2b3640, WHEEL = 0x1a1a1a, IVORY = 0xb8b2a0, TAIL = 0x6a1a1a, POLE = 0x4a4c4e, LAMP = 0xffdb99;

    public readonly PropTiles props;
    public int Cars { get; private set; }
    public int Lamps { get; private set; }
    public int Count => props.Count;
    public int Crushed => props.Crushed;

    readonly S.RampageSim sim;
    readonly S.GDict plan;
    readonly S.RandomNumberGenerator rng = S.Seeds.Make("decor", 0);
    readonly double half, view;
    readonly List<S.Rect2> blocked = new List<S.Rect2>();
    readonly int[] carShapes;
    readonly int paints;
    readonly Dictionary<Vector2Int, int> lampShapes = new Dictionary<Vector2Int, int>();

    public StreetDecor(S.RampageSim sim, Shader shader, Transform parent)
    {
        this.sim = sim;
        plan = S.CityGen.Map(sim.city);
        half = S.CityGen.HalfExtent(sim.city);
        view = sim.arenaHalf + S.Num.F(sim.city["view_beyond"]);
        props = new PropTiles("street decor", shader, parent, PROP_VOXEL, 0f);
        foreach (S.Rect2 basin in S.CityHarbour.Basin(plan)) props.keepOut.Add(basin.Grow(0.3));
        foreach (S.RampageSim.Building b in sim.LotBuildings())
            blocked.Add(new S.Rect2(new S.Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5), new S.Vector2(b.w, b.d)).Grow(0.4));
        foreach (S.Rect2 channel in S.CityRiver.Channels(plan, sim.city)) blocked.Add(channel.Grow(0.5 + CAR_HALF_ALONG));
        S.GArray<S.Variant> colors = sim.city["car_colors"];
        paints = (int)colors.Size();
        carShapes = new int[paints * 2];
        for (int paint = 0; paint < paints; paint++)
        {
            int color = Convert.ToInt32(S.Gd.Str(colors[paint]), 16);
            carShapes[paint * 2] = props.AddShape(Car(color, false));
            carShapes[paint * 2 + 1] = props.AddShape(Car(color, true));
        }
        Streets();
        Parking();
        props.Tick();
    }

    bool Inside(S.Vector2 p, double margin) => Math.Max(Math.Abs(p.x), Math.Abs(p.y)) <= half + margin;

    bool OnBuilding(S.Vector2 p)
    {
        foreach (S.Rect2 r in blocked)
            if (r.HasPoint(p)) return true;
        return false;
    }

    void Streets()
    {
        S.GArray<S.Vector2> nodes = plan["nodes"];
        var lit = new HashSet<long>();
        S.GArray<S.GDict> streets = plan["streets"];
        foreach (S.GDict street in streets)
        {
            string kind = S.Gd.Str(street["kind"]);
            long from = S.Num.I(street["from"]), to = S.Num.I(street["to"]);
            S.Vector2 a = nodes[from], b = nodes[to];
            if (!(Inside(a, view - half) || Inside(b, view - half)) || kind == S.CityGen.ALLEY) continue;
            bool playable = Inside(a, 0.5) && Inside(b, 0.5);
            double width = S.Num.F(street["width"]);
            S.Vector2 dir = (b - a).Normalized();
            var side = new S.Vector2(-dir.y, dir.x);
            if (kind != S.CityGen.DIAGONAL)
            {
                ParkKerb(-1.0, a, b, width, playable);
                ParkKerb(1.0, a, b, width, playable);
            }
            if (!playable) continue;  // past the edge: cars only
            if (kind != S.CityGen.DIAGONAL)
            {
                if (lit.Add(from)) Lamp(a + (dir + side) * (width * 0.5 + 0.7), (dir + side) * -1.0);
                if (lit.Add(to)) Lamp(b + (dir + side) * (width * 0.5 + 0.7), (dir + side) * -1.0);
            }
            double t = LAMP_EVERY, flip = 1.0;
            double length = a.DistanceTo(b);
            while (t < length - LAMP_EVERY * 0.6)
            {
                Lamp(a + dir * t + side * (flip * (width * 0.5 + 0.6)), side * -flip);
                flip = -flip;
                t += LAMP_EVERY;
            }
        }
    }

    // scenes/decor_cars.gd park_kerb: one kerb's parked and stopped cars along the street a..b.
    void ParkKerb(double kerb, S.Vector2 a, S.Vector2 b, double width, bool playable)
    {
        S.GArray<S.Variant> gap = sim.city["parked_gap"];
        double stop = S.Num.F(sim.city["lane_stop_chance"]);
        S.Vector2 dir = (b - a).Normalized();
        var side = new S.Vector2(-dir.y, dir.x);
        double length = a.DistanceTo(b);
        double t = CROSSING_CLEAR + rng.RandfRange(0.0, 2.0);
        if (!playable && t >= length - CROSSING_CLEAR) t = length * 0.5;
        while (t < length - CROSSING_CLEAR || Math.Abs(t - length * 0.5) < 1e-5)
        {
            double lane = width * 0.5 - 0.6;
            if (rng.Randf() < stop) lane = width * 0.25;  // stopped in the traffic lane
            TryCar(a + dir * t + side * (kerb * lane), dir, playable);
            t += rng.RandfRange(S.Num.F(gap[0]), S.Num.F(gap[1]));
        }
    }

    // scenes/decor_cars.gd try_car: a car in one of the paints when the odds allow, off the playable diagonal, in
    // view and off the buildings.
    void TryCar(S.Vector2 p, S.Vector2 dir, bool playable)
    {
        double chance = S.Num.F(sim.city[playable ? "parked_chance" : "parked_chance_beyond"]);
        bool alongX = Math.Abs(dir.x) > 0.5;
        int paint = (int)rng.RandiRange(0, paints - 1);
        bool onDiagonal = playable && S.CityGen.DiagonalDistance(plan, p) < S.CityGen.WidthOf(S.CityGen.DIAGONAL, sim.city) * 0.5 + 1.0;
        bool seen = Inside(p, view - half) && !OnBuilding(p);
        if (rng.Randf() < chance && !onDiagonal && seen && props.Add(new Vector2((float)p.x, (float)p.y), carShapes[paint * 2 + (alongX ? 1 : 0)])) Cars++;
    }

    // scenes/city_decor.gd _blocks: two rows of cars in every parking lot.
    void Parking()
    {
        S.GArray<S.GDict> blocks = plan["blocks"];
        foreach (S.GDict block in blocks)
        {
            if (S.Gd.Str(block["use"]) != "parking") continue;
            S.Rect2 rect = block["rect"];
            S.Rect2 bays = rect.Grow(-0.6);
            double x = bays.position.x + 1.65;
            while (x < bays.end.x - 0.6)
            {
                for (int row = 0; row < 2; row++)
                {
                    double z = row == 0 ? bays.position.y + 1.2 : bays.end.y - 1.2;
                    if (rng.Randf() >= 0.7) continue;
                    int paint = (int)rng.RandiRange(0, paints - 1);
                    if (props.Add(new Vector2((float)x, (float)z), carShapes[paint * 2])) Cars++;
                }
                x += 1.3;
            }
        }
    }

    // scenes/city_decor.gd _lamp: a streetlight at p whose arm reaches toward `toward`.
    void Lamp(S.Vector2 p, S.Vector2 toward)
    {
        if (OnBuilding(p)) return;
        var arm = new Vector2Int(Math.Sign(toward.x), Math.Sign(toward.y));
        if (!lampShapes.TryGetValue(arm, out int shape)) lampShapes[arm] = shape = props.AddShape(Streetlight(arm));
        if (props.Add(new Vector2((float)p.x, (float)p.y), shape)) Lamps++;
    }

    // scenes/city_decor.gd car: about 1.5 long, nose to -z (to -x when alongX).
    static Dictionary<Vector3Int, int> Car(int paint, bool alongX)
    {
        var local = new Dictionary<Vector3Int, int>();
        PropTiles.Box(local, new Vector3Int(-1, 0, -3), new Vector3Int(1, 1, 2), paint);
        PropTiles.Box(local, new Vector3Int(-1, 2, -1), new Vector3Int(1, 2, 1), GLASS);
        for (int x = -1; x <= 1; x += 2)
        {
            local[new Vector3Int(x, 0, -2)] = WHEEL;
            local[new Vector3Int(x, 0, 1)] = WHEEL;
            local[new Vector3Int(x, 1, -3)] = IVORY;
            local[new Vector3Int(x, 1, 2)] = TAIL;
        }
        if (!alongX) return local;
        var turned = new Dictionary<Vector3Int, int>();
        foreach (KeyValuePair<Vector3Int, int> cell in local) turned[new Vector3Int(cell.Key.z, cell.Key.y, cell.Key.x)] = cell.Value;
        return turned;
    }

    // scenes/city_decor.gd _streetlight: a pole, an arm two cells out, the lamp under its end.
    static Dictionary<Vector3Int, int> Streetlight(Vector2Int arm)
    {
        var cells = new Dictionary<Vector3Int, int>();
        var reach = new Vector3Int(arm.x * 2, 0, arm.y * 2);
        PropTiles.Box(cells, new Vector3Int(0, 0, 0), new Vector3Int(0, 11, 0), POLE);
        PropTiles.Box(cells, new Vector3Int(0, 11, 0), reach + new Vector3Int(0, 11, 0), POLE);
        cells[reach + new Vector3Int(0, 10, 0)] = LAMP;
        return cells;
    }
}
