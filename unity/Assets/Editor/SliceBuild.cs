using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.SceneManagement;

// Sets the project up from nothing and builds the Windows exe:
//   Unity.exe -batchmode -quit -projectPath unity -executeMethod SliceBuild.Build -logFile Logs-build.txt
public static class SliceBuild
{
    const string SETTINGS = "Assets/Settings";
    const string SCENE = "Assets/Slice.unity";
    const string EXE = "Build/KaijuSlice.exe";

    public static void Ping()
    {
        Debug.Log($"slice: editor alive {Application.unityVersion}");
    }

    [MenuItem("Slice/Build")]
    public static void Build()
    {
        try
        {
            SetupRendering();
            SetupPlayer();
            SetupScene();
            AssetDatabase.SaveAssets();
            Directory.CreateDirectory("Build");
            BuildReport report = BuildPipeline.BuildPlayer(new[] { SCENE }, EXE, BuildTarget.StandaloneWindows64, BuildOptions.None);
            Debug.Log($"slice: build {report.summary.result}, {report.summary.totalErrors} errors, {report.summary.totalSize / (1024 * 1024)} MB");
            if (report.summary.result != BuildResult.Succeeded) EditorApplication.Exit(1);
        }
        catch (Exception e)
        {
            Debug.LogException(e);
            EditorApplication.Exit(1);
        }
    }

    static void SetupRendering()
    {
        Directory.CreateDirectory(SETTINGS);
        AssetDatabase.Refresh();
        const string HD = SETTINGS + "/SliceHdrp.asset";
        var asset = AssetDatabase.LoadAssetAtPath<HDRenderPipelineAsset>(HD);
        if (asset == null)
        {
            asset = ScriptableObject.CreateInstance<HDRenderPipelineAsset>();
            AssetDatabase.CreateAsset(asset, HD);
        }
        GraphicsSettings.defaultRenderPipeline = asset;
        QualitySettings.renderPipeline = asset;
        EditorUtility.SetDirty(asset);

        RegisterAgx();
    }

    // HDRP only runs a custom post process listed in its global settings. The list's class is internal: the
    // settings window is the only public way in, so this is the same Add call that window makes.
    static void RegisterAgx()
    {
        Assembly hdrp = typeof(HDRenderPipelineAsset).Assembly;
        Type ordersType = hdrp.GetType("UnityEngine.Rendering.HighDefinition.CustomPostProcessOrdersSettings", true);
        MethodInfo getter = typeof(GraphicsSettings).GetMethod(nameof(GraphicsSettings.GetRenderPipelineSettings)).MakeGenericMethod(ordersType);
        object orders = getter.Invoke(null, null);
        const BindingFlags ANY = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
        object list = ordersType.GetField("m_AfterPostProcessCustomPostProcesses", ANY).GetValue(orders);
        MethodInfo add = list.GetType().GetMethod("Add", new[] { typeof(string) });
        bool added = (bool)add.Invoke(list, new object[] { typeof(AgxTonemap).AssemblyQualifiedName });
        // After AgX in the list: the vignette and fringe work on the display picture.
        bool addedPost = (bool)add.Invoke(list, new object[] { typeof(PostFxPass).AssemblyQualifiedName });
        added |= addedPost;
        Debug.Log($"slice: postfx registered, new {addedPost}");
        UnityEngine.Object global = GraphicsSettings.GetSettingsForRenderPipeline<HDRenderPipeline>();
        if (added && global != null) EditorUtility.SetDirty(global);
        Debug.Log($"slice: agx registered, new {added}, global settings {(global != null ? AssetDatabase.GetAssetPath(global) : "none")}");
    }

    public static void Setup()
    {
        SetupRendering();
        SetupPlayer();
        SetupScene();
        AssetDatabase.SaveAssets();
    }

    static void SetInt(SerializedObject so, string name, int value)
    {
        SerializedProperty prop = so.FindProperty(name);
        if (prop != null) prop.intValue = value;
    }

    static void SetupPlayer()
    {
        PlayerSettings.colorSpace = ColorSpace.Linear;
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64, new[] { GraphicsDeviceType.Direct3D12 });
        PlayerSettings.enableFrameTimingStats = true;
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone, ScriptingImplementation.Mono2x);
        PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
        PlayerSettings.defaultScreenWidth = 1920;
        PlayerSettings.defaultScreenHeight = 1080;
        PlayerSettings.resizableWindow = true;
        PlayerSettings.runInBackground = true;
        PlayerSettings.productName = "Kaiju Unity Slice";
        PlayerSettings.companyName = "Kaiju Incremental";
        PlayerSettings.SplashScreen.show = false;
        UnityEngine.Object[] assets = AssetDatabase.LoadAllAssetsAtPath("ProjectSettings/ProjectSettings.asset");
        if (assets.Length > 0)
        {
            var so = new SerializedObject(assets[0]);
            SetInt(so, "activeInputHandler", 0);
            so.ApplyModifiedPropertiesWithoutUndo();
        }
    }

    // U5: the game's own scene (GameFlow alone: the flow, with the rampage inside it), its data and assets beside
    // it, and its player. Rampage.unity, the scene of the U4 builds, is no longer made or built.
    const string GAME_SCENE = "Assets/Game.unity";
    const string RAMPAGE_EXE = "Build/KaijuRampage.exe";
    // The sim carves these models: without them a pool building or landmark has no cells.
    static readonly string[] MODEL_KINDS = { "city_buildings", "landmarks", "vehicles" };
    // What the screens and the audio read at run time, copied whole (Godot's .import files left behind).
    static readonly string[] ASSET_KINDS = { "sfx", "music", "overworld", "lab", "title", "ui", "loading", "kaiju" };
    // kaiju: the bodies' cells, clips and skins (.kclip, .skinf, .skinw, .vskin).
    static readonly string[] ASSET_TYPES = { ".ogg", ".png", ".jpg", ".kvox", ".json", ".kclip", ".skinf", ".skinw", ".vskin" };
    // The kit's fonts load through Resources (UiKit.Font), so they are copied into the project, not beside it.
    const string FONTS = "Assets/Resources/Fonts";

    public static void BuildRampage()
    {
        bool ok = false;
        try
        {
            SetupRendering();
            SetupPlayer();
            string repo = Path.GetFullPath(Path.Combine(Application.dataPath, "..", ".."));
            string res = Path.Combine(Application.streamingAssetsPath, "res");
            string to = Path.Combine(res, "data");
            if (Directory.Exists(to)) Directory.Delete(to, true);
            Directory.CreateDirectory(to);
            foreach (string file in Directory.GetFiles(Path.Combine(repo, "data"), "*.json", SearchOption.AllDirectories))
            {
                string out_ = Path.Combine(to, Path.GetRelativePath(Path.Combine(repo, "data"), file));
                Directory.CreateDirectory(Path.GetDirectoryName(out_));
                File.Copy(file, out_);
            }
            // The text table (Tr.Load).
            Directory.CreateDirectory(Path.Combine(to, "i18n"));
            File.Copy(Path.Combine(repo, "data", "i18n", "strings.csv"), Path.Combine(to, "i18n", "strings.csv"), true);
            foreach (string kind in MODEL_KINDS)
            {
                string models = Path.Combine(res, "assets", kind);
                if (Directory.Exists(models)) Directory.Delete(models, true);
                Directory.CreateDirectory(models);
                foreach (string file in Directory.GetFiles(Path.Combine(repo, "assets", kind), "*.*"))
                    if (file.EndsWith(".kvox") || file.EndsWith(".parts.json"))
                        File.Copy(file, Path.Combine(models, Path.GetFileName(file)));
            }
            int copied = 0;
            foreach (string kind in ASSET_KINDS)
            {
                string from = Path.Combine(repo, "assets", kind);
                string into = Path.Combine(res, "assets", kind);
                if (Directory.Exists(into)) Directory.Delete(into, true);
                if (!Directory.Exists(from))
                {
                    Debug.LogWarning($"rampage: no assets/{kind} to copy");
                    continue;
                }
                foreach (string file in Directory.GetFiles(from, "*.*", SearchOption.AllDirectories))
                {
                    if (Array.IndexOf(ASSET_TYPES, Path.GetExtension(file).ToLowerInvariant()) < 0) continue;
                    string out_ = Path.Combine(into, Path.GetRelativePath(from, file));
                    Directory.CreateDirectory(Path.GetDirectoryName(out_));
                    File.Copy(file, out_);
                    copied++;
                }
            }
            int fonts = 0;
            Directory.CreateDirectory(FONTS);
            string fontsFrom = Path.Combine(repo, "assets", "fonts");
            if (Directory.Exists(fontsFrom))
            {
                foreach (string file in Directory.GetFiles(fontsFrom, "*.ttf"))
                {
                    File.Copy(file, Path.Combine(FONTS, Path.GetFileName(file)), true);
                    fonts++;
                }
            }
            Debug.Log($"rampage: copied {copied} asset files, {fonts} fonts");
            AssetDatabase.Refresh();
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("game").AddComponent<GameFlow>();
            EditorSceneManager.SaveScene(scene, GAME_SCENE);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(GAME_SCENE, true) };
            AssetDatabase.SaveAssets();
            Directory.CreateDirectory("Build");
            BuildReport report = BuildPipeline.BuildPlayer(new[] { GAME_SCENE }, RAMPAGE_EXE, BuildTarget.StandaloneWindows64, BuildOptions.None);
            Debug.Log($"rampage: build {report.summary.result}, {report.summary.totalErrors} errors, {report.summary.totalSize / (1024 * 1024)} MB");
            ok = report.summary.result == BuildResult.Succeeded;
        }
        catch (Exception e)
        {
            Debug.LogException(e);
        }
        // A failed build must fail the command that ran it; an editor someone has open is left open.
        if (!ok && Application.isBatchMode) EditorApplication.Exit(1);
    }

    static void SetupScene()
    {
        Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        new GameObject("game").AddComponent<SliceGame>();
        EditorSceneManager.SaveScene(scene, SCENE);
        EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(SCENE, true) };
    }
}
