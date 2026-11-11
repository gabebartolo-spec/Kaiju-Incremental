// The text table (data/i18n/strings.csv, D-392): the English text is the key, each other column one language.
// Godot's TranslationServer did this; here it is one dictionary per language. Plain C#, no engine.
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace Kaiju.Game
{
    public static class Tr
    {
        // The language every T() reads ("en", "es", ... "zh_CN"); PlayerSettings.ApplyLanguage sets it.
        public static string Language = "en";

        static readonly Dictionary<string, Dictionary<string, string>> tables = new Dictionary<string, Dictionary<string, string>>();
        static string[] header = new string[0];

        // The language codes the loaded file has, in column order.
        public static IReadOnlyList<string> Languages
        {
            get
            {
                List<string> o = new List<string>();
                for (int i = 1; i < header.Length; i++) o.Add(header[i]);
                return o;
            }
        }

        // How many keys the loaded file has.
        public static int Count { get; private set; }

        // Reads the whole CSV: the first row names the columns ("keys", then one locale each).
        public static void Load(string csvText)
        {
            tables.Clear();
            Count = 0;
            List<string[]> rows = Parse(csvText);
            header = rows.Count > 0 ? rows[0] : new string[0];
            for (int c = 1; c < header.Length; c++) tables[header[c]] = new Dictionary<string, string>();
            for (int r = 1; r < rows.Count; r++)
            {
                string[] row = rows[r];
                if (row.Length == 0 || row[0].Length == 0) continue;
                Count++;
                for (int c = 1; c < header.Length && c < row.Length; c++)
                {
                    // An empty cell is no translation: the key shows instead (as Godot's importer leaves it out).
                    if (row[c].Length > 0) tables[header[c]][row[0]] = row[c];
                }
            }
        }

        // The text in the language in use; the key itself when the language or the row has none.
        public static string T(string key)
        {
            return T(key, Language);
        }

        public static string T(string key, string language)
        {
            if (key == null) return "";
            if (language != null && tables.TryGetValue(language, out Dictionary<string, string> table)
                && table.TryGetValue(key, out string text))
            {
                return text;
            }
            return key;
        }

        // T(key) with GDScript's % filled in: %d, %s, %f (with 0, width and .precision) and %%.
        public static string F(string key, params object[] args)
        {
            return Format(T(key), args);
        }

        // GDScript's "text" % [args] for the forms the game's strings use.
        public static string Format(string text, params object[] args)
        {
            StringBuilder b = new StringBuilder();
            int next = 0;
            for (int i = 0; i < text.Length; i++)
            {
                char c = text[i];
                if (c != '%' || i + 1 >= text.Length) { b.Append(c); continue; }
                int at = i + 1;
                if (text[at] == '%') { b.Append('%'); i = at; continue; }
                bool plus = false, zero = false, left = false;
                for (; at < text.Length && (text[at] == '+' || text[at] == '0' || text[at] == '-'); at++)
                {
                    if (text[at] == '+') plus = true;
                    else if (text[at] == '0') zero = true;
                    else left = true;
                }
                int width = 0, precision = -1;
                for (; at < text.Length && char.IsDigit(text[at]); at++) width = width * 10 + (text[at] - '0');
                if (at < text.Length && text[at] == '.')
                {
                    precision = 0;
                    for (at++; at < text.Length && char.IsDigit(text[at]); at++) precision = precision * 10 + (text[at] - '0');
                }
                char kind = at < text.Length ? text[at] : '\0';
                if (kind != 'd' && kind != 's' && kind != 'f') { b.Append(c); continue; } // not a slot: shown as written
                object arg = args != null && next < args.Length ? args[next] : null;
                next++;
                string shown;
                if (kind == 'd') shown = Whole(arg, plus);
                else if (kind == 'f') shown = Number(arg).ToString("F" + (precision < 0 ? 6 : precision), CultureInfo.InvariantCulture);
                else shown = Str(arg);
                if (kind == 'f' && plus && Number(arg) >= 0) shown = "+" + shown;
                if (shown.Length < width)
                {
                    if (left) shown = shown.PadRight(width);
                    else if (zero && kind != 's')
                    {
                        bool signed = shown.Length > 0 && (shown[0] == '-' || shown[0] == '+');
                        shown = signed ? shown[0] + shown.Substring(1).PadLeft(width - 1, '0') : shown.PadLeft(width, '0');
                    }
                    else shown = shown.PadLeft(width);
                }
                b.Append(shown);
                i = at;
            }
            return b.ToString();
        }

        static string Whole(object arg, bool plus)
        {
            long n = (long)Number(arg); // %d cuts a float toward zero, as GDScript does
            string s = n.ToString(CultureInfo.InvariantCulture);
            return plus && n >= 0 ? "+" + s : s;
        }

        static double Number(object arg)
        {
            switch (arg)
            {
                case null: return 0;
                case bool flag: return flag ? 1 : 0;
                case string s: return double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out double v) ? v : 0;
                case Kaiju.Sim.Variant variant: return Kaiju.Sim.Num.F(variant);
                case System.IConvertible n: return n.ToDouble(CultureInfo.InvariantCulture);
                default: return 0;
            }
        }

        static string Str(object arg)
        {
            switch (arg)
            {
                case null: return "";
                case string s: return s;
                case Kaiju.Sim.Variant variant: return Kaiju.Sim.Gd.Str(variant);
                case double d: return Kaiju.Sim.Gd.Str(d);
                case float f: return Kaiju.Sim.Gd.Str((double)f);
                case bool flag: return flag ? "true" : "false";
                case System.IFormattable n: return n.ToString(null, CultureInfo.InvariantCulture);
                default: return arg.ToString();
            }
        }

        // Every row of a CSV as its cells: a quoted cell may hold commas, line breaks and "" for one quote.
        public static List<string[]> Parse(string csvText)
        {
            List<string[]> rows = new List<string[]>();
            if (string.IsNullOrEmpty(csvText)) return rows;
            int at = csvText[0] == '﻿' ? 1 : 0;
            List<string> row = new List<string>();
            StringBuilder cell = new StringBuilder();
            bool quoted = false, any = false;
            for (; at < csvText.Length; at++)
            {
                char c = csvText[at];
                if (quoted)
                {
                    if (c != '"') { cell.Append(c); continue; }
                    if (at + 1 < csvText.Length && csvText[at + 1] == '"') { cell.Append('"'); at++; }
                    else quoted = false;
                    continue;
                }
                if (c == '"') { quoted = true; any = true; }
                else if (c == ',') { row.Add(cell.ToString()); cell.Clear(); any = true; }
                else if (c == '\n' || c == '\r')
                {
                    if (c == '\r' && at + 1 < csvText.Length && csvText[at + 1] == '\n') at++;
                    // A blank line is no row.
                    if (any || cell.Length > 0) { row.Add(cell.ToString()); rows.Add(row.ToArray()); }
                    row.Clear();
                    cell.Clear();
                    any = false;
                }
                else cell.Append(c);
            }
            if (any || cell.Length > 0) { row.Add(cell.ToString()); rows.Add(row.ToArray()); }
            return rows;
        }
    }
}
