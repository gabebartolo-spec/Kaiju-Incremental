// Godot's hash(), bit for bit, for what the sim hashes (D-470 U2): core/templates/hashfuncs.*,
// core/variant/variant.cpp, core/variant/array.cpp. Godot Engine contributors, MIT License.
using System;

namespace Kaiju.Sim
{
    public static class GodotHash
    {
        const uint MurmurSeed = 0x7F07C65U;
        /// Variant::ARRAY, which opens every array's hash.
        const uint ArrayType = 28U;

        public static uint String(string text)
        {
            uint hash = 5381U;
            for (int i = 0; i < text.Length; i++)
            {
                uint c = char.IsHighSurrogate(text[i]) ? (uint)char.ConvertToUtf32(text, i++) : text[i];
                hash = unchecked((hash << 5) + hash + c);
            }
            return hash;
        }

        public static uint Int(long value)
        {
            ulong v = unchecked((ulong)value);
            v = unchecked(~v + (v << 18));
            v ^= v >> 31;
            v = unchecked(v * 21UL);
            v ^= v >> 11;
            v = unchecked(v + (v << 6));
            v ^= v >> 22;
            return (uint)v;
        }

        public static uint Double(double value)
        {
            ulong bits = value == 0.0
                ? 0UL
                : double.IsNaN(value)
                    ? (ulong)BitConverter.DoubleToInt64Bits(double.NaN)
                    : (ulong)BitConverter.DoubleToInt64Bits(value);
            uint h = Murmur((uint)(bits & 0xFFFFFFFFUL), MurmurSeed);
            return Murmur((uint)(bits >> 32), h);
        }

        public static uint Vector4i(int x, int y, int z, int w)
        {
            uint h = Murmur(unchecked((uint)x), MurmurSeed);
            h = Murmur(unchecked((uint)y), h);
            h = Murmur(unchecked((uint)z), h);
            h = Murmur(unchecked((uint)w), h);
            return Mix(h);
        }

        /// hash([a, b, c]) from the hash of each element.
        public static uint Array(params uint[] elementHashes)
        {
            uint h = Murmur(ArrayType, MurmurSeed);
            foreach (uint element in elementHashes)
                h = Murmur(element, h);
            return Mix(h);
        }

        static uint Murmur(uint value, uint seed)
        {
            unchecked
            {
                value *= 0xcc9e2d51U;
                value = (value << 15) | (value >> 17);
                value *= 0x1b873593U;
                seed ^= value;
                seed = (seed << 13) | (seed >> 19);
                return seed * 5U + 0xe6546b64U;
            }
        }

        static uint Mix(uint h)
        {
            unchecked
            {
                h ^= h >> 16;
                h *= 0x85ebca6bU;
                h ^= h >> 13;
                h *= 0xc2b2ae35U;
                h ^= h >> 16;
                return h;
            }
        }
    }
}
