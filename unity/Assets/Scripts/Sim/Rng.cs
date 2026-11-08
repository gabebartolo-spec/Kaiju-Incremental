// Godot's RandomNumberGenerator, bit for bit (D-470 U2): PCG32 and core/math/random_pcg.*.
// PCG32 (c) 2014 M.E. O'Neill, Apache License 2.0. Godot Engine contributors, MIT License.
using System;

namespace Kaiju.Sim
{
    /// Every sim stream draws from one of these, so a seed replays what Godot's stream gave.
    public sealed class Rng
    {
        const ulong Multiplier = 6364136223846793005UL;
        const ulong DefaultSeed = 12047754176567800795UL;
        const ulong DefaultIncrement = 1442695040888963407UL;

        ulong state;
        ulong increment;
        ulong seed;

        public Rng() => Seed = DefaultSeed;

        public Rng(ulong startSeed) => Seed = startSeed;

        public ulong Seed
        {
            get => seed;
            set
            {
                seed = value;
                state = 0UL;
                increment = (DefaultIncrement << 1) | 1UL;
                Next();
                state += seed;
                Next();
            }
        }

        public ulong State { get => state; set => state = value; }

        public uint Randi() => Next();

        /// Two draws: the first sets the exponent, the second the bits.
        public float Randf()
        {
            uint exponentDraw = Next();
            if (exponentDraw == 0U)
                return 0f;
            float bits = Next() | 0x80000001U;
            return (float)(bits * PowerOfTwo(-32 - LeadingZeros(exponentDraw)));
        }

        /// Godot does this sum in 32-bit floats, and so must the copy.
        public float RandfRange(float from, float to)
        {
            float span = (float)(to - from);
            float scaled = (float)(Randf() * span);
            return (float)(scaled + from);
        }

        public int RandiRange(int from, int to)
        {
            if (from == to)
                return from;
            long low = Math.Min(from, to);
            long high = Math.Max(from, to);
            uint diff = (uint)(high - low);
            if (diff == uint.MaxValue)
                return (int)(Next() + low);
            return (int)(Bounded(diff + 1U) + low);
        }

        uint Bounded(uint bound)
        {
            uint threshold = unchecked(0U - bound) % bound;
            while (true)
            {
                uint r = Next();
                if (r >= threshold)
                    return r % bound;
            }
        }

        uint Next()
        {
            ulong old = state;
            state = unchecked(old * Multiplier + (increment | 1UL));
            uint xorshifted = (uint)(((old >> 18) ^ old) >> 27);
            int rot = (int)(old >> 59);
            return (xorshifted >> rot) | (xorshifted << (-rot & 31));
        }

        static int LeadingZeros(uint value)
        {
            int zeros = 0;
            while ((value & 0x80000000U) == 0U)
            {
                value <<= 1;
                zeros++;
            }
            return zeros;
        }

        /// An exact power of two, built from its bits: ldexp without rounding.
        static double PowerOfTwo(int exponent) => BitConverter.Int64BitsToDouble((long)(exponent + 1023) << 52);
    }
}
