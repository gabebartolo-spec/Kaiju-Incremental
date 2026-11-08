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

    // U4: the rampage's own scene, its data beside it, and its own player.
    const string RAMPAGE_SCENE = "Assets/Rampage.unity";
    const string RAMPAGE_EXE = "Build/KaijuRampage.exe";

    public static void BuildRampage()
    {
        try
        {
            SetupRendering();
            SetupPlayer();
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("rampage").AddComponent<RampageGame>();
            EditorSceneManager.SaveScene(scene, RAMPAGE_SCENE);
            string repo = Path.GetFullPath(Path.Combine(Application.dataPath, "..", ".."));
            string to = Path.Combine(Application.streamingAssetsPath, "res", "data");
            if (Directory.Exists(to)) Directory.Delete(to, true);
            Directory.CreateDirectory(to);
            foreach (string file in Directory.GetFiles(Path.Combine(repo, "data"), "*.json", SearchOption.AllDirectories))
            {
                string out_ = Path.Combine(to, Path.GetRelativePath(Path.Combine(repo, "data"), file));
                Directory.CreateDirectory(Path.GetDirectoryName(out_));
                File.Copy(file, out_);
            }
            AssetDatabase.SaveAssets();
            Directory.CreateDirectory("Build");
            BuildReport report = BuildPipeline.BuildPlayer(new[] { RAMPAGE_SCENE }, RAMPAGE_EXE, BuildTarget.StandaloneWindows64, BuildOptions.None);
            Debug.Log($"rampage: build {report.summary.result}, {report.summary.totalErrors} errors, {report.summary.totalSize / (1024 * 1024)} MB");
        }
        catch (Exception e)
        {
            Debug.LogException(e);
        }
    }

    static void SetupScene()
    {
        Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        new GameObject("game").AddComponent<SliceGame>();
        EditorSceneManager.SaveScene(scene, SCENE);
        EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(SCENE, true) };
    }
}
