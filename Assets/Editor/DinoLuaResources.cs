#if UNITY_EDITOR
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

/// <summary>
/// Android cannot read StreamingAssets with File/Directory APIs (it lives in
/// the APK) and WebGL serves StreamingAssets over HTTP. Before those builds
/// we mirror the Lua files into Assets/Resources/DinoLua as TextAssets.
/// StreamingAssets remains the one source of truth for editor/desktop builds.
/// </summary>
public static class DinoLuaResources
{
    public const string SourceDir = "Assets/StreamingAssets/Lua";
    public const string DestDir = "Assets/Resources/DinoLua";

    public static void Sync()
    {
        Directory.CreateDirectory(DestDir);
        var wanted = new HashSet<string>();

        foreach (string src in Directory.GetFiles(SourceDir, "*.lua"))
        {
            string name = Path.GetFileName(src) + ".txt";   // .lua.txt => TextAsset
            string dst = Path.Combine(DestDir, name);
            wanted.Add(name);

            if (!File.Exists(dst) ||
                File.GetLastWriteTimeUtc(dst) < File.GetLastWriteTimeUtc(src))
            {
                File.Copy(src, dst, true);
                AssetDatabase.ImportAsset(dst, ImportAssetOptions.ForceUpdate);
            }
        }

        foreach (string dst in Directory.GetFiles(DestDir, "*.lua.txt"))
        {
            if (!wanted.Contains(Path.GetFileName(dst)))
                AssetDatabase.DeleteAsset(dst.Replace('\\', '/'));
        }

        // Make the freshly created assets visible to the upcoming build.
        AssetDatabase.Refresh();
    }
}

class DinoLuaResourcesPreprocessor : IPreprocessBuildWithReport
{
    public int callbackOrder => 0;

    public void OnPreprocessBuild(BuildReport report)
    {
        if (report.summary.platform == BuildTarget.Android ||
            report.summary.platform == BuildTarget.WebGL)
            DinoLuaResources.Sync();
    }
}
#endif
