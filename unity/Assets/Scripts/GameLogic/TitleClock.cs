// The title's timing without the engine (scenes/title_ambience.gd's gunfire bursts, far booms and stomps, and
// title_backdrop.gd's answers to them: a flash at a far spot, now and then the colossus revealed, the bay's
// shiver, the fade-in), stepped as Godot steps them (the backdrop before the ambience) on Godot's seeded streams.
// Game/Title/TitleCityView.cs plays and draws what each step says; SimTests TitleCheck holds it to Godot's run.
using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    public sealed class TitleClock
    {
        public enum Kind { Shot, Boom, Stomp }

        // One sound this step: what, its pitch scale and dB; a flash at a far spot (only once the city stands);
        // a boom that reveals the colossus carries the next reveal wait.
        public struct Event
        {
            public Kind kind;
            public double pitch, db;
            public bool flash, reveal;
            public S.Vector3 at;
            public double revealWait;
        }

        // title_ambience.gd GUN_PITCH: the distant rifle is pitched down.
        public const double GUN_PITCH = 0.7;
        // How far a shot's pitch and dB wander, a burst's gap stretches, and a loop starts in (s).
        const double SHOT_PITCH_LOW = 0.92, SHOT_PITCH_HIGH = 1.08, SHOT_DB = 3.0;
        const double BURST_LOW = 0.7, BURST_HIGH = 1.4, LOOP_START = 4.0;
        // title_backdrop.gd _far_spot: a flash stands at least this far behind the far shore (m).
        const double SPOT_BACK = 4.0;

        public readonly List<Event> events = new List<Event>();
        public readonly double crowdStart, sirenStart;
        public bool Loaded { get; private set; }
        public double Fade { get; private set; }
        public double RevealWait { get; private set; }

        readonly S.GDict title, cfg;
        readonly double farZ;
        readonly S.RandomNumberGenerator rng = S.Seeds.Make("title_sound", 0);
        readonly S.RandomNumberGenerator flashRng = S.Seeds.Make("title_flash", 0);
        readonly S.RandomNumberGenerator revealRng = S.Seeds.Make("title_colossus", 0);
        double wait, burstGap, stompWait, boomWait, shiver;
        int burst;
        bool rising;

        // title_ambience.gd _ready: the loops' random starts (the siren's only when its file is there), the
        // first stomp at half its pace, the first boom and the first burst.
        public TitleClock(S.GDict title, double farZ, bool siren)
        {
            this.title = title;
            this.farZ = farZ;
            cfg = title["ambience"];
            crowdStart = rng.Randf() * LOOP_START;
            if (siren) sirenStart = rng.Randf() * LOOP_START;
            S.GDict stomp = cfg["stomp"];
            stompWait = S.Num.F(stomp["every_s"]) * 0.5;
            boomWait = BoomGap();
            wait = Gap();
        }

        // The bay's shiver (0 at rest .. 1 a footstep has just landed), title_backdrop.gd shiver().
        public double Shiver => rising ? 1.0 : shiver;

        // The city stands: it fades in, flashes show, and the first shots and boom come soon (flashes_begin).
        public void Begin()
        {
            Loaded = true;
            wait = Math.Min(wait, S.Num.F(cfg["first_gun_s"]));
            boomWait = Math.Min(boomWait, S.Num.F(cfg["first_boom_s"]));
        }

        public void Step(double dt)
        {
            events.Clear();
            if (Loaded) Backdrop(dt);
            TickStomp(dt);
            boomWait -= dt;
            if (boomWait <= 0.0)
            {
                Boom();
                boomWait = BoomGap();
            }
            Gun(dt);
        }

        // title_backdrop.gd _process: the fade, the reveal's wait and the shiver's rise and fall.
        void Backdrop(double dt)
        {
            Fade = Math.Min(1.0, Fade + dt / S.Num.F(title["fade_s"]));
            RevealWait -= dt;
            S.GDict ripple = title["ripple"];
            if (rising)
            {
                shiver = Math.Min(1.0, shiver + dt / S.Num.F(ripple["attack_s"]));
                rising = shiver < 1.0;
            }
            else if (shiver > 0.0)
            {
                shiver = Math.Max(0.0, shiver - dt / S.Num.F(ripple["decay_s"]));
            }
        }

        void Gun(double dt)
        {
            if (burst > 0)
            {
                burstGap -= dt;
                if (burstGap <= 0.0)
                {
                    Shoot();
                    burst -= 1;
                    burstGap = S.Num.F(cfg["gun_burst_gap_s"]) * rng.RandfRange(BURST_LOW, BURST_HIGH);
                }
                return;
            }
            wait -= dt;
            if (wait > 0.0) return;
            S.GArray<S.Variant> shots = cfg["gun_burst"];
            burst = (int)rng.RandiRange(S.Num.I(shots[0]), S.Num.I(shots[1]));
            wait = Gap();
        }

        void Shoot()
        {
            Event e = new Event { kind = Kind.Shot, pitch = GUN_PITCH * rng.RandfRange(SHOT_PITCH_LOW, SHOT_PITCH_HIGH) };
            e.db = S.Num.F(cfg["gun_db"]) + rng.RandfRange(-SHOT_DB, SHOT_DB);
            if (Loaded)
            {
                e.flash = true;
                e.at = FarSpot(0.0, 0.0);
            }
            events.Add(e);
        }

        // title_ambience.gd's boom and title_backdrop.gd boom(): a flash over the district; when the reveal is
        // due, the colossus is lit and the next reveal waits a while.
        void Boom()
        {
            S.GDict boom = cfg["boom"];
            Event e = new Event { kind = Kind.Boom, pitch = S.Num.F(boom["pitch"]), db = S.Num.F(boom["db"]) };
            if (Loaded)
            {
                S.GDict flash = ((S.GDict)title["flashes"])["boom"];
                e.flash = true;
                e.at = FarSpot(S.Num.F(flash["min_height"]), S.Num.F(flash["max_height"]));
                if (RevealWait <= 0.0)
                {
                    S.GArray<S.Variant> every = ((S.GDict)title["colossus"])["reveal_every_s"];
                    RevealWait = revealRng.RandfRange(S.Num.F(every[0]), S.Num.F(every[1]));
                    e.reveal = true;
                    e.revealWait = RevealWait;
                }
            }
            events.Add(e);
        }

        // title_ambience.gd _tick_stomp: no two steps alike, each a little higher or lower, heavier or lighter;
        // the bay starts to shiver (title_backdrop.gd stomp()).
        void TickStomp(double dt)
        {
            stompWait -= dt;
            if (stompWait > 0.0) return;
            S.GDict stomp = cfg["stomp"], vary = cfg["step_vary"];
            double weight = rng.RandfRange(-1.0, 1.0) * S.Num.F(vary["db"]);
            double pitch = 1.0 + rng.RandfRange(-1.0, 1.0) * S.Num.F(vary["pitch"]);
            events.Add(new Event { kind = Kind.Stomp, pitch = S.Num.F(stomp["pitch"]) * pitch, db = S.Num.F(stomp["db"]) + weight });
            rising = true;
            stompWait = S.Num.F(stomp["every_s"]) + rng.RandfRange(-1.0, 1.0) * S.Num.F(stomp["jitter_s"]);
        }

        // title_backdrop.gd _far_spot: somewhere over the burning district (y between low and high).
        S.Vector3 FarSpot(double low, double high)
        {
            S.GArray<S.Variant> spans = ((S.GDict)title["flashes"])["span_x"];
            S.GArray<S.Variant> span = spans[(int)flashRng.RandiRange(0, spans.Size() - 1)];
            double x = flashRng.RandfRange(S.Num.F(span[0]), S.Num.F(span[1]));
            double y = flashRng.RandfRange(low, high);
            S.GDict fires = title["fires"];
            return new S.Vector3(x, y, farZ - flashRng.RandfRange(SPOT_BACK, S.Num.F(fires["depth"])));
        }

        double Gap()
        {
            S.GArray<S.Variant> gap = cfg["gun_gap_s"];
            return rng.RandfRange(S.Num.F(gap[0]), S.Num.F(gap[1]));
        }

        double BoomGap()
        {
            S.GArray<S.Variant> gap = ((S.GDict)cfg["boom"])["every_s"];
            return rng.RandfRange(S.Num.F(gap[0]), S.Num.F(gap[1]));
        }
    }
}
