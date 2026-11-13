using System;
using System.Collections.Generic;
using S = Kaiju.Sim;

// The far beast's rig (scenes/kaiju_rig.gd, rig_chains.gd, chain_step.gd) without nodes: its bones from
// far_beast.rig.json (tools/unity/slicebake BeastBake: rest poses, binds, heads, head->tail), posed by the gait as
// Godot's nodes are, and its spring chains (antennae). The node tree is model (Frame) -> rig (RigYaw, RigAt) -> bones;
// a bone's global transform is read through its parents on demand, as Node3D.global_transform is. Godot axes, rig
// units (the model ~10 tall). Presentation only.
public sealed class FarBeastRig
{
    public sealed class Bone
    {
        public string name, parent;
        public bool physics;
        public double[] head, dir, rest, bind;
    }

    // A run of physics bones (an antenna) simulated as Verlet points (KaijuRig.SpringChain).
    public sealed class SpringChain
    {
        public readonly List<int> bones = new List<int>();
        public double stiffness, gravityScale = 1.0;
        public BV[] pos, prev;

        // Throws every joint (more towards the tip): a twitch flicks the feeler.
        public void Kick(BV velocity, double dt)
        {
            if (pos == null) return;
            for (int i = 1; i < pos.Length; i++) prev[i] -= velocity * dt * i / (pos.Length - 1);
        }
    }

    public readonly string[] names;
    readonly int[] parents;
    readonly BT[] rest, local, binds;
    readonly BV[] heads, dirs;
    readonly Dictionary<string, int> byName = new Dictionary<string, int>();
    public readonly List<SpringChain> chains = new List<SpringChain>();
    readonly S.GDict chainCfg;
    double owed;
    const double STEP_EPS = 1e-6;  // rig_chains.gd: a frame of exactly h is one step

    // The model's transform (KaijuModel: position and yaw) and the rig's own place under it, set by the gait.
    public BT Frame = BT.IDENTITY;
    public double RigYaw;
    public BV RigAt;

    // A foot came down (KaijuRig.foot_planted): which ("fl", "fr", "bl", "br"), how hard, where (little world).
    public event Action<string, double, BV> FootPlanted;

    public FarBeastRig(IReadOnlyList<Bone> defs)
    {
        int n = defs.Count;
        names = new string[n];
        parents = new int[n];
        rest = new BT[n];
        local = new BT[n];
        binds = new BT[n];
        heads = new BV[n];
        dirs = new BV[n];
        for (int i = 0; i < n; i++) byName[defs[i].name] = i;
        for (int i = 0; i < n; i++)
        {
            Bone d = defs[i];
            names[i] = d.name;
            parents[i] = d.parent != null && byName.TryGetValue(d.parent, out int p) ? p : -1;
            rest[i] = BT.FromRow(d.rest);
            local[i] = rest[i];
            binds[i] = BT.FromRow(d.bind);
            heads[i] = new BV(d.head[0], d.head[1], d.head[2]);
            dirs[i] = new BV(d.dir[0], d.dir[1], d.dir[2]);
        }
        chainCfg = S.Content.Section("chain");
        Collect(defs);
    }

    public int Count => names.Length;
    public bool HasBone(string name) => byName.ContainsKey(name);
    public int Index(string name) => byName[name];
    public BV DirOf(string name) => dirs[byName[name]];
    public BV HeadOf(string name) => heads[byName[name]];
    public BT RigLocal => new BT(BB.Axis(BV.UP, RigYaw), RigAt);
    public BT RigGlobal => Frame * RigLocal;

    // A bone's transform under the rig (rig space), and in the little world.
    public BT RigSpace(int i) => parents[i] < 0 ? local[i] : RigSpace(parents[i]) * local[i];
    public BT Global(int i) => RigGlobal * RigSpace(i);
    public BT Global(string name) => Global(byName[name]);
    BT ParentGlobal(int i) => parents[i] < 0 ? RigGlobal : Global(parents[i]);

    // The skin's bone matrices (VoxelSkin.sync): each bone in rig space times its bind.
    public BT SkinPose(int i) => RigSpace(i) * binds[i];

    public void Planted(string id, double strength, BV at) => FootPlanted?.Invoke(id, strength, at);

    // Poses a bone by a rotation on top of its rest pose, and an offset in its parent's space.
    public void Pose(string name, BV euler, BV offset = default)
    {
        if (!byName.TryGetValue(name, out int i)) return;
        local[i] = new BT(rest[i].basis * BB.Euler(euler), rest[i].origin + offset);
    }

    // Turns a bone (from its rest pose under its current parent) so its head->tail points from -> to.
    public void Aim(string name, BV from, BV to) => Aim(byName[name], from, to);

    void Aim(int i, BV from, BV to)
    {
        const double SHORT = 0.0001;
        BT parent = ParentGlobal(i);
        BT restWorld = parent * rest[i];
        BV want = to - from;
        BV have = restWorld.basis * dirs[i];
        if (want.Length() < SHORT || have.Length() < SHORT) return;
        BB world = BB.Arc(have, want) * restWorld.basis;
        local[i] = new BT(parent.basis.Inverse() * world, rest[i].origin);
    }

    // Sets a bone's world orientation (an orthonormal basis; the rig is unscaled here, so no scale to keep).
    public void SetWorldBasis(string name, BB world)
    {
        int i = byName[name];
        local[i] = new BT(ParentGlobal(i).basis.Inverse() * world, local[i].origin);
    }

    // World position of a bone's tail as posed now.
    public BV TailWorld(string name) => Global(name) * DirOf(name);

    // RigChains.collect: each run of physics bones from its first, one child at a time.
    void Collect(IReadOnlyList<Bone> defs)
    {
        var children = new Dictionary<int, List<int>>();
        for (int i = 0; i < defs.Count; i++)
        {
            if (!children.TryGetValue(parents[i], out List<int> list)) children[parents[i]] = list = new List<int>();
            list.Add(i);
        }
        for (int i = 0; i < defs.Count; i++)
        {
            if (!defs[i].physics || (parents[i] >= 0 && defs[parents[i]].physics)) continue;
            var chain = new SpringChain { stiffness = S.Num.F(chainCfg["stiffness"]) };
            chain.bones.Add(i);
            int walk = i;
            while (children.TryGetValue(walk, out List<int> kids) && kids.Count == 1 && defs[kids[0]].physics)
            {
                walk = kids[0];
                chain.bones.Add(walk);
            }
            chains.Add(chain);
        }
    }

    // Spring chains, in fixed steps (tuning chain step_hz): joints follow where the rest pose would put them,
    // with inertia and gravity, then each bone is turned to point at the next joint.
    public void SimulateChains(double delta)
    {
        double h = 1.0 / S.Num.F(chainCfg["step_hz"]);
        owed += delta;
        int steps = Math.Min((int)(owed / h + STEP_EPS), (int)S.Num.F(chainCfg["max_substeps"]));
        owed = BMath.Clamp(owed - steps * h, 0.0, h);  // a long frame's excess time is dropped, not caught up
        foreach (SpringChain chain in chains)
        {
            BV[] target = RestPoints(chain);
            if (chain.pos == null)
            {
                chain.pos = (BV[])target.Clone();
                chain.prev = (BV[])target.Clone();
            }
            chain.pos[0] = target[0];
            for (int s = 0; s < steps; s++) Step(chain, target, h);
            for (int k = 0; k < chain.bones.Count; k++) Aim(chain.bones[k], chain.pos[k], chain.pos[k + 1]);
        }
    }

    // World positions of a chain's joints if every bone of it sat at its rest pose.
    BV[] RestPoints(SpringChain chain)
    {
        var points = new BV[chain.bones.Count + 1];
        BT xform = ParentGlobal(chain.bones[0]) * rest[chain.bones[0]];
        points[0] = xform.origin;
        for (int k = 0; k < chain.bones.Count; k++)
        {
            points[k + 1] = xform * dirs[chain.bones[k]];
            if (k + 1 < chain.bones.Count) xform = xform * rest[chain.bones[k + 1]];
        }
        return points;
    }

    // ChainStep.run: one Verlet step towards the target, then every bone held to its length.
    void Step(SpringChain chain, BV[] target, double h)
    {
        const double SHORT = 0.0001;
        double damping = S.Num.F(chainCfg["damping"]);
        BV g = new BV(0, S.Num.F(chainCfg["gravity_y"]), 0) * chain.gravityScale;
        BV[] pos = chain.pos, prev = chain.prev;
        for (int i = 1; i < pos.Length; i++)
        {
            BV p = pos[i];
            BV vel = (p - prev[i]) * damping;
            prev[i] = p;
            pos[i] = p + vel + ((target[i] - p) * chain.stiffness + g) * h * h;
        }
        for (int pass = 0; pass < (int)S.Num.F(chainCfg["passes"]); pass++)
        {
            for (int i = 1; i < pos.Length; i++)
            {
                double length = (target[i] - target[i - 1]).Length();
                BV d = pos[i] - pos[i - 1];
                if (d.Length() > SHORT) pos[i] = pos[i - 1] + d.Normalized() * length;
            }
        }
    }
}
