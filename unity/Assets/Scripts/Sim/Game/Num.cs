// Generated from sim/num.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Num : RefCounted
    {
        public static implicit operator Num(Variant v) => (Num)v.Obj;

        // Typed reads of JSON and save values (Variant) without unsafe casts: JSON numbers arrive as
        // float, saves may hold int. Use Num.f / Num.i instead of float() / int() on a Variant.

        public static double F(Variant value)
        {
            var matched1 = Gd.Typeof(value);
            if (matched1 == Gd.TYPE_FLOAT)
            {
                double x = value;
                return x;
            }
            else if (matched1 == Gd.TYPE_INT)
            {
                long n = value;
                return n;
            }
            else if (matched1 == Gd.TYPE_BOOL)
            {
                return (Gd.Truthy(value) ? 1.0 : 0.0);
            }
            else if (matched1 == Gd.TYPE_STRING)
            {
                string s = value;
                return s.ToFloat();
            }
            return 0.0;
        }

        public static long I(Variant value)
        {
            return Gd.Int(F(value));
        }

        void _InitFields()
        {
        }
        public Num() { _InitFields(); }
    }
}
