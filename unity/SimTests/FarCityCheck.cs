// The far rampage's schedule (Rampage/SkylineRampagePlan.cs, scenes/skyline_rampage_plan.gd). Player-effect
// fixture "skyline.rampage": on a row of far towers, the beast's path drops the tall towers in its way (on) and
// never a low box or one out of its reach (off); towers keep dropping as the run goes on; every ruin burns and
// smokes, with a few towers left standing on fire; and the same run seed plans the same rampage twice.
using System;
using System.Collections.Generic;
using Kaiju.Sim;

static class FarCityCheck
{
    const double SHORE = -400.0, SALT = 16, STEP = 20.0, LATE = 120.0;
    const int RUN = 0;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        failed = 0;
        checks = 0;
        FileAccess.Root = repoRoot;
        GDict cfg = Content.Section("skyline_rampage");
        Check((bool)cfg["on"], "tuning skyline_rampage.on defaults to true (the feature is in the game)");
        List<SkylineRampagePlan.Box> boxes = Row(cfg, out int low, out int far, out int crowned, out int crown);
        SkylineRampagePlan plan = Plan(cfg, boxes, RUN);
        Drops(cfg, plan, boxes, low, far);
        Crowns(plan, crowned, crown);
        Burns(cfg, plan);
        Repeats(cfg, plan, boxes);
        Console.WriteLine(failed == 0 ? $"far city: ok ({checks} checks)" : $"far city: {failed} of {checks} failed");
        return failed;
    }

    static SkylineRampagePlan Plan(GDict cfg, List<SkylineRampagePlan.Box> boxes, long run) =>
        new SkylineRampagePlan(cfg, boxes, SHORE, Seeds.Derive(Seeds.Make("fx", run), (long)SALT), 9.0);

    static SkylineRampagePlan.Box Box(double x, double y, double z, double sx, double sy, int crownOf = -1) =>
        new SkylineRampagePlan.Box { size = new Vector3(sx, sy, 10), at = new Vector3(x, y, z), crownOf = crownOf };

    // Tall towers on the beast's path and a row beside it, a low box on its path, a tower far out of its reach,
    // and a crown on the first tower.
    static List<SkylineRampagePlan.Box> Row(GDict cfg, out int low, out int far, out int crowned, out int crown)
    {
        double path = SHORE - Num.F(cfg["path_depth"]), swing = Num.F(cfg["swing"]);
        var boxes = new List<SkylineRampagePlan.Box>();
        for (double x = -swing; x <= swing; x += STEP)
        {
            boxes.Add(Box(x, 20.8, path, 12, 40));
            boxes.Add(Box(x + STEP * 0.5, 15.8, path - 40, 12, 30));
        }
        crowned = 0;
        crown = boxes.Count;
        boxes.Add(Box(boxes[0].at.x, 42.8, path, 6, 4, crowned));
        low = boxes.Count;
        boxes.Add(Box(0, 4.8, path, 12, 8));
        far = boxes.Count;
        boxes.Add(Box(swing * 3.0, 20.8, path, 12, 40));
        return boxes;
    }

    static void Drops(GDict cfg, SkylineRampagePlan plan, List<SkylineRampagePlan.Box> boxes, int low, int far)
    {
        double start = Num.F(cfg["start_s"]), fallS = Num.F(cfg["fall_s"]);
        double spread = Math.Abs(plan.BeastX(start) - Num.F(cfg["centre_x"])) / Num.F(cfg["swing"]);
        Check(spread <= 0.35 + 1e-9, $"the beast starts mid-skyline ({spread:F2} of its swing off centre)");
        Check(plan.falls.Count > 0, $"on: towers in its way fall ({plan.falls.Count})");
        bool smash = false;
        foreach (SkylineRampagePlan.Fall f in plan.falls)
        {
            Check(f.index != low, "a box below the tallness bar never falls");
            Check(f.index != far, "a tower out of the beast's reach never falls");
            smash |= f.smash;
        }
        Check(smash, "some falls are the beast's own blows");
        for (int n = 1; n < plan.falls.Count; n++)
            Check(plan.falls[n].at >= plan.falls[n - 1].at, $"falls in time order ({n})");
        int early = Fallen(plan, start, fallS), late = Fallen(plan, start + LATE, fallS);
        Check(late > early, $"towers keep falling as the run goes on ({early} at its start, {late} {LATE:F0} s in)");
    }

    static int Fallen(SkylineRampagePlan plan, double t, double fallS)
    {
        int n = 0;
        foreach (SkylineRampagePlan.Fall f in plan.falls)
            if (f.at + fallS <= t) n++;
        return n;
    }

    static void Crowns(SkylineRampagePlan plan, int crowned, int crown)
    {
        foreach (SkylineRampagePlan.Fall f in plan.falls)
            Check(f.index != crown, "a crown never falls on its own");
        SkylineRampagePlan.Fall mine = plan.falls.Find(f => f.index == crowned);
        if (mine != null) Check(mine.crowns.Contains(crown), "a falling tower takes its crown with it");
    }

    static void Burns(GDict cfg, SkylineRampagePlan plan)
    {
        int ruins = 0;
        foreach (SkylineRampagePlan.Fire f in plan.fires) ruins += f.dust ? 1 : 0;
        Check(ruins == plan.falls.Count, $"every ruin burns ({ruins} of {plan.falls.Count})");
        Check(plan.fires.Count > ruins, $"towers left standing burn too ({plan.fires.Count - ruins})");
        long puffs = Num.I(cfg["puffs"]);
        Check(plan.puffs.Count == (plan.fires.Count + ruins) * puffs, $"a smoke column per fire and dust per ruin ({plan.puffs.Count} puffs)");
    }

    static void Repeats(GDict cfg, SkylineRampagePlan plan, List<SkylineRampagePlan.Box> boxes)
    {
        SkylineRampagePlan again = Plan(cfg, boxes, RUN), other = Plan(cfg, boxes, RUN + 1);
        Check(Same(plan, again), "the same run plans the same far rampage");
        Check(!Same(plan, other), "another run plans another");
    }

    static bool Same(SkylineRampagePlan a, SkylineRampagePlan b)
    {
        if (a.falls.Count != b.falls.Count || a.puffs.Count != b.puffs.Count || a.phase0 != b.phase0) return false;
        for (int n = 0; n < a.falls.Count; n++)
            if (a.falls[n].index != b.falls[n].index || a.falls[n].at != b.falls[n].at) return false;
        for (int n = 0; n < a.puffs.Count; n++)
            if (a.puffs[n].seed != b.puffs[n].seed) return false;
        return true;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL far city: " + what);
    }
}
