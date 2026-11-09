using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

// The approved croc: the voxel-skin cubes and filler from croc.vskin, posed from croc.kclip on the rig in
// rig.json. Everything is computed in Godot axes; the shaders negate z last.
public sealed class Croc
{
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct Cube
    {
        public float cx, cy, cz, w0, r, g, b, w1;
        public uint bones;
        public float corX, corY, corZ, corFlag;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct FillVertex
    {
        public float x, y, z;
        public byte r, g, b, a;
        public byte w0, w1, w2, w3;
        public byte b0, b1, b2, b3;
    }

    struct Helper
    {
        public int a, b, flags;
        public float frac;
        public Vector3 centre, push, turnX, turnY, turnZ;
    }

    sealed class Clip
    {
        public int first, frames, cycles;
        public bool loop;
        public float trailFirst, trailLast;
    }

    public Vector3 position; // Godot axes
    public float yaw;
    public float Scale { get; private set; }
    public float Stride { get; private set; }
    // How much of a walk's speed it is doing (scenes/gait_clip.gd speed_k).
    public float SpeedShare => moveWeight;
    // Metres of claw above the street at body scale 1: down below the first, lifted past the second.
    const float FOOT_DOWN_M = 0.25f, FOOT_UP_M = 0.6f;
    static readonly string[] FOOT_BONES = { "toe_l1", "toe_r1" };
    static readonly string[] FOOT_SIDES = { "left", "right" };
    readonly int[] footBone = { -1, -1 };
    readonly bool[] footDown = { true, true };
    bool footPrimed, footfallPending;
    string footfallSide;
    Vector3 footfallAt;
    public Vector3 Velocity { get; private set; }
    public bool Sweeping => sweep != null;
    public int CubeCount => cubeCount;

    readonly Tuning tuning;
    readonly byte[] clipRaw;
    readonly int dataAt, frameBytes;
    readonly float fps;
    readonly float rigScale;
    readonly Dictionary<string, Clip> clips = new Dictionary<string, Clip>();
    readonly string[] names;
    readonly int[] parents, order, clipToRig;
    readonly Matrix4x4[] rest, bind, local, global, pose;
    readonly Helper[] helpers;
    readonly GraphicsBuffer cubeBuffer, boneBuffer;
    readonly Material cubeMat, fillMat;
    readonly Mesh cube, fill;
    readonly int cubeCount;
    readonly MaterialPropertyBlock cubeBlock = new MaterialPropertyBlock(), fillBlock = new MaterialPropertyBlock();
    readonly List<int> tailClipBones = new List<int>();

    readonly List<(int bone, float r)> bodySpheres = new List<(int, float)>();
    readonly List<(int bone, float r)> tailSpheres = new List<(int, float)>();
    readonly Vector3[] prevBody, prevTail;
    readonly Rigidbody[] pushers;

    Quaternion[] turnsA, turnsB, turnsC, turnsOut, scratch0, scratch1;
    float walkFrame, runFrame, idleFrame, moveWeight, runWeight;
    Clip sweep;
    float sweepTime, sweepAge;
    int sweepSide;
    bool seeded;

    // scenes/clip_takes.gd: the roar's upper-body bones, how long it fades; which clip holds the jaw open.
    static readonly string[] ROAR_PREFIXES = { "spine", "neck", "head", "clavicle", "arm", "tail", "jaw" };
    const float ROAR_FADE_S = 0.4f;
    const string ROAR_CLIP = "roar", JAW_CLIP = "beam_jaw", JAW_BONE = "jaw";
    // HDRP's first user stencil bit: what lands on the street (the scorch) leaves the hide alone.
    public const int BODY_STENCIL = 64;
    readonly bool[] roarBone;
    readonly int jawClip = -1, jawIndex = -1, upperIndex = -1;
    bool jawKnown;
    Quaternion jawHeld;
    float roarTime = -1f, roarAge, jawOpen, jawTarget, jawEase = 0.25f;
    // Each cube's rest position and heaviest bone, for the ridge and the jaws' tips.
    readonly Vector3[] cubeAt;
    readonly byte[] cubeBone;
    int[] ridgeBones = new int[0];
    Vector3[] ridgeRest = new Vector3[0];
    Vector3 jawTip, upperTip;

    public Croc(Tuning t, Dictionary<string, object> slice, Shader litShader, Mesh cubeMesh, float inset)
    {
        tuning = t;
        Scale = MiniJson.F(slice["body_scale"]);

        var rig = SliceData.LoadJson("rig.json");
        rigScale = MiniJson.F(rig["rig_scale"]);
        List<object> bones = MiniJson.Arr(rig["bones"]);
        int count = bones.Count;
        names = new string[count];
        parents = new int[count];
        rest = new Matrix4x4[count];
        bind = new Matrix4x4[count];
        local = new Matrix4x4[count];
        global = new Matrix4x4[count];
        var byName = new Dictionary<string, int>();
        for (int i = 0; i < count; i++)
        {
            var bone = MiniJson.Obj(bones[i]);
            names[i] = (string)bone["name"];
            byName[names[i]] = i;
            rest[i] = Matrix(MiniJson.Arr(bone["rest"]));
            bind[i] = Matrix(MiniJson.Arr(bone["bind"]));
        }
        for (int i = 0; i < count; i++)
        {
            var bone = MiniJson.Obj(bones[i]);
            string parent = (string)bone["parent"];
            parents[i] = string.IsNullOrEmpty(parent) ? -1 : byName[parent];
        }
        order = TopologicalOrder(parents);

        clipRaw = File.ReadAllBytes(Path.Combine(SliceData.Dir, "croc.kclip"));
        int headerLength = BitConverter.ToInt32(clipRaw, 8);
        var header = MiniJson.Obj(MiniJson.Parse(System.Text.Encoding.UTF8.GetString(clipRaw, 12, headerLength)));
        fps = MiniJson.F(header["fps"]);
        frameBytes = MiniJson.I(header["frame_bytes"]);
        int total = 0;
        foreach (object o in MiniJson.Arr(header["clips"]))
        {
            var c = MiniJson.Obj(o);
            var clip = new Clip
            {
                first = MiniJson.I(c["first"]),
                frames = MiniJson.I(c["frames"]),
                loop = c.TryGetValue("loop", out object l) && l is bool lb && lb,
                cycles = c.TryGetValue("cycles", out object cy) && cy is double ? MiniJson.I(cy) : 1,
            };
            if (c.TryGetValue("trail", out object tr) && tr is List<object> trail)
            {
                clip.trailFirst = MiniJson.F(trail[0]);
                clip.trailLast = MiniJson.F(trail[1]);
            }
            clips[(string)c["name"]] = clip;
            total = Mathf.Max(total, clip.first + clip.frames);
        }
        dataAt = clipRaw.Length - total * frameBytes;
        List<object> clipBones = MiniJson.Arr(header["bones"]);
        clipToRig = new int[clipBones.Count];
        for (int i = 0; i < clipBones.Count; i++)
        {
            string name = (string)clipBones[i];
            clipToRig[i] = byName[name];
            if (name.StartsWith("tail")) tailClipBones.Add(i);
        }
        Stride = MiniJson.F(header["stride_m"]) * rigScale * Scale;
        for (int i = 0; i < FOOT_BONES.Length; i++) footBone[i] = byName.TryGetValue(FOOT_BONES[i], out int foot) ? foot : -1;
        turnsA = new Quaternion[clipBones.Count];
        turnsB = new Quaternion[clipBones.Count];
        turnsC = new Quaternion[clipBones.Count];
        turnsOut = new Quaternion[clipBones.Count];
        roarBone = new bool[clipBones.Count];
        for (int i = 0; i < clipBones.Count; i++)
        {
            string name = (string)clipBones[i];
            if (name == JAW_BONE) jawClip = i;
            foreach (string prefix in ROAR_PREFIXES) roarBone[i] |= name.StartsWith(prefix);
        }
        jawIndex = byName.TryGetValue(JAW_BONE, out int jawAt) ? jawAt : -1;
        upperIndex = jawIndex >= 0 ? parents[jawIndex] : -1;

        byte[] skin = File.ReadAllBytes(Path.Combine(SliceData.Dir, "croc.vskin"));
        ushort boneCount = BitConverter.ToUInt16(skin, 16);
        float voxel = BitConverter.ToSingle(skin, 18);
        cubeCount = BitConverter.ToInt32(skin, 22);
        const int HEADER = 26, CELL_BYTES = 15;
        int at = HEADER + cubeCount * CELL_BYTES;
        int fillVerts = BitConverter.ToInt32(skin, at);
        int fillVertsAt = at + 4;
        at = fillVertsAt + fillVerts * 20;
        int fillIndices = BitConverter.ToInt32(skin, at);
        int fillIndexAt = at + 4;
        at = fillIndexAt + fillIndices * 4;

        helpers = ReadHelpers(skin, ref at);
        pose = new Matrix4x4[boneCount];
        int corsAt = -1;
        if (at + 8 <= skin.Length && skin[at] == 'C' && skin[at + 1] == 'O' && skin[at + 2] == 'R' && skin[at + 3] == 'S')
            corsAt = at + 8;

        float noise = MiniJson.F(MiniJson.Obj(slice["look"])["color_noise"]);
        var look = MiniJson.Obj(slice["look"]);
        var data = new NativeArray<Cube>(cubeCount, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        cubeAt = new Vector3[cubeCount];
        cubeBone = new byte[cubeCount];
        for (int i = 0; i < cubeCount; i++)
        {
            int k = HEADER + i * CELL_BYTES;
            short sx = BitConverter.ToInt16(skin, k), sy = BitConverter.ToInt16(skin, k + 2), sz = BitConverter.ToInt16(skin, k + 4);
            float factor = 1f + JitterT(sx, sy, sz, 7) * noise;
            float dark = skin[k + 9] != 0 ? tuning.seam_dark : 1f;
            var c = new Cube
            {
                cx = sx * voxel,
                cy = (sy + 0.5f) * voxel,
                cz = sz * voxel,
                w0 = skin[k + 13] / 255f,
                r = Mathf.Clamp01(skin[k + 6] / 255f * factor) * dark,
                g = Mathf.Clamp01(skin[k + 7] / 255f * factor) * dark,
                b = Mathf.Clamp01(skin[k + 8] / 255f * factor) * dark,
                w1 = skin[k + 14] / 255f,
                bones = (uint)(skin[k + 10] | skin[k + 11] << 8 | skin[k + 12] << 16),
            };
            if (corsAt >= 0)
            {
                int q = corsAt + i * 16;
                c.corX = BitConverter.ToSingle(skin, q);
                c.corY = BitConverter.ToSingle(skin, q + 4);
                c.corZ = BitConverter.ToSingle(skin, q + 8);
                c.corFlag = BitConverter.ToSingle(skin, q + 12);
            }
            data[i] = c;
            cubeAt[i] = new Vector3(c.cx, c.cy, c.cz);
            float w2 = 1f - c.w0 - c.w1;
            cubeBone[i] = skin[k + 10 + (c.w0 >= c.w1 && c.w0 >= w2 ? 0 : c.w1 >= w2 ? 1 : 2)];
        }
        cubeBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, cubeCount, 52);
        cubeBuffer.SetData(data);
        data.Dispose();
        boneBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, boneCount, 64);
        cube = cubeMesh;
        cubeMat = new Material(litShader) { enableInstancing = true };
        cubeMat.EnableKeyword("SLICE_CUBE");
        cubeMat.SetFloat("_CubeSize", voxel * inset);
        fillMat = new Material(litShader);
        fillMat.EnableKeyword("SLICE_FILL");
        fill = BuildFill(skin, fillVertsAt, fillVerts, fillIndexAt, fillIndices);
        foreach (Material m in new[] { cubeMat, fillMat })
            foreach (string pass in new[] { "", "GBuffer", "Depth" })
            {
                m.SetInt("_StencilRef" + pass, m.GetInt("_StencilRef" + pass) | BODY_STENCIL);
                m.SetInt("_StencilWriteMask" + pass, m.GetInt("_StencilWriteMask" + pass) | BODY_STENCIL);
            }

        Shader.SetGlobalFloat("_HideCell", voxel * SliceData.F(look, "kaiju_hide_cell_voxels", 3));
        Shader.SetGlobalFloat("_HideSeed", SliceData.F(look, "kaiju_hide_seed", 0));
        Shader.SetGlobalFloat("_HideCrevice", SliceData.F(look, "kaiju_hide_crevice", 0));
        Shader.SetGlobalFloat("_HideCreviceWidth", SliceData.F(look, "kaiju_hide_crevice_width", 0.1f));
        Shader.SetGlobalFloat("_HideFleck", SliceData.F(look, "kaiju_hide_fleck", 0));
        Shader.SetGlobalFloat("_HideFleckDark", SliceData.F(look, "kaiju_hide_fleck_dark", 0));
        Shader.SetGlobalFloat("_HideTone", SliceData.F(look, "kaiju_hide_tone", 0));
        Shader.SetGlobalFloat("_KaijuRoughness", SliceData.F(look, "kaiju_roughness", 0.85f));

        foreach (SphereDef s in t.body) bodySpheres.Add((byName[s.bone], s.r));
        foreach (SphereDef s in t.tail) tailSpheres.Add((byName[s.bone], s.r));
        prevBody = new Vector3[bodySpheres.Count];
        prevTail = new Vector3[tailSpheres.Count];
        pushers = new Rigidbody[bodySpheres.Count];
        for (int i = 0; i < pushers.Length; i++)
        {
            var go = new GameObject("pusher");
            var sphere = go.AddComponent<SphereCollider>();
            sphere.radius = bodySpheres[i].r * tuning.pusher_scale;
            Rigidbody rb = go.AddComponent<Rigidbody>();
            rb.isKinematic = true;
            pushers[i] = rb;
        }
    }

    static Matrix4x4 Matrix(List<object> f)
    {
        var m = Matrix4x4.identity;
        m.SetColumn(0, new Vector4(MiniJson.F(f[0]), MiniJson.F(f[1]), MiniJson.F(f[2]), 0));
        m.SetColumn(1, new Vector4(MiniJson.F(f[3]), MiniJson.F(f[4]), MiniJson.F(f[5]), 0));
        m.SetColumn(2, new Vector4(MiniJson.F(f[6]), MiniJson.F(f[7]), MiniJson.F(f[8]), 0));
        m.SetColumn(3, new Vector4(MiniJson.F(f[9]), MiniJson.F(f[10]), MiniJson.F(f[11]), 1));
        return m;
    }

    static int[] TopologicalOrder(int[] parents)
    {
        var done = new bool[parents.Length];
        var list = new List<int>(parents.Length);
        void Visit(int i)
        {
            if (done[i]) return;
            if (parents[i] >= 0) Visit(parents[i]);
            done[i] = true;
            list.Add(i);
        }
        for (int i = 0; i < parents.Length; i++) Visit(i);
        return list.ToArray();
    }

    static float JitterT(int x, int y, int z, uint salt)
    {
        uint h = salt * 0x9E3779B1u;
        h = (h ^ (uint)x) * 0xcc9e2d51u;
        h = ((h << 13) | (h >> 19)) * 5 + 0xe6546b64u;
        h = (h ^ (uint)y) * 0xcc9e2d51u;
        h = ((h << 13) | (h >> 19)) * 5 + 0xe6546b64u;
        h = (h ^ (uint)z) * 0xcc9e2d51u;
        h ^= h >> 16;
        h *= 0x85ebca6bu;
        h ^= h >> 13;
        return (h % 1000) / 1000f * 2f - 1f;
    }

    static Helper[] ReadHelpers(byte[] raw, ref int at)
    {
        if (at + 6 > raw.Length || raw[at] != 'H' || raw[at + 1] != 'E' || raw[at + 2] != 'L' || raw[at + 3] != 'P')
            return new Helper[0];
        int n = BitConverter.ToUInt16(raw, at + 4);
        at += 6;
        var list = new Helper[n];
        for (int i = 0; i < n; i++)
        {
            list[i] = new Helper
            {
                a = raw[at],
                b = raw[at + 1],
                flags = raw[at + 2],
                frac = BitConverter.ToSingle(raw, at + 4),
                centre = V3(raw, at + 8),
                push = V3(raw, at + 20),
                turnX = V3(raw, at + 32),
                turnY = V3(raw, at + 44),
                turnZ = V3(raw, at + 56),
            };
            at += 68;
        }
        return list;
    }

    static Vector3 V3(byte[] raw, int at)
    {
        return new Vector3(BitConverter.ToSingle(raw, at), BitConverter.ToSingle(raw, at + 4), BitConverter.ToSingle(raw, at + 8));
    }

    static Mesh BuildFill(byte[] raw, int vertsAt, int verts, int indexAt, int indices)
    {
        var v = new NativeArray<FillVertex>(verts, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        for (int i = 0; i < verts; i++)
        {
            int k = vertsAt + i * 20;
            v[i] = new FillVertex
            {
                x = BitConverter.ToSingle(raw, k),
                y = BitConverter.ToSingle(raw, k + 4),
                z = BitConverter.ToSingle(raw, k + 8),
                r = raw[k + 12],
                g = raw[k + 13],
                b = raw[k + 14],
                a = raw[k + 17],
                w0 = raw[k + 18],
                w1 = raw[k + 19],
                b0 = raw[k + 15],
                b1 = raw[k + 16],
                b2 = raw[k + 17],
            };
        }
        var mesh = new Mesh { name = "croc fill", indexFormat = IndexFormat.UInt32 };
        mesh.SetVertexBufferParams(verts,
            new VertexAttributeDescriptor(VertexAttribute.Position, VertexAttributeFormat.Float32, 3),
            new VertexAttributeDescriptor(VertexAttribute.Color, VertexAttributeFormat.UNorm8, 4),
            new VertexAttributeDescriptor(VertexAttribute.TexCoord0, VertexAttributeFormat.UNorm8, 4),
            new VertexAttributeDescriptor(VertexAttribute.TexCoord1, VertexAttributeFormat.UNorm8, 4));
        mesh.SetVertexBufferData(v, 0, 0, verts, 0, MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
        v.Dispose();
        var x = new NativeArray<uint>(indices, Allocator.Persistent, NativeArrayOptions.UninitializedMemory);
        for (int i = 0; i < indices; i++) x[i] = BitConverter.ToUInt32(raw, indexAt + i * 4);
        mesh.SetIndexBufferParams(indices, IndexFormat.UInt32);
        mesh.SetIndexBufferData(x, 0, 0, indices, MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
        x.Dispose();
        mesh.SetSubMesh(0, new SubMeshDescriptor(0, indices), MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one * 200);
        return mesh;
    }

    void FrameTurns(int frame, Quaternion[] into, out Vector3 offset)
    {
        int at = dataAt + frame * frameBytes;
        for (int i = 0; i < into.Length; i++)
        {
            var q = new Quaternion(
                BitConverter.ToInt16(clipRaw, at) / 32767f,
                BitConverter.ToInt16(clipRaw, at + 2) / 32767f,
                BitConverter.ToInt16(clipRaw, at + 4) / 32767f,
                BitConverter.ToInt16(clipRaw, at + 6) / 32767f);
            into[i] = Quaternion.Normalize(q);
            at += 8;
        }
        offset = new Vector3(BitConverter.ToInt16(clipRaw, at), BitConverter.ToInt16(clipRaw, at + 2), BitConverter.ToInt16(clipRaw, at + 4)) * 0.01f;
    }

    void ClipPose(Clip c, float t, Quaternion[] into, out Vector3 offset)
    {
        float at = c.loop ? Mathf.Repeat(t, c.frames) : Mathf.Clamp(t, 0, c.frames - 1);
        int i0 = Mathf.FloorToInt(at);
        int i1 = c.loop ? (i0 + 1) % c.frames : Mathf.Min(i0 + 1, c.frames - 1);
        float a = at - i0;
        scratch0 ??= new Quaternion[into.Length];
        scratch1 ??= new Quaternion[into.Length];
        FrameTurns(c.first + i0, scratch0, out Vector3 o0);
        FrameTurns(c.first + i1, scratch1, out Vector3 o1);
        for (int i = 0; i < into.Length; i++) into[i] = Quaternion.Slerp(scratch0[i], scratch1[i], a);
        offset = Vector3.Lerp(o0, o1, a);
    }

    public void StartSweep()
    {
        if (sweep != null) return;
        sweepSide = 1 - sweepSide;
        sweep = clips[sweepSide == 0 ? "sweep_r" : "sweep_l"];
        sweepTime = 0;
        sweepAge = 0;
    }

    // move: world direction (Godot x, z), length 0 or 1; run: Shift held.
    public void Step(Vector2 move, bool run, float dt)
    {
        Clip walk = clips["walk"], runClip = clips["run"], idle = clips["idle"];
        float walkCycle = (float)walk.frames / walk.cycles;
        float runCycle = (float)runClip.frames / runClip.cycles;
        float walkSpeed = Stride / (walkCycle / fps);
        float runSpeed = Stride / (runCycle / fps);
        bool moving = move.sqrMagnitude > 0.01f;
        float fade = 1f - Mathf.Exp(-dt / Mathf.Max(0.001f, tuning.clip_fade_s));
        moveWeight = Mathf.Lerp(moveWeight, moving ? 1 : 0, fade);
        runWeight = Mathf.Lerp(runWeight, run ? 1 : 0, fade);
        float speed = Mathf.Lerp(walkSpeed, runSpeed, runWeight) * moveWeight;
        if (moving)
        {
            float want = Mathf.Atan2(-move.x, -move.y);
            yaw += Mathf.Clamp(Mathf.DeltaAngle(yaw * Mathf.Rad2Deg, want * Mathf.Rad2Deg) * Mathf.Deg2Rad, -tuning.turn_rate * dt, tuning.turn_rate * dt);
        }
        var heading = new Vector3(moving ? move.x : -Mathf.Sin(yaw), 0, moving ? move.y : -Mathf.Cos(yaw));
        Vector3 step = heading.normalized * (speed * dt);
        position += step;
        Velocity = new Vector3(step.x, 0, -step.z) / Mathf.Max(dt, 1e-4f);
        Pose(step.magnitude, dt);
    }

    // The sim moved it: the same clips, the feet locked to the distance it actually covered, the body
    // turning toward the sim's facing at the rig's own rate. feet in Godot axes, facing (Godot x, z).
    public void Drive(Vector3 feet, Vector2 facing, float scale, float dt)
    {
        Stride *= scale / Scale;
        Scale = scale;
        Clip walk = clips["walk"], runClip = clips["run"];
        float walkSpeed = Stride / ((float)walk.frames / walk.cycles / fps);
        float runSpeed = Stride / ((float)runClip.frames / runClip.cycles / fps);
        Vector3 step = feet - position;
        step.y = 0;
        position = feet;
        float speed = step.magnitude / Mathf.Max(dt, 1e-4f);
        float fade = 1f - Mathf.Exp(-dt / Mathf.Max(0.001f, tuning.clip_fade_s));
        moveWeight = Mathf.Lerp(moveWeight, Mathf.Clamp01(speed / walkSpeed), fade);
        runWeight = Mathf.Lerp(runWeight, Mathf.Clamp01((speed - walkSpeed) / Mathf.Max(0.001f, runSpeed - walkSpeed)), fade);
        if (facing.sqrMagnitude > 1e-6f)
        {
            float want = Mathf.Atan2(-facing.x, -facing.y);
            yaw += Mathf.Clamp(Mathf.DeltaAngle(yaw * Mathf.Rad2Deg, want * Mathf.Rad2Deg) * Mathf.Deg2Rad, -tuning.turn_rate * dt, tuning.turn_rate * dt);
        }
        Velocity = new Vector3(step.x, 0, -step.z) / Mathf.Max(dt, 1e-4f);
        Pose(step.magnitude, dt);
    }

    public float ClipSeconds(string name) => clips.TryGetValue(name, out Clip c) ? (float)(c.frames - 1) / fps : 0f;

    // Godot axes: where a bone is drawn now.
    public Vector3 BoneAt(string name)
    {
        return WorldMatrix().MultiplyPoint3x4(global[System.Array.IndexOf(names, name)].GetColumn(3));
    }

    public string RootBone => names[0];

    Vector4[] restSpheres;

    // Godot axes, capture only: the body as one sphere per bone (xyz centre, w radius), from the cubes each bone
    // carries, so a framing check can tell when the croc stands between a camera and its own mouth.
    public void BodySpheres(List<Vector4> into)
    {
        if (restSpheres == null)
        {
            restSpheres = new Vector4[pose.Length];
            for (int b = 0; b < pose.Length; b++)
            {
                Vector3 sum = Vector3.zero;
                int count = 0;
                for (int i = 0; i < cubeAt.Length; i++)
                    if (cubeBone[i] == b) { sum += cubeAt[i]; count++; }
                if (count == 0) continue;
                Vector3 mid = sum / count;
                var far = new List<float>(count);
                for (int i = 0; i < cubeAt.Length; i++)
                    if (cubeBone[i] == b) far.Add((cubeAt[i] - mid).magnitude);
                far.Sort();
                restSpheres[b] = new Vector4(mid.x, mid.y, mid.z, far[(count * 3) / 4]);
            }
        }
        into.Clear();
        Matrix4x4 world = WorldMatrix();
        float scale = world.lossyScale.y;
        for (int b = 0; b < restSpheres.Length; b++)
        {
            if (restSpheres[b].w <= 0f) continue;
            Vector3 at = world.MultiplyPoint3x4(pose[b].MultiplyPoint3x4(restSpheres[b]));
            into.Add(new Vector4(at.x, at.y, at.z, restSpheres[b].w * scale));
        }
    }

    // The ridge from tail tip to head (scenes/spine_charge.gd _find_ridge): on each bone, the highest cell
    // of its middle stretch at rest, lifted clear of the hide. This rig's bones carry no direction, so the
    // stretch runs from the bone's head to its farthest cell.
    public void FindRidge(IList<string> bones, float low, float high, float liftVoxels)
    {
        var at = new List<int>();
        var tops = new List<Vector3>();
        float voxel = cubeMat.GetFloat("_CubeSize");
        foreach (string bone in bones)
        {
            int b = System.Array.IndexOf(names, bone);
            if (b < 0) continue;
            Vector3 head = RestHead(b), axis = FarCell(b) - head;
            bool found = false;
            Vector3 best = Vector3.zero;
            for (int i = 0; i < cubeAt.Length; i++)
            {
                if (cubeBone[i] != b) continue;
                float along = Vector3.Dot(cubeAt[i] - head, axis) / Mathf.Max(axis.sqrMagnitude, 1e-4f);
                if (along < low || along > high || (found && cubeAt[i].y <= best.y)) continue;
                best = cubeAt[i];
                found = true;
            }
            if (!found) continue;
            at.Add(b);
            tops.Add(best + Vector3.up * (liftVoxels * voxel));
        }
        ridgeBones = at.ToArray();
        ridgeRest = tops.ToArray();
        if (jawIndex >= 0) jawTip = FarCell(jawIndex);
        if (upperIndex >= 0) upperTip = FarCell(upperIndex);
    }

    public int RidgeSize => ridgeBones.Length;

    // Godot axes: ridge point `i` (tail tip 0 .. head) now.
    public Vector3 RidgeAt(int i) => WorldMatrix().MultiplyPoint3x4(pose[ridgeBones[i]].MultiplyPoint3x4(ridgeRest[i]));

    Vector3 RestHead(int bone) => bind[bone].inverse.GetColumn(3);

    Vector3 FarCell(int bone)
    {
        Vector3 head = RestHead(bone), far = head;
        float most = -1f;
        for (int i = 0; i < cubeAt.Length; i++)
        {
            if (cubeBone[i] != bone) continue;
            float d = (cubeAt[i] - head).sqrMagnitude;
            if (d > most) { most = d; far = cubeAt[i]; }
        }
        return far;
    }

    // Godot axes: where the bolt leaves (scenes/breath_beam.gd throat_of): out from the hinge a share of
    // the way to the jaws' tips, and a share of the way from the lower to the upper.
    public Vector3 ThroatAt(float along, float up)
    {
        Matrix4x4 world = WorldMatrix();
        Vector3 hinge = world.MultiplyPoint3x4(global[jawIndex].GetColumn(3));
        Vector3 low = Vector3.Lerp(hinge, world.MultiplyPoint3x4(pose[jawIndex].MultiplyPoint3x4(jawTip)), along);
        Vector3 high = Vector3.Lerp(hinge, world.MultiplyPoint3x4(pose[upperIndex].MultiplyPoint3x4(upperTip)), along);
        return Vector3.Lerp(low, high, up);
    }

    // The bolt leaves an open maw (scenes/spine_charge.gd _open_jaw): the jaw as keyed at its widest in
    // the beam's own take, laid over whatever plays, over `seconds`.
    public void JawOpen(bool open, float seconds)
    {
        if (jawClip < 0) return;
        if (!jawKnown)
        {
            jawKnown = true;
            jawHeld = WidestJaw();
        }
        jawTarget = open ? 1f : 0f;
        jawEase = Mathf.Max(seconds, 0.01f);
    }

    Quaternion WidestJaw()
    {
        Clip c = clips[JAW_CLIP];
        var turns = new Quaternion[turnsOut.Length];
        FrameTurns(c.first, turns, out Vector3 _);
        Quaternion shut = turns[jawClip], best = shut;
        float most = -1f;
        for (int f = 0; f < c.frames; f++)
        {
            FrameTurns(c.first + f, turns, out Vector3 _);
            float a = Quaternion.Angle(shut, turns[jawClip]);
            if (a > most) { most = a; best = turns[jawClip]; }
        }
        return best;
    }

    // scenes/clip_takes.gd roar_over: the clip whole while standing, its upper body and jaw alone over a walk.
    public void Roar()
    {
        roarTime = 0f;
        roarAge = 0f;
    }

    void LayRoar(float dt, ref Vector3 offset)
    {
        if (roarTime < 0f) return;
        Clip c = clips[ROAR_CLIP];
        roarTime += dt * fps;
        roarAge += dt;
        float end = c.frames - 1;
        if (roarTime >= end)
        {
            roarTime = -1f;
            return;
        }
        ClipPose(c, roarTime, turnsA, out Vector3 roarOffset);
        float w = Mathf.SmoothStep(0f, 1f, Mathf.Min(1f, (end - roarTime) / (ROAR_FADE_S * fps))) * Mathf.SmoothStep(0f, 1f, Mathf.Min(1f, roarAge / ROAR_FADE_S));
        float whole = w * (1f - moveWeight);
        for (int i = 0; i < turnsOut.Length; i++)
            turnsOut[i] = Quaternion.Slerp(turnsOut[i], turnsA[i], roarBone[i] ? w : whole);
        offset = Vector3.Lerp(offset, roarOffset, whole);
    }

    void LayJaw(float dt)
    {
        jawOpen = Mathf.MoveTowards(jawOpen, jawTarget, dt / jawEase);
        if (jawClip >= 0 && jawOpen > 0f) turnsOut[jawClip] = Quaternion.Slerp(turnsOut[jawClip], jawHeld, Mathf.SmoothStep(0f, 1f, jawOpen));
    }

    // The head's crown in the rest pose (scenes/rampage_rise.gd head_at): x ahead of the hips, y over the
    // feet, world units. The model faces -z.
    public Vector2 RestCrown(string name, float scale)
    {
        var at = new Matrix4x4[rest.Length];
        foreach (int i in order)
            at[i] = parents[i] >= 0 ? at[parents[i]] * rest[i] : rest[i];
        Vector4 head = at[System.Array.IndexOf(names, name)].GetColumn(3), hips = at[0].GetColumn(3);
        return new Vector2(hips.z - head.z, head.y) * scale;
    }

    // One clip by the sim's clock (scenes/rampage_rise.gd rise): the keyed rise from the bay.
    public void DriveClip(Vector3 feet, Vector2 facing, float scale, string name, float seconds)
    {
        Stride *= scale / Scale;
        Scale = scale;
        position = feet;
        moveWeight = 0f;
        runWeight = 0f;
        Velocity = Vector3.zero;
        if (facing.sqrMagnitude > 1e-6f) yaw = Mathf.Atan2(-facing.x, -facing.y);
        ClipPose(clips[name], seconds * fps, turnsOut, out Vector3 offset);
        Finish(offset);
        footPrimed = false;
    }

    void Pose(float dist, float dt)
    {
        Clip walk = clips["walk"], runClip = clips["run"], idle = clips["idle"];
        float walkCycle = (float)walk.frames / walk.cycles;
        float runCycle = (float)runClip.frames / runClip.cycles;
        walkFrame += dist / Stride * walkCycle;
        runFrame += dist / Stride * runCycle;
        idleFrame += dt * fps;

        ClipPose(idle, idleFrame, turnsA, out Vector3 offA);
        ClipPose(walk, walkFrame, turnsB, out Vector3 offB);
        ClipPose(runClip, runFrame, turnsC, out Vector3 offC);
        for (int i = 0; i < turnsOut.Length; i++)
            turnsOut[i] = Quaternion.Slerp(turnsA[i], Quaternion.Slerp(turnsB[i], turnsC[i], runWeight), moveWeight);
        Vector3 offset = Vector3.Lerp(offA, Vector3.Lerp(offB, offC, runWeight), moveWeight);

        if (sweep != null)
        {
            sweepTime += dt * fps;
            sweepAge += dt;
            if (sweepTime >= sweep.frames - 1)
            {
                sweep = null;
            }
            else
            {
                ClipPose(sweep, sweepTime, turnsA, out Vector3 _);
                float tail = (sweep.frames - 1 - sweepTime) / (tuning.sweep_fade_s * fps);
                float w = Mathf.SmoothStep(0, 1, sweepAge / tuning.sweep_fade_s) * Mathf.SmoothStep(0, 1, tail);
                foreach (int i in tailClipBones) turnsOut[i] = Quaternion.Slerp(turnsOut[i], turnsA[i], w);
            }
        }

        LayRoar(dt, ref offset);
        LayJaw(dt);
        Finish(offset);
        WatchFeet();
    }

    void Finish(Vector3 offset)
    {
        for (int i = 0; i < rest.Length; i++) local[i] = rest[i];
        for (int i = 0; i < turnsOut.Length; i++)
        {
            int b = clipToRig[i];
            Matrix4x4 m = rest[b] * Matrix4x4.Rotate(turnsOut[i]);
            Vector4 o = rest[b].GetColumn(3);
            if (i == 0) o += (Vector4)(offset * rigScale);
            o.w = 1;
            m.SetColumn(3, o);
            local[b] = m;
        }
        foreach (int i in order)
            global[i] = parents[i] >= 0 ? global[parents[i]] * local[i] : local[i];
        for (int i = 0; i < global.Length; i++) pose[i] = global[i] * bind[i];
        for (int k = 0; k < helpers.Length; k++) pose[global.Length + k] = HelperPose(helpers[k]);
        boneBuffer.SetData(pose);
    }

    // A foot is down when its middle claw is at the street, up again when it has lifted clear; each
    // landing goes out once (scenes/clip_feet.gd put_down; the kclip here carries no planted flags).
    void WatchFeet()
    {
        Matrix4x4 world = WorldMatrix();
        for (int i = 0; i < FOOT_BONES.Length; i++)
        {
            if (footBone[i] < 0) continue;
            Vector3 toe = world.MultiplyPoint3x4(global[footBone[i]].GetColumn(3));
            float height = (toe.y - position.y) / Mathf.Max(Scale, 0.01f);
            if (footDown[i] && height > FOOT_UP_M) footDown[i] = false;
            else if (!footDown[i] && height < FOOT_DOWN_M)
            {
                footDown[i] = true;
                if (footPrimed)
                {
                    footfallPending = true;
                    footfallSide = FOOT_SIDES[i];
                    footfallAt = new Vector3(toe.x, position.y, -toe.z);
                }
            }
        }
        footPrimed = true;
    }

    // The newest footfall since the last call: side, and where (Godot axes).
    public bool TakeFootfall(out string side, out Vector3 at)
    {
        side = footfallSide;
        at = footfallAt;
        bool had = footfallPending;
        footfallPending = false;
        return had;
    }

    Matrix4x4 HelperPose(in Helper h)
    {
        Matrix4x4 pa = pose[h.a], pb = pose[h.b];
        Matrix4x4 ra = Orthonormal(pa), rb = Orthonormal(pb);
        Quaternion q = Normalize(ToQuat(ra.transpose * rb));
        if (q.w < 0) q = new Quaternion(-q.x, -q.y, -q.z, -q.w);
        var v = new Vector3(q.x, q.y, q.z);
        float s = v.magnitude;
        float angle = 2f * Mathf.Atan2(s, q.w);
        Vector3 turn = Vector3.zero;
        Matrix4x4 r = ra;
        if (s > Mathf.Sin(5e-7f))
        {
            Vector3 axis = v / s;
            turn = axis * angle;
            r = ra * Matrix4x4.Rotate(Quaternion.AngleAxis(h.frac * angle * Mathf.Rad2Deg, axis));
        }
        Vector3 c = h.centre;
        Vector3 t = (pa.MultiplyPoint3x4(c) + pb.MultiplyPoint3x4(c)) * 0.5f;
        float g = (1f - Mathf.Cos(angle)) * 0.5f;
        Vector3 perTurn = h.turnX * turn.x + h.turnY * turn.y + h.turnZ * turn.z;
        Vector3 push = perTurn + h.push * g;
        if ((h.flags & 1) != 0) push = (perTurn + h.push) * g;
        Vector3 at = t - r.MultiplyVector(c) + r.MultiplyVector(push);
        r.SetColumn(3, new Vector4(at.x, at.y, at.z, 1));
        return r;
    }

    static Matrix4x4 Orthonormal(in Matrix4x4 m)
    {
        Vector3 x = ((Vector3)m.GetColumn(0)).normalized;
        Vector3 y = (Vector3)m.GetColumn(1);
        y = (y - x * Vector3.Dot(x, y)).normalized;
        Vector3 z = Vector3.Cross(x, y);
        var o = Matrix4x4.identity;
        o.SetColumn(0, x);
        o.SetColumn(1, y);
        o.SetColumn(2, z);
        return o;
    }

    static Quaternion Normalize(Quaternion q)
    {
        float l = Mathf.Sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
        return l > 0 ? new Quaternion(q.x / l, q.y / l, q.z / l, q.w / l) : Quaternion.identity;
    }

    static Quaternion ToQuat(in Matrix4x4 m)
    {
        float tr = m.m00 + m.m11 + m.m22;
        if (tr > 0)
        {
            float s = Mathf.Sqrt(tr + 1f) * 2f;
            return new Quaternion((m.m21 - m.m12) / s, (m.m02 - m.m20) / s, (m.m10 - m.m01) / s, 0.25f * s);
        }
        if (m.m00 > m.m11 && m.m00 > m.m22)
        {
            float s = Mathf.Sqrt(1f + m.m00 - m.m11 - m.m22) * 2f;
            return new Quaternion(0.25f * s, (m.m01 + m.m10) / s, (m.m02 + m.m20) / s, (m.m21 - m.m12) / s);
        }
        if (m.m11 > m.m22)
        {
            float s = Mathf.Sqrt(1f + m.m11 - m.m00 - m.m22) * 2f;
            return new Quaternion((m.m01 + m.m10) / s, 0.25f * s, (m.m12 + m.m21) / s, (m.m02 - m.m20) / s);
        }
        float t = Mathf.Sqrt(1f + m.m22 - m.m00 - m.m11) * 2f;
        return new Quaternion((m.m02 + m.m20) / t, (m.m12 + m.m21) / t, 0.25f * t, (m.m10 - m.m01) / t);
    }

    // Godot's model matrix: T * R(yaw) * S(scale).
    Matrix4x4 WorldMatrix()
    {
        float c = Mathf.Cos(yaw) * Scale, s = Mathf.Sin(yaw) * Scale;
        var m = Matrix4x4.identity;
        m.m00 = c;
        m.m02 = s;
        m.m11 = Scale;
        m.m20 = -s;
        m.m22 = c;
        m.m03 = position.x;
        m.m13 = position.y;
        m.m23 = position.z;
        return m;
    }

    // A bone's head in Unity world axes.
    Vector3 BoneWorld(int bone)
    {
        Vector3 p = WorldMatrix().MultiplyPoint3x4(global[bone].GetColumn(3));
        return new Vector3(p.x, p.y, -p.z);
    }

    public void CollectSpheres(List<City.Sphere> into)
    {
        AddSpheres(into, bodySpheres, prevBody);
        for (int i = 0; i < pushers.Length; i++) pushers[i].MovePosition(prevBody[i]);
        bool tailOn = sweep != null && sweepTime >= sweep.trailFirst - tuning.sweep_margin_frames && sweepTime <= sweep.trailLast + tuning.sweep_margin_frames;
        if (tailOn)
        {
            AddSpheres(into, tailSpheres, prevTail);
        }
        else
        {
            for (int i = 0; i < prevTail.Length; i++) prevTail[i] = BoneWorld(tailSpheres[i].bone);
        }
        seeded = true;
    }

    // A fast bone (the tail in its 360) leaves no gaps between ticks: spheres along its path.
    void AddSpheres(List<City.Sphere> into, List<(int bone, float r)> list, Vector3[] prev)
    {
        for (int i = 0; i < list.Count; i++)
        {
            Vector3 now = BoneWorld(list[i].bone);
            Vector3 from = seeded ? prev[i] : now;
            float r = list[i].r;
            int steps = Mathf.Clamp(Mathf.CeilToInt((now - from).magnitude / (r * 0.5f)), 1, 8);
            for (int k = 1; k <= steps; k++)
                into.Add(new City.Sphere { world = Vector3.Lerp(from, now, (float)k / steps), radius = r, velocity = Velocity * 0.3f });
            prev[i] = now;
        }
    }

    public void Draw()
    {
        Matrix4x4 world = WorldMatrix();
        cubeBlock.SetBuffer("_Cubes", cubeBuffer);
        cubeBlock.SetBuffer("_Bones", boneBuffer);
        cubeBlock.SetMatrix("_CrocWorld", world);
        fillBlock.SetBuffer("_Bones", boneBuffer);
        fillBlock.SetMatrix("_CrocWorld", world);
        var box = new Bounds(new Vector3(position.x, position.y + 10, -position.z), Vector3.one * 120);
        // The cubes are in absolute world space, and this call offsets the object by the bounds' centre: keep it at the origin.
        Graphics.DrawMeshInstancedProcedural(cube, 0, cubeMat, new Bounds(Vector3.zero, Vector3.one * 8000), cubeCount, cubeBlock, ShadowCastingMode.On, true);
        var rf = new RenderParams(fillMat)
        {
            matProps = fillBlock,
            worldBounds = box,
            shadowCastingMode = ShadowCastingMode.On,
            receiveShadows = true,
        };
        Graphics.RenderMesh(rf, fill, 0, Matrix4x4.identity);
    }

    public void Dispose()
    {
        cubeBuffer.Dispose();
        boneBuffer.Dispose();
        UnityEngine.Object.Destroy(cubeMat);
        UnityEngine.Object.Destroy(fillMat);
        UnityEngine.Object.Destroy(fill);
        foreach (Rigidbody rb in pushers)
            if (rb != null)
                UnityEngine.Object.Destroy(rb.gameObject);
    }
}
