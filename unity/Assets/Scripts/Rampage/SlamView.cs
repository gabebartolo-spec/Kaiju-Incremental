using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// scenes/slam_view.gd (D-337): what the player sees of the croc's slam into a building at or over his shoulder
// (sim/game/momentum.gd): a camera kick sized by the slam's strength, the building shuddering along the blow
// and easing out (slam_fx), the body stopped in its keyed take (scenes/gait_clip.gd run), and the run's dust
// trail while momentum is up (scenes/powers_view.gd update). Presentation only: the sim decided the slam,
// its dent and the stop.
public sealed class SlamView
{
    // scenes/gait_clip.gd run: the take a slam stops him in.
    const string SLAM_CLIP = "slam_stop";

    sealed class Shudder
    {
        public int building;
        public Vector3 along, from, now;
        public float amp, age;
    }

    readonly S.RampageSim sim;
    readonly CityDraw city;
    readonly CityFx fx;
    readonly CameraShake shake;
    readonly Croc croc;
    readonly Tuning tuning;
    readonly float shudder, half;
    readonly int swings;
    readonly List<Shudder> live = new List<Shudder>();
    float dustIn;

    public int Slams { get; private set; }
    public int Shuddering => live.Count;

    public SlamView(S.RampageSim sim, CityDraw city, CityFx fx, CameraShake shake, Croc croc, Tuning tuning)
    {
        this.sim = sim;
        this.city = city;
        this.fx = fx;
        this.shake = shake;
        this.croc = croc;
        this.tuning = tuning;
        S.GDict cfg = S.Content.Section("slam_fx");
        shudder = (float)(double)S.Num.F(cfg["shudder"]);
        half = 0.5f / Mathf.Max(0.001f, (float)(double)S.Num.F(cfg["shudder_hz"]));
        swings = Mathf.Max(1, Mathf.CeilToInt((float)(double)S.Num.F(cfg["shudder_s"]) / half));
    }

    // focus: the body as drawn (RampageGame.Focus), Godot axes.
    public void OnEvent(S.GDict e, Vector3 focus)
    {
        if (S.Gd.Str(e["type"]) != "slam") return;
        S.Vector3 hit = e["at"];
        var at = new Vector3((float)hit.x, (float)hit.y, (float)hit.z);
        float strength = (float)(double)S.Num.F(e["strength"]);
        int n = (int)S.Num.I(e["building"]);
        Slams++;
        shake.AddScaledAt("slam", strength, at, focus, (float)sim.BodyScale());
        if (!sim.body.dash.On()) croc.Hold(SLAM_CLIP);
        if (n < 0 || n >= sim.buildings.Size()) return;
        S.RampageSim.Building b = sim.buildings[n];
        Vector3 along = new Vector3((float)(double)b.x - at.x, 0f, (float)(double)b.z - at.z).normalized;
        // A new blow on a building still shuddering takes over from where it stands (slam_view.gd kills the old tween).
        Shudder s = live.Find(x => x.building == n);
        if (s == null)
        {
            s = new Shudder { building = n };
            live.Add(s);
        }
        s.from = s.now;
        s.along = along;
        s.amp = shudder * strength;
        s.age = 0f;
        Debug.Log($"slam at frame {Time.frameCount}: building {n} strength {strength:F2} at {at.x:F1},{at.y:F1},{at.z:F1}");
    }

    // slam_view.gd _shudder: swing n is at rest + along * amp * (1 - n / swings), sides alternating, each over
    // half a cycle, then back to rest over one more.
    Vector3 Swing(Shudder s, int n) => n >= swings ? Vector3.zero : s.along * (s.amp * (1f - (float)n / swings) * (n % 2 == 0 ? 1f : -1f));

    // street: the kaiju's feet on the street (no leap height), Godot axes; facing (Godot x, z).
    public void Step(float dt, Vector3 street, Vector2 facing)
    {
        for (int i = live.Count - 1; i >= 0; i--)
        {
            Shudder s = live[i];
            s.age += dt;
            int seg = Mathf.FloorToInt(s.age / half);
            if (seg > swings)
            {
                city.Nudge(s.building, Vector3.zero);
                live.RemoveAt(i);
                continue;
            }
            Vector3 start = seg == 0 ? s.from : Swing(s, seg - 1);
            s.now = Vector3.Lerp(start, Swing(s, seg), s.age / half - seg);
            city.Nudge(s.building, s.now);
        }

        // scenes/powers_view.gd update: a titan's run kicks dust up behind him.
        dustIn -= dt;
        float momentum = (float)sim.powers.momentum;
        if (momentum > tuning.momentum_dust_min && dustIn <= 0f)
        {
            dustIn = tuning.momentum_dust_every_s;
            float bs = (float)sim.BodyScale();
            fx.Dust(street - new Vector3(facing.x, 0f, facing.y) * bs + new Vector3(0f, tuning.momentum_dust_lift, 0f), bs * momentum);
        }
    }
}
