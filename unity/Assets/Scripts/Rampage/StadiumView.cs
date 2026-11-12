using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using S = Kaiju.Sim;

// The stadium's match on screen (scenes/stadium_match.gd _draw, stadium_crowd.gd _build, crowd_build.gd holder):
// the pitch's markings and posts, the tunnel mouths, two kits of players, the glowing ball and the crowd, one
// instanced batch per outfit. StadiumMatch and StadiumCrowd decide where everyone is; each fan's place this frame
// is CrowdPose (the Godot game's crowd shader, worked out here per fan: D-474). Presentation only (hard rule 3).
public sealed class StadiumView
{
    // Graphics.DrawMeshInstanced's most per call.
    const int BATCH = 1023;
    // stadium_match.gd MOUTH_COLOR.
    const int MOUTH_COLOR = 0x0b0b0d;
    const int WHITE = 0xffffff, HEX = 16;
    // stadium_match.gd _ball_mesh: the blob's centre height and radii, in ball cells.
    const float BALL_Y = 1.5f, BALL_LONG = 1.6f, BALL_SHORT = 1.3f;
    const float HALF_TURN = 180f;

    public readonly StadiumMatch match;
    readonly Material people, marks, ballGlow, dark;
    readonly Mesh props, mouth, ball;
    readonly Mesh[] kits, seated, standing;
    readonly List<Matrix4x4[]>[] fanBatches;
    readonly int[] fanCounts;
    readonly Matrix4x4[][] playerBatches;
    readonly int[] playerCounts;
    readonly Matrix4x4[] mouths;
    readonly Matrix4x4 pitch;

    public int FansDrawn { get; private set; }

    public StadiumView(S.RampageSim sim, int index, CityFx fx, Shader shader, S.RandomNumberGenerator rng, int crowdMax)
    {
        match = new StadiumMatch(sim, index, at => fx.Puff(new Vector3((float)at.x, (float)at.y, (float)at.z)), rng, crowdMax);
        S.GDict cfg = S.Content.Sports()["pitch"];
        float voxel = (float)S.Num.F(S.Content.Section("street")["person_voxel"]);
        double noise = S.Num.F(S.Content.Look().Get("color_noise", 0.0));
        people = Instanced(shader, voxel);
        float cell = (float)S.Num.F(cfg["voxel"]);
        marks = ArmyView.PlainMaterial(shader, cell);
        props = ArmyView.Faces(PropTiles.Model(Marks()), cell, Vector3.zero);
        pitch = Matrix4x4.Translate(new Vector3((float)match.centre.x, (float)match.top, -(float)match.centre.y));
        dark = Instanced(shader, 1f);
        mouth = ArmyView.Faces(PropTiles.Model(new Dictionary<Vector3Int, int> { [Vector3Int.zero] = MOUTH_COLOR }), 1f, new Vector3(0f, 0.5f, 0f));
        mouths = Mouths();
        float ballCell = voxel * (float)S.Num.F(cfg["ball_scale"]);
        ballGlow = ArmyView.PlainMaterial(shader, ballCell);
        ballGlow.SetFloat("_WindowGlow", (float)S.Num.F(cfg["ball_glow"]));
        ball = Ball(ballCell);
        kits = Kits(voxel, noise);
        playerBatches = new Matrix4x4[kits.Length][];
        for (int k = 0; k < kits.Length; k++) playerBatches[k] = new Matrix4x4[match.players.Count];
        playerCounts = new int[kits.Length];
        int outfits = match.crowd != null ? match.crowd.outfits.Count : 0;
        seated = new Mesh[outfits];
        standing = new Mesh[outfits];
        fanBatches = new List<Matrix4x4[]>[outfits];
        fanCounts = new int[outfits];
        for (int o = 0; o < outfits; o++)
        {
            CrowdBuild.Outfit wear = match.crowd.outfits[o];
            int[] outfit = PersonCells.Outfit(wear.shirt, wear.pants, wear.hair, wear.skin);
            seated[o] = PersonCells.Mesh(PersonCells.Seated(outfit), PersonCells.SEATED_SALT, voxel, noise);
            standing[o] = PersonCells.Mesh(PersonCells.Body(outfit, StreetPeople.RUN_A, false), PersonCells.DRESSED_SALT + StreetPeople.RUN_A, voxel, noise);
            fanBatches[o] = new List<Matrix4x4[]>();
        }
    }

    static Material Instanced(Shader shader, float voxel)
    {
        Material m = ArmyView.PlainMaterial(shader, voxel);
        m.enableInstancing = true;
        return m;
    }

    static int Hex(S.Variant color) => Convert.ToInt32(S.Gd.Str(color), HEX);

    // scenes/pitch_props.gd mesh: the sport's lines, posts and strip in its colours.
    Dictionary<Vector3Int, int> Marks()
    {
        S.GDict sport = match.sport;
        int[] colors = { Hex(sport["line"]), Hex(sport["post_color"]), Hex(sport.Get("strip", sport["line"])) };
        var cells = new Dictionary<Vector3Int, int>();
        foreach (KeyValuePair<S.Vector3i, int> c in PitchProps.Cells(sport, match.half))
            cells[new Vector3Int((int)c.Key.x, (int)c.Key.y, (int)c.Key.z)] = colors[c.Value];
        return cells;
    }

    // stadium_match.gd _add_mouths: a dark box at each tunnel mouth, its back to the stands.
    Matrix4x4[] Mouths()
    {
        S.Vector3 size = match.MouthSize();
        var boxes = new Matrix4x4[match.mouths.Count];
        for (int k = 0; k < boxes.Length; k++)
        {
            S.Vector2 away = match.MouthOut(k);
            S.Vector2 edge = match.mouths[k] - away * size.z * 0.5;
            var at = new Vector3((float)edge.x, (float)(match.top + size.y * 0.5), -(float)edge.y);
            Quaternion turn = Quaternion.LookRotation(new Vector3((float)away.x, 0f, -(float)away.y));
            boxes[k] = Matrix4x4.TRS(at, turn, new Vector3((float)size.x, (float)size.y, (float)size.z));
        }
        return boxes;
    }

    // stadium_match.gd _ball_mesh: a blob in the sport's ball colour with a pale highlight on top, all of it lit.
    Mesh Ball(float cell)
    {
        var cells = new Dictionary<Vector3Int, int>();
        int color = Hex(match.sport["ball"]);
        int reach = Mathf.CeilToInt(BALL_LONG), top = Mathf.CeilToInt(BALL_Y + BALL_SHORT);
        for (int x = -reach; x <= reach; x++)
            for (int y = 0; y <= top; y++)
                for (int z = -reach; z <= reach; z++)
                {
                    var p = new Vector3(x / BALL_LONG, (y - BALL_Y) / BALL_SHORT, z / BALL_SHORT);
                    if (p.sqrMagnitude <= 1f) cells[new Vector3Int(x, y, z)] = color;
                }
        cells[new Vector3Int(0, 2, 0)] = WHITE;
        cells[new Vector3Int(-1, 2, 0)] = WHITE;
        var glow = new bool[cells.Count];
        for (int i = 0; i < glow.Length; i++) glow[i] = true;
        return ArmyView.Faces(PropTiles.Model(cells), cell, Vector3.zero, glow);
    }

    // stadium_match.gd _add_kits: one mesh per team, skin and pose, in StadiumMatch.Bucket's order.
    Mesh[] Kits(float voxel, double noise)
    {
        S.GArray<S.Variant> teams = match.sport["kits"];
        var meshes = new List<Mesh>();
        foreach (S.Variant t in teams)
        {
            S.GDict kit = t;
            foreach (string skin in StadiumMatch.SKINS)
            {
                int[] outfit = PersonCells.Outfit(S.Gd.Str(kit["shirt"]), S.Gd.Str(kit["pants"]), S.Gd.Str(kit["hair"]), skin);
                for (int pose = 0; pose < StadiumMatch.POSES; pose++)
                    meshes.Add(PersonCells.Mesh(PersonCells.Body(outfit, pose, false), PersonCells.DRESSED_SALT + pose, voxel, noise));
            }
        }
        return meshes.ToArray();
    }

    public void Step(float dt) => match.Step(dt);

    public void Draw()
    {
        Graphics.DrawMesh(props, pitch, marks, 0);
        Graphics.DrawMeshInstanced(mouth, 0, dark, mouths, mouths.Length);
        Players();
        if (match.ballScale > 0.0)
        {
            var at = new Vector3((float)match.ball.x, (float)(match.top + match.BallArc()), -(float)match.ball.y);
            Graphics.DrawMesh(ball, Matrix4x4.TRS(at, Quaternion.identity, Vector3.one * (float)match.ballScale), ballGlow, 0);
        }
        if (match.crowd != null) Fans(match.crowd);
    }

    void Players()
    {
        Array.Clear(playerCounts, 0, playerCounts.Length);
        foreach (StadiumMatch.Player p in match.players)
        {
            int bucket = match.Bucket(p);
            var at = new Vector3((float)p.pos.x, (float)match.top, -(float)p.pos.y);
            playerBatches[bucket][playerCounts[bucket]++] = Matrix4x4.TRS(at, Facing(p.heading), Vector3.one);
        }
        for (int k = 0; k < kits.Length; k++)
            if (playerCounts[k] > 0) Graphics.DrawMeshInstanced(kits[k], 0, people, playerBatches[k], playerCounts[k]);
    }

    static Quaternion Facing(S.Vector2 heading)
    {
        var forward = new Vector3((float)heading.x, 0f, -(float)heading.y);
        return forward.sqrMagnitude > Mathf.Epsilon ? Quaternion.LookRotation(forward) : Quaternion.identity;
    }

    // Every fan still in view, where CrowdPose puts it: seated meshes until the panic, the arms-up runner after
    // (stadium_crowd.gd swaps the whole crowd's mesh). No shadows, as Godot (a third of their cost).
    void Fans(StadiumCrowd crowd)
    {
        Array.Clear(fanCounts, 0, fanCounts.Length);
        FansDrawn = 0;
        foreach (StadiumCrowd.Fan fan in crowd.fans)
        {
            CrowdPose pose = CrowdPose.Of(crowd, fan, crowd.clock);
            if (pose.hidden || pose.scale <= 0.0) continue;
            int n = fanCounts[fan.outfit]++;
            List<Matrix4x4[]> batches = fanBatches[fan.outfit];
            if (n / BATCH >= batches.Count) batches.Add(new Matrix4x4[BATCH]);
            batches[n / BATCH][n % BATCH] = Place(crowd, fan, pose);
            FansDrawn++;
        }
        Mesh[] meshes = crowd.fleeing ? standing : seated;
        for (int o = 0; o < fanCounts.Length; o++)
            for (int from = 0; from < fanCounts[o]; from += BATCH)
                Graphics.DrawMeshInstanced(meshes[o], 0, people, fanBatches[o][from / BATCH], Mathf.Min(BATCH, fanCounts[o] - from), null, ShadowCastingMode.Off, true);
    }

    // crowd.gdshader's vertex maths as one matrix: facing the pitch from its seat, then (in its own frame) turned
    // to run, gone over as it falls and lifted off its back, shrunk under the dust. The tilt's sign flips with z.
    static Matrix4x4 Place(StadiumCrowd crowd, StadiumCrowd.Fan fan, CrowdPose pose)
    {
        S.Vector3 at = fan.pos + pose.off;
        S.Vector2 facing = crowd.centre - new S.Vector2(fan.pos.x, fan.pos.z);
        Matrix4x4 world = Matrix4x4.TRS(new Vector3((float)at.x, (float)at.y, -(float)at.z), Facing(facing), Vector3.one * (float)pose.scale);
        Quaternion own = Quaternion.AngleAxis(-(float)pose.tilt * Mathf.Rad2Deg, Vector3.right);
        if (pose.turned) own *= Quaternion.AngleAxis(HALF_TURN, Vector3.up);
        return world * Matrix4x4.TRS(new Vector3(0f, (float)pose.lift, 0f), own, Vector3.one);
    }

    public void Dispose()
    {
        foreach (Mesh[] set in new[] { kits, seated, standing, new[] { props, mouth, ball } })
            foreach (Mesh mesh in set) UnityEngine.Object.Destroy(mesh);
        foreach (Material m in new[] { people, marks, ballGlow, dark }) UnityEngine.Object.Destroy(m);
    }
}
