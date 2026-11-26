// loading_overlay.gd's first-load note (D-415): Godot shows "First load takes longer" while its facade bake has
// not run. Unity has no facade bake; its slow first load is the first one after a new build (shaders and caches
// warm up: about 29 s cold against 15 s warm, measured 2026-11-26). So a small file in the player's folder holds
// the build that last finished a load, and the note shows while it is missing or names another build.
namespace Kaiju.Game
{
    public static class FirstLoad
    {
        public const string FILE = "first_load_done";
        public const string NOTE = "First load takes longer (up to half a minute). Nothing is frozen.";

        // True while no load has finished on `build`.
        public static bool Pending(string build) => UserDir.ReadText(FILE).Trim() != build;

        // A load finished on `build`: later loads of it show no note. False when the file could not be written.
        public static bool Done(string build) => !Pending(build) || UserDir.WriteText(FILE, build);
    }
}
