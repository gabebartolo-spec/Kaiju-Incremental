// The numbers of the Kaiju Creation lab set (scenes/creation_lab.gd, creation_injector.gd, creation_set.gd): where
// the vials, the injector's post and the canister stand, the injector's pose through a trip, the liquids' levels,
// the hit-stops' white and shake, the screens' beat and the camera. Every beat is a pure function of its progress
// (0..1), in Godot's axes (the view mirrors z). Plain C#: the view draws what this says.
using System;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public struct CreationVec
    {
        public double x, y, z;

        public CreationVec(double x, double y, double z)
        {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        public static CreationVec operator +(CreationVec a, CreationVec b) => new CreationVec(a.x + b.x, a.y + b.y, a.z + b.z);
        public static CreationVec operator -(CreationVec a, CreationVec b) => new CreationVec(a.x - b.x, a.y - b.y, a.z - b.z);
        public static CreationVec operator *(CreationVec a, double k) => new CreationVec(a.x * k, a.y * k, a.z * k);

        public CreationVec Lerp(CreationVec to, double k) => this + (to - this) * k;

        // Godot's Vector3.rotated(UP, angle).
        public CreationVec Turned(double angle)
        {
            double c = Math.Cos(angle), s = Math.Sin(angle);
            return new CreationVec(x * c + z * s, y, -x * s + z * c);
        }

        public double FlatLength() => Math.Sqrt(x * x + z * z);
    }

    public sealed class CreationLab
    {
        public const int TICKS_PER_SECOND = 60;

        // The white over the screen this tick (0..1), and the camera's shake offsets (metres, right and up).
        public double Flash, ShakeX, ShakeY;
        // The camera: where it stands, what it looks at, its vertical field of view (degrees).
        public CreationVec CameraAt, CameraLook;
        public double CameraFov;
        // The injector: the post's place, the carriage's turn, rise and slide, the needle tip in the lab.
        public readonly CreationVec Post;
        public double Yaw, Lift, Slide;
        public CreationVec Tip;
        public readonly CreationVec CanisterAt;
        // Liquids (0..1): each shown titan's vial, the Special K canister, the syringe barrel.
        public readonly double[] Vials;
        public double SpecialK = 1.0, Barrel;
        // The barrel holds Special K (else the picked genome).
        public bool BarrelIsSpecialK = true;
        // The dish: how far the gene has settled, the takeover's front, the overload's burn (each 0..1).
        public double Settle, Takeover_, Overload;
        // The screens' green spill (light energy) and the focused vial (-1: none lit).
        public double ScreensEnergy;
        public int Focused;

        readonly int titans;
        readonly GDict cfg, injector;
        readonly CreationVec tipLocal;
        int flashAge = -1, tick;
        bool struck, overloaded, poured;

        public CreationLab(int titanCount)
        {
            titans = titanCount;
            cfg = Cfg();
            injector = cfg["injector"];
            Vials = new double[titanCount];
            for (int i = 0; i < titanCount; i++) Vials[i] = 1.0;
            tipLocal = TipLocal();
            Post = PostAt();
            // creation_lab.gd _add_canister: a needle's reach from the post, turned round it from the dish.
            double turn = Num.F(injector["canister_turn"]) * Math.PI / 180.0;
            CanisterAt = Post + (Post * -1.0).Turned(turn);
            ScreensEnergy = Energy("screens");
            Pose(Aim(new CreationVec()), LiftFor(Num.F(injector["park_tip"])), 0.0);
            Zoom(0.0);
        }

        public static GDict Cfg() => Content.Section("creation")["lab"];

        public static double Energy(string key)
        {
            GDict energies = Cfg()["energy"];
            return Num.F(energies[key]);
        }

        public static CreationVec Vec(Variant raw)
        {
            GArray<Variant> xyz = raw;
            return new CreationVec(Num.F(xyz[0]), Num.F(xyz[1]), Num.F(xyz[2]));
        }

        public static double Smoothstep(double from, double to, double x)
        {
            double s = Math.Min(Math.Max((x - from) / (to - from), 0.0), 1.0);
            return s * s * (3.0 - 2.0 * s);
        }

        // Godot's roundi: a half rounds away from zero.
        public static int Round(double v) => (int)Math.Round(v, MidpointRounding.AwayFromZero);

        // ---- the rack (creation_set.gd) -----------------------------------------------------------------

        // The vial titan `index` fills.
        public static int VialOf(int index)
        {
            GDict vials = Cfg()["vials"];
            GArray<Variant> slots = vials["titan_slots"];
            return (int)Num.I(slots[index]);
        }

        // The middle of a vial's liquid column (x, z in the rack's cells): where the needle goes down.
        public static void VialCentre(int vial, out double x, out double z)
        {
            GDict v = Cfg()["vials"];
            GArray<Variant> columns = v["columns_x"];
            GArray<Variant> xs = columns[vial];
            GArray<Variant> zs = v["column_z"];
            x = (Num.F(xs[0]) + Num.F(xs[1])) * 0.5;
            z = (Num.F(zs[0]) + Num.F(zs[1])) * 0.5;
        }

        // A prop's place and turn (radians) as CreationSet.place gives them: a .kvox faces -Z, so a half turn more.
        public static void Placed(string prop, out CreationVec at, out double yaw)
        {
            GDict props = Cfg()["props"];
            GDict row = props[prop];
            at = Vec(row["at"]);
            yaw = (Num.F(row["yaw"]) + 180.0) * Math.PI / 180.0;
        }

        // Where the needle goes down into titan `index`'s vial (the lab's space, at the bench).
        public static CreationVec VialPoint(int index)
        {
            double voxel = Num.F(Cfg()["voxel"]);
            VialCentre(VialOf(index), out double cx, out double cz);
            Placed("rack", out CreationVec at, out double yaw);
            return at + new CreationVec(cx * voxel, 0.0, cz * voxel).Turned(yaw);
        }

        // ---- the injector (creation_injector.gd) --------------------------------------------------------

        // The needle tip from the post's axis: the model's tip cell, lengthened by `needle` cells, at its block's top.
        static CreationVec TipLocal()
        {
            GDict inj = Cfg()["injector"];
            double voxel = Num.F(Cfg()["voxel"]);
            GArray<Variant> tc = inj["tip"];
            GArray<Variant> pv = inj["pivot"];
            long x = Num.I(tc[0]) - Num.I(pv[0]), y = Num.I(tc[1]) - Num.I(inj["needle"]), z = Num.I(tc[2]) - Num.I(pv[1]);
            return new CreationVec(x * voxel, y * voxel + voxel * 0.5, z * voxel);
        }

        // How far the needle reaches from the post's axis (metres).
        public static double Reach()
        {
            GDict inj = Cfg()["injector"];
            GArray<Variant> tc = inj["tip"];
            GArray<Variant> pv = inj["pivot"];
            double dx = Num.F(tc[0]) - Num.F(pv[0]), dz = Num.F(tc[2]) - Num.F(pv[1]);
            return Math.Sqrt(dx * dx + dz * dz) * Num.F(Cfg()["voxel"]);
        }

        // creation_lab.gd _add_injector: the post stands behind the dish and the first vial, where the needle
        // reaches both.
        static CreationVec PostAt()
        {
            double reach = Reach();
            CreationVec v = VialPoint(0);
            double length = Math.Sqrt(v.x * v.x + v.z * v.z), half = length * 0.5;
            double k = Math.Sqrt(Math.Max(reach * reach - half * half, 0.0));
            // Vector2.orthogonal(): (y, -x).
            double sx = length > 0.0 ? v.z / length * k : 0.0, sy = length > 0.0 ? -v.x / length * k : 0.0;
            if (!(sy < 0.0))
            {
                sx = -sx;
                sy = -sy;
            }
            return new CreationVec(v.x * 0.5 + sx, 0.0, v.z * 0.5 + sy);
        }

        // The post's own turn: its base plate reaches out on the side away from the dish.
        public double PostYaw() => Math.Atan2(-Post.z, Post.x);

        // The carriage's turn that puts the needle over `target`.
        public double Aim(CreationVec target)
        {
            CreationVec d = target - Post;
            return Math.Atan2(-d.z, d.x) - Math.Atan2(-tipLocal.z, tipLocal.x);
        }

        // How far the boom slides out (metres, back if negative) to put the needle over `target`.
        public double SlideFor(CreationVec target) => (target - Post).FlatLength() - Reach();

        // The carriage's rise that puts the needle tip at height `h` (metres above the bench).
        public double LiftFor(double h) => h - tipLocal.y;

        // Which phase of a trip (tuning "trips" `key`) progress t is in: 0 rise, 1 turn to the source, 2 lower,
        // 3 draw, 4 rise, 5 turn back, 6 lower, 7 dispense, 8 park.
        public static int Phase(double t, string key)
        {
            GDict trips = Cfg()["trips"];
            GArray<Variant> shares = trips[key];
            double acc = 0.0;
            int n = (int)shares.Size();
            for (int i = 0; i < n; i++)
            {
                acc += Num.F(shares[i]);
                if (t < acc) return i;
            }
            return n - 1;
        }

        static double LerpAngle(double from, double to, double weight)
        {
            double tau = Math.PI * 2.0;
            double diff = Math.IEEERemainder(to - from, tau);  // the short way round, as Godot's lerp_angle
            return from + diff * weight;
        }

        // One trip (t 0..1) to `source` and back to the dish. heights: the needle's depth in the source, the swing
        // height and the depth in the dish. Gives the draw and dispense progress (0..1) for the liquids.
        public void Trip(double t, string key, CreationVec source, double sourceTip, double swing, double dishTip, out double draw, out double dispense)
        {
            GDict trips = Cfg()["trips"];
            GArray<Variant> raw = trips[key];
            int n = (int)raw.Size();
            double[] shares = new double[n];
            for (int i = 0; i < n; i++) shares[i] = Num.F(raw[i]);
            double home = Aim(new CreationVec()), there = Aim(source);
            double up = LiftFor(swing), down = LiftFor(sourceTip), dish = LiftFor(dishTip);
            double park = LiftFor(Num.F(injector["park_tip"])), reachOut = SlideFor(source);
            double[,] poses =
            {
                { home, park, 0.0 }, { home, up, 0.0 }, { there, up, reachOut }, { there, down, reachOut }, { there, down, reachOut },
                { there, up, reachOut }, { home, up, 0.0 }, { home, dish, 0.0 }, { home, dish, 0.0 }, { home, park, 0.0 },
            };
            double acc = 0.0;
            int end = 0;
            double[] progress = new double[n];
            double yaw = poses[0, 0], lift = poses[0, 1], slide = poses[0, 2];
            bool placed = false;
            for (int i = 0; i < n; i++)
            {
                double share = shares[i];
                if (share <= 0.0) continue;
                double k = Math.Min(Math.Max((t - acc) / share, 0.0), 1.0);
                progress[i] = k;
                if (!placed && t <= acc + share)
                {
                    bool last = i == n - 1 || RestZero(shares, i + 1);
                    double e = last ? k * k : Smoothstep(0.0, 1.0, k);
                    yaw = LerpAngle(poses[i, 0], poses[i + 1, 0], e);
                    lift = poses[i, 1] + (poses[i + 1, 1] - poses[i, 1]) * e;
                    slide = poses[i, 2] + (poses[i + 1, 2] - poses[i, 2]) * e;
                    placed = true;
                }
                acc += share;
                end = i + 1;
            }
            if (!placed)
            {
                yaw = poses[end, 0];
                lift = poses[end, 1];
                slide = poses[end, 2];
            }
            Pose(yaw, lift, slide);
            draw = progress[3];
            dispense = progress[7];
        }

        static bool RestZero(double[] shares, int from)
        {
            for (int j = from; j < shares.Length; j++)
                if (shares[j] > 0.0) return false;
            return true;
        }

        // The needle rises out of the agar to its park over the dish (k 0..1).
        void Rest(double k, double dishTip)
        {
            double e = Smoothstep(0.0, 1.0, k);
            double from = LiftFor(dishTip), to = LiftFor(Num.F(injector["park_tip"]));
            Pose(Aim(new CreationVec()), from + (to - from) * e, 0.0);
        }

        // Where the carriage sits on the post for the pose on show (the view places it there).
        public CreationVec CarriageAt()
        {
            double flat = tipLocal.FlatLength();
            var along = flat > 0.0 ? new CreationVec(tipLocal.x / flat, 0.0, tipLocal.z / flat).Turned(Yaw) : new CreationVec();
            return new CreationVec(0.0, Lift, 0.0) + along * Slide;
        }

        void Pose(double yaw, double lift, double slide)
        {
            Yaw = yaw;
            Lift = lift;
            Slide = slide;
            Tip = Post + CarriageAt() + tipLocal.Turned(yaw);
        }

        // ---- the beats (creation_lab.gd) ----------------------------------------------------------------

        // Lights the vial of titan `index` (-1: none).
        public void Focus(int index)
        {
            Focused = index >= 0 && index < titans ? index : -1;
        }

        // The swing height of a trip to a source as tall as `top`.
        double Clear(double top)
        {
            double tallest = Math.Max(Math.Max(top, Num.F(injector["cradle_top"])), Num.F(injector["park_tip"]));
            return tallest + Num.F(injector["clear"]);
        }

        // The gene goes in (t 0..1): the injector drains titan `index`'s vial into its barrel, swings back and puts
        // the gene into the agar, which settles from the needle out.
        public void Place(int index, double t)
        {
            if (!poured)
            {
                poured = true;
                BarrelIsSpecialK = false;
            }
            Trip(t, "place", VialPoint(index), Num.F(injector["vial_tip"]), Clear(Num.F(injector["vial_top"])), Num.F(injector["dish_tip"]), out double draw, out double dispense);
            if (index >= 0 && index < Vials.Length) Vials[index] = 1.0 - draw;
            Barrel = draw - dispense;
            Settle = dispense;
        }

        // The injection (t 0..1): the injector draws Special K from the canister and lowers the needle into the
        // agar (the strike at its end); the screens' glow starts to beat.
        public void Inject(double t)
        {
            tick++;
            if (t <= 0.0 || Math.Abs(Barrel) < 1e-5) BarrelIsSpecialK = true;
            Trip(t, "inject", CanisterAt, Num.F(injector["canister_tip"]), Clear(Num.F(injector["canister_top"])), Num.F(injector["dish_tip"]), out double draw, out double dispense);
            SpecialK = 1.0 - Num.F(injector["canister_draw"]) * draw;
            Barrel = draw - dispense;
            Beat(0.5);
        }

        // The takeover (t 0..1): a hit-stop at the strike, the lightning, a second hit-stop at the overload, then
        // the dish burns white. Each hit-stop flashes white and shakes the camera; the barrel drains into the dish.
        public void Takeover(double t)
        {
            tick++;
            GDict timing = Content.Section("creation")["timing"];
            double freeze = Num.F(cfg["freeze_s"]) / Num.F(timing["takeover_s"]);
            double ov = Num.F(cfg["overload_at"]);
            if (!struck)
            {
                struck = true;
                flashAge = 0;
            }
            if (t >= ov && !overloaded)
            {
                overloaded = true;
                flashAge = 0;
            }
            if (t < freeze) Takeover_ = 0.0;
            else if (t < ov) Takeover_ = (t - freeze) / (ov - freeze);
            else if (t >= ov + freeze) Overload = (t - ov - freeze) / (1.0 - ov - freeze);
            Hit((int)Num.I(cfg["flash_ticks"]), Num.F(cfg["shake"]), Num.F(cfg["shake_s"]));
            Beat(1.0 + t);
            Barrel = 1.0 - Smoothstep(freeze, 0.3, t);
            Rest(Smoothstep(0.3, 0.6, t), Num.F(injector["dish_tip"]));
        }

        // A hit-stop's white (full on its first tick, fading over `ticks`) and camera shake (`amount` metres,
        // fading over `seconds`); deterministic, from the tick.
        void Hit(int ticks, double amount, double seconds)
        {
            if (flashAge < 0)
            {
                Flash = 0.0;
                return;
            }
            Flash = Math.Min(Math.Max(1.0 - (double)flashAge / Math.Max(ticks, 1), 0.0), 1.0);
            double fade = 1.0 - Math.Min(Math.Max(flashAge / (seconds * TICKS_PER_SECOND), 0.0), 1.0);
            ShakeX = Math.Sin(flashAge * 2.3) * amount * fade;
            ShakeY = Math.Cos(flashAge * 3.1) * amount * fade;
            flashAge++;
        }

        // The screens' green spill beats like a heart, faster as the takeover grows.
        void Beat(double rate)
        {
            double pulse = Math.Pow(Math.Max(Math.Sin(tick * 0.16 * rate), 0.0), 6.0);
            ScreensEnergy = Energy("screens") * (0.6 + 1.4 * pulse);
        }

        // The camera (t 0..1): from the close-up over the bench it turns onto the dish and rushes down into it,
        // faster and faster, narrowing.
        public void Zoom(double t)
        {
            Flash = 0.0;
            ShakeX = ShakeY = 0.0;
            GDict shot = cfg["camera"];
            GDict end = cfg["zoom"];
            double k = t * t;
            CameraAt = Vec(shot["position"]).Lerp(Vec(end["position"]), k);
            double from = Num.F(shot["fov"]);
            CameraFov = from + (Num.F(end["fov"]) - from) * k;
            CameraLook = Vec(shot["look"]).Lerp(Vec(end["look"]), Smoothstep(0.0, 0.25, t));
        }
    }
}
