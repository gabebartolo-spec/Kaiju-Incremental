using UnityEngine;

// RampageGame's arena edge bollards (ArenaEdgeView, scenes/arena_edge.gd): built the first frame, once CityTrees has
// planted the kerb trees they keep clear of, and drawn each frame after the debris.
public sealed partial class RampageGame
{
    ArenaEdgeView arenaEdge;

    void DrawDebrisAndBollards()
    {
        debris.Draw();
        arenaEdge ??= new ArenaEdgeView(sim, trees.KerbTrunks, Resources.Load<Shader>("Shaders/SliceLit"));
        arenaEdge.Draw();
    }
}
