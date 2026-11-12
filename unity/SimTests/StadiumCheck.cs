// The stadium's match and crowd (Rampage/StadiumMatch.cs, StadiumCrowd.cs, CrowdBuild.cs, PitchProps.cs, after
// scenes/stadium_match.gd, stadium_crowd.gd, crowd_build.gd, crowd_cells.gd, pitch_props.gd) are plain seeded maths
// over the sim's stadium, so they are held here against Godot 4.7.2 itself: with the same city (stage 2, seed 0),
// the same presentation stream (fx 0, salt 0x5907), soccer forced, crowd_max 2500 and the same calls at 60 steps a
// second, Godot's own classes gave the numbers pinned below. Off: while the stadium stands whole nobody flees.
// On: the frame it loses a chunk the players and every fan run, those over the gap fall, and the stands empty over
// seconds. Also: where a fan is drawn (CrowdPose, after crowd.gdshader), a blow on the pitch, the pitch's cells.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class StadiumCheck
{
    const long Seed = 0, Tier = 2, Salt = 0x5907;
    const int CrowdMax = 2500;
    const double Dt = 1.0 / 60.0, Near = 2.0e-4, Huge = 1.0e9;
    // Godot's run.
    const int StadiumIndex = 1549, Players = 22, Fans = 2500, Outfits = 18, OutfitSum = 61008, LastSlot = 252, FirstOutfit = 5;
    const int PlayFrames = 600, FleeFrames = 300, EndFrames = 1200, Kicks = 8;
    const int AliveAfter = 2544, PanicStands = 2490, PanicRunning = 2418, PanicDying = 72, PanicFallen = 82;
    const int FledStands = 2393, FledRunning = 1697, FledDying = 696, FledFallen = 710, FledEscaped = 93;
    const int Crushed = 47, EndStands = 237, EndFallen = 1993, EndEscaped = 460;
    const double CrushAt = 0.7, CrushRadius = 1.5;
    const int SoccerX = 50, SoccerZ = 30, AflX = 61, AflZ = 37, Mouth = 7, Mate = 5, Third = 3, SlotWeights = 7;

    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        Kaiju.Sim.FileAccess.Root = repoRoot;
        RampageSim sim = MakeSim();
        int index = Stadium(sim);
        Check(index == StadiumIndex, $"the city's stadium is Godot's building: {index}");
        RampageSim.Building b = sim.buildings[index];

        var picked = new StadiumMatch(sim, index, null, Stream(), 0);
        Check(Gd.Str(picked.sport["id"]) == "afl", $"the seeded pick is Godot's sport: {picked.sport["id"]}");
        Check(picked.crowd == null, "off: with crowd_max 0 the match seats no crowd");
        Pitch(picked);

        var puffs = new List<Vector3>();
        var m = new StadiumMatch(sim, index, puffs.Add, Stream(), CrowdMax, "soccer");
        Built(m);

        // Off: the stadium whole, ten seconds of play.
        Steps(m, PlayFrames);
        Check(!m.fleeing && m.kicks == Kicks && m.OnPitch() == Players && m.crowd.InStands() == Fans && m.crowd.Running() == 0,
            $"off: the stadium whole, they play on and nobody flees, as Godot: kicks {m.kicks}");
        Check(At(m.ball, -26.4955, 143.6221) && At(m.players[Third].pos, -29.73766, 140.431),
            $"the ball and a player are where Godot's are after ten seconds: {m.ball.x},{m.ball.y}");
        Poses(m, false);

        // On: one chunk of the stands goes.
        StadiumCrowd.Fan mid = m.crowd.fans[m.crowd.fans.Count / 2];
        var corner = new Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5);
        var cells = new GArray<Vector3i>();
        cells.Append(CrowdBuild.Chunk(mid.pos, corner));
        sim.DamageChunks(index, cells, Huge);
        Check(b.frame.aliveCount == AliveAfter, $"the blow takes the chunks it took in Godot: {b.frame.aliveCount}");
        Steps(m, 1);
        Line(m, "panic", PanicStands, PanicRunning, PanicDying, PanicFallen, 0);
        Check(m.fleeing && puffs.Count > 0, $"on: the frame a chunk goes, everyone flees and dust rises where fans fall: {puffs.Count} puffs");
        StadiumCrowd.Fan first = m.crowd.fans[0];
        Check(Math.Abs(first.run - 0.25438) < Near && Math.Abs(first.outAt - 1.73414) < Near, $"a fan's run to the back is Godot's: {first.run}");
        Steps(m, FleeFrames);
        Line(m, "five seconds on", FledStands, FledRunning, FledDying, FledFallen, FledEscaped);
        Check(m.OnPitch() == 0 && m.escaped == Players, $"every player is down a tunnel in five seconds, as Godot: {m.escaped}");
        Poses(m, true);
        int dead = m.crowd.Crush(new Vector3(b.x + b.w * 0.5 * CrushAt, 0.0, b.z), CrushRadius);
        Check(dead == Crushed && m.crowd.killed == Crushed, $"a blow on the stands kills the fans Godot's did: {dead}");
        Steps(m, EndFrames);
        Line(m, "twenty seconds more", EndStands, 0, EndStands, EndFallen, EndEscaped);
        Blow(sim, index);

        Console.WriteLine(failed == 0
            ? $"stadium: {checks} checks, 0 failed (off: {Fans} seated, 0 flee; on: {PanicRunning} run the frame a chunk goes, {EndEscaped} out, {EndFallen} fallen)"
            : $"stadium: {failed} failed");
        return failed;
    }

    static RampageSim MakeSim()
    {
        GDict stats = UpgradeTree.RunStats(Content.Section("kaiju"), Content.SpeciesDef("reptilian"), new UpgradeTree(Content.Upgrades()));
        GArray<GDict> layout = CityGrowth.Layout(Content.Tuning(), Tier, Seeds.Make("city", Seed));
        return new RampageSim(stats, CityGrowth.TuningFor(Content.Tuning(), Tier), layout, Seeds.Make("army", Seed));
    }

    static RandomNumberGenerator Stream() => Seeds.Derive(Seeds.Make("fx", Seed), Salt);

    static int Stadium(RampageSim sim)
    {
        GDict pitch = Content.Sports()["pitch"];
        int index = -1;
        for (int i = 0; i < sim.buildings.Size(); i++)
            if (sim.buildings[i].landmark == Gd.Str(pitch["landmark"])) index = i;
        return index;
    }

    static void Steps(StadiumMatch m, int frames)
    {
        for (int i = 0; i < frames; i++) m.Step(Dt);
    }

    // The pitch's markings: the field Godot measured, and the cells of each sport on the grass or on a post.
    static void Pitch(StadiumMatch m)
    {
        Vector2i afl = PitchProps.Field(m.sport, m.half);
        Check(afl.x == AflX && afl.y == AflZ, $"an oval sport's field is the whole pitch, as Godot: {afl.x},{afl.y}");
        GArray<Variant> sports = Content.Sports()["sports"];
        foreach (Variant s in sports)
        {
            GDict sport = s;
            Dictionary<Vector3i, int> cells = PitchProps.Cells(sport, m.half);
            int posts = 0;
            bool low = false;
            foreach (KeyValuePair<Vector3i, int> c in cells)
            {
                if (c.Value == PitchProps.POST) posts++;
                low |= c.Key.y < 0;
            }
            Check(cells.Count > posts && posts > 0 && !low, $"{sport["id"]}: lines on the grass and posts above it: {cells.Count} cells, {posts} of post");
        }
    }

    static void Built(StadiumMatch m)
    {
        Vector2i field = PitchProps.Field(m.sport, m.half);
        Check(field.x == SoccerX && field.y == SoccerZ, $"soccer's field is Godot's rectangle: {field.x},{field.y}");
        List<StadiumMatch.Player> ps = m.players;
        Check(ps.Count == Players && At(ps[0].home, -30.25, 141.5) && At(ps[Mate].home, -31.98443, 141.8394) && At(ps[Players - 1].home, -25.53067, 142.5004),
            $"two sides stand where Godot stood them: {ps.Count}, {ps[Mate].home.x},{ps[Mate].home.y}");
        Check(ps[Mate].skin == 0 && Math.Abs(ps[Mate].phase - 0.616780) < Near && Math.Abs(ps[Mate].pull - 0.441105) < Near, "a player's skin, beat and pull are Godot's draws");
        Check(At(m.mouths[0], -22.36919, 142.7682) && At(m.mouths[Mouth], -35.58614, 138.0352), $"the tunnel mouths are Godot's: {m.mouths[0].x},{m.mouths[0].y}");
        List<StadiumCrowd.Fan> fans = m.crowd.fans;
        Check(fans.Count == Fans && m.crowd.outfits.Count == Outfits, $"a fan on each seat Godot found, up to crowd_max: {fans.Count} in {m.crowd.outfits.Count} outfits");
        Check(Spot(fans[0].pos, -41.6875, 4.75, 140.3125) && Spot(fans[Fans - 1].pos, -33.9375, 4.125, 133.5625),
            $"the first and last seats are Godot's: {fans[0].pos.x},{fans[0].pos.y},{fans[0].pos.z}");
        int sum = 0;
        foreach (StadiumCrowd.Fan f in fans) sum += f.outfit * (f.slot % SlotWeights + 1);
        Check(sum == OutfitSum && fans[0].outfit == FirstOutfit && fans[Fans - 1].slot == LastSlot, $"every fan wears what Godot drew: {sum}");
    }

    static void Line(StadiumMatch m, string when, int stands, int running, int dying, int fallen, int escaped)
    {
        StadiumCrowd c = m.crowd;
        Check(c.InStands() == stands && c.Running() == running && c.Dying() == dying && c.fallen == fallen && c.escaped == escaped,
            $"{when}, the crowd as Godot's: in view {c.InStands()}, running {c.Running()}, dying {c.Dying()}, fallen {c.fallen}, out {c.escaped}");
    }

    // Where the fans are drawn: seated they only bob; fleeing, a runner faces out and is where the crowd counts it;
    // a body lies no lower than it landed and one out of sight is hidden.
    static void Poses(StadiumMatch m, bool fleeing)
    {
        StadiumCrowd c = m.crowd;
        double bob = Num.F(c.cfg["bob"]);
        bool still = true, placed = true, bodies = true, hidden = true;
        int turned = 0;
        foreach (StadiumCrowd.Fan fan in c.fans)
        {
            CrowdPose pose = CrowdPose.Of(c, fan, m.clock);
            if (fan.state == StadiumCrowd.State.SEATED) still &= pose.off.x == 0.0 && pose.off.z == 0.0 && pose.off.y >= 0.0 && pose.off.y <= bob + Near && !pose.turned;
            if (fan.state == StadiumCrowd.State.GONE) hidden &= pose.hidden;
            if (fan.state == StadiumCrowd.State.DYING) bodies &= fan.pos.y + pose.off.y >= fan.land - Near && pose.scale >= 0.0 && pose.scale <= 1.0;
            if (fan.state != StadiumCrowd.State.UP || pose.hidden) continue;
            Vector3 feet = c.RunningAt(fan);
            placed &= Math.Abs(fan.pos.x + pose.off.x - feet.x) < Near && Math.Abs(fan.pos.z + pose.off.z - feet.z) < Near && fan.pos.y + pose.off.y >= feet.y - Near;
            if (pose.turned) turned++;
        }
        if (!fleeing) Check(still, "off: a seated fan only bobs on its seat");
        else Check(placed && bodies && hidden && turned > 0, $"on: runners are drawn where they are counted, facing out ({turned}); bodies lie where they landed; the gone are hidden");
    }

    // A blow on the pitch: the players under it die with one puff of dust; one that misses kills nobody.
    static void Blow(RampageSim sim, int index)
    {
        var puffs = new List<Vector3>();
        var m = new StadiumMatch(sim, index, puffs.Add, Stream(), 0, "soccer");
        Vector2 at = m.players[0].pos;
        int miss = m.Crush(new Vector3(at.x + Huge, 0.0, at.y), CrushRadius);
        int dead = m.Crush(new Vector3(at.x, 0.0, at.y), CrushRadius);
        Check(miss == 0 && dead > 0 && m.killed == dead && m.OnPitch() == Players - dead && puffs.Count == 1,
            $"a blow on the pitch kills the players under it, with one puff: {dead} dead, {puffs.Count} puffs");
    }

    static bool At(Vector2 p, double x, double y) => Math.Abs(p.x - x) < Near && Math.Abs(p.y - y) < Near;

    static bool Spot(Vector3 p, double x, double y, double z) => Math.Abs(p.x - x) < Near && Math.Abs(p.y - y) < Near && Math.Abs(p.z - z) < Near;

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL stadium: " + what);
    }
}
