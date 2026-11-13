using UnityEngine;
using S = Kaiju.Sim;

// RampageGame's wildlife (scenes/city_view.gd _build_outskirts: WildlifeView.attach; rampage.gd _on_event:
// WildlifeView.feed): gulls, pigeons and the whale, fed every sim event with the kaiju where the sim has him.
public sealed partial class RampageGame
{
    WildlifeView wildlife;

    void BuildWildlife(Shader lit)
    {
        wildlife = new WildlifeView(sim, lit, fx);
        Debug.Log("wildlife: " + wildlife.Built());
    }

    // One sim event for the living things outdoors: the birds and the whale (WildlifeView.feed), and the trees a stomp
    // crushes.
    void Nature(S.GDict e)
    {
        wildlife.OnEvent(e, Feet());
        if (S.Gd.Str(e["type"]) == "stomp") trees.Crush(Feet(), (float)(double)S.Num.F(e["radius"]));
    }

    void DisposeWildlife()
    {
        if (wildlife == null) return;
        Debug.Log("wildlife: " + wildlife.Ended());
        wildlife.Dispose();
    }
}
