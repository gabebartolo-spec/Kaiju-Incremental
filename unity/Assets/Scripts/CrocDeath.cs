using System.Collections.Generic;
using UnityEngine;
using S = Kaiju.Sim;

// The croc as he dies (scenes/death_pose.gd, voxel_skin.gd overload / world_points): the gait lets go and the
// stagger take plays once from the pose he stood in (a short cross-fade), then holds its last frame; a body
// without the take holds the pose it died in. The Special K overload lights his hide violet and the stone creeps
// up from his feet (SliceSurface.hlsl, the cubes' and filler's stone); at the shatter the burst takes his cubes
// where they are drawn, and he is hidden. Presentation only.
public sealed partial class Croc
{
    const float DEATH_BLEND_S = 0.2f; // death_pose.gd BLEND_SECONDS
    const float TOP_FLOOR = 0.001f;

    Clip deathClip;
    Quaternion[] deathFrom;
    Vector3 deathFromOffset, lastOffset;
    float deathFrame, deathBlend;
    bool overloadSet;

    // From StartDeath: the gait no longer drives the body.
    public bool Dying { get; private set; }
    // False once he has shattered: Draw draws nothing.
    public bool Visible { get; set; } = true;

    // He dies: the gait stops and `clip` plays once and holds, when this stage has it keyed.
    public void StartDeath(string clip)
    {
        Dying = true;
        Velocity = Vector3.zero;
        if (!clips.TryGetValue(clip, out deathClip)) return;
        deathFrom = (Quaternion[])turnsOut.Clone();
        deathFromOffset = lastOffset;
        deathFrame = 0f;
        deathBlend = 0f;
    }

    // death_pose.gd update: the take's frame at its fps, held at the last, faded in from the pose he died in.
    public void DriveDeath(float dt)
    {
        if (deathClip == null) return;
        deathFrame = Mathf.Min(deathFrame + dt * fps, deathClip.frames - 1);
        deathBlend = Mathf.Min(1f, deathBlend + dt / DEATH_BLEND_S);
        ClipPose(deathClip, deathFrame, turnsA, out Vector3 offset);
        float w = Mathf.SmoothStep(0f, 1f, deathBlend);
        for (int i = 0; i < turnsOut.Length; i++) turnsOut[i] = Quaternion.Slerp(deathFrom[i], turnsA[i], w);
        Finish(Vector3.Lerp(deathFromOffset, offset, w));
    }

    // voxel_skin.gd overload: charge 0..1 the violet crackle, stone 0..1 how far the stone has crept up his body.
    public void Overload(float charge, float stone, S.GDict look, Color violet)
    {
        if (!overloadSet)
        {
            overloadSet = true;
            float top = 0f;
            foreach (Vector3 c in cubeAt) top = Mathf.Max(top, c.y);
            foreach (MaterialPropertyBlock b in new[] { cubeBlock, fillBlock })
            {
                b.SetColor("_OverloadColor", violet.linear);
                StoneLook(b, look);
                b.SetFloat("_BodyTop", Mathf.Max(TOP_FLOOR, top));
            }
            cubeBlock.SetFloat("_CrackleShare", (float)S.Num.F(look["crackle_share"]));
            cubeBlock.SetFloat("_CrackleHz", (float)S.Num.F(look["crackle_hz"]));
            cubeBlock.SetFloat("_CrackleEnergy", (float)S.Num.F(look["crackle"]));
        }
        cubeBlock.SetFloat("_Overload", charge);
        cubeBlock.SetFloat("_Stone", stone);
        fillBlock.SetFloat("_Stone", stone);
    }

    // scenes/death_stone.gd look: the stone's colour, per-block variation and the share of his own shade a stone
    // cube keeps, on his hide and on the pieces that fly off (one stone).
    public static void StoneLook(MaterialPropertyBlock b, S.GDict look)
    {
        ColorUtility.TryParseHtmlString("#" + S.Gd.Str(look["stone"]), out Color stone);
        b.SetColor("_StoneColor", stone.linear);
        b.SetFloat("_StoneVary", (float)S.Num.F(look["stone_vary"]));
        b.SetFloat("_StoneKeep", (float)S.Num.F(look["stone_keep"]));
    }

    // voxel_skin.gd world_points: up to `most` cubes, evenly picked, where they are drawn now (Godot axes), each
    // following its first bone only (close enough for a burst), with its own sRGB colour.
    public void BodyPoints(int most, List<Vector3> at, List<Color> colour)
    {
        at.Clear();
        colour.Clear();
        if (most <= 0) return;
        Matrix4x4 world = WorldMatrix();
        int every = Mathf.Max(1, Mathf.CeilToInt((float)cubeCount / most));
        for (int i = 0; i < cubeCount; i += every)
        {
            at.Add(world.MultiplyPoint3x4(pose[cubeFirst[i]].MultiplyPoint3x4(cubeAt[i])));
            colour.Add(cubeTint[i]);
        }
    }

    // kaiju_model.gd focus + hip_height: the root bone over his feet, lifted by the legs' mean hip height
    // (gait_biped.gd: each leg's first bone's rest head), world units, Godot axes.
    public Vector3 HipFocus()
    {
        Vector3 root = BoneAt(RootBone);
        float hips = 0f;
        int legs = 0;
        foreach (string leg in new[] { "leg_l0", "leg_r0" })
        {
            int b = System.Array.IndexOf(names, leg);
            if (b < 0) continue;
            hips += bind[b].inverse.GetColumn(3).y;
            legs++;
        }
        return new Vector3(root.x, position.y + hips / Mathf.Max(1, legs) * Scale, root.z);
    }
}
