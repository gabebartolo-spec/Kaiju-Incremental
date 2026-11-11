// Kaiju Creation's logic (Assets/Scripts/GameLogic/Creation*.cs) against Godot's: scenes/creation_rack.gd,
// kaiju_creation.gd, creation_lab.gd, creation_injector.gd and specimen_card.gd, read line by line, on the data
// files. Each expectation below names the Godot line or data row it comes from.
using System;
using System.Collections.Generic;
using Kaiju.Game;
using Kaiju.Sim;

static class CreationCheck
{
    const double EPS = 1e-6;

    static int checks, failed;

    public static int Run(string repoRoot)
    {
        FileAccess.Root = repoRoot;
        checks = failed = 0;
        Rack();
        Steps();
        Injector();
        Card();
        Console.WriteLine($"creation: {checks} checks, {failed} failed");
        return failed;
    }

    static void Check(bool ok, string what)
    {
        checks++;
        if (ok) return;
        failed++;
        Console.WriteLine("FAIL creation: " + what);
    }

    static void Near(double got, double want, string what)
    {
        Check(Math.Abs(got - want) < EPS, $"{what} is {got}, Godot gives {want}");
    }

    // creation_rack.gd: data/tuning.json creation.titans is croc (reptilian, unlocked), komodo and serpent (no
    // species yet, locked until conquests).
    static void Rack()
    {
        List<CreationTitan> all = CreationRack.Titans(new GDict());
        Check(all.Count == 3, $"{all.Count} titans, data has 3");
        if (all.Count < 3) return;
        Check(all[0].Id == "croc" && all[0].Name == "CROC" && all[0].Species == "reptilian" && all[0].Genome == "6f8a3e", "the first titan is not the croc as data writes it");
        Check(!all[0].Locked && all[0].Selectable, "the croc is locked or not selectable on a new save");
        Check(all[1].Id == "komodo" && all[1].Locked && !all[1].Selectable, "the komodo is not locked on a new save");
        Check(all[2].Id == "serpent" && all[2].Locked && !all[2].Selectable, "the serpent is not locked on a new save");
        // titans(): unlocked by the save's titans_unlocked, but with no species there is nothing to play.
        var save = new GDict { { "titans_unlocked", Gd.Arr("komodo", "serpent") } };
        all = CreationRack.Titans(save);
        Check(!all[1].Locked && !all[1].Selectable, "an unlocked komodo with no species is locked or selectable");
        // shown() (D-454): only the unlocked and playable, so the croc alone either way.
        Check(CreationRack.Shown(new GDict()).Count == 1 && CreationRack.Shown(new GDict())[0].Id == "croc", "a new save's rack does not show the croc alone");
        Check(CreationRack.Shown(save).Count == 1, "a save with every titan unlocked shows more than the croc");
        Check(CreationRack.Shown(null).Count == 1, "no save shows no croc");
    }

    static string Joined(List<string> cues) => string.Join(",", cues);

    // kaiju_creation.gd, the whole screen from the rack to `created`.
    static void Steps()
    {
        var s = new CreationSteps(new GDict());
        // _ready: timing place_s 4.2, inject_s 3.0, takeover_s 2.0, zoom_s 0.9, black_s 1.9 at 60 ticks a second.
        Check(s.Ticks(CreationStep.Place) == 252 && s.Ticks(CreationStep.Inject) == 180 && s.Ticks(CreationStep.Takeover) == 120
            && s.Ticks(CreationStep.Zoom) == 54 && s.Ticks(CreationStep.Black) == 114, "the steps' tick counts are not 252, 180, 120, 54, 114");
        Check(s.Ticks(CreationStep.Rack) == 0 && s.Ticks(CreationStep.Dish) == 0, "the rack or the dish runs on a timer");
        // _ready: the room's loops start with the screen.
        Check(Joined(s.Cues) == "lab_room,lab_screens", $"the opening cues are {Joined(s.Cues)}");
        Check(s.Sounds.Count == 2 && s.Sounds[0].What == CreationSound.Kind.Loop, "the room's sounds are not loops");
        Check(s.Step == CreationStep.Rack && s.CanBack, "the screen does not open on the rack with BACK live");
        // _physics_process: nothing moves on the rack; _on_inject is dead before the dish.
        s.Tick();
        s.Inject();
        Check(s.Step == CreationStep.Rack, "the rack moved on without a pick");
        s.Pick(5);
        Check(s.Step == CreationStep.Rack, "a pick off the rack's end was taken");
        s.Pick(0);
        Check(s.Step == CreationStep.Place && s.Picked == 0 && !s.CanBack, "the pick did not start the pour, or BACK is live in it");
        Check(s.Cues[s.Cues.Count - 1] == "lab_latch", "the pick does not play sounds.pick");
        s.Pick(0);
        Check(s.Cues.Count == 3, "a second pick was taken");
        for (int i = 0; i < 251; i++) s.Tick();
        Check(s.Step == CreationStep.Place, "the pour ended before its 252 ticks");
        s.Tick();
        Check(s.Step == CreationStep.Dish && s.CanBack, "the pour did not end on the dish with BACK live");
        // _trip_cue with sounds.trip {1: lab_arm, 3: lab_drawup, 5: lab_arm, 7: lab_dispense}.
        Check(Joined(s.Cues) == "lab_room,lab_screens,lab_latch,lab_arm,lab_drawup,lab_arm,lab_dispense", $"the pour's cues are {Joined(s.Cues)}");
        // creation_lab.gd place: the vial is drained, the barrel emptied into the dish, the gene settled.
        Near(s.Lab.Vials[0], 0.0, "the picked vial's level after the pour");
        Near(s.Lab.Barrel, 0.0, "the barrel's level after the pour");
        Near(s.Lab.Settle, 1.0, "the gene's settle after the pour");
        Check(!s.Lab.BarrelIsSpecialK, "the barrel held Special K during the pour");
        for (int i = 0; i < 10; i++) s.Tick();
        Check(s.Step == CreationStep.Dish, "the dish moved on without the injection");
        s.Inject();
        Check(s.Step == CreationStep.Inject && !s.CanBack, "INJECT did not start the injection, or BACK is live in it");
        for (int i = 0; i < 180; i++) s.Tick();
        Check(s.Step == CreationStep.Takeover, "the injection did not end in the takeover after 180 ticks");
        // inject trip shares end [.., 0.19, 0, 0]: no dispense phase, so no lab_dispense; _begin(TAKEOVER) strikes.
        Check(Joined(s.Cues).EndsWith("lab_dispense,lab_arm,lab_drawup,lab_arm,lab_strike,lab_crackle"), $"the injection's cues are {Joined(s.Cues)}");
        // creation_lab.gd inject: canister_draw 0.4 of the canister goes, the barrel is full.
        Near(s.Lab.SpecialK, 0.6, "the canister's level after the draw");
        Near(s.Lab.Barrel, 1.0, "the barrel's level before the strike");
        Check(s.Lab.BarrelIsSpecialK, "the barrel does not hold Special K at the strike");
        Near(s.Lab.Tip.y, 0.135, "the needle's depth at the strike (dish_tip)");
        // creation_lab.gd takeover _hit: flash_ticks 6, full on the first tick.
        s.Tick();
        Near(s.Lab.Flash, 1.0, "the strike's flash on its first tick");
        s.Tick();
        Near(s.Lab.Flash, 5.0 / 6.0, "the strike's flash on its second tick");
        // shake 0.02 m: sin(1 * 2.3) * 0.02 * (1 - 1 / (0.33 * 60)).
        Near(s.Lab.ShakeX, Math.Sin(2.3) * 0.02 * (1.0 - 1.0 / (0.33 * 60.0)), "the camera's shake on the second tick");
        for (int i = 0; i < 5; i++) s.Tick();
        Near(s.Lab.Flash, 0.0, "the flash after its 6 ticks");
        // _overload_cue: overload_lead_s 0.3 of takeover_s 2.0 before overload_at 0.85, so about tick 84.
        for (int i = 7; i < 82; i++) s.Tick();
        Check(!s.Cues.Contains("lab_overload"), "the overload sounded before its lead");
        for (int i = 0; i < 4; i++) s.Tick();
        Check(s.Cues[s.Cues.Count - 1] == "lab_overload", "the overload did not sound 0.3 s before the second hit-stop");
        Check(s.Sounds.Exists(c => c.What == CreationSound.Kind.Stop && c.Id == "lab_crackle"), "the crackle is not stopped at the overload");
        // overload_at 0.85 of 120 ticks: the second hit-stop flashes on tick 102.
        for (int i = 86; i < 101; i++) s.Tick();
        Near(s.Lab.Flash, 0.0, "the flash before the overload");
        s.Tick();
        Near(s.Lab.Flash, 1.0, "the overload's flash on tick 102");
        for (int i = 102; i < 120; i++) s.Tick();
        Check(s.Step == CreationStep.Zoom, "the takeover did not end in the zoom after 120 ticks");
        Near(s.Lab.Barrel, 0.0, "the barrel after the takeover");
        Near(s.Lab.Tip.y, 0.3, "the needle's park height after the takeover (park_tip)");
        Check(s.Cues[s.Cues.Count - 1] == "lab_dive", "the zoom does not play sounds.dive");
        // zoom: black_from 0.99, so the screen is clear until the last tick; lab.zoom clears the flash.
        for (int i = 0; i < 53; i++) s.Tick();
        Near(s.Black, 0.0, "the black one tick before the zoom's end");
        Near(s.Lab.Flash, 0.0, "the flash in the zoom");
        s.Sounds.Clear();
        s.Tick();
        Check(s.Step == CreationStep.Black, "the zoom did not end in the black after 54 ticks");
        Near(s.Black, 1.0, "the black");
        // lab.camera to lab.zoom: position, look and fov at the zoom's end.
        Near(s.Lab.CameraAt.x, 0.049, "the camera's x at the zoom's end");
        Near(s.Lab.CameraAt.y, 0.208, "the camera's y at the zoom's end");
        Near(s.Lab.CameraLook.y, 0.14, "the camera's look at the zoom's end");
        Near(s.Lab.CameraFov, 30.0, "the camera's fov at the zoom's end");
        // _begin(BLACK) stops the room and the one-shots; _advance cracks at once (cracks[0].at_s 0, from 0.5 for 0.25).
        Check(s.Sounds.Exists(c => c.What == CreationSound.Kind.Stop && c.Id == "lab_room") && s.Sounds.Exists(c => c.What == CreationSound.Kind.Stop && c.Id == "lab_dive"), "the room or the dive is not cut at the black");
        CreationSound crack = s.Sounds[s.Sounds.Count - 1];
        Check(crack.Id == "egg_crack" && crack.What == CreationSound.Kind.Play, "the egg does not crack as the black falls");
        Near(crack.From, 0.5, "the first crack's from_s");
        Near(crack.Len, 0.25, "the first crack's len_s");
        // cracks at_s 1.15 and 1.4: ticks 69 and 84 of the black.
        for (int i = 0; i < 68; i++) s.Tick();
        Check(s.Cues.FindAll(c => c == "egg_crack").Count == 1, "the second crack came before tick 69");
        s.Tick();
        Check(s.Cues.FindAll(c => c == "egg_crack").Count == 2, "the second crack did not come on tick 69");
        for (int i = 69; i < 83; i++) s.Tick();
        Check(s.Cues.FindAll(c => c == "egg_crack").Count == 2, "the third crack came before tick 84");
        s.Tick();
        Check(s.Cues.FindAll(c => c == "egg_crack").Count == 3, "the third crack did not come on tick 84");
        for (int i = 84; i < 113; i++) s.Tick();
        Check(s.Step == CreationStep.Black && s.Species == "", "the kaiju was made before the black's 114 ticks");
        s.Tick();
        // _advance: created.emit(titan.species).
        Check(s.Step == CreationStep.Done && s.Species == "reptilian", $"the screen ends in {s.Step} with '{s.Species}', want Done with reptilian");
        Check(Joined(s.Cues) == "lab_room,lab_screens,lab_latch,lab_arm,lab_drawup,lab_arm,lab_dispense,lab_arm,lab_drawup,lab_arm,lab_strike,lab_crackle,lab_overload,lab_dive,egg_crack,egg_crack,egg_crack", $"the cues are {Joined(s.Cues)}");
        int before = s.Cues.Count;
        s.Tick();
        Check(s.Step == CreationStep.Done && s.Cues.Count == before, "a tick after the end did something");
    }

    // creation_injector.gd trip and creation_lab.gd place / inject: the needle goes down into each source, then the dish.
    static void Injector()
    {
        GDict inj = CreationLab.Cfg()["injector"];
        var probe = new CreationLab(3);
        // _add_injector: the post stands a needle's reach from both the dish and the first vial.
        Near(probe.Post.FlatLength(), CreationLab.Reach(), "the post's distance from the dish");
        Near((CreationLab.VialPoint(0) - probe.Post).FlatLength(), CreationLab.Reach(), "the post's distance from the first vial");
        // reach(): tip [46, 26, 0] from pivot [-35, 0] at voxel 0.005.
        Near(CreationLab.Reach(), 81 * 0.005, "the needle's reach");
        // _add_canister: also a reach from the post.
        Near((probe.CanisterAt - probe.Post).FlatLength(), CreationLab.Reach(), "the canister's distance from the post");
        // _ready: parked over the dish at park_tip.
        Near(probe.Tip.x, 0.0, "the parked needle's x");
        Near(probe.Tip.z, 0.0, "the parked needle's z");
        Near(probe.Tip.y, Num.F(inj["park_tip"]), "the parked needle's height");
        // vials.titan_slots [2, 1, 0]: the croc fills the third vial.
        Check(CreationLab.VialOf(0) == 2 && CreationLab.VialOf(2) == 0, "the titans' vials are not titan_slots");
        for (int index = 0; index < 3; index++)
        {
            var lab = new CreationLab(3);
            CreationVec vial = CreationLab.VialPoint(index);
            // place shares: the draw is phase 3, t 0.34 to 0.5; the dispense is phase 7, t 0.83 to 0.93.
            lab.Place(index, 0.42);
            Near(lab.Tip.x, vial.x, $"the needle's x in vial {index}");
            Near(lab.Tip.z, vial.z, $"the needle's z in vial {index}");
            Near(lab.Tip.y, Num.F(inj["vial_tip"]), $"the needle's depth in vial {index}");
            Near(lab.Vials[index], 0.5, $"vial {index}'s level half way through the draw");
            Near(lab.Barrel, 0.5, $"the barrel's level half way through vial {index}'s draw");
            // _heights: the swing is max(vial_top, cradle_top, park_tip) + clear = 0.35 + 0.06.
            lab.Place(index, 0.6);
            Near(lab.Tip.y, 0.41, $"the swing height back from vial {index}");
            lab.Place(index, 0.88);
            Near(lab.Tip.x, 0.0, $"the needle's x in the dish from vial {index}");
            Near(lab.Tip.z, 0.0, $"the needle's z in the dish from vial {index}");
            Near(lab.Tip.y, Num.F(inj["dish_tip"]), $"the needle's depth in the dish from vial {index}");
            Near(lab.Settle, 0.5, $"the gene's settle half way through the dispense from vial {index}");
            lab.Place(index, 1.0);
            Near(lab.Tip.y, Num.F(inj["park_tip"]), $"the needle's park after vial {index}");
        }
        // inject shares: the draw is phase 3, t 0.38 to 0.54.
        var k = new CreationLab(1);
        k.Inject(0.46);
        Near(k.Tip.x, k.CanisterAt.x, "the needle's x in the canister");
        Near(k.Tip.z, k.CanisterAt.z, "the needle's z in the canister");
        Near(k.Tip.y, Num.F(inj["canister_tip"]), "the needle's depth in the canister");
        Near(k.SpecialK, 1.0 - 0.4 * 0.5, "the canister's level half way through the draw");
        // phase(): the shares' running sum.
        Check(CreationLab.Phase(0.0, "place") == 0 && CreationLab.Phase(0.1, "place") == 1 && CreationLab.Phase(0.42, "place") == 3
            && CreationLab.Phase(0.88, "place") == 7 && CreationLab.Phase(0.95, "place") == 8, "the place trip's phases are not its shares'");
        // lab.camera: the opening shot.
        Near(k.CameraAt.x, 0.55, "the camera's opening x");
        Near(k.CameraFov, 54.0, "the camera's opening fov");
    }

    // specimen_card.gd fill and the copy in data/tuning.json news.specimen, ui.specimen_card.
    static void Card()
    {
        Check(CreationCard.Fill("K-{lost} / K-{next}", 2) == "K-01 / K-02", "fill does not write two-digit numbers");
        Check(CreationCard.Fill("{lost}", 1) == "01", "the first specimen's lost number is not 01 (maxi(1, specimen - 1))");
        Check(CreationCard.Fill("{next}", 12) == "12", "a two-digit specimen is not written whole");
        Check(CreationCard.Title(2) == "SPECIMEN K-02", $"the title is '{CreationCard.Title(2)}'");
        Check(CreationCard.Headline(2) == "K-01 LOST - K-02 RELEASED", $"the headline is '{CreationCard.Headline(2)}'");
        Near(CreationCard.Seconds(), 2.0, "the card's seconds");
        Check(CreationCard.Gap() == 24, "the card's gap is not 24");
        Check(CreationCard.Specimen(new GDict { { "specimen", 3L } }) == 3 && CreationCard.Specimen(new GDict()) == 1, "the specimen is not the save's (1 with none)");
    }
}
