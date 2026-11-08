// Generated from sim/seeds.gd by tools/unity/gd2cs.py; do not edit until the switch (D-470 U6).
// See Sim/Runtime for what the types below mean.
namespace Kaiju.Sim
{
    public class Seeds : RefCounted
    {
        public static implicit operator Seeds(Variant v) => (Seeds)v.Obj;

        // Every random stream is derived from a name and an index, so any run can be replayed from
        // (stream, index). Sim code takes the RandomNumberGenerator it is given.
        public const long MASTER_SEED = 0x4B41494AL;

        public static RandomNumberGenerator Make(string stream, long index = 0)
        {
            var rng = new RandomNumberGenerator();
            rng.seed = Gd.Hash(Gd.Format("%d:%s:%d", Gd.Arr(MASTER_SEED, stream, index)));
            return rng;
        }
        // A second stream drawn from an existing one's seed, so adding a consumer (a new power)
        // never shifts what the first stream produces.

        public static RandomNumberGenerator Derive(RandomNumberGenerator rng, long salt)
        {
            var @out = new RandomNumberGenerator();
            @out.seed = Gd.Hash(Gd.Format("%d:%d", Gd.Arr(rng.seed, salt)));
            return @out;
        }

        void _InitFields()
        {
        }
        public Seeds() { _InitFields(); }
    }
}
