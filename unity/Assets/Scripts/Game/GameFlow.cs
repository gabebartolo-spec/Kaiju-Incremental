// The game flow (scenes/main.gd): title -> Kaiju Creation -> the globe -> a city's rampage -> results -> the
// evolution tree, whose RAMPAGE goes back to the globe. The only object in Assets/Game.unity. It owns the save;
// screens get what they need through Show(...) and report back by delegate. Entering or leaving a rampage
// reloads the scene with the next state in statics: the rampage is only proven to start from a fresh scene.
// Any -rampage-* flag is a standalone capture run: RampageGame alone, as before the flow existed.
// -ui-gallery shows the kit's gallery; -flow-smoke plays the whole loop unattended on a throwaway save folder.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Kaiju.Game;
using UnityEngine;
using UnityEngine.SceneManagement;
using Opt = Kaiju.Game.PlayerSettings;
using S = Kaiju.Sim;

[DefaultExecutionOrder(-100)]  // Inputs.Poll before any screen reads a press
public sealed class GameFlow : MonoBehaviour
{
    public enum State { Title, Creation, Globe, Rampage, Results, Tree, DemoEnd }

    // -flow-smoke: seconds a screen is on show before its button is pressed, the rampage age at which the clock
    // is run out, how long one state may last, rampages played, and the gallery's time on show.
    const float SMOKE_WAIT = 1f;
    const int SMOKE_TIMEUP = 6;
    const float SMOKE_STUCK = 120f;
    const int SMOKE_RUNS = 2;
    const float SMOKE_GALLERY = 2f;
    const string SMOKE_DIR = "flow_smoke";

    // The save in play, its slot (SaveFile.Slot) and the rampage being started or played.
    public static S.GDict Save = new S.GDict();
    public static int Slot { get { return SaveFile.Slot; } set { SaveFile.Slot = value; } }
    public static RunRequest Pending;
    public static State Now { get; private set; }

    static State next;
    static bool booted, smoke, gallery, smokeOver;
    static string dataRoot;
    static int smokeRuns;
    static long smokeEarned;
    static GameFlow live;

    RampageGame game;
    RectTransform screen, pause;
    bool standalone, pressed;
    float stateAt;
    int pausedFrame, resumedFrame = -1;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset()
    {
        Application.wantsToQuit -= WantsToQuit;
        Application.logMessageReceived -= SmokeLog;
        Save = new S.GDict();
        Pending = null;
        Now = next = State.Title;
        booted = smoke = gallery = smokeOver = false;
        smokeRuns = 0;
        smokeEarned = 0;
        live = null;
    }

    // The screen on show (null in a rampage with nothing over it).
    public static RectTransform Screen => live != null ? live.screen : null;

    // Shows `state`. Into or out of a rampage the scene is reloaded first.
    public static void Go(State state)
    {
        if (live == null || state == State.Rampage || live.game != null)
        {
            next = state;
            if (live != null) SceneManager.LoadScene(0);
            return;
        }
        live.Enter(state);
    }

    void Awake()
    {
        live = this;
        if (SettingsApply.Standalone)
        {
            standalone = true;
            gameObject.AddComponent<RampageGame>();
            return;
        }
        try
        {
            Boot();
            if (gallery)
            {
                Mark(State.Title);
                screen = UiGallery.Show();
                return;
            }
            Enter(next);
        }
        catch (Exception e)
        {
            Debug.LogException(e);
            Fail("boot: " + e.Message);
        }
    }

    // RampageGame.DataRoot: the data the build bundled, or the repo's own in the editor.
    static string DataRoot()
    {
        string bundled = Path.Combine(Application.streamingAssetsPath, "res");
        return Directory.Exists(Path.Combine(bundled, "data")) ? bundled : Path.GetFullPath(Path.Combine(Application.dataPath, "..", ".."));
    }

    // Once per process: where data and saves live, the text table, the window's own close. Settings are loaded on
    // the first scene and only re-applied after a reload (SettingsApply.Boot).
    static void Boot()
    {
        if (!booted)
        {
            booted = true;
            string[] args = Environment.GetCommandLineArgs();
            smoke = args.Contains("-flow-smoke");
            gallery = args.Contains("-ui-gallery");
            dataRoot = DataRoot();
            S.FileAccess.Root = dataRoot;
            if (smoke)
            {
                // Never the player's saves or settings: a folder of its own, emptied first, and a pinned city seed.
                string dir = Path.Combine(Application.temporaryCachePath, SMOKE_DIR);
                if (Directory.Exists(dir)) Directory.Delete(dir, true);
                Directory.CreateDirectory(dir);
                UserDir.Root = dir;
                SaveFile.PinnedSeed = 0;
                Application.logMessageReceived += SmokeLog;
            }
            else
            {
                UserDir.Root = Application.persistentDataPath;
            }
            string csv = Path.Combine(dataRoot, "data", "i18n", "strings.csv");
            if (File.Exists(csv)) Tr.Load(File.ReadAllText(csv));
            else Debug.LogWarning("flow: no text table at " + csv);
            SaveFile.Warn = text => Debug.LogWarning(text);
            Application.wantsToQuit += WantsToQuit;
            Debug.Log($"flow: boot ok, data root {dataRoot}, user dir {UserDir.Root}, {Tr.Count} texts, {SaveFile.SlotCount()} slots{(smoke ? ", smoke" : "")}");
        }
        S.FileAccess.Root = dataRoot;
        SettingsApply.Boot();
    }

    // The window's own close (Alt+F4, the X) leaves as the QUIT buttons do (main.gd _notification).
    static bool WantsToQuit()
    {
        if (!Quit.Quitting && !smokeOver) Quit.Now();
        return true;
    }

    void Mark(State state)
    {
        Now = state;
        stateAt = Time.realtimeSinceStartup;
        pressed = false;
        Opt.InPlay = state == State.Rampage || state == State.Results;  // main.gd _swap: next is Rampage
    }

    // A screen that called back before it returned (StubCreation) has already moved the flow on.
    void Shown(State state, RectTransform made)
    {
        if (Now == state && made != null) screen = made;
    }

    void Enter(State state)
    {
        if (screen != null) Destroy(screen.gameObject);
        screen = null;
        Mark(state);
        switch (state)
        {
            case State.Title: ShowTitle(); break;
            case State.Creation: Shown(state, StubCreation.Show(Save, OnSpeciesChosen, () => Enter(State.Title))); break;
            case State.Globe: ShowGlobe(); break;
            case State.Rampage: StartScene(); break;
            case State.Tree: ShowTree(); break;
            case State.DemoEnd:
                Shown(state, StubDemoEnd.Show(Save, () => StartRampage(null, true), () => Enter(State.Tree)));
                Debug.Log($"flow: demo end shown, biomass {Biomass()}");
                break;
            default:
                // Results are only shown over the rampage that just ended.
                Debug.LogWarning($"flow: {state} has no rampage behind it, the tree instead");
                Enter(State.Tree);
                break;
        }
    }

    static long Biomass() => S.Num.I(Save.Get("rubble", 0L));
    static long Runs() => S.Num.I(Save.Get("runs", 0L));

    void ShowTitle()
    {
        List<SlotInfo> slots = SaveFile.Slots();
        int latest = SaveFile.LatestSlot();
        Shown(State.Title, StubTitle.Show(slots, latest, ContinueSlot, NewGame, Quit.Now));
        Debug.Log($"flow: title shown, {slots.Count} slots, {slots.Count(s => s.Taken)} taken, continue slot {latest}");
    }

    // main.gd _continue_slot.
    void ContinueSlot(int n)
    {
        SaveFile.Slot = n;
        Save = SaveFile.LoadGame();
        Continue();
    }

    // main.gd _new_game: nothing is saved until the kaiju is made.
    void NewGame(int n)
    {
        SaveFile.Slot = n;
        Save = SaveFile.LoadGame();
        Enter(State.Creation);
    }

    // main.gd _on_species_chosen.
    void OnSpeciesChosen(string speciesId)
    {
        Save = S.Campaign.CarryUnlocks(Save, SaveFile.NewSave(speciesId, SaveFile.FreshSeed()));
        Save["demo"] = S.Demo.Enabled();  // a demo save never continues in the full game (D-145)
        SaveFile.SaveGame(Save);
        Debug.Log($"flow: creation made {speciesId} in slot {SaveFile.Slot}, seed {S.Num.I(Save.Get("seed", 0L))}, biomass {Biomass()}");
        Continue();
    }

    // main.gd _continue.
    void Continue()
    {
        if (!Save.Has("seed"))  // a save from before saves had a city seed draws its own now
        {
            Save["seed"] = SaveFile.FreshSeed();
            SaveFile.SaveGame(Save);
        }
        Enter(State.Globe);
    }

    void ShowGlobe()
    {
        S.GDict target = StubGlobe.Target(Save);
        Shown(State.Globe, StubGlobe.Show(Save, def => StartRampage(def, false)));
        Debug.Log($"flow: globe shown, continent {(target != null ? S.Gd.Str(target["id"]) : "none")}, biomass {Biomass()}, runs {Runs()}");
    }

    // main.gd _start_rampage and globe_missions.gd _start_city: `continent` null is the plain rampage (Endless only).
    void StartRampage(S.GDict continent, bool endless)
    {
        if (SaveFile.TakeLabCard(Save))  // it died last time: the lab card, then the new specimen
        {
            SaveFile.SaveGame(Save);
            Debug.Log($"flow: lab card owed for specimen {S.Num.I(Save.Get("specimen", 1L))} (no card screen yet)");
        }
        Pending = RunStart.Prepare(Save, continent, Opt.TimeOfDay, Opt.Weather, endless, SaveFile.Slot);
        SaveFile.SaveGame(Save);
        RunStart.Intro(Save, Pending);  // saved with the run's result
        if (smoke) Pending.fullIntro = false;  // the short cut, as the -rampage-auto runs the time-up path is proven on
        Go(State.Rampage);
    }

    // The fresh scene's rampage, hosted: it reads the request as it wakes.
    void StartScene()
    {
        if (Pending == null)
        {
            Debug.LogWarning("flow: no rampage was asked for, the title instead");
            Enter(State.Title);
            return;
        }
        RampageGame.Request = Pending;
        RampageGame.HostAuto = smoke;
        RampageGame.HostTimeUp = smoke ? SMOKE_TIMEUP : 0;
        Debug.Log($"flow: rampage starting, run {Pending.runIndex}, continent {(Pending.continent != "" ? Pending.continent : "none")}, tier {Pending.tier}, endless {Pending.endless}, biomass {Biomass()}");
        game = new GameObject("rampage").AddComponent<RampageGame>();
        RampageGame.Request = null;
        game.Finished += OnFinished;
        game.PauseRequested += OnPause;
        if (game.Error != null) Debug.LogWarning("flow: the rampage did not load");
    }

    // main.gd _on_rampage_finished: banked, then the results over the wrecked city.
    void OnFinished(S.GDict result)
    {
        if (pause != null) Destroy(pause.gameObject);
        bool endless = Pending != null && Pending.endless;
        S.GDict previous = SaveFile.Bank(Save, result, endless);
        SaveFile.SaveGame(Save);
        Mark(State.Results);
        screen = StubResults.Show(result, previous, endless ? "BACK  >" : "EVOLVE  >", () => Go(State.Tree));
        Debug.Log($"flow: results shown, reason {S.Gd.Str(result.Get("reason", ""))}, earned {S.Num.I(result.Get("rubble", 0L))}, biomass {Biomass()}, runs {Runs()}");
        if (smoke) SmokeBanked(result);
    }

    // rampage_hud.gd pause(): the world stops under the menu.
    void OnPause()
    {
        // The press that closed the menu is not also a new pause, whichever of the menu and the run reads it first.
        if (pause != null || Time.frameCount == resumedFrame) return;
        game.Paused = true;
        pausedFrame = Time.frameCount;
        pause = StubPause.Show(Resume, () =>
        {
            Unpause();
            game.Sim.End("ended");  // rampage_hud.gd _end_now
        });
    }

    void Resume()
    {
        if (Time.frameCount == pausedFrame) return;  // the press that opened the menu is not also its cancel
        Unpause();
    }

    void Unpause()
    {
        if (pause != null) Destroy(pause.gameObject);
        pause = null;
        resumedFrame = Time.frameCount;
        game.Paused = false;
    }

    void ShowTree()
    {
        Pending = null;
        Action endless = Save.Get("demo_done", false) == true ? () => StartRampage(null, true) : (Action)null;
        // The tree's RAMPAGE goes back to the globe: the globe is the loop (D-463).
        Shown(State.Tree, StubTree.Show(Save, () => Enter(State.Globe), endless, () => Enter(State.Title)));
        Debug.Log($"flow: tree shown, biomass {Biomass()}, runs {Runs()}");
    }

    void Update()
    {
        if (standalone) return;
        Inputs.Poll();
        SettingsApply.Tick(game != null && game.Paused);
        // A rampage that failed to load shows its error; cancel leaves it.
        if (game != null && game.Error != null && Inputs.Cancel()) { Pending = null; Go(State.Title); return; }
        if (smoke) SmokeTick();
    }

    // ---- -flow-smoke ------------------------------------------------------------------------------------

    // Presses the button named `name` on the screen on show, as a click would.
    void Press(string name)
    {
        if (screen == null) throw new InvalidOperationException($"no screen on show in {Now}");
        foreach (KitButton b in screen.GetComponentsInChildren<KitButton>(true))
        {
            if (b.name != name) continue;
            if (!b.interactable) throw new InvalidOperationException($"button {name} is off in {Now}");
            Debug.Log($"flow: smoke presses {name} in {Now}");
            b.onClick.Invoke();
            return;
        }
        throw new InvalidOperationException($"no button {name} in {Now}");
    }

    void SmokeTick()
    {
        if (smokeOver) return;
        float waited = Time.realtimeSinceStartup - stateAt;
        if (waited > SMOKE_STUCK) { Fail($"stuck in {(gallery ? "the gallery" : Now.ToString())} for {waited:F0} s"); return; }
        if (pressed) return;
        try
        {
            if (gallery)
            {
                if (waited >= SMOKE_GALLERY) Pass("gallery on show");
                return;
            }
            if (waited < SMOKE_WAIT) return;
            switch (Now)
            {
                case State.Title: pressed = true; Press("NewKaiju"); break;
                case State.Globe: pressed = true; Press("Launch"); break;
                case State.Tree: pressed = true; Press("Rampage"); break;
                case State.Results:
                    pressed = true;
                    if (smokeRuns >= SMOKE_RUNS) Pass($"{smokeRuns} rampages, biomass {Biomass()}, runs {Runs()}");
                    else Press("Go");
                    break;
            }
        }
        catch (Exception e)
        {
            Fail(e.Message);
        }
    }

    // After each bank: the save in memory and the file on disk both hold what the rampages earned.
    static void SmokeBanked(S.GDict result)
    {
        smokeRuns++;
        smokeEarned += S.Num.I(result.Get("rubble", 0L));
        S.GDict disk = SaveFile.LoadGame();
        if (Biomass() != smokeEarned || Runs() != smokeRuns) Fail($"the save holds biomass {Biomass()} after {Runs()} runs, the rampages earned {smokeEarned} in {smokeRuns}");
        else if (S.Num.I(disk.Get("rubble", -1L)) != smokeEarned || S.Num.I(disk.Get("runs", -1L)) != smokeRuns) Fail($"slot {SaveFile.Slot} on disk holds biomass {S.Num.I(disk.Get("rubble", -1L))} after {S.Num.I(disk.Get("runs", -1L))} runs, not {smokeEarned} after {smokeRuns}");
    }

    static void SmokeLog(string text, string stack, LogType type)
    {
        if (type == LogType.Exception) Fail("exception: " + text);
    }

    static void Pass(string what)
    {
        if (smokeOver) return;
        Debug.Log("flow: smoke ok, " + what);
        smokeOver = true;
        Quit.Now();
    }

    // Outside the smoke run a failure is only what the log already says.
    static void Fail(string why)
    {
        if (!smoke || smokeOver) return;
        smokeOver = true;
        Debug.Log("flow: smoke FAILED " + why);
        Application.Quit(1);
    }
}
