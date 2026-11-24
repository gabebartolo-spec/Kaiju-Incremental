using Kaiju.Game;
using UnityEngine;
using N = System.Numerics;
using S = Kaiju.Sim;

// The croc's hide (scenes/kaiju_model.gd hide_cast, hide_hits, voxel_world; voxel_skin.gd hits): every skin cube
// filed under its first bone in SkinHits, so a shot meets the cube actually drawn, at its face, however the body
// is bent, and a wound is a rest-space point that rides its bone. Godot axes, like the rest of Croc.
public sealed partial class Croc
{
    static readonly int WOUNDS = Shader.PropertyToID("_Wounds"), WOUND_RADIUS = Shader.PropertyToID("_WoundRadius");
    static readonly int WOUND_TINT = Shader.PropertyToID("_WoundTint");

    SkinHits hide = new SkinHits();
    float woundSeconds;
    N.Matrix4x4[] rowPose = new N.Matrix4x4[0];
    readonly Vector4[] woundsOut = new Vector4[SkinHits.SHADER_CAP];

    // KaijuModel's _colors["eye"]: the species' eye colour, for the eye check. Black (Godot's fallback) until set.
    public N.Vector3 HideEyeColour { get; set; }

    // kaiju_model.gd hide_hits: the wounds (AddWound at a HideCast's rest point, Live to count them).
    public SkinHits Hide => hide;

    // voxel_skin.gd attach: the hide from the .vskin (SkinHits.FromVskin: each cube under its first bone, as
    // cubeFirst, in its base colour), and _cube_material's wound look. Hands raw back for the constructor's own read.
    byte[] HideSkin(byte[] raw)
    {
        var tune = (S.GDict)S.Content.Section("fx")["hide_hit"];
        hide = SkinHits.FromVskin(raw, (int)S.Num.I(tune["max_wounds"]));
        woundSeconds = (float)S.Num.F(tune["wound_seconds"]);
        cubeBlock.SetFloat(WOUND_RADIUS, hide.voxel * (float)S.Num.F(tune["wound_radius_voxels"]));
        N.Vector3 tint = HideEye.Hex(S.Gd.Str(tune["wound_tint"]));
        cubeBlock.SetVector(WOUND_TINT, new Color(tint.X, tint.Y, tint.Z).linear);
        return raw;
    }

    // kaiju_model.gd hide_cast: where a shot along from -> to (world) first meets the hide, or false. eye: the hit
    // is within HideEye.EYE_KEEP_OFF cubes of an eye, which never takes a wound.
    public bool HideCast(Vector3 from, Vector3 to, out SkinHit hit, out bool eye)
    {
        if (rowPose.Length != pose.Length) rowPose = new N.Matrix4x4[pose.Length];
        for (int i = 0; i < pose.Length; i++) rowPose[i] = Rows(pose[i]);
        bool got = hide.Cast(rowPose, Rows(WorldMatrix()), new N.Vector3(from.x, from.y, from.z), new N.Vector3(to.x, to.y, to.z), out hit);
        eye = got && HideEye.Is(hide, hit, HideEyeColour);
        return got;
    }

    // kaiju_model.gd voxel_world: one hide cube's size in the world.
    public float VoxelWorld() => hide.voxel * Mathf.Abs(Scale);

    // kaiju_model.gd animate: the wounds fade by a frame of their wound_seconds life, every frame, dying or not,
    // and voxel_skin.gd _process hands the cubes the ring (wounds[48]).
    public void AgeHide(float dt)
    {
        hide.Age(dt, woundSeconds);
        N.Vector4[] wounds = hide.Wounds;
        for (int i = 0; i < woundsOut.Length; i++) woundsOut[i] = new Vector4(wounds[i].X, wounds[i].Y, wounds[i].Z, wounds[i].W);
        cubeBlock.SetVectorArray(WOUNDS, woundsOut);
    }

    // A UnityEngine (column-vector) matrix as System.Numerics' row-vector one: its transpose.
    static N.Matrix4x4 Rows(Matrix4x4 m)
    {
        return new N.Matrix4x4(m.m00, m.m10, m.m20, m.m30, m.m01, m.m11, m.m21, m.m31, m.m02, m.m12, m.m22, m.m32,
            m.m03, m.m13, m.m23, m.m33);
    }
}
