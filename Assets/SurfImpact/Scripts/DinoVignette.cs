using UnityEngine;

namespace DinoImpact
{
    // Edge darkening on the main camera (docs/lighting-plan.md 第 3 步).
    // Strength comes from DinoLighting.Vignette, which Lua sets each frame.
    // The same full-screen pass scatters daylight through moving cloud gaps.
    [RequireComponent(typeof(Camera))]
    public class DinoVignette : MonoBehaviour
    {
        // Preferred path: a material in Assets/Resources/Dino that references
        // Surf/Vignette. Resources content is always packed into builds, while
        // Shader.Find on an Always Included shader was not reliable in the Windows
        // player (the first build logged "Surf/Vignette missing").
        const string ResourcePath = "Dino/DinoVignette";

        Camera _camera;
        Material _mat;
        bool _ownsMat;
        bool _missing;

        void Awake() => _camera = GetComponent<Camera>();

        void OnRenderImage(RenderTexture src, RenderTexture dst)
        {
            float strength = DinoLighting.Vignette;
            if (_missing || !EnsureMaterial())
            {
                Graphics.Blit(src, dst);
                return;
            }
            Vector3 center = _camera.transform.position;
            float halfHeight = _camera.orthographicSize;
            _mat.SetVector("_CloudView", new Vector4(center.x, center.y, halfHeight * _camera.aspect, halfHeight));
            _mat.SetFloat("_Strength", strength);
            Graphics.Blit(src, dst, _mat);
        }

        bool EnsureMaterial()
        {
            if (_mat != null) return true;

            _mat = Resources.Load<Material>(ResourcePath);
            if (_mat != null) return true;

            Shader sh = Shader.Find("Surf/Vignette");
            if (sh == null)
            {
                Debug.LogWarning("[DinoVignette] Surf/Vignette missing, vignette disabled.");
                _missing = true;
                return false;
            }
            _mat = new Material(sh) { name = "DinoVignette" };
            _ownsMat = true;
            return true;
        }

        void OnDestroy()
        {
            // Only destroy the material we created; Resources assets are shared.
            if (_ownsMat && _mat != null) Destroy(_mat);
        }
    }
}
