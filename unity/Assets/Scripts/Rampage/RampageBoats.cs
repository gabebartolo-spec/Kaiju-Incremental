using UnityEngine;

// RampageGame's boats (scenes/city_view.gd _build_outskirts: BoatView.attach after the skyline): moored at the
// piers, in the bay and on the river, posed each frame with the kaiju where the sim has him.
public sealed partial class RampageGame
{
    BoatView boats;

    void BuildBoats(Shader lit, Transform root)
    {
        boats = new BoatView(sim, lit, root);
        Debug.Log("boats: " + boats.Moored());
    }

    void DisposeBoats()
    {
        if (boats == null) return;
        Debug.Log("boats: " + boats.Moved());
        boats.Dispose();
    }
}
