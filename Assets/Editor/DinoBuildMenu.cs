#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

// One-click player builds for sharing the game.
//   DinoImpact > Build Windows (exe)   -> Builds/Win64/DinoImpact.exe
//   DinoImpact > Build Linux           -> Builds/Linux/DinoImpact
//   DinoImpact > Build WebGL (itch)    -> Builds/WebGL
// Win64 on a Linux editor needs the "Windows Build Support (Mono)" module
// (install it for this editor version in Unity Hub) and uses the Mono
// backend, which cross-compiles fine without an IL2CPP Windows toolchain.
public static class DinoBuildMenu
{
    const string Scene = "Assets/Scenes/DinoImpact.unity";
    public static bool SuppressDialogs { get; set; }

    [MenuItem("DinoImpact/Build Windows (exe)")]
    public static void BuildWindows()
    {
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.Mono2x);
        Build(BuildTarget.StandaloneWindows64, "Builds/Win64/DinoImpact.exe");
    }

    [MenuItem("DinoImpact/Build Linux")]
    public static void BuildLinux()
    {
        Build(BuildTarget.StandaloneLinux64, "Builds/Linux/DinoImpact");
    }

    [MenuItem("DinoImpact/Build WebGL (itch)")]
    public static void BuildWebGL()
    {
        EditorUserBuildSettings.SwitchActiveBuildTarget(
            BuildTargetGroup.WebGL, BuildTarget.WebGL);
        PlayerSettings.SetScriptingBackend(
            BuildTargetGroup.WebGL, ScriptingImplementation.IL2CPP);
        // itch.io's static host may not add Content-Encoding for .br files.
        // Gzip plus the JS fallback keeps the zip self-contained on any host.
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
        PlayerSettings.WebGL.decompressionFallback = true;
        PlayerSettings.WebGL.memorySize = 256;
        PlayerSettings.runInBackground = true;
        // WebGL cannot read StreamingAssets through File APIs; mirror the Lua
        // files into Resources as TextAssets for the IL2CPP player.
        DinoLuaResources.Sync();
        Build(BuildTarget.WebGL, "Builds/WebGL");
    }

    public static void BuildWebGLForAutomation()
    {
        SuppressDialogs = true;
        try
        {
            BuildWebGL();
        }
        finally
        {
            SuppressDialogs = false;
        }
    }

    static void ShowDialog(string message)
    {
        if (!SuppressDialogs && !Application.isBatchMode)
            EditorUtility.DisplayDialog("DinoImpact build", message, "OK");
    }

    static void Build(BuildTarget target, string outFile)
    {
        if (!File.Exists(Scene))
        {
            ShowDialog("Scene not found:\n" + Scene);
            return;
        }

        var group = target == BuildTarget.WebGL
            ? BuildTargetGroup.WebGL
            : BuildTargetGroup.Standalone;
        EditorUserBuildSettings.SwitchActiveBuildTarget(group, target);
        Directory.CreateDirectory(Path.GetDirectoryName(outFile));

        var opts = new BuildPlayerOptions
        {
            scenes = new[] { Scene },
            locationPathName = outFile,
            target = target,
            options = BuildOptions.None,
        };

        BuildReport report = BuildPipeline.BuildPlayer(opts);
        string summary = report.summary.result + ": " +
                         report.summary.totalSize / (1024 * 1024) + " MB -> " + outFile;
        Debug.Log("[DinoBuildMenu] " + summary);
        ShowDialog(summary);
    }
}
#endif
