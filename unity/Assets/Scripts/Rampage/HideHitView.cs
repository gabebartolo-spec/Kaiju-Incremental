using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

// scenes/hide_hit.gd HideHit: what a shot looks like landing on the kaiju's hide. One impact for every hitter
// (rooftop rounds, tank shells, helicopter guns, an armoured glance): found on the real cube the shot meets
// (Croc.HideCast), lying on its face along the normal, depth-tested so a body in front hides it. A flash under a
// tenth of a second and under the bloom threshold, a few dull sparks, a small dark-red puff (the smoke family), and
// a faint wound the hide keeps (SkinHits, drawn by the croc's cubes). Numbers in tuning "fx" "hide_hit"; the rest
// are hide_hit.gd's own literals, named below. Godot axes, like the rest of CityFx. Presentation only.
public sealed class HideHitView
{
    // hide_hit.gd LIFT: how far off the surface the flash, sparks and mist start, in voxels.
    const float LIFT = 0.35f;
    // hide_hit.gd land: the voxel Godot falls back on for a body with no voxel_world.
    const float GODOT_VOXEL = 0.12f;
    // hide_hit.gd _find: the straight ray, then rings 1-3 of RING_RAYS rays round the aim point.
    const int RINGS = 4, RING_RAYS = 8;
    // hide_hit.gd _flash: a glance's flash is wider along its slide and flatter; under SIDE_MIN a direction is none.
    const float GLANCE_WIDE = 1.6f, GLANCE_FLAT = 0.6f, SIDE_MIN = 0.01f;
    // hide_hit.gd _sparks: spread (degrees), speeds per GODOT_VOXEL of hide, gravity, life; the ramp darkens by half.
    const float SPARK_SPREAD = 35f, SPARK_VMIN = 2f, SPARK_VMAX = 5f, SPARK_FALL = -9f, SPARK_LIFE = 0.2f, SPARK_DARKEN = 0.5f;
    // hide_hit.gd _mist: spread, speeds per GODOT_VOXEL, damping, gravity, scale range, the grow curve and ramp stops.
    const float MIST_SPREAD = 30f, MIST_VMIN = 0.6f, MIST_VMAX = 1.4f, MIST_DMIN = 1f, MIST_DMAX = 2f, MIST_FALL = -0.4f;
    const float MIST_SMIN = 0.8f, MIST_SMAX = 1.2f, MIST_GROW_FROM = 0.5f, MIST_GROW_TO = 1.5f, MIST_PEAK_AT = 0.15f;
    // ability_fx.gd deflect's caller tank_fx.gd fire_shell: a glance flies off away from the tank and up by half.
    const float GLANCE_LIFT = 0.5f;

    readonly CityFx fx;
    readonly Bursts bursts;
    readonly float flashVoxels, flashSeconds, flashAlpha, glanceSeconds, mistVoxels, mistSeconds, sparkVoxels;
    readonly float rayExtra, aimRings;
    readonly int mistCount, sparkCount, glanceSparks;
    readonly Color flashTint, glanceTint;
    readonly BurstStyle spark, mist;

    // The body shots land on (KaijuModel); null lands every shot on its aim point.
    public Croc Kaiju { get; set; }

    public HideHitView(CityFx fx, Bursts bursts)
    {
        this.fx = fx;
        this.bursts = bursts;
        S.GDict tune = S.Content.Section("fx")["hide_hit"];
        flashVoxels = F(tune, "flash_voxels");
        flashSeconds = F(tune, "flash_seconds");
        flashAlpha = F(tune, "flash_alpha");
        glanceSeconds = F(tune, "glance_seconds");
        mistVoxels = F(tune, "mist_voxels");
        mistSeconds = F(tune, "mist_seconds");
        sparkVoxels = F(tune, "spark_voxels");
        rayExtra = F(tune, "ray_extra");
        aimRings = F(tune, "aim_rings");
        mistCount = (int)S.Num.I(tune["mist_count"]);
        sparkCount = (int)S.Num.I(tune["spark_count"]);
        glanceSparks = (int)S.Num.I(tune["glance_sparks"]);
        // The flash shader's tint is a source_color: Godot reads the hex as sRGB.
        flashTint = Hex(tune, "flash_tint").linear;
        glanceTint = Hex(tune, "glance_tint").linear;
        // _sparks: unshaded vertex colour, the ramp's raw hex (as CityFx's sparks), fading to half dark and clear.
        Color tint = Hex(tune, "spark_tint");
        Color dark = Color.Lerp(tint, Color.black, SPARK_DARKEN);
        spark = new BurstStyle { glow = true, spread = SPARK_SPREAD, gravity = new Vector3(0f, SPARK_FALL, 0f), smin = 1f, smax = 1f }
            .Size(0f, 1f).Colors(new[] { 0f, 1f }, tint, new Color(dark.r, dark.g, dark.b, 0f));
        // _mist_ramp: the tint in linear, in fast to mist_alpha, then out; the smoke's own, self-lit, no clearing
        // over the kaiju (centre_keep 1, focus_clear 0).
        Color blood = Hex(tune, "mist_tint").linear;
        Color clear = new Color(blood.r, blood.g, blood.b, 0f);
        mist = new BurstStyle
        {
            spread = MIST_SPREAD, gravity = new Vector3(0f, MIST_FALL, 0f), dmin = MIST_DMIN, dmax = MIST_DMAX,
            smin = MIST_SMIN, smax = MIST_SMAX, selfLit = 1f, clear = 0f,
        }.Size(0f, MIST_GROW_FROM, 1f, MIST_GROW_TO)
            .Colors(new[] { 0f, MIST_PEAK_AT, 1f }, clear, new Color(blood.r, blood.g, blood.b, F(tune, "mist_alpha")), clear);
    }

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);

    static Color Hex(S.GDict d, string key)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(d[key]), out Color c);
        return c;
    }

    static Vector3 V(System.Numerics.Vector3 v) => new Vector3(v.X, v.Y, v.Z);

    // hide_hit.gd land: lands a shot on the kaiju along from -> aim: the real hit if the segment meets the hide
    // (carried a little past aim), else the aim point facing the shooter. A glance (armour) leaves no blood and no
    // wound and throws its sparks along `away`. True when it met the hide; `point` is where it was drawn.
    public bool Land(Vector3 from, Vector3 aim, out Vector3 point, bool glance = false, Vector3 away = default)
    {
        Vector3 dir = (aim - from).normalized;
        point = aim;
        Vector3 normal = -dir;
        float unit = Kaiju != null ? Kaiju.VoxelWorld() : GODOT_VOXEL;
        bool got = Kaiju != null && Find(from, aim, out SkinHit hit, out bool eye);
        if (got)
        {
            point = V(hit.point);
            normal = V(hit.normal);
            if (!glance && !eye) Kaiju.Hide.AddWound(hit.rest, 1f);
        }
        Play(point, normal, unit, glance, away);
        return got;
    }

    public bool Land(Vector3 from, Vector3 aim) => Land(from, aim, out _);

    // tank_fx.gd fire_shell on arrival: against armour (the armor stat) ability_fx.gd deflect's glance, off away
    // from the tank and up; else a plain landing.
    public void Shell(Vector3 muzzle, Vector3 target, Vector3 tank, bool armoured)
    {
        if (armoured) Land(muzzle, target, out _, true, (tank - target).normalized + Vector3.up * GLANCE_LIFT);
        else Land(muzzle, target);
    }

    // hide_hit.gd _find: the hide cube a shot at aim meets: the straight ray first, then rings of rays round the aim
    // point (a shell aimed between his legs still lands on the nearest thigh, never in the air), nearest first.
    bool Find(Vector3 from, Vector3 aim, out SkinHit best, out bool bestEye)
    {
        best = default;
        bestEye = false;
        float bs = Mathf.Abs(Kaiju.Scale);
        Vector3 dir = (aim - from).normalized;
        Vector3 side = Vector3.Cross(dir, Vector3.up).normalized;
        Vector3 up = Vector3.Cross(side, dir);
        float reach = Vector3.Distance(from, aim) + rayExtra * bs;
        for (int ring = 0; ring < RINGS; ring++)
        {
            float radius = aimRings * bs * ring;
            float bestGap = float.PositiveInfinity;
            bool found = false;
            for (int k = 0; k < (ring == 0 ? 1 : RING_RAYS); k++)
            {
                float a = 2f * Mathf.PI * k / RING_RAYS;
                Vector3 to = aim + (side * Mathf.Cos(a) + up * Mathf.Sin(a)) * radius;
                Vector3 line = (to - from).normalized;
                if (!Kaiju.HideCast(from, from + line * reach, out SkinHit hit, out bool eye)) continue;
                float gap = Vector3.Distance(V(hit.point), aim);
                if (gap >= bestGap) continue;
                bestGap = gap;
                best = hit;
                bestEye = eye;
                found = true;
            }
            if (found) return true;
        }
        return false;
    }

    // hide_hit.gd play: the impact at `at` on a surface facing `normal`; `unit` one voxel of the hide (world).
    void Play(Vector3 at, Vector3 normal, float unit, bool glance, Vector3 away)
    {
        Vector3 n = normal.normalized;
        Vector3 lifted = at + n * (LIFT * unit);
        Flash(lifted, n, unit, glance, away);
        Sparks(lifted, n, unit, glance, away);
        if (!glance) Mist(lifted, n, unit);
    }

    // hide_hit.gd _flash: a ragged disc lying on the surface, its +Z the normal, its X along a glance's slide.
    void Flash(Vector3 at, Vector3 n, float unit, bool glance, Vector3 away)
    {
        float width = flashVoxels * unit;
        Vector3 slide = away - n * Vector3.Dot(away, n);
        Vector3 side = glance && slide.magnitude > SIDE_MIN ? slide.normalized : Vector3.Cross(n, Vector3.up);
        if (side.magnitude < SIDE_MIN) side = Vector3.Cross(n, Vector3.right);
        side = side.normalized;
        Vector3 across = side * (width * (glance ? GLANCE_WIDE : 1f));
        Vector3 along = Vector3.Cross(n, side) * (width * (glance ? GLANCE_FLAT : 1f));
        bursts.Flash(at, across, along, glance ? glanceSeconds : flashSeconds, glance ? glanceTint : flashTint, flashAlpha, fx.Now);
    }

    // hide_hit.gd _sparks: a few dull sparks, below the bloom threshold, thrown along the normal (a glance: away).
    void Sparks(Vector3 at, Vector3 n, float unit, bool glance, Vector3 away)
    {
        spark.aim = glance && away.magnitude > SIDE_MIN ? away.normalized : n;
        spark.vmin = SPARK_VMIN * unit / GODOT_VOXEL;
        spark.vmax = SPARK_VMAX * unit / GODOT_VOXEL;
        spark.unit = sparkVoxels * unit;
        fx.Spray(spark, at, Vector3.zero, glance ? glanceSparks : sparkCount, SPARK_LIFE, 0f);
    }

    // hide_hit.gd _mist: the blood, a few small dark-red smoke puffs drifting out along the normal.
    void Mist(Vector3 at, Vector3 n, float unit)
    {
        mist.aim = n;
        mist.vmin = MIST_VMIN * unit / GODOT_VOXEL;
        mist.vmax = MIST_VMAX * unit / GODOT_VOXEL;
        mist.unit = mistVoxels * unit;
        fx.Spray(mist, at, Vector3.zero, mistCount, mistSeconds, 0f);
    }
}
