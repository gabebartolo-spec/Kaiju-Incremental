// The one save from before slots (save_file.gd LEGACY_PATH, adopt_legacy): moved into the first empty slot,
// migrated, and kept beside it as a backup. Every HasSave looks for it first, as Godot's has_save does.
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static partial class SaveFile
    {
        // The single save from before slots (v4 and older); adopted into a slot on first use.
        public const string LegacyPath = "save.json";
        // Where the legacy file is kept once a slot holds it: renamed, never deleted.
        public const string LegacyBackup = "save.json.pre_slots";

        static void WipeLegacy()
        {
            UserDir.Delete(LegacyPath);
            UserDir.Delete(LegacyBackup);
        }

        // Moves the pre-slots save into the first empty slot, migrated to Version. The old file is renamed to
        // LegacyBackup first (a stale backup is removed), and only once that worked is the slot written, so it is
        // adopted exactly once; a failed write renames it back. Leaves it untouched when it cannot be read or no
        // slot is empty, so nothing is ever lost (save_file.gd adopt_legacy).
        public static void AdoptLegacy()
        {
            if (!UserDir.Exists(LegacyPath)) return;
            int target = 0;
            for (int n = 1; n <= SlotCount(); n++)
            {
                if (!UserDir.Exists(PathOf(n)))
                {
                    target = n;
                    break;
                }
            }
            if (target == 0) return;
            GDict data = Migrate(Json.ParseDict(UserDir.ReadText(LegacyPath)));
            if (data.IsEmpty()) return;
            if (UserDir.Exists(LegacyBackup))
            {
                UserDir.Delete(LegacyBackup);
                if (UserDir.Exists(LegacyBackup)) return;
            }
            if (!UserDir.Rename(LegacyPath, LegacyBackup)) return;
            SaveGame(data, target);
            if (!UserDir.Exists(PathOf(target))) UserDir.Rename(LegacyBackup, LegacyPath);
        }
    }
}
