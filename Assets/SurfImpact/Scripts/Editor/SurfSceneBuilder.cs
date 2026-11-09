using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace SurfImpact.EditorTools
{
    /// <summary>
    /// Creates the playable scene (one object with SurfBootstrap) and registers it
    /// in Build Settings. Menu: Surf Impact / Build Play Scene.
    /// </summary>
    public static class SurfSceneBuilder
    {
        const string ScenePath = "Assets/Scenes/SurfImpact.unity";

        [MenuItem("Surf Impact/Build Play Scene")]
        public static void BuildPlayScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var root = new GameObject("SURF IMPACT");
            root.AddComponent<SurfBootstrap>();

            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene, ScenePath);

            var scenes = EditorBuildSettings.scenes.Where(s => s.path != ScenePath).ToList();
            scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
            EditorBuildSettings.scenes = scenes.ToArray();

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[Surf] Scene created at " + ScenePath);
        }

        /// <summary>Batch-mode entry point: Unity -executeMethod SurfImpact.EditorTools.SurfSceneBuilder.BuildFromBatch</summary>
        public static void BuildFromBatch()
        {
            BuildPlayScene();
            if (Application.isBatchMode)
                EditorApplication.Exit(0);
        }
    }
}
