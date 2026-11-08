// Generated from sim/breath_cone.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class BreathCone : RefCounted
    {
        public static implicit operator BreathCone(Variant v) => (BreathCone)v.Obj;

        // The cone a cone breath (the reptilian's Atomic Breath) burns, the sim's one definition of it:
        // RampageSim fires it and BreathAim (presentation) draws it while the breath is ready.
        // It starts at the snout: kaiju_pos is the model's origin, on the croc its tail root, and the
        // snout is city "breath_snout_ahead" model lengths ahead (per size tier, x body scale; measured
        // from the reptilian rigs: baby 10.4, adolescent 10.3, adult 13.5). It runs along the facing
        // out to the ability's reach, within cone_half_angle_deg either side.
        // How far past its flank or end a cover circle may go, in rows (reach / count), and the share of
        // that margin its radius takes up; how far in from the flank (rows) the flank circles sit.
        public const double FLANK_ROWS = 2.0;
        public const double FLANK_FIT = 0.99;
        public const double FLANK_INSET_ROWS = 0.72;
        // {"origin": Vector2, "dir": Vector2, "reach": float, "half_angle": float (radians)}.

        public static GDict Of(RampageSim sim)
        {
            GArray<Variant> snout = sim.city["breath_snout_ahead"];
            double ahead = Num.F(snout[Gd.Mini(sim.SizeTier(), snout.Size() - 1)]) * sim.BodyScale();
            double half = Gd.DegToRad(Num.F(sim.city["cone_half_angle_deg"]));
            var at = sim.kaijuPos + sim.facing * ahead;
            return new GDict { { "origin", at }, { "dir", sim.facing }, { "reach", sim.AbilityReach() }, { "half_angle", half } };
        }
        // Fires the breath (the signature): burns what BreathAim shows by `damage`, reaches up to the
        // helicopters, and with City Ablaze owned can set the buildings it hits alight (D-129).

        public static void Breathe(RampageSim sim, double reach, double damage)
        {
            GDict aim = Of(sim);
            double halfAngle = Num.F(aim["half_angle"]);
            Vector2 origin = aim["origin"];
            var dir = sim.facing;
            sim.events.Append(new GDict { { "type", "ability" }, { "kind", "cone" }, { "reach", reach }, { "from", origin } });
            var cone = new Callable(a_ =>
            {
                Vector2 p = a_[0];
                double r = a_[1];
                var to = p - origin;
                if (to.Length() > reach + r)
                {
                    return 0.0;
                }
                return ((to.Length() <= r || Gd.Absf(dir.AngleTo(to)) <= halfAngle) ? 1.0 : 0.0);
            });
            // The ignite rolls come first, on the buildings as they stood: a block the breath then breaks
            // was still in its path (lead 2026-10-22, baby-stage finding).
            sim.powers.fire.Scorch(new Rect2(origin - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), cone);
            // fire reaches up to the helicopters
            sim.hitAir = true;
            sim.HitArea(cone, damage);
            sim.hitAir = false;
        }
        // Circles (x, y centre, z radius) that together cover the cone `of` gives, out to its reach,
        // so presentation can flatten everything the breath burns (build 2 note 26: trees stood).
        // `count` circles down the axis (each as wide as the cone there, but never more than
        // FLANK_ROWS rows past its flank or end), plus count / 2 a side along each flank to take in
        // what the axis circles leave at the edges. So nothing outside the cone goes by more than that
        // margin, and under 1 percent of the cone's area is left (tests/lib/city_breath_trees.gd).

        public static GArray<Vector3> Cover(GDict cone, long count = 12)
        {
            Vector2 origin = cone["origin"];
            Vector2 dir = cone["dir"];
            var across = dir.Orthogonal();
            double reach = Num.F(cone["reach"]);
            double half = Num.F(cone["half_angle"]);
            double slope = Gd.Tan(half);
            double step = reach / count;
            double margin = FLANK_ROWS * step;
            GArray<Vector3> @out = new GArray<Vector3>();
            foreach (long i in Gd.Range(count))
            {
                double d = (i + 0.5) * step;
                double wide = new Vector2((d + step * 0.5) * slope, step * 0.5).Length();
                double inside = Gd.Minf((d * slope + margin) * Gd.Cos(half), Gd.Minf(reach + step - d, d + step));
                var at = origin + dir * d;
                @out.Append(new Vector3(at.x, at.y, Gd.Minf(wide, inside * FLANK_FIT)));
            }
            long perFlank = Gd.Maxi(1, count / 2);
            double radius = margin * Gd.Cos(half) * FLANK_FIT;
            double inset = step * FLANK_INSET_ROWS;
            foreach (long k in Gd.Range(perFlank))
            {
                double rho = (k + 0.5) / perFlank * reach;
                foreach (double side in Gd.Arr(1.0, -1.0))
                {
                    double along = rho * Gd.Cos(half) + inset * Gd.Sin(half);
                    double off = side * (rho * Gd.Sin(half) - inset * Gd.Cos(half));
                    var at = origin + dir * along + across * off;
                    @out.Append(new Vector3(at.x, at.y, radius));
                }
            }
            return @out;
        }

        void _InitFields()
        {
        }
        public BreathCone() { _InitFields(); }
    }
}
