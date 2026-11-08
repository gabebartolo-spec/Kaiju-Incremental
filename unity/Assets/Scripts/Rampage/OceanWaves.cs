using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using S = Kaiju.Sim;

// The bay's open sea (scenes/ocean_waves.gd): GodotOceanWaves by Ethan Truong (MIT,
// scenes/ocean/LICENSE_GodotOceanWaves.txt). A JONSWAP/TMA spectrum turned into displacement and normal maps
// by a Stockham FFT on the GPU, one cascade a frame, with foam where the surface folds. Numbers: tuning
// water.ocean. Presentation only: nothing reads it back.
public sealed class OceanWaves : IDisposable
{
    const double G = 9.81, DEPTH = 20.0;
    const int SEED = 1234, SEED_RANGE = 10000;
    const int SPECTRA = 4, MIN_LAYERS = 2, MAX_CASCADES = 8;
    const int SPECTRUM_TILE = 16, TRANSPOSE_TILE = 32;

    sealed class Cascade
    {
        public S.GDict cfg;
        public int seedX, seedY;
        public double time, grow, decay;
        public bool spectrum = true;
    }

    struct Butterfly
    {
        public uint r0, r1;
        public float x, y;
    }

    readonly ComputeShader cs;
    readonly S.GDict cfg;
    readonly Cascade[] cascades;
    readonly int map, stages;
    readonly float scale;
    readonly Vector4[] scales = new Vector4[MAX_CASCADES];
    readonly RenderTexture spectrumMap, disp, normals, foam;
    readonly ComputeBuffer butterfly, data;
    readonly int kSpectrum, kModulate, kFft, kTranspose, kUnpack;
    double now, next;
    int left;

    public OceanWaves(ComputeShader shader)
    {
        cs = shader;
        cfg = S.Content.Section("water")["ocean"];
        map = (int)S.Num.I(cfg["map_size"]);
        scale = (float)S.Num.F(cfg["scale"]);
        stages = Mathf.RoundToInt(Mathf.Log(map, 2f));
        var rng = new S.RandomNumberGenerator();
        rng.seed = SEED;
        S.GArray<S.GDict> list = cfg["cascades"];
        cascades = new Cascade[list.Size()];
        for (int i = 0; i < cascades.Length; i++)
        {
            S.GDict c = list[i];
            int x = (int)rng.RandiRange(-SEED_RANGE, SEED_RANGE);
            int y = (int)rng.RandiRange(-SEED_RANGE, SEED_RANGE);
            // the source's time offset per cascade, so they never line up
            cascades[i] = new Cascade { cfg = c, seedX = x, seedY = y, time = 120.0 + Math.PI * i };
            float tile = (float)S.Num.F(c["tile"]) * scale;
            scales[i] = new Vector4(1f / tile, 1f / tile, (float)S.Num.F(c["displacement"]), (float)S.Num.F(c["normal"]));
        }

        int layers = Mathf.Max(MIN_LAYERS, cascades.Length);
        spectrumMap = Map(RenderTextureFormat.ARGBFloat, layers);
        disp = Map(RenderTextureFormat.ARGBHalf, layers);
        normals = Map(RenderTextureFormat.ARGBHalf, layers);
        foam = Map(RenderTextureFormat.RFloat, layers);
        data = new ComputeBuffer(layers * map * map * SPECTRA * 2, sizeof(float) * 2);
        butterfly = new ComputeBuffer(stages * map, sizeof(float) * 4);
        butterfly.SetData(Factors());

        kSpectrum = cs.FindKernel("SpectrumCompute");
        kModulate = cs.FindKernel("SpectrumModulate");
        kFft = cs.FindKernel("FftCompute");
        kTranspose = cs.FindKernel("Transpose");
        kUnpack = cs.FindKernel("FftUnpack");
        cs.SetTexture(kSpectrum, "_Spectrum", spectrumMap);
        cs.SetTexture(kModulate, "_SpectrumIn", spectrumMap);
        cs.SetBuffer(kModulate, "_Data", data);
        cs.SetBuffer(kFft, "_Butterfly", butterfly);
        cs.SetBuffer(kFft, "_Data", data);
        cs.SetBuffer(kTranspose, "_Data", data);
        cs.SetBuffer(kUnpack, "_Data", data);
        cs.SetTexture(kUnpack, "_Disp", disp);
        cs.SetTexture(kUnpack, "_Normals", normals);
        cs.SetTexture(kUnpack, "_Foam", foam);
        cs.SetInt("_Map", map);
        cs.SetInt("_Stages", stages);
    }

    // Hands a bay sheet the maps.
    public void Bind(Material mat)
    {
        mat.SetFloat("_OceanOn", 1f);
        mat.SetFloat("_OceanCount", cascades.Length);
        mat.SetTexture("_OceanDisp", disp);
        mat.SetTexture("_OceanNormals", normals);
        mat.SetVectorArray("_OceanScales", scales);
        mat.SetFloat("_OceanMapSize", map);
        S.GArray<S.Variant> fade = cfg["fade_texels"];
        mat.SetVector("_OceanFade", new Vector2((float)S.Num.F(fade[0]), (float)S.Num.F(fade[1])));
    }

    public void Step(float delta)
    {
        double rate = S.Num.F(cfg["updates_per_second"]);
        if (now >= next)
        {
            double step = 1.0 / rate + (now - next);
            next = now + 1.0 / rate;
            Update(step);
        }
        now += delta;
        if (left > 0)
        {
            left--;
            Run(left);
        }
    }

    // The source's per-update step: time and foam rates for every cascade, then one cascade a frame.
    void Update(double step)
    {
        for (int i = 0; i < left; i++) Run(i);  // the last update's cascades not run yet
        foreach (Cascade c in cascades)
        {
            double amount = S.Num.F(c.cfg["foam_amount"]);
            c.time += step;
            // the source's constants: they set the foam parameters on a 0-10 scale
            c.grow = step * amount * 7.5;
            c.decay = step * Math.Max(0.5, 10.0 - amount) * 1.15;
        }
        left = cascades.Length;
    }

    void Run(int i)
    {
        Cascade c = cascades[i];
        float tile = (float)S.Num.F(c.cfg["tile"]) * scale;
        float depth = (float)DEPTH * scale;
        cs.SetInt("_Cascade", i);
        cs.SetFloat("_TileX", tile);
        cs.SetFloat("_TileZ", tile);
        cs.SetFloat("_Depth", depth);
        int groups = map / SPECTRUM_TILE;
        if (c.spectrum)
        {
            double wind = S.Num.F(c.cfg["wind_speed"]) * Math.Sqrt(scale);
            double fetch = S.Num.F(c.cfg["fetch_km"]) * 1e3 * scale;
            cs.SetInt("_SeedX", c.seedX);
            cs.SetInt("_SeedY", c.seedY);
            cs.SetFloat("_Alpha", (float)(0.076 * Math.Pow(wind * wind / (fetch * G), 0.22)));  // JONSWAP (wikiwaves)
            cs.SetFloat("_PeakFrequency", (float)(22.0 * Math.Pow(G * G / (wind * fetch), 1.0 / 3.0)));
            cs.SetFloat("_WindSpeed", (float)wind);
            // heading: turns the source's winds so its waves run landward here (tuning water.ocean)
            double direction = S.Num.F(c.cfg["wind_direction"]) + S.Num.F(cfg["heading"]);
            cs.SetFloat("_Angle", (float)(direction * Math.PI / 180.0));
            cs.SetFloat("_Swell", (float)S.Num.F(c.cfg["swell"]));
            cs.SetFloat("_Detail", (float)S.Num.F(c.cfg["detail"]));
            cs.SetFloat("_SpreadShare", (float)S.Num.F(c.cfg["spread"]));
            cs.Dispatch(kSpectrum, groups, groups, 1);
            c.spectrum = false;
        }
        cs.SetFloat("_Time0", (float)c.time);
        cs.Dispatch(kModulate, groups, groups, 1);
        // the source: no second transpose (a wave turned a quarter looks the same)
        cs.Dispatch(kFft, 1, map, SPECTRA);
        cs.Dispatch(kTranspose, map / TRANSPOSE_TILE, map / TRANSPOSE_TILE, SPECTRA);
        cs.Dispatch(kFft, 1, map, SPECTRA);
        cs.SetFloat("_Whitecap", (float)S.Num.F(c.cfg["whitecap"]));
        cs.SetFloat("_FoamGrow", (float)c.grow);
        cs.SetFloat("_FoamDecay", (float)c.decay);
        cs.Dispatch(kUnpack, groups, groups, 1);
    }


    // scenes/ocean/fft_butterfly.glsl, once.
    Butterfly[] Factors()
    {
        var b = new Butterfly[stages * map];
        uint m = (uint)map;
        for (int s = 0; s < stages; s++)
        {
            uint stride = 1u << s, mid = m >> (s + 1);
            for (uint col = 0; col < m / 2u; col++)
            {
                uint i = col >> s, j = col % stride;
                double a = Math.PI / stride * j;
                float x = (float)Math.Cos(a), y = (float)Math.Sin(a);
                uint r0 = stride * i + j, r1 = stride * (i + mid) + j;
                uint w0 = stride * (2u * i) + j, w1 = stride * (2u * i + 1u) + j;
                b[s * map + w0] = new Butterfly { r0 = r0, r1 = r1, x = x, y = y };
                b[s * map + w1] = new Butterfly { r0 = r0, r1 = r1, x = -x, y = -y };
            }
        }
        return b;
    }

    RenderTexture Map(RenderTextureFormat format, int layers)
    {
        var rt = new RenderTexture(map, map, 0, format, RenderTextureReadWrite.Linear)
        {
            dimension = UnityEngine.Rendering.TextureDimension.Tex2DArray,
            volumeDepth = layers,
            enableRandomWrite = true,
            useMipMap = false,
            wrapMode = TextureWrapMode.Repeat,
            filterMode = FilterMode.Bilinear,
        };
        rt.Create();
        return rt;
    }

    public void Dispose()
    {
        butterfly.Release();
        data.Release();
        spectrumMap.Release();
        disp.Release();
        normals.Release();
        foam.Release();
        UnityEngine.Object.Destroy(spectrumMap);
        UnityEngine.Object.Destroy(disp);
        UnityEngine.Object.Destroy(normals);
        UnityEngine.Object.Destroy(foam);
    }
}
