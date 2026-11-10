#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

// One-click player builds for sharing the game.
//   DinoImpact > Build Windows (exe)   -> Builds/Win64/DinoImpact.exe
//   DinoImpact > Build Linux           -> Builds/Linux/DinoImpact
// Win64 on a Linux editor needs the "Windows Build Support (Mono)" module
// (install it for this editor version in Unity Hub) and uses the Mono
// backend, which cross-compiles fine without an IL2CPP Windows toolchain.
public static class DinoBuildMenu
{
    const string Scene = "Assets/Scenes/DinoImpact.unity";

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

    static void Build(BuildTarget target, string outFile)
    {
        if (!File.Exists(Scene))
        {
            EditorUtility.DisplayDialog("DinoImpact build",
                "Scene not found:\n" + Scene, "OK");
            return;
        }

        EditorUserBuildSettings.SwitchActiveBuildTarget(
            BuildTargetGroup.Standalone, target);
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
        EditorUtility.DisplayDialog("DinoImpact build", summary, "OK");
    }
}
#endif
