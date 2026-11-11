// The JSON writer the sim runtime lacks (it only reads): Godot's JSON.stringify for saves and settings.
// Keys are sorted as Godot sorts them; a whole number prints as an integer, never "1.0" or "1E+12", so a bank
// reads back as the same number. Reading stays S.JSON.ParseString.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using Kaiju.Sim;

namespace Kaiju.Game
{
    public static class Json
    {
        // Past this a double holds no fraction and a long cannot hold it either.
        const double WholeLimit = 9.0e18;

        public static string Stringify(Variant value, string indent = "\t", bool sortKeys = true)
        {
            StringBuilder s = new StringBuilder();
            Write(s, value, indent ?? "", 0, sortKeys);
            return s.ToString();
        }

        // Parses without throwing: a file that is not JSON gives nil (Godot's JSON.parse_string gives null).
        public static Variant Parse(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return default;
            try
            {
                return JSON.ParseString(text);
            }
            catch (Exception e) when (e is FormatException || e is IndexOutOfRangeException || e is ArgumentException)
            {
                return default;
            }
        }

        // The object in `text`, or an empty dictionary when it is not one.
        public static GDict ParseDict(string text)
        {
            Variant parsed = Parse(text);
            return parsed.Obj is GDict d ? d : new GDict();
        }

        static void Write(StringBuilder s, Variant v, string indent, int depth, bool sortKeys)
        {
            if (v.Obj is GDict d)
            {
                Dict(s, d, indent, depth, sortKeys);
            }
            else if (v.Obj is IGArray a)
            {
                if (a.Size() == 0) { s.Append("[]"); return; }
                s.Append('[');
                for (long i = 0; i < a.Size(); i++)
                {
                    if (i > 0) s.Append(',');
                    Line(s, indent, depth + 1);
                    Write(s, a.GetVariant(i), indent, depth + 1, sortKeys);
                }
                Line(s, indent, depth);
                s.Append(']');
            }
            else if (v.Type == Gd.TYPE_NIL) s.Append("null");
            else if (v.Type == Gd.TYPE_BOOL) s.Append((bool)v ? "true" : "false");
            else if (v.Type == Gd.TYPE_INT) s.Append(((long)v).ToString(CultureInfo.InvariantCulture));
            else if (v.Type == Gd.TYPE_FLOAT) s.Append(Number((double)v));
            else Text(s, Gd.Str(v));
        }

        static void Dict(StringBuilder s, GDict d, string indent, int depth, bool sortKeys)
        {
            if (d.IsEmpty()) { s.Append("{}"); return; }
            List<Variant> keys = new List<Variant>();
            foreach (Variant key in d) keys.Add(key);
            if (sortKeys) keys.Sort((a, b) => string.CompareOrdinal(Gd.Str(a), Gd.Str(b)));
            s.Append('{');
            for (int i = 0; i < keys.Count; i++)
            {
                if (i > 0) s.Append(',');
                Line(s, indent, depth + 1);
                Text(s, Gd.Str(keys[i]));
                s.Append(indent.Length > 0 ? ": " : ":");
                Write(s, d[keys[i]], indent, depth + 1, sortKeys);
            }
            Line(s, indent, depth);
            s.Append('}');
        }

        static void Line(StringBuilder s, string indent, int depth)
        {
            if (indent.Length == 0) return;
            s.Append('\n');
            for (int i = 0; i < depth; i++) s.Append(indent);
        }

        // A whole value as an integer; a fraction as the shortest text the reader turns back into the same bits.
        public static string Number(double v)
        {
            if (double.IsNaN(v) || double.IsInfinity(v)) return "0";
            if (v == Math.Floor(v) && Math.Abs(v) < WholeLimit) return ((long)v).ToString(CultureInfo.InvariantCulture);
            string shortest = v.ToString("R", CultureInfo.InvariantCulture);
            if (Strtod.Parse(shortest) == v) return shortest;
            // Godot's reader is not correctly rounded, so the shortest text can land one bit off: try the long one.
            string full = v.ToString("G17", CultureInfo.InvariantCulture);
            return Strtod.Parse(full) == v ? full : shortest;
        }

        static void Text(StringBuilder s, string text)
        {
            s.Append('"');
            foreach (char c in text)
            {
                switch (c)
                {
                    case '"': s.Append("\\\""); break;
                    case '\\': s.Append("\\\\"); break;
                    case '\n': s.Append("\\n"); break;
                    case '\t': s.Append("\\t"); break;
                    case '\r': s.Append("\\r"); break;
                    case '\b': s.Append("\\b"); break;
                    case '\f': s.Append("\\f"); break;
                    default:
                        if (c < ' ') s.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                        else s.Append(c);
                        break;
                }
            }
            s.Append('"');
        }
    }
}
