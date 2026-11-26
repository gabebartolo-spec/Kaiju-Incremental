// -flow-smoke's save paths (U5 2): the throwaway folder starts with a cut-off slot file and one from a newer save
// version, which the title must show taken and UNREADABLE and leave byte for byte; the new kaiju goes in slot 1.
// After the last rampage the tree buys its cheapest node (the bank is topped up to its cost if the runs fell short)
// and reopens from the save. `-flow-smoke -flow-continue` is the second process: it keeps the folder, presses
// CONTINUE on the title and checks the globe holds what the first run saved. The lab card after a death is noted.
using System.IO;
using System.Linq;
using Kaiju.Game;
using UnityEngine;
using S = Kaiju.Sim;

public sealed partial class GameFlow
{
    const string SMOKE_KEEP = "-flow-continue";
    const int SMOKE_CUT_SLOT = 2, SMOKE_NEWER_SLOT = 3, SMOKE_NEW_SLOT = 1;
    // A save file cut off mid-word, as a crash during a write would leave it.
    const string SMOKE_CUT = "{\n\t\"version\": 6,\n\t\"species\": \"reptil";
    const string SMOKE_NODE = "claws";

    static bool smokeContinue, smokeBought;
    static long smokeLabCard;

    static void ResetPaths()
    {
        smokeContinue = smokeBought = false;
        smokeLabCard = 0;
    }

    // A file a newer build wrote: whole and readable, but its version is past this build's.
    static string NewerFile() => Json.Stringify(new S.GDict
    {
        { "version", (long)SaveFile.Version + 1 }, { "species", "reptilian" }, { "runs", 4L },
    }, "\t");

    // Never the player's saves or settings: a folder of its own and a pinned city seed. The first run empties it
    // and leaves the two unreadable slot files; the -flow-continue run plays on what the first left.
    static void SmokeBoot(string[] args)
    {
        smokeContinue = args.Contains(SMOKE_KEEP);
        string dir = Path.Combine(Application.temporaryCachePath, SMOKE_DIR);
        if (!smokeContinue && Directory.Exists(dir)) Directory.Delete(dir, true);
        Directory.CreateDirectory(dir);
        UserDir.Root = dir;
        SaveFile.PinnedSeed = 0;
        Application.logMessageReceived += SmokeLog;
        if (smokeContinue) return;
        UserDir.WriteText(SaveFile.PathOf(SMOKE_CUT_SLOT), SMOKE_CUT);
        UserDir.WriteText(SaveFile.PathOf(SMOKE_NEWER_SLOT), NewerFile());
        Debug.Log($"flow: smoke left a cut-off file in slot {SMOKE_CUT_SLOT} and a version {SaveFile.Version + 1} file in slot {SMOKE_NEWER_SLOT}");
    }

    static void UnreadableKept()
    {
        Expect(UserDir.ReadText(SaveFile.PathOf(SMOKE_CUT_SLOT)) == SMOKE_CUT, $"slot {SMOKE_CUT_SLOT}'s cut-off file was changed");
        Expect(UserDir.ReadText(SaveFile.PathOf(SMOKE_NEWER_SLOT)) == NewerFile(), $"slot {SMOKE_NEWER_SLOT}'s newer file was changed");
    }

    string PlateText(string name)
    {
        KitButton b = Find(screen, name);
        Expect(b != null, $"no plate {name} on the title");
        return b.label.text;
    }

    // NEW KAIJU with two slots taken opens the slot list: both unreadable plates say so, slot 1 is empty.
    void SmokeNewSlot()
    {
        string unreadable = Tr.T(TitleMenu.UNREADABLE);
        foreach (int n in new[] { SMOKE_CUT_SLOT, SMOKE_NEWER_SLOT })
        {
            string text = PlateText("Slot" + n);
            Expect(text.Contains(unreadable), $"slot {n}'s plate reads '{text}', not {unreadable}");
            SlotInfo info = SaveFile.Info(n);
            Expect(info.Taken && !info.Readable && !info.Continues, $"slot {n} is not taken and unreadable");
        }
        Expect(PlateText("Slot" + SMOKE_NEW_SLOT).Contains(Tr.T(TitleMenu.EMPTY)), $"slot {SMOKE_NEW_SLOT} is not empty");
        Debug.Log($"flow: smoke slot list ok, slots {SMOKE_CUT_SLOT} and {SMOKE_NEWER_SLOT} taken and unreadable");
        Press("Slot" + SMOKE_NEW_SLOT);
    }

    // The second process: CONTINUE, the unreadable plates off, then the slot the first run played.
    void SmokeContinueTitle()
    {
        switch (smokeStep)
        {
            case 0:
                Step();
                Expect(SaveFile.LatestSlot() == SMOKE_NEW_SLOT, $"CONTINUE resumes slot {SaveFile.LatestSlot()}, not {SMOKE_NEW_SLOT}");
                Press("Continue");
                break;
            case 1:
                Step();
                Expect(!Find(screen, "Slot" + SMOKE_CUT_SLOT).interactable && !Find(screen, "Slot" + SMOKE_NEWER_SLOT).interactable,
                    "an unreadable slot can be continued");
                Press("Slot" + SMOKE_NEW_SLOT);
                break;
        }
    }

    // The globe after CONTINUE holds what the first process saved: its runs, its bank and the node it bought.
    void SmokeGlobe()
    {
        if (smokeStep != 0) return;
        Step();
        if (!smokeContinue) { Press("Launch"); return; }
        S.GDict disk = SaveFile.LoadGame();
        long level = TreeText.TreeOf(Save).Level(SMOKE_NODE);
        Expect(SaveFile.Slot == SMOKE_NEW_SLOT && Runs() == S.Num.I(disk.Get("runs", -1L)) && Biomass() == S.Num.I(disk.Get("rubble", -1L)),
            $"the continued save holds {Runs()} runs and biomass {Biomass()}, slot {SaveFile.Slot} on disk {Json.Stringify(disk, "")}");
        Expect(Runs() >= SMOKE_RUNS && level == 1, $"the continued kaiju has {Runs()} runs and {SMOKE_NODE} at level {level}");
        UnreadableKept();
        Pass($"continued slot {SaveFile.Slot} after a restart: {Runs()} runs, biomass {Biomass()}, {SMOKE_NODE} level {level}, specimen {S.Num.I(Save.Get("specimen", 1L))}, unreadable slots kept");
    }

    static int Shown(S.UpgradeTree tree)
    {
        int n = 0;
        foreach (string id in tree.order) if (!TreeText.Hidden(tree, id)) n++;
        return n;
    }

    // One level of the cheapest node, pressed as the pad would, then the tree again from the save.
    void SmokeBuy()
    {
        S.UpgradeTree tree = TreeText.TreeOf(Save);
        long cost = tree.Cost(SMOKE_NODE);
        if (Biomass() < cost)
        {
            Debug.Log($"flow: smoke tops the bank up from {Biomass()} to {cost} for {SMOKE_NODE}");
            Save["rubble"] = cost;
            Expect(SaveFile.SaveGame(Save), "the topped-up bank was not saved");
            Enter(State.Tree);
            return;
        }
        TreeNodeButton node = screen.GetComponentsInChildren<TreeNodeButton>().FirstOrDefault(b => b.name == "Node_" + SMOKE_NODE);
        Expect(node != null && node.interactable, $"no node {SMOKE_NODE} to press on the tree");
        long before = Biomass();
        Debug.Log($"flow: smoke presses Node_{SMOKE_NODE} in Tree");
        node.OnSubmit(null);
        S.GDict disk = SaveFile.LoadGame();
        S.UpgradeTree after = TreeText.TreeOf(disk);
        Expect(after.Level(SMOKE_NODE) == 1 && S.Num.I(disk.Get("rubble", -1L)) == before - cost && Biomass() == before - cost,
            $"after the buy the save holds {SMOKE_NODE} level {after.Level(SMOKE_NODE)} and biomass {S.Num.I(disk.Get("rubble", -1L))}, not 1 and {before - cost}");
        Debug.Log($"flow: smoke bought {SMOKE_NODE} for {cost}, biomass {before} to {Biomass()} in memory and on disk, nodes shown {Shown(tree)} to {Shown(after)}");
        smokeBought = true;
        Enter(State.Tree);
    }

    void SmokeTree()
    {
        if (smokeStep != 0) return;
        Step();
        if (smokeRuns < SMOKE_RUNS) { Press("Rampage"); return; }
        if (!smokeBought) { SmokeBuy(); return; }
        // The smoke never buys out the tree, so the thanks card is visited once by hand before the pass.
        if (!smokeDemoEnd) { Debug.Log("flow: smoke opens the demo end"); Enter(State.DemoEnd); return; }
        Expect(smokeSettings, "the settings were never opened");
        Expect(smokePaused, "the rampage was never paused");
        Expect(smokePhoto, "photo mode was never entered");
        Expect(smokeReported, "no feedback report was written");
        Expect(smokeLost != "" && smokeWon != "", $"the missions did not end (lost '{smokeLost}', won '{smokeWon}')");
        Expect(smokeLabCard > 1, "no lab card was shown after the first rampage's death");
        UnreadableKept();
        Pass($"{smokeRuns} rampages, biomass {Biomass()}, runs {Runs()}, settings opened and closed, paused and resumed, photo mode entered and left, feedback report written, lost {smokeLost}, won {smokeWon}, lab card for specimen {smokeLabCard}, {SMOKE_NODE} bought, unreadable slots kept, demo end visited");
    }

    // After a city's WIN / LOSE: the file on disk holds the continent as the answer left it.
    static void SmokeMission(MissionOutcome done)
    {
        long want = done.won ? S.Campaign.State.CONQUERED : S.Campaign.State.AVAILABLE;
        long onDisk = GlobeMissions.StateOf(GlobeMissions.States(SaveFile.LoadGame()), done.id);
        if (onDisk != want) { Fail($"slot {SaveFile.Slot} on disk holds {done.id} in state {onDisk} after it was {(done.won ? "won" : "lost")}, not {want}"); return; }
        if (done.won) smokeWon = done.id;
        else smokeLost = done.id;
        Debug.Log($"flow: smoke save ok after mission, {done.id} {(done.won ? "conquered" : "still open")} on disk");
    }

    // After each bank: the save in memory and the file on disk both hold what the rampages earned.
    static void SmokeBanked(S.GDict result)
    {
        smokeRuns++;
        smokeEarned += S.Num.I(result.Get("rubble", 0L));
        S.GDict disk = SaveFile.LoadGame();
        if (Biomass() != smokeEarned || Runs() != smokeRuns) Fail($"the save holds biomass {Biomass()} after {Runs()} runs, the rampages earned {smokeEarned} in {smokeRuns}");
        else if (S.Num.I(disk.Get("rubble", -1L)) != smokeEarned || S.Num.I(disk.Get("runs", -1L)) != smokeRuns) Fail($"slot {SaveFile.Slot} on disk holds biomass {S.Num.I(disk.Get("rubble", -1L))} after {S.Num.I(disk.Get("runs", -1L))} runs, not {smokeEarned} after {smokeRuns}");
        else Debug.Log($"flow: smoke save ok after run {smokeRuns}, biomass {smokeEarned} in memory and on disk");
    }
}
