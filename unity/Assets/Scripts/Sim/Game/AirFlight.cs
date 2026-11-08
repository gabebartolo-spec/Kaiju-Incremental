// Generated from sim/air_flight.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class AirFlight : RefCounted
    {
        public static implicit operator AirFlight(Variant v) => (AirFlight)v.Obj;

        // How the military helicopters fly (D-183 "Stand-off gunships", motion first D-177). Each one
        // has its own position, velocity and nose and steers for its firing position: a slot on a ring
        // well beyond the kaiju's reach (`standoff` x body scale, so it grows with him) that goes where
        // he goes, `lead_seconds` of his walk ahead of him. It is never pinned to him: its speed,
        // acceleration and nose turn are limited (`heli_speed`, `heli_accel`, `heli_turn_deg`), so it
        // glides to its slot, matches the kaiju's walk, backs off in front of him when he walks at it
        // and hovers facing him when he stops. When he comes within `pull_back` of it, its slot is
        // straight behind it. After `hold_seconds` it glides along the ring to another slot (`glide_deg`).
        // Now and then (`strafe_gap`) ONE helicopter makes a strafing pass: a fly-by at full speed along a
        // straight flank line along the camera's view that passes `strafe_close` from him, inside his tail
        // reach, aimed at where he will be (his smoothed walk); it never brakes, is over `strafe_exit` past
        // him and turns back out to its slot. Slots keep `clear_arc` (and `clear_lead_deg` more) off the
        // camera's side (`camera_bearing`); a pass flies a flank line that never crosses the corridor
        // between the camera and him.
        // Part of AirWing; pure, on its own seeded stream.
        public RampageSim sim;
        public GDict cfg = new GDict();
        // Strafing passes started this run.
        public long passes = 0;
        public RandomNumberGenerator _rng;
        public double _gapLeft;
        // where the pilots take the kaiju to be (smoothed, `anchor_seconds`)
        public Vector2 _anchor = Vector2.ZERO;
        // the anchor's velocity, units a second: where the pilots expect it to go
        public Vector2 _walk = Vector2.ZERO;

        public AirFlight(RampageSim pSim, GDict pCfg, RandomNumberGenerator rng)
        {
            _InitFields();
            sim = pSim;
            cfg = pCfg;
            _rng = rng;
            _gapLeft = _Span("strafe_gap");
            _anchor = sim.kaijuPos;
        }
        // A new helicopter: on the far side of the kaiju from the camera, `spawn_far` rings out, flying
        // in to its slot.

        public void Place(AirWing.Heli heli)
        {
            double jitter = Num.F(cfg["standoff_jitter"]);
            heli.ring = (Num.F(cfg["standoff"]) * sim.BodyScale() * _rng.RandfRange(1.0 - jitter, 1.0 + jitter));
            double arc = _Arc();
            heli.slot = _Bearing() + arc + _rng.Randf() * (Gd.TAU - 2.0 * arc);
            heli.goal = _SlotPoint(heli);
            heli.pos = sim.kaijuPos + Vector2.FromAngle(heli.slot) * heli.ring * Num.F(cfg["spawn_far"]);
            heli.heading = (sim.kaijuPos - heli.pos).Angle();
            heli.vel = Vector2.ZERO;
            heli.hold = _Span("hold_seconds");
        }
        // One step for every helicopter: the strafing clock, then each one's plan and flight.

        public void Step(GArray<AirWing.Heli> helis, double dt)
        {
            if (dt <= 0.0)
            {
                return;
            }
            _WatchKaiju(dt);
            _StrafeClock(helis, dt);
            foreach (AirWing.Heli heli in helis)
            {
                _Plan(heli, helis, dt);
                _Steer(heli, dt);
            }
        }
        // Where the pilots take the kaiju to be: his position smoothed over `anchor_seconds`, which is also
        // about where the camera looks (his stepped turns swing the root point ten units a step).

        public Vector2 Anchor()
        {
            return _anchor;
        }
        // The pilots' estimate of where the kaiju is and where it is heading: his position smoothed over
        // `anchor_seconds` (a stepped turn swings it ten units about the planted foot every few steps,
        // which the pilots do not chase) and that anchor's velocity.

        public void _WatchKaiju(double dt)
        {
            var before = _anchor;
            _anchor = _anchor.Lerp(sim.kaijuPos, Gd.Minf(1.0, dt / Num.F(cfg["anchor_seconds"])));
            _walk = (_anchor - before) / dt;
        }
        // Sends `heli` on a strafing pass (the clock does it now and then; a test may too).

        public void StartPass(AirWing.Heli heli)
        {
            GArray<Variant> line = _PassLine(heli);
            heli.passing = true;
            heli.run = false;
            heli.passAt = Vector2.FromAngle(Num.F(line[0]));
            heli.passDir = heli.passAt.Orthogonal() * Num.F(line[1]);
            heli.passLeft = Num.F(cfg["strafe_seconds"]);
            passes += 1;
        }
        // The line a pass of `heli` flies: [the bearing of its nearest point to the kaiju, +1 or -1 for
        // the way along it, how far round the ring the heli's slot is from the line's entry end (radians)].
        // The line passes `strafe_close` from him and runs out to the heli's ring at both ends. It is the
        // flank pass on the side of the heli's slot (so it never crosses to the other side) that keeps
        // clear of the corridor between the camera and him (`pass_corridor` x scale either side of the
        // camera's line to him; D-183: it may cross the camera's side but never fly between the camera and
        // him), so it runs along the camera's view beside him where the player sees it. Its entry is the
        // end nearer the heli's slot.

        public GArray<Variant> _PassLine(AirWing.Heli heli)
        {
            double close = Num.F(cfg["strafe_close"]) * sim.BodyScale();
            double centre = _Flank(heli.slot, close, heli.ring);
            GArray<Variant> best = Gd.Arr(centre, 1.0, Gd.INF);
            foreach (double way in Gd.Arr(1.0, -1.0))
            {
                double entry = _LineEnd(centre, close, heli.ring, -way);
                double apart = Gd.Absf(Gd.Wrapf(heli.slot - entry, -Gd.PI, Gd.PI));
                if (apart < Num.F(best[2]))
                {
                    best = Gd.Arr(centre, way, apart);
                }
            }
            return best;
        }
        // The bearing of a pass's nearest point: the one of the two flanks (a quarter turn each side of the
        // camera's bearing) on the side of `slot`, turned on until its line clears the corridor.

        public double _Flank(double slot, double close, double ring)
        {
            double side = (Gd.Wrapf(slot - _Bearing(), -Gd.PI, Gd.PI) >= 0.0 ? 1.0 : -1.0);
            foreach (long step in Gd.Range(37))
            {
                double centre = _Bearing() + side * (Gd.PI * 0.5 + Gd.DegToRad(5.0) * step);
                if (_LineClear(centre, close, ring))
                {
                    return centre;
                }
            }
            return _Bearing() + side * Gd.PI;
        }
        // Does the pass line with nearest point `close` out at bearing `centre` keep out of the corridor
        // between the camera and the kaiju (on the camera's side, within `pass_corridor` of its line)?

        public bool _LineClear(double centre, double close, double ring)
        {
            var toward = Vector2.FromAngle(_Bearing());
            var near = Vector2.FromAngle(centre);
            double halfLen = Gd.Sqrt(Gd.Maxf(0.0, ring * ring - close * close));
            double wide = Num.F(cfg["pass_corridor"]) * sim.BodyScale();
            double t = -halfLen;
            while (t <= halfLen)
            {
                var at = near * close + near.Orthogonal() * t;
                if (at.Dot(toward) > 0.0 && Gd.Absf(at.Dot(toward.Orthogonal())) < wide)
                {
                    return false;
                }
                t += 1.0;
            }
            return true;
        }
        // The bearing from the kaiju of the end of the line (nearest point at bearing `centre`, `close`
        // out) that lies `end` x its half-length along the way `way` points: the line's entry for -1.

        public double _LineEnd(double centre, double close, double ring, double end)
        {
            var near = Vector2.FromAngle(centre);
            double halfLen = Gd.Sqrt(Gd.Maxf(0.0, ring * ring - close * close));
            return (near * close + near.Orthogonal() * end * halfLen).Angle();
        }
        // The clock only runs while no pass is on; when it is up the helicopter whose slot is nearest the
        // entry of a pass goes, if it is near enough (else the clock tries again soon).

        public void _StrafeClock(GArray<AirWing.Heli> helis, double dt)
        {
            if (helis.IsEmpty())
            {
                return;
            }
            foreach (AirWing.Heli heli in helis)
            {
                if (heli.passing)
                {
                    return;
                }
            }
            _gapLeft -= dt;
            if (_gapLeft > 0.0)
            {
                return;
            }
            AirWing.Heli pick = null;
            double least = Gd.DegToRad(Num.F(cfg["strafe_reach_deg"]));
            foreach (AirWing.Heli heli in helis)
            {
                double apart = Num.F(_PassLine(heli)[2]);
                if (apart <= least)
                {
                    pick = heli;
                    least = apart;
                }
            }
            if (pick == null)
            {
                _gapLeft = Num.F(cfg["strafe_retry"]);
                return;
            }
            _gapLeft = _Span("strafe_gap");
            StartPass(pick);
        }
        // Decides where `heli` steers: its pass, else its slot, which is straight behind it when the
        // kaiju is within `pull_back` and a new one along the ring once it has held this one `hold` long.

        public void _Plan(AirWing.Heli heli, GArray<AirWing.Heli> helis, double dt)
        {
            if (heli.passing)
            {
                _PlanPass(heli, dt);
                if (heli.passing)
                {
                    return;
                }
            }
            heli.hold -= dt;
            var away = heli.pos - sim.kaijuPos;
            if (away.Length() < Num.F(cfg["pull_back"]) * sim.BodyScale())
            {
                heli.slot = _Clear(away.Angle());
            }
            else if (heli.hold <= 0.0)
            {
                _Glide(heli, helis);
            }
            heli.goal = _SlotPoint(heli);
        }
        // A pass in two parts. It lines up: the helicopter flies to the entry end of the line (on its own
        // side, beyond him, as it flies to a slot, braking to a hover) and once there (`arrive`, and
        // drifting across the line no faster than it hovers: run sooner and it skids on over the line)
        // it runs:
        // it follows a point `strafe_carrot` ahead along the line (which moves with the kaiju's walk) at
        // full speed; once abeam of him the line bends outward (`strafe_veer`, so it never swings back
        // across the corridor) and it is over `strafe_exit` past him, where it turns back out to its slot.

        public void _PlanPass(AirWing.Heli heli, double dt)
        {
            heli.passLeft -= dt;
            double close = Num.F(cfg["strafe_close"]) * sim.BodyScale();
            var origin = _anchor + _walk * Num.F(cfg["strafe_lead"]) + heli.passAt * close;
            double reach = Gd.Sqrt(Gd.Maxf(0.0, heli.ring * heli.ring - close * close));
            double along = (heli.pos - origin).Dot(heli.passDir);
            if (!heli.run)
            {
                heli.goal = origin - heli.passDir * reach;
                double hover = Num.F(cfg["nose_share"]) * Num.F(cfg["heli_speed"]);
                heli.run = (heli.pos.DistanceTo(heli.goal) <= Num.F(cfg["arrive"]) * 2.0 && Gd.Absf(heli.vel.Dot(heli.passAt)) <= hover);
            }
            if ((heli.run && along >= Num.F(cfg["strafe_exit"]) * sim.BodyScale() || heli.passLeft <= 0.0))
            {
                heli.passing = false;
                heli.run = false;
                heli.slot = _Clear((heli.pos - sim.kaijuPos).Angle());
                heli.hold = _Span("hold_seconds");
                return;
            }
            if (heli.run)
            {
                double carrot = Gd.Clampf(along, -reach, reach) + Num.F(cfg["strafe_carrot"]) * sim.BodyScale();
                // past him the line bends outward
                double veer = Gd.Maxf(0.0, carrot) * Num.F(cfg["strafe_veer"]);
                heli.goal = origin + heli.passDir * carrot + heli.passAt * veer;
            }
        }
        // The heli's slot moves along its ring by `glide_deg` to one side: the best of `slot_tries`
        // seeded tries for room from the other helicopters' slots.

        public void _Glide(AirWing.Heli heli, GArray<AirWing.Heli> helis)
        {
            GArray<Variant> span = cfg["glide_deg"];
            double best = heli.slot;
            double room = -1.0;
            foreach (long _try in Gd.Range(Num.I(cfg["slot_tries"])))
            {
                double turn = Gd.DegToRad(_rng.RandfRange(Num.F(span[0]), Num.F(span[1])));
                double side = (_rng.Randf() < 0.5 ? 1.0 : -1.0);
                double slot = _Clear(heli.slot + side * turn);
                double apart = _Room(slot, heli, helis);
                if (apart > room)
                {
                    best = slot;
                    room = apart;
                }
            }
            heli.slot = best;
            heli.hold = _Span("hold_seconds");
        }
        // How far round the ring `slot` is from the nearest other helicopter's slot (INF with none).

        public double _Room(double slot, AirWing.Heli heli, GArray<AirWing.Heli> helis)
        {
            double least = Gd.INF;
            foreach (AirWing.Heli other in helis)
            {
                if (other != heli)
                {
                    least = Gd.Minf(least, Gd.Absf(Gd.Wrapf(slot - other.slot, -Gd.PI, Gd.PI)));
                }
            }
            return least;
        }
        // The flight: the velocity moves toward the one that brings it to its goal (matching the goal's
        // own walk, braking to a stop at it) by at most `heli_accel` a second and never past
        // `heli_speed`, so it glides, backs off and banks round without a jerk, however the kaiju
        // lurches. Its nose turns at most `heli_turn_deg` a second, along its flight when it is moving
        // (`nose_share` of top speed or more) and at the kaiju when it hovers.

        public void _Steer(AirWing.Heli heli, double dt)
        {
            var to = heli.goal - heli.pos;
            double top = Num.F(cfg["heli_speed"]);
            double accel = Num.F(cfg["heli_accel"]);
            var want = _walk;
            // a fly-by: at full speed along the line, no braking
            if (heli.passing && heli.run)
            {
                want = to.Normalized() * top;
            }
            else if (to.Length() > Num.F(cfg["arrive"]))
            {
                want += to.Normalized() * Gd.Minf(top, Gd.Sqrt(2.0 * accel * to.Length()));
            }
            heli.vel = heli.vel.MoveToward(want.LimitLength(top), accel * dt);
            heli.pos += heli.vel * dt;
            var moving = heli.vel.Length() >= Num.F(cfg["nose_share"]) * top;
            var look = (moving ? heli.vel : sim.kaijuPos - heli.pos);
            double turn = Gd.DegToRad(Num.F(cfg["heli_turn_deg"])) * dt;
            double err = Gd.Wrapf(look.Angle() - heli.heading, -Gd.PI, Gd.PI);
            heli.heading = Gd.Wrapf(heli.heading + Gd.Clampf(err, -turn, turn), -Gd.PI, Gd.PI);
        }
        // Where the heli's slot is now: on its ring round the kaiju, at its bearing, and when he is
        // walking toward it `lead_seconds` of that walk further out, so it backs off before he is on
        // it rather than after (his walk away from it moves the slot no nearer).

        public Vector2 _SlotPoint(AirWing.Heli heli)
        {
            var @out = Vector2.FromAngle(heli.slot);
            double toward = Gd.Maxf(0.0, _walk.Dot(@out));
            return _anchor + @out * (heli.ring + toward * Num.F(cfg["lead_seconds"]));
        }
        // `angle` moved out of the camera's side (to the nearer edge of the clear arc) if it is in it.

        public double _Clear(double angle)
        {
            return _ClearBy(angle, _Arc());
        }
        // `angle` moved to at least `arc` radians round from the camera's bearing (the nearer way).

        public double _ClearBy(double angle, double arc)
        {
            double side = Gd.Wrapf(angle - _Bearing(), -Gd.PI, Gd.PI);
            if (Gd.Absf(side) >= arc)
            {
                return angle;
            }
            return _Bearing() + ((side >= 0.0 ? arc : -arc));
        }
        // The half-width of the camera's side no slot may be in: `clear_arc` and `clear_lead_deg` more.

        public double _Arc()
        {
            return Gd.DegToRad(Num.F(cfg["clear_arc"]) + Num.F(cfg["clear_lead_deg"]));
        }
        // The direction from the kaiju toward the game camera, on the ground plane.

        public double _Bearing()
        {
            return Gd.DegToRad(Num.F(cfg["camera_bearing"]));
        }
        // A seeded value in the data's [min, max] range `key`.

        public double _Span(string key)
        {
            GArray<Variant> bounds = cfg[key];
            return _rng.RandfRange(Num.F(bounds[0]), Num.F(bounds[1]));
        }

        void _InitFields()
        {
        }
    }
}
