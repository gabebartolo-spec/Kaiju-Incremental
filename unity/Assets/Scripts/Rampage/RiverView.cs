using UnityEngine;
using S = Kaiju.Sim;

// The splash of the kaiju's rise from the river at the start of a run (scenes/river_view.gd, D-083; the sim's
// Emergence holds the rise and the kaiju's height): a foam ring on the sunk water as the run opens, a big one as the
// body breaks the surface, and a last one as it steps out. The opening and break rings ring where the head comes up,
// the last round the body. Paced by the sim's rise; presentation only. Godot axes.
public sealed class RiverView
{
    // scenes/river_view.gd: the ring's radius per body scale; each splash's size; the ring's lift off the water.
    const float RING = 5f, OPEN = 0.6f, BREAK = 1.4f, OUT = 1f, WATER_LIFT = 0.02f;
    // The splash that rings round the body, not ahead of it at the head (river_view.gd _beat < 3).
    const int ROUND_BODY = 3;

    readonly S.RampageSim sim;
    readonly CityFx fx;
    readonly float ahead;
    readonly Color foam;
    int beat;  // splashes made so far

    public int Splashes => beat;

    // ahead: how far the head's crown stands ahead of the hips (world units). foam: intro_water.gd foam, the water's
    // second tone (intro "water" "colors"), linear.
    public RiverView(S.RampageSim sim, CityFx fx, float ahead, Color foam)
    {
        this.sim = sim;
        this.fx = fx;
        this.ahead = ahead;
        this.foam = foam;
    }

    public void Step()
    {
        S.Emergence emerge = sim.emerge;
        if (beat == 0 && emerge.active) Splash(OPEN);
        else if (beat == 1 && emerge.surfaced) Splash(BREAK);  // the head breaks the surface
        else if (beat == 2 && !emerge.active) Splash(OUT);
    }

    void Splash(float size)
    {
        beat++;
        float water = (float)sim.emerge.WaterY();
        S.Vector2 p = sim.kaijuPos + (beat < ROUND_BODY ? sim.facing * ahead : S.Vector2.ZERO);
        var at = new Vector3((float)p.x, Mathf.Max((float)sim.standY, water) + WATER_LIFT, (float)p.y);
        // A foam ring on the water, never the street's dust puffs (they popped in at the break).
        fx.RingOf(at, RING * (float)sim.BodyScale() * size, 0f, foam);
    }
}
