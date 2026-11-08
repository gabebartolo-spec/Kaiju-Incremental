// Generated from sim/weather.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Weather : RefCounted
    {
        public static implicit operator Weather(Variant v) => (Weather)v.Obj;

        // Which weather a rampage plays (D-155, ROADMAP M1). Mirrors TimeOfDay: the weathers are
        // data/looks.json "weather" "order"; the player's setting is "" (Random, the default) or one of
        // them. A random pick draws from its own seeded stream by run number and leaves out the weather
        // the last run played, so a save replays the same sequence. Pure: no Node, no clock.
        // The pick is the run's one current weather, Content.weather_id() (set by Main when a rampage
        // starts); the sim only picks and remembers it, the view decides how it looks.
        // The setting that means a random weather.
        public const string RANDOM = "";
        // The weather for run number `run_index`: `setting` when it names one, else a seeded pick from
        // the others than `last` (the last run's; "" or unknown leaves all of them in).

        public static string Pick(long runIndex, string last, string setting)
        {
            GArray<Variant> all = Content.Weathers();
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
            var rng = Seeds.Make("weather", runIndex);
            return Gd.Str(pool[rng.RandiRange(0, pool.Size() - 1)]);
        }
        // The settings in the order the options button steps through: Random first, then each weather.

        public static GArray<string> Settings()
        {
            GArray<string> @out = new GArray<string> { RANDOM };
            foreach (Variant id in Content.Weathers())
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
        // What the options menu shows for `setting` (data/looks.json "weather" labels).

        public static string Label(string setting)
        {
            GDict table = Content.WeatherTable();
            if ((setting == RANDOM || !(Content.Weathers().Has(setting))))
            {
                return Gd.Str(table["random_label"]);
            }
            GDict labels = table["labels"];
            return Gd.Str(labels[setting]);
        }
        // `setting` as the options file should keep it: a known weather or Random.

        public static string Clean(string setting)
        {
            return (Content.Weathers().Has(setting) ? setting : RANDOM);
        }

        void _InitFields()
        {
        }
        public Weather() { _InitFields(); }
    }
}
