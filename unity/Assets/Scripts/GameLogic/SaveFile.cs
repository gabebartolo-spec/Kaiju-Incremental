// Versioned saves in three slots, after autoload/save_file.gd function for function (and save_system.gd, which
// only forwards to the slot in play). Each slot is one file: species, rubble bank, upgrade levels, run history,
// the best rampage so far, the specimen number (K-01, +1 each time the kaiju dies) and the campaign.
// A save from a newer version is refused, never half-loaded; an older one is migrated.
// Not ported: the pre-slots save.json adoption (the Unity game starts from a fresh folder).
using System;
using System.Collections.Generic;
using Kaiju.Sim;

namespace Kaiju.Game
{
    // What one save slot holds, for the title's slot list (scenes/main.gd _slots()).
    public sealed class SlotInfo
    {
        public int Slot;
        // A file is there. A file that cannot be read (corrupt, newer) is still taken: never shown as EMPTY.
        public bool Taken;
        public bool Readable;
        // This build can continue it (Demo.Continues); false also when it is not readable.
        public bool Continues;
        // "SPECIMEN K-04", translated; "" when not readable.
        public string Specimen = "";
        // The species' name as data holds it (untranslated), and its id.
        public string Species = "";
        public string SpeciesId = "";
        public long Runs;
        public long Rubble;
        // "Reptilian, 3 rampages, 120 biomass", translated; "" when this build cannot continue it.
        public string Summary = "";
    }

    public static class SaveFile
    {
        public const string SlotPath = "save_slot_{0}.json";
        public const int Version = 6;
        // The results screen's records (personal bests, D-259): the best single rampage, per stat.
        public static readonly string[] BestKeys =
        {
            "rubble", "best_combo", "destruction", "toppled", "tallest_topple", "landmarks", "civilians", "tanks",
            "helis", "agents", "mechs",
        };
        // The rampage ends that count as the kaiju's death: killed, time's up (D-263) and End rampage.
        // Felling the whole city ("city_fallen") is not one.
        public static readonly string[] Deaths = { "defeated", "time", "ended" };

        // The slot the game is playing (1-based); the flow sets it when a slot is picked.
        public static int Slot = 1;
        // When >= 0, every FreshSeed() is this, so tests and unattended proofs play the same cities.
        public static long PinnedSeed = -1;
        // Player-facing text goes through the text table (Tr.T gives the key back until it is loaded).
        public static Func<string, string> Translate = Tr.T;
        // Where warnings go (the host may send them to the player log).
        public static Action<string> Warn = text => Console.Error.WriteLine(text);

        // How many save slots there are (data/tuning.json "save" "slots").
        public static int SlotCount() => (int)Num.I(Content.Section("save")["slots"]);

        // The slot's file name inside UserDir.
        public static string PathOf(int n) => string.Format(System.Globalization.CultureInfo.InvariantCulture, SlotPath, n);
        public static string PathOf() => PathOf(Slot);

        public static bool HasSave(int n) => UserDir.Exists(PathOf(n));
        public static bool HasSave() => HasSave(Slot);

        // False when the file could not be written (the slot then still holds what it held).
        public static bool SaveGame(GDict data, int n)
        {
            GDict payload = data.Duplicate(true);
            payload["version"] = (long)Version;
            if (UserDir.WriteText(PathOf(n), Json.Stringify(payload, "\t")))
            {
                return true;
            }
            Warn("SaveSystem: cannot write " + PathOf(n));
            return false;
        }
        public static bool SaveGame(GDict data) => SaveGame(data, Slot);

        // Empty when there is no file, or it cannot be read; the file is left as it is either way.
        public static GDict LoadGame(int n)
        {
            if (!HasSave(n))
            {
                return new GDict();
            }
            return Migrate(Json.ParseDict(UserDir.ReadText(PathOf(n))));
        }
        public static GDict LoadGame() => LoadGame(Slot);

        public static void DeleteSave(int n) => UserDir.Delete(PathOf(n));
        public static void DeleteSave() => DeleteSave(Slot);

        // Every slot emptied (tests start from nothing).
        public static void Wipe()
        {
            for (int n = 1; n <= SlotCount(); n++)
            {
                DeleteSave(n);
            }
        }

        // The slot written most recently among those holding a save that `keep` accepts, or 0.
        public static int LatestSlot(Func<GDict, bool> keep)
        {
            int best = 0;
            long bestTime = -1;
            for (int n = 1; n <= SlotCount(); n++)
            {
                if (!HasSave(n) || !keep(LoadGame(n)))
                {
                    continue;
                }
                long time = UserDir.ModifiedTicks(PathOf(n));
                if (time > bestTime)
                {
                    best = n;
                    bestTime = time;
                }
            }
            return best;
        }
        // What CONTINUE resumes: the newest save this build can continue (main.gd _continues).
        public static int LatestSlot() => LatestSlot(Demo.Continues);

        // A fresh save for a new kaiju of `speciesId`: specimen K-01. `citySeed` is the slot's own city seed
        // (D-263 "Different per save"): the flow draws it with FreshSeed(); 0 elsewhere.
        public static GDict NewSave(string speciesId, long citySeed = 0)
        {
            GDict save = new GDict
            {
                { "version", (long)Version },
                { "species", speciesId },
                { "seed", citySeed },
                { "rubble", 0L },
                { "levels", new GDict() },
                { "runs", 0L },
                { "best", new GDict() },
                { "city_seconds", 0.0 },
                { "demo", false },
                { "demo_done", false },
                { "totals", new GDict() },
                { "specimen", 1L },
                { "lab_card", false },
            };
            save.Merge(Campaign());
            return save;
        }

        // The campaign keys a new save starts with (D-418 to D-422): continent ids conquered, in order; the bonus
        // id picked for each; the global Threat, 0 to 100; and the noise log, one entry per mission.
        public static GDict Campaign()
        {
            return new GDict
            {
                { "conquered", Gd.Arr() },
                { "bonuses", new GDict() },
                { "threat", 0.0 },
                { "noise_log", Gd.Arr() },
            };
        }

        // A new save's city seed: random per save (32 bits, as Godot's randi), or PinnedSeed when pinned.
        public static long FreshSeed()
        {
            if (PinnedSeed >= 0)
            {
                return PinnedSeed;
            }
            byte[] bytes = Guid.NewGuid().ToByteArray(); // seed-ok: a new run's seed is picked here, then logged
            return BitConverter.ToUInt32(bytes, 0);
        }

        // The specimen's name, e.g. "SPECIMEN K-01" (the number goes up when the kaiju dies).
        public static string SpecimenName(GDict save)
        {
            return Gd.Format(Translate("SPECIMEN K-%02d"), Gd.Arr(Num.I(save.Get("specimen", 1L))));
        }

        // After a rampage `result`: every death (Deaths, Endless too) makes the next rise a new specimen, one
        // number up, and owes the lab card before it rises. True when the number moved.
        public static bool NoteEnd(GDict save, GDict result)
        {
            if (Array.IndexOf(Deaths, Gd.Str(result.Get("reason", ""))) < 0)
            {
                return false;
            }
            save["specimen"] = Num.I(save.Get("specimen", 1L)) + 1;
            save["lab_card"] = true;
            return true;
        }

        // True (once) when the next rise owes the lab card: the flag is cleared here. A save from before the flag
        // existed owes none.
        public static bool TakeLabCard(GDict save)
        {
            if (save.Get("lab_card", false) != true)
            {
                return false;
            }
            save["lab_card"] = false;
            return true;
        }

        // Brings an older save up to Version. v1 kept only "best_destruction"; v2 keeps a "best" record per stat;
        // v3 drops the nodes tuning "save" "refunds" names (D-135) and gives their rubble back; v4 adds the demo
        // keys; v5 adds the specimen number; v6 adds the campaign keys, empty.
        // Unknown or newer versions are refused (empty), never guessed at.
        public static GDict Migrate(GDict data)
        {
            long version = Num.I(data.Get("version", 0L));
            if (version > Version || version < 1)
            {
                Warn("SaveSystem: save version " + version + " not supported");
                return new GDict();
            }
            GDict @out = data.Duplicate(true);
            if (version == 1)
            {
                @out["best"] = new GDict { { "destruction", Num.F(@out.Get("best_destruction", 0.0)) } };
                @out.Erase("best_destruction");
            }
            if (version < 3)
            {
                RefundCutNodes(@out);
            }
            if (!@out.Has("city_seconds"))
            {
                @out["city_seconds"] = 0.0; // rampage time in the adolescent city (D-160)
            }
            if (version < 4) // v4: demo marker, thanks seen, demo rampage totals (Demo.Add)
            {
                @out["demo"] = @out.Get("demo", false);
                @out["demo_done"] = @out.Get("demo_done", false);
                @out["totals"] = @out.Get("totals", new GDict());
            }
            if (version < 5) // v5: the specimen number lives in the slot
            {
                @out["specimen"] = Num.I(@out.Get("specimen", 1L));
            }
            if (version < 6) // v6: the campaign (D-418 to D-422), empty for a kaiju from before it
            {
                GDict campaign = Campaign();
                foreach (Variant key in campaign)
                {
                    if (!@out.Has(key))
                    {
                        @out[key] = campaign[key];
                    }
                }
            }
            @out["version"] = (long)Version;
            return @out;
        }

        // Removes every owned node tuning "save" "refunds" lists and banks its refund per level.
        static void RefundCutNodes(GDict save)
        {
            GDict refunds = Content.Section("save")["refunds"];
            if (!(save.Get("levels", default(Variant)).Obj is GDict levels))
            {
                return;
            }
            foreach (Variant id in refunds)
            {
                if (levels.Has(id))
                {
                    save["rubble"] = Num.I(save.Get("rubble", 0L)) + Num.I(refunds[id]) * Num.I(levels[id]);
                    levels.Erase(id);
                }
            }
        }

        // The best record after a rampage `result`, keeping the higher of each stat.
        public static GDict MergeBest(GDict best, GDict result)
        {
            GDict @out = best.Duplicate();
            foreach (string key in BestKeys)
            {
                if (result.Has(key))
                {
                    @out[key] = Gd.Maxf(Num.F(@out.Get(key, 0.0)), Num.F(result[key]));
                }
            }
            return @out;
        }

        // Banks a rampage `result` into `save` (the flow and the globe's cities share it): every death makes the
        // next rise a new specimen (NoteEnd, Endless too); a normal rampage adds its biomass, one run, the
        // Taskforce's clock, the best record and, in the demo, the thanks screen's totals. Endless banks nothing
        // else. Returns the best record before it ({} on a first rampage), for the results screen.
        public static GDict Bank(GDict save, GDict result, bool endless)
        {
            GDict previous = save.Get("best", default(Variant)).Obj as GDict ?? new GDict();
            if (Num.I(save.Get("runs", 0L)) == 0)
            {
                previous = new GDict();
            }
            NoteEnd(save, result);
            if (endless)
            {
                return previous;
            }
            save["rubble"] = Num.I(save.Get("rubble", 0L)) + Num.I(result.Get("rubble", 0L));
            save["runs"] = Num.I(save.Get("runs", 0L)) + 1;
            double clock = Num.F(save.Get("city_seconds", 0.0));
            save["city_seconds"] = Num.F(result.Get("city_seconds", clock)); // the Taskforce's clock
            save["best"] = MergeBest(previous, result);
            if (Demo.Enabled())
            {
                GDict totals = save.Get("totals", default(Variant)).Obj as GDict ?? new GDict();
                save["totals"] = Demo.Add(totals, result);
            }
            return previous;
        }

        // What Continue resumes, e.g. "Reptilian, 3 rampages, 120 biomass"; "" with no save (or a save this build
        // cannot continue). main.gd _summary().
        public static string Summary(GDict save)
        {
            if (!Demo.Continues(save))
            {
                return "";
            }
            long runs = Num.I(save.Get("runs", 0L));
            string line = Translate(runs == 1 ? "%s, %d rampage, %d biomass" : "%s, %d rampages, %d biomass");
            string who = Translate(SpeciesName(save));
            return Gd.Format(line, Gd.Arr(who, runs, Num.I(save.Get("rubble", 0L))));
        }

        // The save's species name as data holds it (untranslated).
        public static string SpeciesName(GDict save)
        {
            return Gd.Str(Content.SpeciesDef(Gd.Str(save.Get("species", "")))["name"]);
        }

        // What slot `n` holds, for the title's slot list.
        public static SlotInfo Info(int n)
        {
            GDict save = LoadGame(n);
            SlotInfo info = new SlotInfo { Slot = n, Taken = HasSave(n), Readable = !save.IsEmpty() };
            if (!save.IsEmpty())
            {
                info.Continues = Demo.Continues(save);
                info.Specimen = SpecimenName(save);
                info.Summary = Summary(save);
                info.Species = SpeciesName(save);
                info.SpeciesId = Gd.Str(save.Get("species", ""));
                info.Runs = Num.I(save.Get("runs", 0L));
                info.Rubble = Num.I(save.Get("rubble", 0L));
            }
            return info;
        }

        // Every slot, in order (main.gd _slots()).
        public static List<SlotInfo> Slots()
        {
            List<SlotInfo> @out = new List<SlotInfo>();
            for (int n = 1; n <= SlotCount(); n++)
            {
                @out.Add(Info(n));
            }
            return @out;
        }
    }
}
