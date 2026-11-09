using System.Linq;
using DinoImpact;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace DinoImpact.EditorTools
{
    /// <summary>Creates the playable 2D scene and registers it in Build Settings.</summary>
    public static class DinoSceneBuilder
    {
        public const string ScenePath = "Assets/Scenes/DinoImpact.unity";

        [MenuItem("Dino Impact/Build Play Scene")]
        public static void BuildPlayScene()
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var root = new GameObject("DINO IMPACT");
            root.AddComponent<DinoBootstrap>();

            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene, ScenePath);

            var scenes = EditorBuildSettings.scenes.Where(s => s.path != ScenePath).ToList();
            scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
            EditorBuildSettings.scenes = scenes.ToArray();

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[Dino] Scene created at " + ScenePath);
        }

        public static void BuildFromBatch()
        {
            BuildPlayScene();
            if (Application.isBatchMode) EditorApplication.Exit(0);
        }
    }
}
