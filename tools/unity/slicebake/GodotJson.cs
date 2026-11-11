// Godot's JSON.stringify(data, " ") (core/io/json.cpp), so the bake's JSON is Godot's text: keys
// sorted, floats at 14 significant digits with trailing zeros cut (but at least "x.0"), ints bare.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;
using Kaiju.Sim;

static class GodotJson
{
    const string Indent = " ";

    public static string Stringify(Variant v)
    {
        var b = new StringBuilder();
        Write(b, v, 0);
        return b.ToString();
    }

    static void Write(StringBuilder b, Variant v, int depth)
    {
        switch (v.Type)
        {
            case Gd.TYPE_NIL: b.Append("null"); return;
            case Gd.TYPE_BOOL: b.Append((bool)v ? "true" : "false"); return;
            case Gd.TYPE_INT: b.Append(((long)v).ToString(CultureInfo.InvariantCulture)); return;
            case Gd.TYPE_FLOAT: b.Append(Float((double)v)); return;
            case Gd.TYPE_STRING: b.Append('"').Append(Escape((string)v)).Append('"'); return;
        }
        if (v.Obj is GDict d)
        {
            if (d.Size() == 0) { b.Append("{}"); return; }
            var keys = new List<string>();
            var byName = new Dictionary<string, Variant>();
            foreach (Variant k in d)
            {
                string name = Gd.Str(k);
                keys.Add(name);
                byName[name] = d[k];
            }
            keys.Sort(string.CompareOrdinal);
            b.Append("{\n");
            for (int i = 0; i < keys.Count; i++)
            {
                if (i > 0) b.Append(",\n");
                Pad(b, depth + 1);
                b.Append('"').Append(Escape(keys[i])).Append("\": ");
                Write(b, byName[keys[i]], depth + 1);
            }
            b.Append('\n');
            Pad(b, depth);
            b.Append('}');
            return;
        }
        if (v.Obj is IGArray a)
        {
            long n = a.Size();
            if (n == 0) { b.Append("[]"); return; }
            b.Append("[\n");
            for (long i = 0; i < n; i++)
            {
                if (i > 0) b.Append(",\n");
                Pad(b, depth + 1);
                Write(b, a.GetVariant(i), depth + 1);
            }
            b.Append('\n');
            Pad(b, depth);
            b.Append(']');
            return;
        }
        throw new InvalidOperationException("GodotJson: no writer for variant type " + v.Type);
    }

    static void Pad(StringBuilder b, int depth)
    {
        for (int i = 0; i < depth; i++) b.Append(Indent);
    }

    // json.cpp: exactly 0 is "0.0"; else 14 significant digits (String::num with that many decimals,
    // trailing zeros cut), and a whole number keeps ".0".
    public static string Float(double num)
    {
        if (num == 0.0) return "0.0";
        if (double.IsNaN(num)) return "NaN";
        if (double.IsInfinity(num)) return num > 0 ? "inf" : "-inf";
        double magnitude = Math.Log10(Math.Abs(num));
        int precision = Math.Max(1, 14 - (int)Math.Floor(magnitude));
        string s = num.ToString("F" + precision, CultureInfo.InvariantCulture);
        if (s.IndexOf('.') >= 0)
        {
            int end = s.Length;
            while (end > 0 && s[end - 1] == '0') end--;
            if (end > 0 && s[end - 1] == '.') end--;
            s = s.Substring(0, end);
        }
        if (s.IndexOf('.') < 0 && s.IndexOf('e') < 0) s += ".0";
        return s;
    }

    static string Escape(string s) => s
        .Replace("\\", "\\\\").Replace("\b", "\\b").Replace("\f", "\\f").Replace("\n", "\\n")
        .Replace("\r", "\\r").Replace("\t", "\\t").Replace("\v", "\\v").Replace("\"", "\\\"");
}
