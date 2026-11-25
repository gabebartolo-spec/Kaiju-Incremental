// Heavy stomps crack the street (GameLogic/StompCrack.cs; scenes/ability_fx.gd power and stomp_cracks): a blow is
// weighed against the species' own stomp_damage, 1 up to fx "power_max"; from fx "crack_stomp_power" up it cracks,
// glowing 2.5 + 3 per power past that. The player effect, on against off (tests/run_flow_tests.gd _check_powers: "a
// plain one does not crack the street"): the plain croc's stomps leave no cracks, one grown to the Behemoth with two
// levels of Crushing Weight does, and the Heavy Heel alone stomps harder without cracking.
using System;
using Kaiju.Game;
using S = Kaiju.Sim;

static class StompCrackCheck
{
    const string Species = "reptilian";
    const double NEAR = 1e-9;
    // ability_fx.gd stomp_cracks: the glow at the threshold, and one power past it.
    const double GLOW_AT_FROM = 2.5, GLOW_PER_POWER = 3.0;
    static int failed, checks;

    public static int Run(string repoRoot)
    {
        S.FileAccess.Root = repoRoot;
        failed = 0;
        checks = 0;
        S.GDict fx = S.Content.Section("fx");
        double max = S.Num.F(fx["power_max"]), from = S.Num.F(fx["crack_stomp_power"]);
        Power(max);
        Threshold(from, max);
        OnAgainstOff(from);
        Console.WriteLine(failed == 0 ? $"stomp cracks: ok ({checks} checks)" : $"stomp cracks: {failed} of {checks} failed");
        return failed;
    }

    static void Power(double max)
    {
        Check(Math.Abs(StompCrack.Power(10.0, 10.0) - 1.0) < NEAR, "the species' own stomp weighs 1");
        Check(Math.Abs(StompCrack.Power(15.0, 10.0) - 1.5) < NEAR, "half as heavy again weighs 1.5");
        Check(StompCrack.Power(5.0, 10.0) == 1.0, "a lighter blow never weighs under 1");
        Check(StompCrack.Power(1000.0, 10.0) == max, $"nor over power_max {max}");
        Check(StompCrack.Power(10.0, 0.0) == max, "no own stat: any blow is as heavy as it gets");
    }

    static void Threshold(double from, double max)
    {
        Check(StompCrack.Cracks(from, out double glow) && Math.Abs(glow - GLOW_AT_FROM) < NEAR,
            $"a blow of exactly crack_stomp_power {from} cracks, glowing {GLOW_AT_FROM}: {glow}");
        Check(!StompCrack.Cracks(from - 0.01, out _), "just under it does not");
        StompCrack.Cracks(max, out double top);
        Check(Math.Abs(top - (GLOW_AT_FROM + GLOW_PER_POWER * (max - from))) < NEAR, $"the heaviest glows {top}");
        StompCrack.Cracks(from + 0.5, out double more);
        Check(more > glow, "heavier glows brighter");
    }

    static void OnAgainstOff(double from)
    {
        S.GDict species = S.Content.SpeciesDef(Species);
        double own = S.Num.F(((S.GDict)species["stats"])["stomp_damage"]);
        double plain = Stomp(species, new S.GDict());
        double heel = Stomp(species, new S.GDict { { "r_heel", 1 } });
        double grown = Stomp(species, new S.GDict { { "evolve1", 1 }, { "tail", 2 } });
        Check(!StompCrack.Cracks(StompCrack.Power(plain, own), out _), $"off: the plain croc (stomp {plain}) cracks nothing");
        Check(heel > plain && !StompCrack.Cracks(StompCrack.Power(heel, own), out _),
            $"the Heavy Heel stomps harder ({heel}) but does not crack");
        Check(StompCrack.Cracks(StompCrack.Power(grown, own), out _),
            $"on: the Behemoth with Crushing Weight 2 (stomp {grown}, power {StompCrack.Power(grown, own)}) cracks the street");
    }

    static double Stomp(S.GDict species, S.GDict levels)
    {
        S.GDict stats = S.UpgradeTree.RunStats(S.Content.Section("kaiju"), species, new S.UpgradeTree(S.Content.Upgrades(), levels, Species));
        return S.Num.F(stats["stomp_damage"]);
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("  FAIL " + what);
    }
}
