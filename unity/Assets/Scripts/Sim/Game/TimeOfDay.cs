// Generated from sim/time_of_day.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class TimeOfDay : RefCounted
    {
        public static implicit operator TimeOfDay(Variant v) => (TimeOfDay)v.Obj;

        // Which time of day a rampage plays (D-145, director 2026-10-22: "the time of day will be
        // randomised each run (a toggle available in the options menu to set a fixed time if players
        // prefer)", "random but cannot do the same time of day twice in a row"). The times are
        // data/looks.json "times" "play" (a subset of "order", D-359); the player's setting is "" (Random,
        // the default) or one of them. A random pick draws from its own seeded stream by run number and
        // leaves out the time the last run played, so a save replays the same sequence. Pure: no Node, no
        // clock.
        // The setting that means a random time.
        public const string RANDOM = "";
        // The time of day for run number `run_index`: `setting` when it names a time, else a seeded pick
        // from the others than `last` (the last run's; "" or unknown leaves all of them in).

        public static string Pick(long runIndex, string last, string setting)
        {
            GArray<Variant> all = Content.PlayTimes();
            if (all.Has(setting))
            {
                return setting;
            }
            GArray<Variant> pool = all.Filter(new Callable(a_ =>
            {
                Variant id = a_[0];
                return Gd.Str(id) != last;
            }));
            if (pool.IsEmpty())
            {
                pool = all;
            }
            var rng = Seeds.Make("time_of_day", runIndex);
            return Gd.Str(pool[rng.RandiRange(0, pool.Size() - 1)]);
        }
        // The settings in the order the options button steps through: Random first, then each time.

        public static GArray<string> Settings()
        {
            GArray<string> @out = new GArray<string> { RANDOM };
            foreach (Variant id in Content.PlayTimes())
            {
                @out.Append(Gd.Str(id));
            }
            return @out;
        }
        // The setting after `setting` (wrapping); an unknown one counts as Random.

        public static string Next(string setting)
        {
            var all = Settings();
            return all[(Gd.Maxi(all.Find(setting), 0) + 1) % all.Size()];
        }
        // What the options menu shows for `setting` (data/looks.json "times" labels).

        public static string Label(string setting)
        {
            GDict times = Content.TimeTable();
            if ((setting == RANDOM || !(Content.Times().Has(setting))))
            {
                return Gd.Str(times["random_label"]);
            }
            GDict labels = times["labels"];
            return Gd.Str(labels[setting]);
        }
        // `setting` as the options file should keep it: a playable time or Random
        // (an old "night" is Random).

        public static string Clean(string setting)
        {
            return (Content.PlayTimes().Has(setting) ? setting : RANDOM);
        }
        // Whether the options menu has a choice to offer: more than one time may be played (D-359).

        public static bool HasChoice()
        {
            return Content.PlayTimes().Size() > 1;
        }

        void _InitFields()
        {
        }
        public TimeOfDay() { _InitFields(); }
    }
}
