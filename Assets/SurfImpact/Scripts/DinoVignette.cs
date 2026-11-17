using UnityEngine;

namespace DinoImpact
{
    // Edge darkening on the main camera (docs/lighting-plan.md 第 3 步).
    // Strength comes from DinoLighting.Vignette, which Lua sets each frame.
    // With strength 0 the image is copied untouched.
    [RequireComponent(typeof(Camera))]
    public class DinoVignette : MonoBehaviour
    {
        // Preferred path: a material in Assets/Resources/Dino that references
        // Surf/Vignette. Resources content is always packed into builds, while
        // Shader.Find on an Always Included shader was not reliable in the Windows
        // player (the first build logged "Surf/Vignette missing").
        const string ResourcePath = "Dino/DinoVignette";

        Material _mat;
        bool _ownsMat;
        bool _missing;

        void OnRenderImage(RenderTexture src, RenderTexture dst)
        {
            float strength = DinoLighting.Vignette;
            if (strength <= 0f || _missing || !EnsureMaterial())
            {
                Graphics.Blit(src, dst);
                return;
            }
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
