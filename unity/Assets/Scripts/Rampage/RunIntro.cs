using UnityEngine;
using S = Kaiju.Sim;

// The run's opening, copied from scenes/run_intro.gd: the rise from the bay's pacing, and the shot from
// low on the water that pulls out onto the gameplay camera. Reads the sim's Emergence, decides nothing.
public sealed class RunIntro
{
    const float TICKS_PER_SECOND = 60f;

    readonly S.RampageSim sim;
    readonly S.GDict cfg;
    readonly int skipTicks;
    readonly int firstTicks = 1;
    readonly float rate = 1f;
    float owed;
    bool started, skipped;

    public struct View
    {
        public Vector3 eye, aim;
        public float fov;
    }

    static float F(S.GDict d, string key) => (float)(double)S.Num.F(d[key]);
    static float Smoother(float x) => x * x * x * (x * (x * 6f - 15f) + 10f);

    public RunIntro(S.RampageSim sim, bool full)
    {
        this.sim = sim;
        cfg = S.Content.Section("intro");
        skipTicks = (int)S.Num.I(cfg["skip_ticks"]);
        if (!sim.emerge.active) return;
        float lead = F(cfg, full ? "full_lead_seconds" : "short_lead_seconds");
        float from = Mathf.Max(0f, (float)sim.emerge.BreakAt(sim) - lead);
        firstTicks = Mathf.Max(1, Mathf.RoundToInt(from * TICKS_PER_SECOND));
        if (full) return;
        rate = Mathf.Max(1f, Mathf.Ceil(((float)sim.emerge.Total() - from) / F(cfg, "short_seconds")));
    }

    public void Skip() => skipped = sim.emerge.active;

    // How many sim ticks this 60 Hz frame runs: 1 once the kaiju is out and in the whole intro.
    public int Ticks()
    {
        if (!sim.emerge.active) return 1;
        if (skipped)
        {
            int left = Mathf.RoundToInt((1f - (float)sim.emerge.Progress()) * (float)sim.emerge.Total() * TICKS_PER_SECOND);
            return Mathf.Clamp(Mathf.CeilToInt((float)left / skipTicks), 1, skipTicks);
        }
        if (!started)
        {
            started = true;
            return firstTicks;
        }
        owed += rate;
        int n = Mathf.FloorToInt(owed);
        owed -= n;
        return n;
    }

    // All Godot axes. crown: the head's top, x ahead of the hips, y over the feet. headMid: the drawn head now.
    public View Shot(Vector3 body, View rest, Vector2 crown, Vector3 headMid, float frac)
    {
        S.Emergence emerge = sim.emerge;
        float total = (float)emerge.Total();
        float t = Mathf.Min(total, (float)emerge.Progress() * total + frac / TICKS_PER_SECOND);
        float s = (float)sim.BodyScale();
        float water = (float)emerge.WaterY();
        float pullFrom = F(cfg, "pull_from_seconds") + (float)emerge.Late();
        float x = Mathf.Clamp01((t - pullFrom) / Mathf.Max(0.001f, total - pullFrom));
        float w = Smoother(x);
        var facing = new Vector2((float)(double)sim.facing.x, (float)(double)sim.facing.y);
        Vector2 headAt = new Vector2(body.x, body.z) + facing * crown.x;
        Vector2 pivot = Vector2.Lerp(headAt, new Vector2(body.x, body.z), w);
        float wait = 1f - Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(t / Mathf.Max(0.001f, (float)emerge.BreakAt(sim))));
        float close = F(cfg, "distance") * s * (1f + F(cfg, "push_in") * wait);
        float front = Mathf.Atan2(facing.y, facing.x) + F(cfg, "yaw_deg") * Mathf.Deg2Rad;
        Vector3 back = rest.eye - new Vector3(body.x, 0f, body.z);
        float yaw = front + Mathf.DeltaAngle(front * Mathf.Rad2Deg, Mathf.Atan2(back.z, back.x) * Mathf.Rad2Deg) * Mathf.Deg2Rad * w;
        float radius = Mathf.Lerp(close, new Vector2(back.x, back.z).magnitude, w);
        var eye = new Vector3(pivot.x + Mathf.Cos(yaw) * radius, 0f, pivot.y + Mathf.Sin(yaw) * radius);
        float up = Smoother(Mathf.Min(1f, x * 1.5f));
        eye.y = Mathf.Lerp(LowEye(crown.x, front, facing), rest.eye.y, up);
        var headAim = new Vector3(headMid.x, AimY(water, headMid.y - (float)sim.standY), headMid.z);
        float wa = w * w * w;
        return new View { eye = eye, aim = Vector3.Lerp(headAim, rest.aim, wa), fov = Mathf.Lerp(F(cfg, "fov"), rest.fov, w) };
    }

    // The gameplay camera follows a body still under the water: never let the eye go under it.
    public View AboveWater(View view)
    {
        float lowest = (float)sim.emerge.WaterY() + F(cfg, "clearance") * (float)sim.BodyScale();
        if (view.eye.y < lowest) view.eye.y = lowest;
        return view;
    }

    float LowEye(float ahead, float front, Vector2 facing)
    {
        float s = (float)sim.BodyScale();
        float water = (float)sim.emerge.WaterY();
        Vector2 head = new Vector2((float)(double)sim.emerge.riseAt.x, (float)(double)sim.emerge.riseAt.y) + facing * ahead;
        Vector2 outward = new Vector2(Mathf.Cos(front), Mathf.Sin(front)) * F(cfg, "distance") * s;
        float under = water;
        float[] pushes = { 1f, 1f + F(cfg, "push_in") };
        foreach (float k in pushes)
        {
            Vector2 at = head + outward * k;
            under = Mathf.Max(under, (float)sim.emerge.GroundAt(new S.Vector2(at.x, at.y)));
        }
        return Mathf.Max(water + F(cfg, "height") * s, under + F(cfg, "clearance") * s);
    }

    float AimY(float water, float crown)
    {
        float s = (float)sim.BodyScale();
        float head = (float)sim.standY + crown;
        float low = water + F(cfg, "aim_height") * s;
        float rise = head - low;
        float soft = F(cfg, "aim_soft") * s;
        return low + 0.5f * (rise + Mathf.Sqrt(rise * rise + soft * soft));
    }
}
