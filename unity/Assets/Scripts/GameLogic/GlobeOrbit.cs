// The hologram globe's motion and its screen maths (scenes/globe_view.gd, D-418): it spins idly; a left-drag turns
// it (sideways spins, up and down tilts) and a press that moved no further than the click slop is a click; a pick
// flies the camera in over FLY_S (the globe turns the continent to the centre, the camera closes in, the spin holds)
// and fly_out goes back. The camera ray meets the land sphere's near side for the hit test, and each marker's anchor
// projects to the screen, faded as it turns toward the globe's edge. All in Godot's axes (y up, the camera on +z
// looking down -z), screen points in px from the top-left of a `Width` x `Height` view; plain C#.
using System;

namespace Kaiju.Game
{
    public sealed class GlobeOrbit
    {
        // globe_view.gd's consts, by name.
        public const double RADIUS = 1.0;
        public const double LAND_LIFT = 1.003;  // the land sphere's radius over the shell's, so the two never fight
        public const int SEGMENTS = 96;
        public const int RINGS = 48;
        public const double CAMERA_DISTANCE = 3.4;
        public const double ZOOM_DISTANCE = 2.6;  // the camera's distance from the centre while a continent is selected
        public const double CAMERA_FOV = 38.0;  // degrees, vertical
        public const double START_TILT = 0.3;  // rad, the globe leans toward the camera so the north reads
        public const double TILT_LIMIT = 1.1;  // rad either way
        public const double IDLE_SPIN = 0.25;  // rad/s
        public const double DRAG_RAD_PER_PX = 0.006;
        public const double CLICK_SLOP_PX = 6.0;  // a press that moves further than this is a drag, not a pick
        public const double FLY_S = 0.7;  // the fly-to and fly-out time, eased in and out
        // A marker fades over this much of the facing range as its anchor turns toward the globe's edge.
        public const double MARKER_FADE = 0.25;

        const double DEGREES_PER_HALF_TURN = 180.0;

        public double Yaw;
        public double Tilt { get; private set; } = START_TILT;
        public double Distance { get; private set; } = CAMERA_DISTANCE;
        public bool Spin = true;
        // The continent the camera has flown to ("" when it is out at CAMERA_DISTANCE).
        public string Selected { get; private set; } = "";
        // The view's size in px (Godot's visible rect).
        public double Width = 1.0, Height = 1.0;

        readonly double[] from = new double[3], to = new double[3];
        double flyT = 1.0;  // 1 when no flight is under way
        double dragPx;

        public bool Flying => flyT < 1.0;
        public bool Dragging { get; private set; }

        public void SetTilt(double rad) => Tilt = Clamp(rad, -TILT_LIMIT, TILT_LIMIT);

        // Back to the pose the globe opens in (globe_view.gd _ready), nothing selected, no flight.
        public void Reset(double yaw)
        {
            Yaw = yaw;
            Tilt = START_TILT;
            Distance = CAMERA_DISTANCE;
            Selected = "";
            flyT = 1.0;
            Dragging = false;
        }

        // globe_view.gd _process: the flight eased along, else the idle spin.
        public void Step(double dt)
        {
            if (flyT < 1.0)
            {
                flyT = Math.Min(1.0, flyT + dt / FLY_S);
                double k = Smoothstep(0.0, 1.0, flyT);
                Yaw = from[0] + (to[0] - from[0]) * k;
                SetTilt(from[1] + (to[1] - from[1]) * k);
                Distance = from[2] + (to[2] - from[2]) * k;
            }
            else if (Spin && !Dragging && Selected == "") Yaw += IDLE_SPIN * dt;
        }

        // The left button went down: a drag starts unless a flight is under way.
        public void Press()
        {
            Dragging = flyT >= 1.0;
            dragPx = 0.0;
        }

        // The pointer moved (dx, dy) px: while dragging it turns the globe.
        public void Move(double dx, double dy)
        {
            if (!Dragging) return;
            dragPx += Math.Sqrt(dx * dx + dy * dy);
            Yaw += dx * DRAG_RAD_PER_PX;
            SetTilt(Tilt + dy * DRAG_RAD_PER_PX);
        }

        // The left button came up: true when the press was a click (a drag no longer than CLICK_SLOP_PX).
        public bool Release()
        {
            if (!Dragging) return false;
            Dragging = false;
            return dragPx <= CLICK_SLOP_PX;
        }

        // globe_view.gd fly_to: `id` turned to the centre (its anchor n, a unit point in the globe's frame) and the
        // camera closed in.
        public void FlyTo(string id, double nx, double ny, double nz)
        {
            Selected = id;
            double face = -Math.Atan2(nx, nz);
            double yaw = Yaw + Wrap(face - Yaw, -Math.PI, Math.PI);
            double tilt = Clamp(Math.Asin(Clamp(ny, -1.0, 1.0)), -TILT_LIMIT, TILT_LIMIT);
            Fly(yaw, tilt, ZOOM_DISTANCE);
        }

        // globe_view.gd fly_out: back out to CAMERA_DISTANCE where the globe stands; the spin resumes.
        public void FlyOut()
        {
            Selected = "";
            Fly(Yaw, Tilt, CAMERA_DISTANCE);
        }

        // The flight's target (yaw, tilt, distance), as the last FlyTo or FlyOut set it.
        public double[] Target => (double[])to.Clone();

        void Fly(double yaw, double tilt, double distance)
        {
            from[0] = Yaw;
            from[1] = Tilt;
            from[2] = Distance;
            to[0] = yaw;
            to[1] = tilt;
            to[2] = distance;
            flyT = 0.0;
        }

        // The screen's focal length in px: the vertical field of view spans the height (Godot's keep_height).
        double Focal => Height / 2.0 / Math.Tan(CAMERA_FOV * Math.PI / DEGREES_PER_HALF_TURN / 2.0);

        // A point in the globe's own frame to world space as it turns now: the tilt about x over the yaw about y.
        public void ToWorld(double x, double y, double z, out double wx, out double wy, out double wz)
        {
            double c = Math.Cos(Yaw), s = Math.Sin(Yaw);
            double ax = x * c + z * s, az = -x * s + z * c;
            double ct = Math.Cos(Tilt), st = Math.Sin(Tilt);
            wx = ax;
            wy = y * ct - az * st;
            wz = y * st + az * ct;
        }

        // The inverse of ToWorld.
        public void ToLocal(double wx, double wy, double wz, out double x, out double y, out double z)
        {
            double ct = Math.Cos(Tilt), st = Math.Sin(Tilt);
            double ay = wy * ct + wz * st, az = -wy * st + wz * ct;
            double c = Math.Cos(Yaw), s = Math.Sin(Yaw);
            x = wx * c - az * s;
            y = ay;
            z = wx * s + az * c;
        }

        // globe_view.gd continent_at's ray: where the camera ray through a screen point meets the land sphere's near
        // side, in the globe's own frame; false off the globe.
        public bool Hit(double sx, double sy, out double x, out double y, out double z)
        {
            x = y = z = 0.0;
            double f = Focal;
            double dx = (sx - Width / 2.0) / f, dy = -(sy - Height / 2.0) / f, dz = -1.0;
            double len = Math.Sqrt(dx * dx + dy * dy + dz * dz);
            dx /= len; dy /= len; dz /= len;
            double r = RADIUS * LAND_LIFT;
            double along = -Distance * dz;  // (centre - origin) . dir, the camera at (0, 0, Distance)
            double mx = dx * along, my = dy * along, mz = Distance + dz * along;
            double miss = mx * mx + my * my + mz * mz;
            if (miss > r * r) return false;
            double t = along - Math.Sqrt(r * r - miss);
            ToLocal(dx * t, dy * t, Distance + dz * t, out x, out y, out z);
            return true;
        }

        // globe_view.gd continent_at: the mask value under a screen point, 0 for sea or off the globe.
        public int ValueAt(byte[] mask, int width, int height, double sx, double sy)
        {
            if (!Hit(sx, sy, out double x, out double y, out double z)) return 0;
            GlobeMath.UvOf(x, y, z, out double u, out double v);
            return GlobeMath.IdAtUv(mask, width, height, u, v);
        }

        // globe_view.gd _place_markers: an anchor (unit point, the globe's frame) on the land sphere, projected to the
        // screen; `alpha` its fade, 0 (and false) when it is on the far side.
        public bool Marker(double nx, double ny, double nz, out double sx, out double sy, out double alpha)
        {
            double r = RADIUS * LAND_LIFT;
            ToWorld(nx * r, ny * r, nz * r, out double wx, out double wy, out double wz);
            double wl = Math.Sqrt(wx * wx + wy * wy + wz * wz);
            double ex = -wx, ey = -wy, ez = Distance - wz;
            double el = Math.Sqrt(ex * ex + ey * ey + ez * ez);
            double facing = (wx * ex + wy * ey + wz * ez) / (wl * el);
            double depth = Distance - wz, f = Focal;
            sx = Width / 2.0 + wx / depth * f;
            sy = Height / 2.0 - wy / depth * f;
            alpha = facing > 0.0 ? Smoothstep(0.0, MARKER_FADE, facing) : 0.0;
            return facing > 0.0;
        }

        // Godot's smoothstep.
        public static double Smoothstep(double a, double b, double x)
        {
            double t = Clamp((x - a) / (b - a), 0.0, 1.0);
            return t * t * (3.0 - 2.0 * t);
        }

        // Godot's wrapf.
        public static double Wrap(double value, double min, double max)
        {
            double range = max - min;
            return value - range * Math.Floor((value - min) / range);
        }

        static double Clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
    }
}
