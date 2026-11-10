using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The two post effects of a rampage (scenes/post_fx.gd, D-142): the always-on dark vignette and the split-second
// colour fringe on top-tier impacts, drawn by PostFxPass after AgX. PostFxState holds the numbers; this only
// feeds it what the sim and the footfalls report and writes the result to the pass. Decides nothing.
public sealed class PostFxView
{
    // Off draws nothing (scenes/post_fx.gd `enabled`, the benchmark's baseline; no setting turns it off).
    public bool Enabled = true;
    // Reduce flashing hides the fringe (autoload/player_settings.gd fringe_on); on until the options are ported.
    public bool FringeAllowed = true;

    public int Fringes => state.fringes;
    public double FringePx => state.fringePx;
    public double VignetteAlpha => state.vignetteAlpha;
    public int Draws => PostFxPass.Draws;

    readonly S.RampageSim sim;
    readonly PostFxState state = new PostFxState();
    readonly PostFxPass pass;

    public PostFxView(S.RampageSim sim, VolumeProfile profile)
    {
        this.sim = sim;
        PostFxPass.Draws = 0;
        S.GDict cfg = S.Content.Section("post_fx")["vignette"];
        pass = profile.Add<PostFxPass>(true);
        pass.inner.Override((float)S.Num.F(cfg["inner"]));
        pass.outer.Override((float)S.Num.F(cfg["outer"]));
        ColorUtility.TryParseHtmlString(state.vignetteHex, out Color tint);
        pass.tint.Override(tint);
        // The first picture already has the vignette (scenes/post_fx.gd _init: update(0.0, 1.0, 1.0)).
        Step(0f, 1.0, 1f);
    }

    // The collapses and railgun hits of this tick (scenes/post_fx.gd _physics_process).
    public void OnEvent(S.GDict e)
    {
        switch (S.Gd.Str(e["type"]))
        {
            case "fall_land":
                if (state.Fall(e)) Began("collapse");
                break;
            case "railgun_hit":
                state.Railgun();
                Began("railgun");
                break;
        }
    }

    // A stomp's foot came down (scenes/rampage_footfall.gd land_stomp; EventFx.Footfall returned true).
    public void Stomp()
    {
        if (state.Stomp(sim.StompRadius())) Began("stomp");
    }

    // One frame (scenes/post_fx.gd _process): `motion` is the 0..1 camera-motion setting.
    public void Step(float dt, float motion) => Step(dt, sim.hp / System.Math.Max(sim.maxHp, 0.001), motion);

    void Step(float dt, double hpShare, float motion)
    {
        if (!Enabled)
        {
            pass.strength.Override(0f);
            pass.fringePx.Override(0f);
            return;
        }
        int before = state.fringes;
        state.Update(dt, hpShare, motion);
        if (state.fringes > before) Began("hurt");
        pass.strength.Override((float)state.vignetteAlpha);
        pass.fringePx.Override(FringeAllowed ? (float)state.fringePx : 0f);
    }

    void Began(string cause) => Debug.Log($"fringe {state.fringes} at frame {Time.frameCount}: {cause}");
}
