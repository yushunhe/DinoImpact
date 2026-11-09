using UnityEngine;

namespace SurfImpact
{
    /// <summary>Infinite-looking ocean made from a camera-following displaced grid.</summary>
    public class SurfOcean : MonoBehaviour
    {
        public static SurfOcean Instance;
        const int Resolution = 160;
        const float Size = 640f;

        Material _water;
        Material _deep;
        MeshRenderer _waterRenderer;
        Transform _backdrop;
        Color _deepColor = new Color(.03f, .28f, .38f);
        Color _shallowColor = new Color(.2f, .8f, .78f);
        Color _foamColor = Color.white;
        Color _skyColor = new Color(.6f, .85f, .95f);
        Color _sunColor = Color.white;
        Vector3 _sunDir = Vector3.up;
        float _sunIntensity = 1f;

        public static SurfOcean Build()
        {
            var go = new GameObject("Ocean");
            var ocean = go.AddComponent<SurfOcean>();
            ocean.Create();
            return ocean;
        }

        void Create()
        {
            Instance = this;
            var mesh = BuildGrid();
            _waterRenderer = gameObject.AddComponent<MeshRenderer>();
            var mf = gameObject.AddComponent<MeshFilter>();
            mf.sharedMesh = mesh;

            Shader shader = Shader.Find("Surf/Water");
            if (shader == null)
            {
                Debug.LogError("[Surf] Missing shader Surf/Water");
                shader = Shader.Find("Standard");
            }
            _water = new Material(shader) { name = "SurfWater" };
            _waterRenderer.sharedMaterial = _water;
            _waterRenderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            _waterRenderer.receiveShadows = false;

            // A large, cheap plane below the waves hides the edge of the detailed grid.
            var deepGo = new GameObject("OceanBackdrop");
            deepGo.transform.SetParent(transform, false);
            deepGo.transform.localPosition = new Vector3(0, -2.4f, 0);
            deepGo.transform.localScale = new Vector3(5000f, 1f, 5000f);
            var dmf = deepGo.AddComponent<MeshFilter>();
            dmf.sharedMesh = SurfMeshFactory.Quad();
            var dmr = deepGo.AddComponent<MeshRenderer>();
            _deep = new Material(SurfMaterials.Unlit) { name = "DeepWater" };
            _deep.SetTexture("_MainTex", Texture2D.whiteTexture);
            dmr.sharedMaterial = _deep;
            dmr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            dmr.receiveShadows = false;
            _backdrop = deepGo.transform;

            ApplyLook();
        }

        Mesh BuildGrid()
        {
            int n = Resolution + 1;
            var verts = new Vector3[n * n];
            var uvs = new Vector2[n * n];
            var tris = new int[Resolution * Resolution * 6];
            float half = Size * .5f;
            for (int z = 0; z < n; z++)
            {
                for (int x = 0; x < n; x++)
                {
                    int i = z * n + x;
                    verts[i] = new Vector3(
                        -half + Size * x / Resolution,
                        0f,
                        -half + Size * z / Resolution);
                    uvs[i] = new Vector2((float)x / Resolution, (float)z / Resolution);
                }
            }
            int t = 0;
            for (int z = 0; z < Resolution; z++)
            {
                for (int x = 0; x < Resolution; x++)
                {
                    int i = z * n + x;
                    tris[t++] = i;
                    tris[t++] = i + n;
                    tris[t++] = i + 1;
                    tris[t++] = i + 1;
                    tris[t++] = i + n;
                    tris[t++] = i + n + 1;
                }
            }
            var mesh = new Mesh { name = "OceanGrid" };
            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            mesh.vertices = verts;
            mesh.uv = uvs;
            mesh.triangles = tris;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            return mesh;
        }

        public void SetLook(Color deep, Color shallow, Color foam, Color sky, Vector3 sunDir, Color sunColor, float sunIntensity)
        {
            _deepColor = deep;
            _shallowColor = shallow;
            _foamColor = foam;
            _skyColor = sky;
            _sunDir = sunDir.normalized;
            _sunColor = sunColor;
            _sunIntensity = sunIntensity;
            ApplyLook();
        }

        void ApplyLook()
        {
            if (_water == null) return;
            _water.SetColor("_DeepColor", _deepColor);
            _water.SetColor("_ShallowColor", _shallowColor);
            _water.SetColor("_FoamColor", _foamColor);
            _water.SetColor("_SkyColor", _skyColor);
            _water.SetVector("_SunDir", _sunDir);
            _water.SetColor("_SunColor", _sunColor * _sunIntensity);
            if (_deep != null) _deep.SetColor("_Color", Color.Lerp(_deepColor, _skyColor, .18f));
        }

        void LateUpdate()
        {
            Camera cam = Camera.main;
            if (cam == null) return;
            Vector3 p = cam.transform.position;
            transform.position = new Vector3(p.x, 0f, p.z);
            _water.SetFloat("_WaveTime", Time.time);
        }
    }
}
