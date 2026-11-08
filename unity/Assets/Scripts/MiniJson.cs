using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

// A small JSON reader: objects to Dictionary<string, object>, arrays to List<object>, numbers to double.
public static class MiniJson
{
    public static object Parse(string text)
    {
        int at = 0;
        return Value(text, ref at);
    }

    public static Dictionary<string, object> Obj(object o) => (Dictionary<string, object>)o;
    public static List<object> Arr(object o) => (List<object>)o;
    public static float F(object o) => (float)(double)o;
    public static int I(object o) => (int)(double)o;

    static void Skip(string s, ref int at)
    {
        while (at < s.Length && char.IsWhiteSpace(s[at])) at++;
    }

    static object Value(string s, ref int at)
    {
        Skip(s, ref at);
        char c = s[at];
        if (c == '{') return Object(s, ref at);
        if (c == '[') return Array(s, ref at);
        if (c == '"') return Str(s, ref at);
        if (c == 't') { at += 4; return true; }
        if (c == 'f') { at += 5; return false; }
        if (c == 'n') { at += 4; return null; }
        int start = at;
        while (at < s.Length && "+-0123456789.eE".IndexOf(s[at]) >= 0) at++;
        return double.Parse(s.Substring(start, at - start), CultureInfo.InvariantCulture);
    }

    static Dictionary<string, object> Object(string s, ref int at)
    {
        var d = new Dictionary<string, object>();
        at++;
        for (;;)
        {
            Skip(s, ref at);
            if (s[at] == '}') { at++; return d; }
            if (s[at] == ',') { at++; continue; }
            string key = Str(s, ref at);
            Skip(s, ref at);
            at++; // the colon
            d[key] = Value(s, ref at);
        }
    }

    static List<object> Array(string s, ref int at)
    {
        var a = new List<object>();
        at++;
        for (;;)
        {
            Skip(s, ref at);
            if (s[at] == ']') { at++; return a; }
            if (s[at] == ',') { at++; continue; }
            a.Add(Value(s, ref at));
        }
    }

    static string Str(string s, ref int at)
    {
        var b = new StringBuilder();
        at++;
        for (;;)
        {
            char c = s[at++];
            if (c == '"') return b.ToString();
            if (c != '\\') { b.Append(c); continue; }
            c = s[at++];
            switch (c)
            {
                case 'n': b.Append('\n'); break;
                case 't': b.Append('\t'); break;
                case 'r': b.Append('\r'); break;
                case 'b': b.Append('\b'); break;
                case 'f': b.Append('\f'); break;
                case 'u':
                    b.Append((char)Convert.ToInt32(s.Substring(at, 4), 16));
                    at += 4;
                    break;
                default: b.Append(c); break;
            }
        }
    }
}
