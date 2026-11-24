// A downed helicopter's numbers (scenes/heli_wreck.gd, scenes/heli_debris.gd; D-140, D-141, D-145, D-458): the
// spinning fall's pose, the model's parts and the chunks thrown out (each draw from the view's own heli_wreck stream in
// Godot's order), every piece's arc, bounce, landing, rest and fade, and a crew member's drift under a canopy and the
// canopy's cells. Godot axes. Plain C# (System.Numerics) so SimTests/HeliWreckCheck.cs walks it against Godot's own
// output. Presentation only: the sim's AirWing decides the fate and the crash point.
using System;
using System.Collections.Generic;
using N = System.Numerics;
using S = Kaiju.Sim;

namespace Kaiju.Game
{
    // Tuning "heli_wreck", the keys these numbers read.
    public struct HeliTuning
    {
        public float spin, pitchDeg, rollDeg, swing, gravity, throwMin, throwMax, upMin, upMax, restSeconds, fadeSeconds;
        public float partFire, shardFire, chuteSpeed, canopyHang, trailOffset;
        // Tuning "street" person_voxel: the crew's cell, which sets where the shroud lines hold.
        public float personVoxel;
        // GDScript works these out in doubles: the dome's rim is round(width / 2 / voxel), 7.5 cells, a half.
        public double canopyVoxel, canopyWidth;

        public static HeliTuning Of(S.GDict cfg)
        {
            float F(string key) => (float)(double)S.Num.F(cfg[key]);
            double D(string key) => S.Num.F(cfg[key]);
            return new HeliTuning
            {
                spin = F("spin"), pitchDeg = F("pitch_deg"), rollDeg = F("roll_deg"), swing = F("swing"), gravity = F("gravity"),
                throwMin = F("throw_min"), throwMax = F("throw_max"), upMin = F("up_min"), upMax = F("up_max"),
                restSeconds = F("rest_seconds"), fadeSeconds = F("fade_seconds"), partFire = F("part_fire"),
                shardFire = F("shard_fire"), chuteSpeed = F("chute_speed"), canopyVoxel = D("canopy_voxel"),
                canopyWidth = D("canopy_width"), canopyHang = F("canopy_hang"), trailOffset = F("trail_offset"),
                personVoxel = (float)(double)S.Num.F(S.Content.Section("street")["person_voxel"]),
            };
        }
    }

    // A wreck falling along the sim's drift (heli_wreck.gd Fall): where it is and how it is turned after each step.
    public sealed class HeliFall
    {
        public N.Vector3 from, drift, side, position;
        // Godot's basis columns (x, y, z): the body's right, up and back.
        public N.Vector3 basisX = N.Vector3.UnitX, basisY = N.Vector3.UnitY, basisZ = N.Vector3.UnitZ;
        public double seconds, t, yaw;

        // _spin: the path bows out to the drift's left; a fall with no drift bows along +x.
        public HeliFall(N.Vector3 from, N.Vector3 drift, double seconds)
        {
            this.from = from;
            this.drift = new N.Vector3(drift.X, 0f, drift.Z);
            this.seconds = seconds;
            position = from;
            var left = new N.Vector3(-this.drift.Z, 0f, this.drift.X);
            side = left.LengthSquared() > 0f ? N.Vector3.Normalize(left) : N.Vector3.Zero;
            if (side.Length() < HeliWreck.SIDE_MIN) side = N.Vector3.UnitX;
        }

        // _fall: its height drops slowly then fast, it bows out of the straight line, pitches nose down, rolls and
        // spins up as it goes.
        public void Step(double dt, in HeliTuning tuning)
        {
            t += dt;
            double u = Math.Clamp(t / seconds, 0.0, 1.0);
            N.Vector3 bow = side * (float)(Math.Sin(Math.PI * u) * tuning.swing);
            position = from + drift * (float)t + bow - new N.Vector3(0f, (float)(from.Y * u * u), 0f);
            yaw += dt * tuning.spin * (HeliWreck.SPIN_BASE + u);
            double tumble = Math.Pow(u, HeliWreck.TUMBLE_POWER);
            double pitch = -tuning.pitchDeg * Math.PI / HeliWreck.DEGREES_PER_HALF_TURN * tumble;
            double roll = tuning.rollDeg * Math.PI / HeliWreck.DEGREES_PER_HALF_TURN * tumble;
            // Basis(UP, yaw) * Basis(RIGHT, pitch) * Basis(BACK, roll), written row-vector (the product reversed).
            N.Matrix4x4 m = N.Matrix4x4.CreateFromAxisAngle(N.Vector3.UnitZ, (float)roll)
                * N.Matrix4x4.CreateFromAxisAngle(N.Vector3.UnitX, (float)pitch)
                * N.Matrix4x4.CreateFromAxisAngle(N.Vector3.UnitY, (float)yaw);
            basisX = new N.Vector3(m.M11, m.M12, m.M13);
            basisY = new N.Vector3(m.M21, m.M22, m.M23);
            basisZ = new N.Vector3(m.M31, m.M32, m.M33);
        }

        // Where flame `k` (0 nose, 1 middle, 2 tail) burns along the body now.
        public N.Vector3 Flame(int k, in HeliTuning tuning) =>
            position + basisY * HeliWreck.FLAME_UP + basisZ * ((k - 1) * tuning.trailOffset);
    }

    // One thing thrown from a wreck (heli_debris.gd Piece): a model part or a chunk, flying, then lying, then fading.
    public sealed class HeliPiece
    {
        // Godot's position and Euler rotation (YXZ, as Node3D.rotation), its push and tumble, and its scale before it
        // fades.
        public N.Vector3 position, rotation, velocity, spin, size = N.Vector3.One, scale = N.Vector3.One;
        public float half = HeliWreck.CHUNK_HALF, lie;
        public bool flat;
        public double rest = -1.0;
        // A burning piece's Fire size and seed (Fire.new); 0: none. `burning` goes false when it is put out.
        public float fire, fireSeed;
        public bool burning;
        // A chunk's colour (HeliWreck.ChunkColour); -1 for a model part.
        public int colour = -1;
    }

    // One crew member under a canopy, drifting from `from` to `to` (heli_wreck.gd Chute).
    public struct HeliChute
    {
        public N.Vector3 from, to;
        public double seconds;

        // Where it hangs `t` seconds after the jump and its swing (rotation.z); false once it has landed.
        public bool Pose(double t, out N.Vector3 at, out float swing)
        {
            double u = t / seconds;
            at = N.Vector3.Lerp(from, to, (float)u);
            swing = (float)(Math.Sin(t * HeliWreck.SWING_RATE) * HeliWreck.SWING_REACH);
            return u < 1.0;
        }
    }

    // One cube of a canopy's dome (in voxels from its middle) and which of the two panel shades it wears.
    public struct CanopyCell
    {
        public int x, y, z;
        public bool dark;
    }

    public static class HeliWreck
    {
        // heli_wreck.gd WRECK_HALF: how high the body's middle rides lying on the street; a rotor's or the gun's.
        public const float WRECK_HALF = 0.7f, PART_HALF = 0.3f;
        // heli_debris.gd Piece.half's default.
        public const float CHUNK_HALF = 0.2f;
        // heli_debris.gd BOUNCE_BELOW, BOUNCE_KEEP; a bounce halves the slide and the tumble.
        public const float BOUNCE_BELOW = -3f, BOUNCE_KEEP = 0.3f, BOUNCE_SLIDE = 0.5f, BOUNCE_SPIN = 0.5f;
        // _step: a burning piece is put out this share of the way through its rest.
        public const double FIRE_OUT = 0.6;
        // _fall: below this length the drift's side is no direction; spin starts at SPIN_BASE; the tumble's curve.
        public const float SIDE_MIN = 0.5f;
        public const double SPIN_BASE = 0.5, TUMBLE_POWER = 1.4;
        // deg_to_rad: pitch_deg and roll_deg are degrees.
        public const double DEGREES_PER_HALF_TURN = 180.0;
        // _fall: the flames ride this high on the body.
        public const float FLAME_UP = 0.5f;
        // _break_up: a part's lift starts here; its tumble's x and z run TUMBLE_MIN..1, y -1..1, all times PART_SPIN;
        // the body rolls BODY_ROLL and keeps BODY_YAW of its yaw tumble, and flies at BODY_PUSH of the push.
        public const double PART_UP_MIN = 2.0, TUMBLE_MIN = 0.4;
        public const float PART_SPIN = 7f, BODY_ROLL = 0.8f, BODY_YAW = 0.3f, BODY_PUSH = 0.5f;
        // HeliDebris.throw: a voxel part lands rolled LIE_MIN..LIE_MAX either way; a fire's seed runs 0..FIRE_SEED.
        public const double LIE_MIN = 0.7, LIE_MAX = 1.4, FIRE_SEED = 10.0, COIN = 0.5;
        // shards: a chunk's size, its start this far out, its tumble rate.
        public const double CHUNK_MIN = 0.25, CHUNK_MAX = 0.7, CHUNK_SPIN_MIN = 4.0, CHUNK_SPIN_MAX = 12.0;
        public const float CHUNK_OUT = 0.5f;
        // HelicopterModel.break_up's parts, in its order.
        public const int BODY = 0, MAIN_ROTOR = 1, TAIL_ROTOR = 2, GUN = 3, PARTS = 4;
        // heli_debris.gd chunk_colours: paint 0, CHARCOAL, SCORCH, paint 1.
        public const int PAINT_A = 0, CHARCOAL = 1, SCORCH = 2, PAINT_B = 3, CHUNK_COLOURS = 4;
        public const int CHARCOAL_RGB = 0x3a3d40, SCORCH_RGB = 0x5a4a36;
        // _jump: crew jump this far apart across x, half a metre down and 1.5 m back; they drift at half the wind.
        public const float CREW_APART = 7f, CREW_DROP = 0.5f, CREW_BACK = 1.5f, CREW_DRIFT = 0.5f, CREW_MIDDLE = 0.5f;
        // _process: a chute swings at this rate and reach.
        public const double SWING_RATE = 2.0, SWING_REACH = 0.15;
        // _canopy: the dome rises this share of its rim; 8 panels; the lines run from 0.4 of the width down to the
        // tops of the raised hands (voxel_person.gd HANDS_UP 11, a cell higher).
        public const double CANOPY_RISE = 0.55;
        public const int CANOPY_PANELS = 8;
        public const float LINE_SPREAD = 0.4f;
        public const int HANDS_TOP = 12;
        // crashed: the body drops where it lands (break_up at 0.6), shards fly 0.7 as far from 0.8 m up, 2 of them burning.
        public const double CRASH_REACH = 0.6, CRASH_SHARD_REACH = 0.7;
        public const float CRASH_LIFT = 0.8f;
        public const int CRASH_BURNING = 2;
        const double TAU = 2 * Math.PI;

        // _break_up: the model's four parts thrown out from where they are (`reach` scales the throw; `inAir`: the
        // body flies on burning, else it drops where it lies), drawn from `rng` in Godot's order (HeliDebris.throw's
        // draws come after each part's own). Each part's position and rotation are the view's; the body's yaw is
        // set to a quarter turn. Returns the pieces in part order.
        public static void BreakUp(S.RandomNumberGenerator rng, in HeliTuning tuning, double reach, bool inAir, List<HeliPiece> into)
        {
            for (int n = 0; n < PARTS; n++)
            {
                double side = TAU * (n + rng.Randf()) / PARTS;
                N.Vector3 outward = Around(side) * (float)rng.RandfRange(tuning.throwMin, tuning.throwMax);
                N.Vector3 velocity = outward * (float)reach + new N.Vector3(0f, (float)(rng.RandfRange(PART_UP_MIN, tuning.upMax) * reach), 0f);
                var spin = new N.Vector3((float)rng.RandfRange(TUMBLE_MIN, 1.0), (float)rng.RandfRange(-1.0, 1.0), (float)rng.RandfRange(TUMBLE_MIN, 1.0));
                bool body = n == BODY;
                if (body) spin = new N.Vector3(0f, spin.Y * BODY_YAW, BODY_ROLL);
                if (body && !inAir)
                {
                    velocity = N.Vector3.Zero;
                    spin = N.Vector3.Zero;
                }
                float fire = inAir && n % 2 == 0 ? tuning.partFire : 0f;
                HeliPiece piece = Throw(rng, velocity * (body ? BODY_PUSH : 1f), spin * PART_SPIN, fire, true);
                piece.half = WRECK_HALF;
                if (n > BODY)
                {
                    piece.flat = true;
                    piece.lie = n == TAIL_ROTOR ? (float)(Math.PI * 0.5) : 0f;
                    piece.half = PART_HALF;
                }
                into.Add(piece);
            }
        }

        // The body's yaw once break_up has turned it to lie across the view.
        public const float BODY_TURN = (float)(Math.PI * 0.5);

        // shards: `count` chunks from `at`, `burning` of them on fire, thrown out and up (`reach` scales it), each in
        // its ChunkColour; positions start at the chunk's place.
        public static void Shards(S.RandomNumberGenerator rng, in HeliTuning tuning, N.Vector3 at, int count, int burning, double reach,
            List<HeliPiece> into)
        {
            for (int n = 0; n < count; n++)
            {
                double side = TAU * (n + rng.Randf()) / Math.Max(1.0, count);
                N.Vector3 outward = Around(side) * (float)rng.RandfRange(tuning.throwMin, tuning.throwMax);
                N.Vector3 velocity = outward * (float)reach + new N.Vector3(0f, (float)(rng.RandfRange(tuning.upMin, tuning.upMax) * reach), 0f);
                N.Vector3 size = N.Vector3.One * (float)rng.RandfRange(CHUNK_MIN, CHUNK_MAX);
                float fire = n < burning ? tuning.shardFire : 0f;
                double rate = rng.RandfRange(CHUNK_SPIN_MIN, CHUNK_SPIN_MAX);
                var spin = new N.Vector3((float)rng.RandfRange(-1.0, 1.0), (float)rng.RandfRange(-1.0, 1.0), (float)rng.RandfRange(-1.0, 1.0)) * (float)rate;
                HeliPiece piece = Throw(rng, velocity, spin, fire, false);
                piece.position = at + N.Vector3.Normalize(outward) * CHUNK_OUT;
                piece.size = size;
                piece.scale = size;
                piece.half = size.Y * 0.5f;
                piece.colour = n % CHUNK_COLOURS;
                into.Add(piece);
            }
        }

        // HeliDebris.throw: a voxel part (not a chunk) lands rolled either way; a burning piece seeds its Fire.
        static HeliPiece Throw(S.RandomNumberGenerator rng, N.Vector3 velocity, N.Vector3 spin, float fire, bool part)
        {
            var piece = new HeliPiece { velocity = velocity, spin = spin };
            if (part) piece.lie = (float)(rng.RandfRange(LIE_MIN, LIE_MAX) * (rng.Randf() < COIN ? 1.0 : -1.0));
            if (fire > 0f)
            {
                piece.fire = fire;
                piece.fireSeed = (float)(rng.Randf() * FIRE_SEED);
                piece.burning = true;
            }
            return piece;
        }

        static N.Vector3 Around(double angle) => new N.Vector3((float)Math.Cos(angle), 0f, (float)Math.Sin(angle));

        // _step: one frame of a piece; false once it has faded away.
        public static bool Step(HeliPiece piece, double dt, in HeliTuning tuning)
        {
            if (piece.rest < 0.0)
            {
                piece.velocity.Y = (float)(piece.velocity.Y - tuning.gravity * dt);
                piece.position += piece.velocity * (float)dt;
                // Moving the node rebuilds its rotation from its basis (Node3D.get_rotation), so the tumble adds to
                // Godot's own reading of the angles, not the last ones set.
                piece.rotation = GodotEuler.Read(piece.rotation, ref piece.scale) + piece.spin * (float)dt;
                if (piece.position.Y <= piece.half && piece.velocity.Y < 0f) Land(piece);
                return true;
            }
            piece.rest += dt;
            if (piece.burning && piece.rest > tuning.restSeconds * FIRE_OUT) piece.burning = false;
            if (piece.rest > tuning.restSeconds)
                piece.scale = piece.size * (float)Math.Max(0.0, 1.0 - (piece.rest - tuning.restSeconds) / tuning.fadeSeconds);
            if (piece.rest > tuning.restSeconds + tuning.fadeSeconds)
            {
                piece.burning = false;
                return false;
            }
            return true;
        }

        // _land: a hard landing bounces once; otherwise it lies, a long part level and rolled onto its side, a chunk
        // flat on a face.
        static void Land(HeliPiece piece)
        {
            piece.position.Y = piece.half;
            if (piece.velocity.Y < BOUNCE_BELOW)
            {
                piece.velocity = new N.Vector3(piece.velocity.X * BOUNCE_SLIDE, -piece.velocity.Y * BOUNCE_KEEP, piece.velocity.Z * BOUNCE_SLIDE);
                piece.spin *= BOUNCE_SPIN;
                return;
            }
            // Setting node.rotation.x reads the angles back from the moved node first; a bounce leaves them alone.
            piece.rotation = GodotEuler.Read(piece.rotation, ref piece.scale);
            piece.velocity = N.Vector3.Zero;
            piece.spin = N.Vector3.Zero;
            piece.rest = 0.0;
            if (piece.lie != 0f || piece.flat)
            {
                piece.rotation.X = 0f;
                piece.rotation.Z = piece.lie;
                return;
            }
            piece.rotation.X = Face(piece.rotation.X);
            piece.rotation.Z = Face(piece.rotation.Z);
        }

        // roundf(a / (PI / 2)) * PI / 2: the nearest quarter turn (halves away from zero, as Godot rounds).
        static float Face(float a) => (float)(Math.Round(a / (Math.PI * 0.5), MidpointRounding.AwayFromZero) * Math.PI * 0.5);

        // _spin and _jump: crew member `n` of a wreck hit at `at`, drifting with the fall's `drift`.
        public static HeliChute Chute(int n, N.Vector3 at, N.Vector3 drift, in HeliTuning tuning)
        {
            N.Vector3 from = at + new N.Vector3((n - CREW_MIDDLE) * CREW_APART, -CREW_DROP, CREW_BACK);
            double seconds = from.Y / tuning.chuteSpeed;
            return new HeliChute
            {
                from = from, seconds = seconds,
                to = new N.Vector3(from.X, 0f, from.Z) + drift * (float)(seconds * CREW_DRIFT),
            };
        }

        // _canopy: the dome's cubes, widest at the rim, in Godot's order; each sits at (x, y, z) * canopy_voxel above
        // the hang.
        public static void Canopy(in HeliTuning tuning, List<CanopyCell> into)
        {
            int rim = (int)Math.Round(tuning.canopyWidth * 0.5 / tuning.canopyVoxel, MidpointRounding.AwayFromZero);
            int rise = Math.Max(1, (int)Math.Round(rim * CANOPY_RISE, MidpointRounding.AwayFromZero));
            for (int x = -rim; x <= rim; x++)
                for (int z = -rim; z <= rim; z++)
                    for (int y = 0; y <= rise; y++)
                    {
                        double flat = (float)(x * x + z * z) / (double)(rim * rim);
                        if (flat + (double)(y * y) / (rise * rise) > 1.0) continue;
                        int panel = (int)Math.Floor((Math.Atan2(z, x) + Math.PI) / (TAU / CANOPY_PANELS)) % 2;
                        into.Add(new CanopyCell { x = x, y = y, z = z, dark = panel != 0 });
                    }
        }

        // _canopy: shroud line `corner` (0..3: (1, 1), (-1, 1), (1, -1), (-1, -1)) from the dome's edge to the
        // tops of the soldier's raised hands.
        public static void Line(int corner, in HeliTuning tuning, out N.Vector3 from, out N.Vector3 to)
        {
            float cx = corner % 2 == 0 ? 1f : -1f, cz = corner < 2 ? 1f : -1f;
            float reach = (float)(tuning.canopyWidth * LINE_SPREAD);
            from = new N.Vector3(cx * reach, tuning.canopyHang, cz * reach);
            to = new N.Vector3(0f, HANDS_TOP * tuning.personVoxel, 0f);
        }
    }
}
