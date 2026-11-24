using System.IO;
using Kaiju.Game;
using N = System.Numerics;
using S = Kaiju.Sim;

// RampageGame's walking trample (scenes/city_decor.gd _process, D-065): every tree, prop and streetlamp whose base
// lies under the drawn body's ground box (KaijuFootprint, the middle city.trample_share of the sculpt's box) goes down
// on the frame the body moves, the box turned and scaled with the body. The drawn body is the croc, so its sculpt is
// SPECIES's. The box is read again when the size tier changes (Godot's when it finds a new model). On the ground only.
public sealed partial class RampageGame
{
    FootRect trampleFoot;
    long trampleTier = -1;

    void TrampleBox()
    {
        long tier = sim.SizeTier();
        if (tier != trampleTier)
        {
            trampleTier = tier;
            trampleFoot = KaijuFootprint.Of(RepoFile, SPECIES, tier, (double)S.Num.F(sim.city["trample_share"]), () => default);
        }
        if (!trampleFoot.HasArea) return;
        N.Matrix4x4 body = N.Matrix4x4.CreateScale(croc.Scale) * N.Matrix4x4.CreateRotationY(croc.yaw)
            * N.Matrix4x4.CreateTranslation(croc.position.x, croc.position.y, croc.position.z);
        trees.CrushBox(body, trampleFoot);
        street.TrampleBox(body, trampleFoot);
    }

    // A repo file's bytes (KaijuFootprint's sculpt), null when it is missing.
    static byte[] RepoFile(string path)
    {
        string file = Path.Combine(S.FileAccess.Root, path);
        return File.Exists(file) ? File.ReadAllBytes(file) : null;
    }
}
