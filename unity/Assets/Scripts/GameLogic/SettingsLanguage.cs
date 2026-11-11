// Which of the game's languages is in use (autoload/settings_language.gd): the player's choice, else the system's.
using System.Collections.Generic;

namespace Kaiju.Game
{
    public static class SettingsLanguage
    {
        // Unity names its system language in English words; Godot gave a locale. Both are read.
        static readonly Dictionary<string, string> UnityNames = new Dictionary<string, string>
        {
            { "English", "en" }, { "Spanish", "es" }, { "French", "fr" }, { "Italian", "it" }, { "German", "de" },
            { "Russian", "ru" }, { "Chinese", "zh" }, { "ChineseSimplified", "zh" }, { "ChineseTraditional", "zh" },
        };

        // The language in use: the player's, else the system's when the game has it, else English.
        // `system` is a locale ("es_ES", "zh-TW") or Unity's SystemLanguage name ("Spanish").
        public static string Code(string system)
        {
            List<string> codes = Codes();
            if (codes.Contains(PlayerSettings.Language)) return PlayerSettings.Language;
            string sys = (system ?? "").Replace('-', '_');
            if (UnityNames.TryGetValue(sys, out string named)) sys = named;
            foreach (string each in codes)
            {
                // Any Chinese system gets Simplified Chinese, the only Chinese the game has.
                if (sys == each || Base(sys) == Base(each)) return each;
            }
            return "en";
        }

        // The name of the language in use, as its own speakers write it.
        public static string ShownName(string system)
        {
            return PlayerSettings.LANGUAGES[Codes().IndexOf(Code(system))][1];
        }

        public static List<string> Codes()
        {
            List<string> o = new List<string>();
            foreach (string[] row in PlayerSettings.LANGUAGES) o.Add(row[0]);
            return o;
        }

        static string Base(string locale)
        {
            int cut = locale.IndexOf('_');
            return cut < 0 ? locale : locale.Substring(0, cut);
        }
    }
}
