// The sim's native classes: the same calls Godot's extension answered (nat.call("land", ...)), over
// kaiju_core.dll's plain C functions (unity/native/kaiju_sim.cpp, kaiju_core.cpp). A packed array the
// call changes is duplicated first, as Godot's copy-on-write did.
using System;
using System.Runtime.InteropServices;

namespace Kaiju.Sim
{
    internal static class KaijuNative
    {
        const string Dll = "kaiju_core";
        static int available = -1;

        public static bool Available
        {
            get
            {
                if (available < 0) available = Probe() ? 1 : 0;
                return available == 1;
            }
        }

        static bool Probe()
        {
            try { return kc_sim_version() >= 1; }
            catch (DllNotFoundException) { return false; }
            catch (EntryPointNotFoundException) { return false; }
        }

        [DllImport(Dll)] public static extern int kc_sim_version();
        [DllImport(Dll)] public static extern int kc_label(byte[] cells, byte[] fix, int hasFixtures, int w, int h, int d, int[] lab);
        [DllImport(Dll)] public static extern int kc_islands(int[] lab, byte[] cells, byte[] fix, int hasFixtures, int w, int h, int d, int[] @out, int outCap, int[] sizes, int sizeCap, out int total);
        [DllImport(Dll)] public static extern void kc_floors(int[] lab, byte[] cells, byte[] fix, int w, int h, int d, int count, long[] ms, long[] xs, long[] zs, int[] bx);
        [DllImport(Dll)] public static extern int kc_gather(int[] lab, byte[] cells, int n, int from, int label, int[] @out);
        [DllImport(Dll)] public static extern void kc_land(int[] idx, int count, byte[] cells, int w, int h, int d, long[] o);
        [DllImport(Dll)] public static extern void kc_chunk_counts(byte[] cells, long n, int[] cx, int[] cz, int[] fy, int[] geo, int chunks, int[] o);
        [DllImport(Dll)] public static extern void kc_part_info(int[] idx, int count, byte[] cells, int[] cx, int[] cz, int[] fy, int[] geo, int[] lv, int[] o);
        [DllImport(Dll)] public static extern int kc_wear(byte[] c, float[] wr, float[] at, float[] amounts, int even, int[] sp, int nSpans, float[] strength, double[] nums, int[] ints, int[] cx, int[] cz, int[] fy, int[] lv);
        [DllImport(Dll)] public static extern void kc_wear_copy(int[] removed, byte[] mats);
        [DllImport(Dll)] public static extern void kc_beam_at(int[] sp, int nSpans, int[] ints, double[] nums, float[] a);
        [DllImport(Dll)] public static extern long kc_cells(int[] ints, double[] nums, int[] ids, int nIds, int[] out6);
        [DllImport(Dll)] public static extern void kc_cells_copy(byte[] dst);
        [DllImport(Dll)] public static extern double kc_water_step(float[] fl, float[] d, float[] body, float[] f, long n, long nx, int rx, int ry, int rw, int rh, long subs, double h, double keep, double g, double cell, double rest, int open);
    }

    public sealed class KaijuSettle : RefCounted
    {
        public override bool HasMethod(string name)
        {
            switch (name)
            {
                case "label": case "islands": case "floors": case "cells": case "gather": case "take":
                case "land": case "chunk_counts": case "part_info": case "wear": case "beam_at":
                    return true;
                default:
                    return false;
            }
        }

        public override Variant Call(string name, params Variant[] a)
        {
            switch (name)
            {
                case "label": return Label(a[0], a[1], a[2], a[3]);
                case "islands": return Islands(a[0], a[1], a[2], a[3], a[4]);
                case "floors": return Floors(a[0], a[1], a[2], a[3], a[4]);
                case "cells": return Cells(a[0], a[1], a[2]);
                case "gather": return Gather(a[0], a[1], a[2], a[3]);
                case "take": return Take(a[0], (IGArray)a[1].Obj, a[2], a[3]);
                case "land": return Land(a[0], a[1], a[2]);
                case "chunk_counts": return ChunkCounts(a[0], a[1], a[2], a[3], a[4], a[5]);
                case "part_info": return PartInfo(a[0], a[1], a[2], a[3], a[4], a[5], a[6]);
                case "wear": return Wear(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]);
                case "beam_at": return BeamAt(a[0], a[1], a[2]);
                default: throw new InvalidOperationException(name);
            }
        }

        static PackedInt32Array Ints(long n)
        {
            PackedInt32Array p = new PackedInt32Array();
            p.Resize(n);
            return p;
        }

        static GArray<Variant> Label(PackedByteArray cells, PackedByteArray fix, Vector3i dims, bool hasFixtures)
        {
            long n = (long)dims.X * dims.Y * dims.Z;
            PackedInt32Array labels = new PackedInt32Array();
            long count = 0;
            if (cells.Size() == n && fix.Size() >= 256 && n != 0)
            {
                labels.Resize(n);
                count = KaijuNative.kc_label(cells.Raw, fix.Raw, hasFixtures ? 1 : 0, dims.X, dims.Y, dims.Z, labels.Raw);
            }
            GArray<Variant> o = new GArray<Variant>();
            o.Append(labels);
            o.Append(count);
            return o;
        }

        static GArray<Variant> Islands(PackedInt32Array labels, PackedByteArray cells, PackedByteArray fix, Vector3i dims, bool hasFixtures)
        {
            GArray<Variant> o = new GArray<Variant>();
            long n = (long)dims.X * dims.Y * dims.Z;
            if (cells.Size() != n || labels.Size() != n || fix.Size() < 256) return o;
            int[] flat = new int[n], sizes = new int[n];
            int parts = KaijuNative.kc_islands(labels.Raw, cells.Raw, fix.Raw, hasFixtures ? 1 : 0, dims.X, dims.Y, dims.Z, flat, (int)n, sizes, (int)n, out int _);
            int at = 0;
            for (int p = 0; p < parts; p++)
            {
                PackedInt32Array island = Ints(sizes[p]);
                Array.Copy(flat, at, island.Raw, 0, sizes[p]);
                at += sizes[p];
                o.Append(island);
            }
            return o;
        }

        static GDict Floors(PackedInt32Array labels, PackedByteArray cells, PackedByteArray fix, Vector3i dims, long count)
        {
            long n = (long)dims.X * dims.Y * dims.Z, slots = count * (dims.Y + 1);
            PackedInt64Array mass = new PackedInt64Array(), sx = new PackedInt64Array(), sz = new PackedInt64Array();
            PackedInt32Array box = Ints(count * dims.Y * 4);
            mass.Resize(slots);
            sx.Resize(slots);
            sz.Resize(slots);
            Array.Fill(box.Raw, -1, 0, (int)box.Size());
            if (cells.Size() == n && labels.Size() == n && fix.Size() >= 256 && count > 0)
                KaijuNative.kc_floors(labels.Raw, cells.Raw, fix.Raw, dims.X, dims.Y, dims.Z, (int)count, mass.Raw, sx.Raw, sz.Raw, box.Raw);
            GDict o = new GDict();
            o["mass"] = mass;
            o["sx"] = sx;
            o["sz"] = sz;
            o["box"] = box;
            return o;
        }

        static GArray<Variant> Cells(PackedInt32Array ints, PackedFloat64Array nums, PackedInt32Array ids)
        {
            GArray<Variant> o = new GArray<Variant>();
            if (ints.Size() < 9 || nums.Size() < 3) return o;
            int[] box = new int[6];
            long size = KaijuNative.kc_cells(ints.Raw, nums.Raw, ids.Raw, (int)ids.Size(), box);
            if (size < 0) return o;
            PackedByteArray cells = new PackedByteArray();
            cells.Resize(size);
            KaijuNative.kc_cells_copy(cells.Raw);
            o.Append(new Vector3i(box[0], box[1], box[2]));
            o.Append(new Vector3i(box[3], box[4], box[5]));
            o.Append(cells);
            return o;
        }

        static PackedInt32Array Gather(PackedInt32Array labels, PackedByteArray cells, long from, long label)
        {
            int n = (int)cells.Size();
            if (labels.Size() != n || from < 0) return new PackedInt32Array();
            int count = KaijuNative.kc_gather(labels.Raw, cells.Raw, n, (int)from, (int)label, null);
            PackedInt32Array o = Ints(count);
            KaijuNative.kc_gather(labels.Raw, cells.Raw, n, (int)from, (int)label, o.Raw);
            return o;
        }

        // Builds Variants cell by cell, so nothing would be gained in C++.
        static GArray<Variant> Take(PackedByteArray source, IGArray parts, Vector3i dims, Vector3i offset)
        {
            int w = dims.X, plan = dims.X * dims.Z, d = dims.Z;
            PackedByteArray cells = source.Duplicate();
            byte[] c = cells.Raw;
            GArray<Variant> mats = new GArray<Variant>(), lists = new GArray<Variant>();
            for (long p = 0; p < parts.Size(); p++)
            {
                PackedInt32Array part = parts.GetVariant(p);
                int[] idx = part.Raw;
                int count = (int)part.Size();
                PackedByteArray m = new PackedByteArray();
                m.Resize(count);
                byte[] mo = m.Raw;
                GArray<Variant> list = new GArray<Variant>(count, true);
                for (int k = 0; k < count; k++)
                {
                    int i = idx[k];
                    mo[k] = c[i];
                    c[i] = 0;
                    list.Append(new Vector3i(i % w + offset.X, i / plan + offset.Y, (i / w) % d + offset.Z));
                }
                mats.Append(m);
                lists.Append(list);
            }
            GArray<Variant> o = new GArray<Variant>();
            o.Append(cells);
            o.Append(mats);
            o.Append(lists);
            return o;
        }

        static PackedInt64Array Land(PackedInt32Array part, PackedByteArray cells, Vector3i dims)
        {
            PackedInt64Array o = new PackedInt64Array();
            o.Resize(9);
            if (cells.Size() == (long)dims.X * dims.Z * dims.Y)
                KaijuNative.kc_land(part.Raw, (int)part.Size(), cells.Raw, dims.X, dims.Y, dims.Z, o.Raw);
            return o;
        }

        static PackedInt32Array ChunkCounts(PackedByteArray cells, PackedInt32Array cx, PackedInt32Array cz, PackedInt32Array fy, PackedInt32Array geo, long chunks)
        {
            PackedInt32Array o = Ints(Math.Max(0, chunks));
            if (geo.Size() < 5) return o;
            int[] g = geo.Raw;
            if (cells.Size() != (long)g[0] * g[1] * g[2] || cx.Size() < g[0] || cz.Size() < g[1] || fy.Size() < g[2]) return o;
            KaijuNative.kc_chunk_counts(cells.Raw, cells.Size(), cx.Raw, cz.Raw, fy.Raw, g, (int)chunks, o.Raw);
            return o;
        }

        static GArray<Variant> PartInfo(PackedInt32Array index, PackedByteArray cells, PackedInt32Array cx, PackedInt32Array cz, PackedInt32Array fy, PackedInt32Array geo, PackedInt32Array live)
        {
            PackedInt32Array lv = live.Duplicate(), info = Ints(11);
            KaijuNative.kc_part_info(index.Raw, (int)index.Size(), cells.Raw, cx.Raw, cz.Raw, fy.Raw, geo.Raw, lv.Raw, info.Raw);
            GArray<Variant> o = new GArray<Variant>();
            o.Append(lv);
            o.Append(info);
            return o;
        }

        static GArray<Variant> Wear(PackedByteArray cells, PackedFloat32Array wear, PackedFloat32Array at, PackedFloat32Array amounts, PackedInt32Array spans, PackedFloat32Array strength, PackedFloat64Array nums, PackedInt32Array ints, PackedInt32Array cx, PackedInt32Array cz, PackedInt32Array fy, PackedInt32Array live)
        {
            GArray<Variant> o = new GArray<Variant>();
            bool even = at.Size() == 0;
            if (even && amounts.Size() * 5 < spans.Size()) return o;
            PackedByteArray c = cells.Duplicate();
            PackedFloat32Array worn = wear.Duplicate();
            PackedInt32Array lv = live.Duplicate();
            int gone = KaijuNative.kc_wear(c.Raw, worn.Raw, at.Raw, amounts.Raw, even ? 1 : 0, spans.Raw, (int)spans.Size(), strength.Raw, nums.Raw, ints.Raw, cx.Raw, cz.Raw, fy.Raw, lv.Raw);
            PackedInt32Array removed = Ints(gone);
            PackedByteArray mats = new PackedByteArray();
            mats.Resize(gone);
            KaijuNative.kc_wear_copy(removed.Raw, mats.Raw);
            o.Append(c);
            o.Append(worn);
            o.Append(lv);
            o.Append(removed);
            o.Append(mats);
            return o;
        }

        static PackedFloat32Array BeamAt(PackedInt32Array spans, PackedInt32Array ints, PackedFloat64Array nums)
        {
            PackedFloat32Array o = new PackedFloat32Array();
            o.Resize((long)ints.Raw[0] * ints.Raw[1]);
            KaijuNative.kc_beam_at(spans.Raw, (int)spans.Size(), ints.Raw, nums.Raw, o.Raw);
            return o;
        }
    }

    public sealed class KaijuWater : RefCounted
    {
        public override bool HasMethod(string name) => name == "step";

        public override Variant Call(string name, params Variant[] a)
        {
            if (name != "step") throw new InvalidOperationException(name);
            PackedFloat32Array floorY = a[0], depth = a[1], body = a[2], flow = a[3];
            long nx = a[4], n = floorY.Size();
            GArray<Variant> o = new GArray<Variant>();
            if (nx <= 0 || n % nx != 0 || depth.Size() != n || body.Size() != n || flow.Size() != n * 4) return o;
            Rect2i r = a[5];
            PackedFloat32Array d = depth.Duplicate(), f = flow.Duplicate();
            double stir = KaijuNative.kc_water_step(floorY.Raw, d.Raw, body.Raw, f.Raw, n, nx, r.position.X, r.position.Y, r.size.X, r.size.Y, a[6], a[7], a[8], a[9], a[10], a[11], a[12] ? 1 : 0);
            o.Append(d);
            o.Append(f);
            o.Append(stir);
            return o;
        }
    }
}
