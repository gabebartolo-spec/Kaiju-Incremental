using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// Cars keep out of the tanks' way (scenes/tank_keep_out.gd, line for line; D-066): a car stops short of a tank in
// its lane (then turns round, as behind any hold-up), and a parked police cruiser a tank closes on pulls back along
// its street. Presentation only: the sim's tanks never see a car. Part of Traffic. No UnityEngine here.
public static class TankKeepOut
{
    // The tanks' positions and facings, read once a frame for every car's checks, with the street numbers
    // (street.tank_keep, tank_lane, police_pull_back, car_half_tank). `reach` bounds how far (centre to centre) a
    // tank can be and still matter to a car.
    public sealed class Poses
    {
        public readonly List<S.Vector2> pos = new List<S.Vector2>();
        public readonly List<S.Vector2> front = new List<S.Vector2>();
        public double length, width, reach;
        internal readonly double keep, lane, pullBack;
        internal readonly S.Vector2 carHalf;

        public Poses(S.RampageSim sim, S.GDict cfg)
        {
            S.GDict convoy = sim.army["convoy"];
            S.GArray<S.Variant> hull = convoy["hull"];
            (keep, lane, pullBack, carHalf) = Read(cfg);
            length = S.Num.F(hull[0]);
            width = S.Num.F(hull[1]);
            reach = Reach();
            foreach (S.RampageSim.Tank tank in sim.tanks)
            {
                pos.Add(tank.pos);
                front.Add(sim.armyUnits.convoy.Front(tank.id));
            }
        }

        // For tests: tanks placed by hand.
        internal Poses(S.GDict cfg, double length, double width, List<S.Vector2> pos, List<S.Vector2> front)
        {
            (keep, lane, pullBack, carHalf) = Read(cfg);
            this.length = length;
            this.width = width;
            reach = Reach();
            this.pos.AddRange(pos);
            this.front.AddRange(front);
        }

        static (double, double, double, S.Vector2) Read(S.GDict cfg)
        {
            S.GArray<S.Variant> half = cfg["car_half_tank"];
            return (S.Num.F(cfg["tank_keep"]), S.Num.F(cfg["tank_lane"]), S.Num.F(cfg["police_pull_back"]),
                new S.Vector2(S.Num.F(half[0]), S.Num.F(half[1])));
        }

        double Reach() => (length + width) * 0.5 + keep + lane + carHalf.x + carHalf.y;
    }

    // Is a tank in the lane ahead of a car driving along `dir` (its drawn hull, any way it lies)?
    public static bool InLane(Poses tanks, Traffic.Car car, S.Vector2 dir)
    {
        S.Vector2 side = dir.Orthogonal();
        double reach2 = tanks.reach * tanks.reach;
        for (int i = 0; i < tanks.pos.Count; i++)
        {
            S.Vector2 rel = tanks.pos[i] - car.pos;
            if (rel.LengthSquared() > reach2) continue;
            S.Vector2 front = tanks.front[i];
            if (front == S.Vector2.ZERO) front = dir;
            double wide = tanks.length * 0.5 * Math.Abs(front.Dot(side)) + tanks.width * 0.5 * Math.Abs(front.Cross(side));
            double along = tanks.length * 0.5 * Math.Abs(front.Dot(dir)) + tanks.width * 0.5 * Math.Abs(front.Cross(dir));
            if (Math.Abs(rel.Dot(side)) >= wide + tanks.lane) continue;
            double ahead = rel.Dot(dir);
            if (ahead > -along && ahead < tanks.keep + along) return true;
        }
        return false;
    }

    // Does a tank's drawn hull lie over the car (a car it could not keep clear of)? Then the tank runs it over and
    // the caller flattens it.
    public static bool RunOver(Poses tanks, Traffic.Car car)
    {
        double reach2 = tanks.reach * tanks.reach;
        for (int i = 0; i < tanks.pos.Count; i++)
        {
            S.Vector2 front = tanks.front[i];
            if (front == S.Vector2.ZERO) continue;
            S.Vector2 rel = car.pos - tanks.pos[i];
            if (rel.LengthSquared() > reach2) continue;
            double along = Math.Abs(rel.Dot(front)) - tanks.length * 0.5 - tanks.carHalf.x;
            double across = Math.Abs(rel.Dot(front.Orthogonal())) - tanks.width * 0.5 - tanks.carHalf.y;
            if (Math.Max(along, across) <= 0.0) return true;
        }
        return false;
    }

    // A parked cruiser a tank closes on pulls back along its street (across its nose), away from the tank.
    public static void MakeWay(Poses tanks, Traffic.Car car)
    {
        if (!car.police) return;  // a car parked at the kerb stays, and a tank drives over it
        foreach (S.Vector2 tankPos in tanks.pos)
        {
            S.Vector2 rel = car.pos - tankPos;
            if (rel.Length() >= tanks.keep) continue;
            S.Vector2 street = car.arriveFacing.Orthogonal().Normalized();
            car.parked = false;
            car.arriveFrom = car.pos;
            car.arriveTo = car.pos + (street.Dot(rel) >= 0.0 ? street : -street) * tanks.pullBack;
            car.arriveT = 0.0;
            return;
        }
    }
}
