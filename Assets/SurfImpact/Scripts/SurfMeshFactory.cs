using System.Collections.Generic;
using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// Runtime-generated low-poly meshes and prop assemblies. Everything the game
    /// shows is built here from primitives - no external art assets are used.
    /// </summary>
    public static class SurfMeshFactory
    {
        static readonly Dictionary<string, Mesh> Cache = new Dictionary<string, Mesh>();

        // ---------------------------------------------------------------- meshes

        class MB
        {
            public readonly List<Vector3> V = new List<Vector3>();
            public readonly List<int> T = new List<int>();
            public readonly List<Color> C = new List<Color>();
            public readonly List<Vector2> UV = new List<Vector2>();
            public bool WithColors;

            public int Add(Vector3 p, Color c, Vector2 uv)
            {
                V.Add(p);
                C.Add(c);
                UV.Add(uv);
                return V.Count - 1;
            }

            public void Tri(Vector3 a, Vector3 b, Vector3 c, Color col)
            {
                int ia = Add(a, col, Vector2.zero);
                int ib = Add(b, col, Vector2.zero);
                int ic = Add(c, col, Vector2.zero);
                T.Add(ia); T.Add(ib); T.Add(ic);
            }

            public void Tri(int a, int b, int c)
            {
                T.Add(a); T.Add(b); T.Add(c);
            }

            public void Quad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Color col)
            {
                Tri(a, b, c, col);
                Tri(a, c, d, col);
            }

            public Mesh Build(string name)
            {
                Mesh m = new Mesh { name = name };
                m.SetVertices(V);
                m.SetTriangles(T, 0);
                if (C.Count != V.Count) C.Clear();
                while (C.Count < V.Count) C.Add(Color.white);
                m.SetColors(C);
                m.SetUVs(0, UV);
                m.RecalculateNormals();
                m.RecalculateBounds();
                return m;
            }
        }

        static Mesh Get(string key, System.Func<Mesh> make)
        {
            if (!Cache.TryGetValue(key, out Mesh m) || m == null)
            {
                m = make();
                Cache[key] = m;
            }
            return m;
        }

        public static Mesh Cube()
        {
            return Get("cube", () =>
            {
                var b = new MB();
                Color c = Color.white;
                Vector3 p000 = new Vector3(-.5f, -.5f, -.5f), p100 = new Vector3(.5f, -.5f, -.5f),
                        p110 = new Vector3(.5f, .5f, -.5f), p010 = new Vector3(-.5f, .5f, -.5f),
                        p001 = new Vector3(-.5f, -.5f, .5f), p101 = new Vector3(.5f, -.5f, .5f),
                        p111 = new Vector3(.5f, .5f, .5f), p011 = new Vector3(-.5f, .5f, .5f);
                b.Quad(p001, p101, p111, p011, c); // +z
                b.Quad(p100, p000, p010, p110, c); // -z
                b.Quad(p101, p100, p110, p111, c); // +x
                b.Quad(p000, p001, p011, p010, c); // -x
                b.Quad(p010, p011, p111, p110, c); // +y
                b.Quad(p000, p100, p101, p001, c); // -y
                return b.Build("cube");
            });
        }

        public static Mesh Quad()
        {
            return Get("quad", () =>
            {
                var b = new MB();
                int a = b.Add(new Vector3(-.5f, 0f, -.5f), Color.white, new Vector2(0, 0));
                int c = b.Add(new Vector3(.5f, 0f, -.5f), Color.white, new Vector2(1, 0));
                int d = b.Add(new Vector3(.5f, 0f, .5f), Color.white, new Vector2(1, 1));
                int e = b.Add(new Vector3(-.5f, 0f, .5f), Color.white, new Vector2(0, 1));
                b.Tri(a, d, c); b.Tri(a, e, d);
                return b.Build("quad");
            });
        }

        public static Mesh Icosphere(int subdivisions)
        {
            string key = "ico" + subdivisions;
            return Get(key, () =>
            {
                float t = (1f + Mathf.Sqrt(5f)) / 2f;
                Vector3[] v =
                {
                    new Vector3(-1, t, 0), new Vector3(1, t, 0), new Vector3(-1, -t, 0), new Vector3(1, -t, 0),
                    new Vector3(0, -1, t), new Vector3(0, 1, t), new Vector3(0, -1, -t), new Vector3(0, 1, -t),
                    new Vector3(t, 0, -1), new Vector3(t, 0, 1), new Vector3(-t, 0, -1), new Vector3(-t, 0, 1),
                };
                int[] faces =
                {
                    0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11,
                    1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8,
                    3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9,
                    4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1,
                };
                var tris = new List<Vector3>();
                for (int i = 0; i < faces.Length; i += 3)
                {
                    tris.Add(v[faces[i]].normalized);
                    tris.Add(v[faces[i + 1]].normalized);
                    tris.Add(v[faces[i + 2]].normalized);
                }
                for (int s = 0; s < subdivisions; s++)
                {
                    var next = new List<Vector3>(tris.Count * 4);
                    for (int i = 0; i < tris.Count; i += 3)
                    {
                        Vector3 a = tris[i], b2 = tris[i + 1], c = tris[i + 2];
                        Vector3 ab = ((a + b2) * .5f).normalized;
                        Vector3 bc = ((b2 + c) * .5f).normalized;
                        Vector3 ca = ((c + a) * .5f).normalized;
                        next.Add(a); next.Add(ab); next.Add(ca);
                        next.Add(ab); next.Add(b2); next.Add(bc);
                        next.Add(ca); next.Add(bc); next.Add(c);
                        next.Add(ab); next.Add(bc); next.Add(ca);
                    }
                    tris = next;
                }
                var mb = new MB();
                for (int i = 0; i < tris.Count; i += 3) mb.Tri(tris[i], tris[i + 1], tris[i + 2], Color.white);
                return mb.Build("icosphere" + subdivisions);
            });
        }

        public static Mesh Cylinder(int segments, float radiusTop, float radiusBottom, float height, bool caps)
        {
            string key = $"cyl{segments}_{radiusTop}_{radiusBottom}_{height}_{caps}";
            return Get(key, () =>
            {
                var b = new MB();
                float half = height * .5f;
                for (int i = 0; i < segments; i++)
                {
                    float a0 = Mathf.PI * 2f * i / segments;
                    float a1 = Mathf.PI * 2f * (i + 1) / segments;
                    Vector3 t0 = new Vector3(Mathf.Cos(a0) * radiusTop, half, Mathf.Sin(a0) * radiusTop);
                    Vector3 t1 = new Vector3(Mathf.Cos(a1) * radiusTop, half, Mathf.Sin(a1) * radiusTop);
                    Vector3 b0 = new Vector3(Mathf.Cos(a0) * radiusBottom, -half, Mathf.Sin(a0) * radiusBottom);
                    Vector3 b1 = new Vector3(Mathf.Cos(a1) * radiusBottom, -half, Mathf.Sin(a1) * radiusBottom);
                    b.Quad(t0, b0, b1, t1, Color.white);
                    if (caps)
                    {
                        b.Tri(new Vector3(0, half, 0), t1, t0, Color.white);
                        b.Tri(new Vector3(0, -half, 0), b0, b1, Color.white);
                    }
                }
                return b.Build(key);
            });
        }

        public static Mesh Cone(int segments, float radius, float height)
        {
            string key = $"cone{segments}_{radius}_{height}";
            return Get(key, () =>
            {
                var b = new MB();
                Vector3 apex = new Vector3(0, height, 0);
                for (int i = 0; i < segments; i++)
                {
                    float a0 = Mathf.PI * 2f * i / segments;
                    float a1 = Mathf.PI * 2f * (i + 1) / segments;
                    Vector3 p0 = new Vector3(Mathf.Cos(a0) * radius, 0, Mathf.Sin(a0) * radius);
                    Vector3 p1 = new Vector3(Mathf.Cos(a1) * radius, 0, Mathf.Sin(a1) * radius);
                    b.Tri(apex, p0, p1, Color.white);
                    b.Tri(Vector3.zero, p1, p0, Color.white);
                }
                return b.Build(key);
            });
        }

        public static Mesh Torus(int ringSeg, int tubeSeg, float ringRadius, float tubeRadius)
        {
            string key = $"torus{ringSeg}_{tubeSeg}_{ringRadius}_{tubeRadius}";
            return Get(key, () =>
            {
                var b = new MB();
                // Ring lies in the XY plane, hole along Z (a coin standing upright).
                for (int i = 0; i < ringSeg; i++)
                {
                    float u0 = Mathf.PI * 2f * i / ringSeg;
                    float u1 = Mathf.PI * 2f * (i + 1) / ringSeg;
                    for (int j = 0; j < tubeSeg; j++)
                    {
                        float v0 = Mathf.PI * 2f * j / tubeSeg;
                        float v1 = Mathf.PI * 2f * (j + 1) / tubeSeg;
                        Vector3 p00 = TorusPoint(u0, v0, ringRadius, tubeRadius);
                        Vector3 p10 = TorusPoint(u1, v0, ringRadius, tubeRadius);
                        Vector3 p11 = TorusPoint(u1, v1, ringRadius, tubeRadius);
                        Vector3 p01 = TorusPoint(u0, v1, ringRadius, tubeRadius);
                        b.Quad(p00, p10, p11, p01, Color.white);
                    }
                }
                return b.Build(key);
            });
        }

        static Vector3 TorusPoint(float u, float v, float R, float r)
        {
            float rr = R + r * Mathf.Cos(v);
            return new Vector3(Mathf.Cos(u) * rr, Mathf.Sin(u) * rr, r * Mathf.Sin(v));
        }

        public static Mesh Board()
        {
            return Get("board", () =>
            {
                var b = new MB { WithColors = true };
                Vector2[] outline =
                {
                    new Vector2(0f, 1.18f), new Vector2(.27f, .78f), new Vector2(.33f, .15f),
                    new Vector2(.29f, -.55f), new Vector2(.17f, -.98f), new Vector2(0f, -1.16f),
                    new Vector2(-.17f, -.98f), new Vector2(-.29f, -.55f), new Vector2(-.33f, .15f),
                    new Vector2(-.27f, .78f),
                };
                const float h = .045f;
                Color top = new Color(.96f, .99f, 1f);
                Color bottom = new Color(.16f, .78f, .74f);
                Color rail = new Color(.10f, .55f, .56f);
                Vector3 up = new Vector3(0, h, 0), down = new Vector3(0, -h, 0);
                Vector3 centerTop = up, centerBottom = down;
                for (int i = 0; i < outline.Length; i++)
                {
                    Vector2 a = outline[i];
                    Vector2 c = outline[(i + 1) % outline.Length];
                    Vector3 at = new Vector3(a.x, h, a.y), ct = new Vector3(c.x, h, c.y);
                    Vector3 ab = new Vector3(a.x, -h, a.y), cb = new Vector3(c.x, -h, c.y);
                    b.Tri(centerTop, at, ct, top);
                    b.Tri(centerBottom, cb, ab, bottom);
                    b.Quad(at, ab, cb, ct, rail);
                }
                return b.Build("board");
            });
        }

        public static Mesh Wedge(float width, float length, float height)
        {
            string key = $"wedge{width}_{length}_{height}";
            return Get(key, () =>
            {
                var b = new MB { WithColors = true };
                float w = width * .5f, l = length * .5f;
                Vector3 f0 = new Vector3(-w, 0, -l), f1 = new Vector3(w, 0, -l);
                Vector3 b0 = new Vector3(-w, 0, l), b1 = new Vector3(w, 0, l);
                Vector3 t0 = new Vector3(-w, height, l), t1 = new Vector3(w, height, l);
                Color foam = new Color(.85f, 1f, 1f);
                Color side = new Color(.35f, .78f, .86f);
                Color back = new Color(.15f, .5f, .62f);
                b.Quad(f0, f1, t1, t0, foam);      // ramp surface
                b.Quad(b0, b1, t1, t0, back);      // back
                b.Quad(f0, f1, b1, b0, back);      // bottom
                b.Tri(f0, b0, t0, side);           // left
                b.Tri(f1, b1, t1, side);           // right
                return b.Build(key);
            });
        }

        public static Mesh Rock(int seed)
        {
            string key = "rock" + seed;
            return Get(key, () =>
            {
                Mesh ico = Icosphere(1);
                Vector3[] verts = ico.vertices;
                int[] tris = ico.triangles;
                var b = new MB { WithColors = true };
                var rnd = new System.Random(seed * 7919 + 13);
                // deterministic per-direction jitter so shared corners stay welded visually
                var cache = new Dictionary<Vector3, float>();
                float Patch(Vector3 p)
                {
                    Vector3 keyv = new Vector3(Mathf.Round(p.x * 100), Mathf.Round(p.y * 100), Mathf.Round(p.z * 100));
                    if (cache.TryGetValue(keyv, out float value)) return value;
                    float n = Mathf.PerlinNoise(p.x * 2.3f + seed * 3.1f, p.y * 2.3f + p.z * 1.7f + seed);
                    value = 0.78f + n * 0.42f;
                    cache[keyv] = value;
                    return value;
                }
                Color c1 = new Color(.42f, .45f, .48f);
                Color c2 = new Color(.55f, .56f, .54f);
                for (int i = 0; i < tris.Length; i += 3)
                {
                    Vector3 p0 = verts[tris[i]], p1 = verts[tris[i + 1]], p2 = verts[tris[i + 2]];
                    p0 = Vector3.Scale(p0 * Patch(p0), new Vector3(1.25f, .85f, 1.05f));
                    p1 = Vector3.Scale(p1 * Patch(p1), new Vector3(1.25f, .85f, 1.05f));
                    p2 = Vector3.Scale(p2 * Patch(p2), new Vector3(1.25f, .85f, 1.05f));
                    float shade = 0.8f + (float)rnd.NextDouble() * .25f;
                    Color col = Color.Lerp(c1, c2, (float)rnd.NextDouble()) * shade;
                    b.Tri(p0, p1, p2, col);
                }
                return b.Build(key);
            });
        }

        public static Mesh Island(int seed)
        {
            string key = "island" + seed;
            return Get(key, () =>
            {
                var b = new MB { WithColors = true };
                int rings = 6, seg = 16;
                var rnd = new System.Random(seed * 3571 + 7);
                Vector3[,] grid = new Vector3[rings + 1, seg];
                Color[,] cols = new Color[rings + 1, seg];
                float n = (float)rnd.NextDouble() * 10f;
                for (int ri = 0; ri <= rings; ri++)
                {
                    float t = (float)ri / rings;            // 0 outer .. 1 center
                    float radius = Mathf.Lerp(1f, 0.02f, t);
                    float height = Mathf.Pow(t, 1.7f) * 0.9f;
                    for (int si = 0; si < seg; si++)
                    {
                        float ang = Mathf.PI * 2f * si / seg;
                        float wob = 0.9f + Mathf.PerlinNoise(n + Mathf.Cos(ang) * 1.5f, n + 2.2f + Mathf.Sin(ang) * 1.5f) * 0.28f;
                        float rr = radius * wob;
                        float y = height * (0.88f + Mathf.PerlinNoise(n + 3 + si * .37f, ri * .6f) * .24f);
                        grid[ri, si] = new Vector3(Mathf.Cos(ang) * rr, y, Mathf.Sin(ang) * rr);
                        float elev = y / 0.9f;
                        Color sand = new Color(.90f, .78f, .55f);
                        Color grass = Color.Lerp(new Color(.30f, .62f, .36f), new Color(.20f, .45f, .28f), elev);
                        cols[ri, si] = elev < .16f ? Color.Lerp(sand, grass, elev / .16f * .25f) : Color.Lerp(grass, new Color(.25f, .35f, .22f), (elev - .16f) * .4f);
                    }
                }
                for (int ri = 0; ri < rings; ri++)
                {
                    for (int si = 0; si < seg; si++)
                    {
                        int sn = (si + 1) % seg;
                        Vector3 a = grid[ri, si], c = grid[ri, sn], d = grid[ri + 1, sn], e = grid[ri + 1, si];
                        Color ca = cols[ri, si], cc = cols[ri, sn], cd = cols[ri + 1, sn], ce = cols[ri + 1, si];
                        if (ri + 1 == rings)
                        {
                            b.Tri(a, c, d, Color.Lerp(ca, cc, .5f));
                        }
                        else
                        {
                            // per-vertex color is approximated with the face average
                            b.Tri(a, c, d, Color.Lerp(Color.Lerp(ca, cc, .5f), cd, .5f));
                            b.Tri(a, d, e, Color.Lerp(Color.Lerp(ca, cd, .5f), ce, .5f));
                        }
                    }
                }
                return b.Build(key);
            });
        }

        public static Mesh Leaf()
        {
            return Get("leaf", () =>
            {
                var b = new MB();
                const int steps = 4;
                for (int i = 0; i < steps; i++)
                {
                    float t0 = i / (float)steps, t1 = (i + 1) / (float)steps;
                    float w0 = (1 - t0) * .42f + .03f, w1 = (1 - t1) * .42f + .03f;
                    float y0 = -1.9f * t0 * t0, y1 = -1.9f * t1 * t1;
                    Vector3 a = new Vector3(t0 * 2.5f, y0, -w0);
                    Vector3 c = new Vector3(t0 * 2.5f, y0, w0);
                    Vector3 d = new Vector3(t1 * 2.5f, y1, w1);
                    Vector3 e = new Vector3(t1 * 2.5f, y1, -w1);
                    b.Quad(a, c, d, e, Color.white);
                    b.Quad(a, e, d, c, Color.white); // double sided
                }
                return b.Build("leaf");
            });
        }

        public static Mesh Fin()
        {
            return Get("fin", () =>
            {
                var b = new MB();
                Vector3 a = new Vector3(-.8f, 0, -.9f), c = new Vector3(.8f, 0, -.9f);
                Vector3 d = new Vector3(.5f, 0, 1.1f), e = new Vector3(-.5f, 0, 1.1f);
                Vector3 top = new Vector3(-.05f, 2.1f, .2f);
                b.Tri(a, c, top, Color.white);
                b.Tri(e, d, top, Color.white);
                b.Tri(a, e, top, Color.white);
                b.Tri(c, d, top, Color.white);
                b.Quad(a, c, d, e, Color.white);
                return b.Build("fin");
            });
        }

        public static Mesh Cloud(int seed)
        {
            string key = "cloud" + seed;
            return Get(key, () =>
            {
                Mesh ico = Icosphere(1);
                Vector3[] srcV = ico.vertices;
                int[] srcT = ico.triangles;
                var b = new MB();
                var rnd = new System.Random(seed * 97 + 31);
                var blobs = new Vector3[5];
                var scales = new float[5];
                for (int i = 0; i < blobs.Length; i++)
                {
                    blobs[i] = new Vector3((float)(rnd.NextDouble() - .5) * 5.2f, (float)(rnd.NextDouble() - .5) * 1.3f, (float)(rnd.NextDouble() - .5) * 2.2f);
                    scales[i] = .9f + (float)rnd.NextDouble() * 1.4f;
                }
                for (int i = 0; i < srcT.Length; i += 3)
                {
                    for (int bl = 0; bl < blobs.Length; bl++)
                    {
                        Vector3 p0 = srcV[srcT[i]] * scales[bl] + blobs[bl];
                        Vector3 p1 = srcV[srcT[i + 1]] * scales[bl] + blobs[bl];
                        Vector3 p2 = srcV[srcT[i + 2]] * scales[bl] + blobs[bl];
                        b.Tri(p0, p1, p2, Color.white);
                    }
                }
                return b.Build(key);
            });
        }

        // -------------------------------------------------------------- entities

        public static GameObject Create(string kind, int variant = 0)
        {
            switch (kind)
            {
                case "cube": return Simple("cube", Cube());
                case "sphere": return Simple("sphere", Icosphere(2));
                case "ico": return Simple("ico", Icosphere(1));
                case "cylinder": return Simple("cylinder", Cylinder(10, .5f, .5f, 2f, true));
                case "cone": return Simple("cone", Cone(10, .6f, 2f));
                case "torus": return Simple("torus", Torus(16, 8, .8f, .22f));
                case "quad": return Simple("quad", Quad());
                case "rock": return Simple("rock", Rock(variant % 4));
                case "island": return CreateIsland(variant % 3);
                case "palm": return CreatePalm(variant % 3);
                case "log": return CreateLog(variant);
                case "buoy": return CreateBuoy(variant);
                case "coin": return CreateCoin();
                case "heart": return CreateHeart();
                case "bolt": return CreateBolt();
                case "ramp": return CreateRamp();
                case "gate": return CreateGate(false);
                case "checkpoint": return CreateGate(true);
                case "surfer": return CreateSurfer(false, variant);
                case "rival": return CreateSurfer(true, variant);
                case "kraken": return CreateKraken();
                case "shark": return CreateShark();
                case "cloud": return Simple("cloud", Cloud(variant % 3));
                case "shadow": return CreateShadow();
                default: return Simple(kind, Cube());
            }
        }

        static GameObject Simple(string name, Mesh mesh, bool unlit = false)
        {
            var go = new GameObject(name);
            var mf = go.AddComponent<MeshFilter>();
            mf.sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = unlit ? SurfMaterials.Unlit : SurfMaterials.Flat;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            mr.receiveShadows = false;
            return go;
        }

        static GameObject Part(GameObject parent, string name, Mesh mesh, Vector3 pos, Vector3 euler, Vector3 scale, Color color, float emission = 0f, bool unlit = false)
        {
            var go = Simple(name, mesh, unlit);
            go.transform.SetParent(parent.transform, false);
            go.transform.localPosition = pos;
            go.transform.localRotation = Quaternion.Euler(euler);
            go.transform.localScale = scale;
            SurfMaterials.Tint(go, color, emission);
            return go;
        }

        static GameObject CreateIsland(int seed)
        {
            var root = new GameObject("island");
            var mesh = Island(seed);
            var body = Simple("island_body", mesh);
            body.transform.SetParent(root.transform, false);
            SurfMaterials.Tint(body, new Color(.92f, .86f, .70f));
            // palms on the summit
            int palms = 1 + (seed % 3);
            var rnd = new System.Random(seed * 131 + 5);
            for (int i = 0; i < palms; i++)
            {
                var palm = CreatePalm(seed + i);
                palm.transform.SetParent(root.transform, false);
                float ang = (float)rnd.NextDouble() * Mathf.PI * 2f;
                float rad = palms > 1 ? .12f + (float)rnd.NextDouble() * .18f : .05f;
                palm.transform.localPosition = new Vector3(Mathf.Cos(ang) * rad, .86f, Mathf.Sin(ang) * rad);
                palm.transform.localRotation = Quaternion.Euler(0, ang * Mathf.Rad2Deg, 0);
                palm.transform.localScale = Vector3.one * (0.42f + (float)rnd.NextDouble() * .16f);
            }
            // rocky outcrop
            var rock = Simple("island_rock", Rock(seed + 2));
            rock.transform.SetParent(root.transform, false);
            rock.transform.localPosition = new Vector3(.55f, .30f, -.35f);
            rock.transform.localScale = Vector3.one * .35f;
            SurfMaterials.Tint(rock, new Color(.48f, .47f, .44f));
            return root;
        }

        static GameObject CreatePalm(int seed)
        {
            var root = new GameObject("palm");
            var rnd = new System.Random(seed * 43 + 11);
            Vector3 pos = Vector3.zero;
            float bend = (float)(rnd.NextDouble() - .5) * 26f;
            Color trunkCol = new Color(.46f, .32f, .20f);
            for (int i = 0; i < 4; i++)
            {
                float h = .85f;
                var seg = Part(root, "trunk", Cylinder(7, .15f - i * .015f, .18f - i * .015f, h, false),
                    pos + new Vector3(0, h * .5f, 0), new Vector3(0, 0, bend * (i + 1) * .3f), Vector3.one, trunkCol);
                pos = seg.transform.localPosition + seg.transform.localRotation * new Vector3(0, h * .5f, 0);
            }
            Vector3 top = pos;
            int leaves = 7;
            for (int i = 0; i < leaves; i++)
            {
                float ang = i * (360f / leaves) + (float)rnd.NextDouble() * 20f;
                var leaf = Part(root, "leaf", Leaf(), top, new Vector3(0, ang, -8f - (float)rnd.NextDouble() * 18f), Vector3.one * .9f,
                    Color.Lerp(new Color(.16f, .48f, .24f), new Color(.28f, .66f, .30f), (float)rnd.NextDouble()));
                leaf.transform.localRotation = Quaternion.Euler(-18f - (float)rnd.NextDouble() * 14f, ang, 0);
            }
            for (int i = 0; i < 3; i++)
            {
                Part(root, "coconut", Icosphere(1), top + new Vector3((float)(rnd.NextDouble() - .5) * .35f, -.12f, (float)(rnd.NextDouble() - .5) * .35f),
                    Vector3.zero, Vector3.one * .16f, new Color(.30f, .22f, .12f));
            }
            return root;
        }

        static GameObject CreateLog(int variant)
        {
            var root = new GameObject("log");
            var body = Part(root, "log_body", Cylinder(8, .55f, .62f, 4.4f, true), Vector3.zero,
                new Vector3(0, 0, 90 + (variant % 3) * 13), Vector3.one, new Color(.43f, .29f, .18f));
            body.transform.localPosition = new Vector3(0, .12f, 0);
            var stub = Part(root, "branch", Cylinder(5, .12f, .16f, 1.2f, false), new Vector3(.9f, .55f, 0),
                new Vector3(0, 0, 55), Vector3.one, new Color(.38f, .25f, .15f));
            return root;
        }

        static GameObject CreateBuoy(int variant)
        {
            var root = new GameObject("buoy");
            Color bodyCol = variant == 1 ? new Color(.95f, .55f, .2f) : new Color(.96f, .96f, .92f);
            Part(root, "buoy_body", Cylinder(8, .5f, .62f, 2.2f, true), Vector3.zero, Vector3.zero, Vector3.one, bodyCol);
            Part(root, "buoy_band", Torus(12, 5, .58f, .10f), new Vector3(0, .45f, 0), new Vector3(90, 0, 0), Vector3.one, new Color(.9f, .2f, .2f));
            Part(root, "buoy_top", Icosphere(1), new Vector3(0, 1.2f, 0), Vector3.zero, Vector3.one * .55f, new Color(.95f, .22f, .18f), .3f);
            return root;
        }

        static GameObject WithMotion(GameObject root, float spin, float bob)
        {
            var visual = root.transform.Find("visual");
            if (visual != null)
            {
                var motion = visual.gameObject.AddComponent<BobSpin>();
                motion.spinSpeed = spin;
                motion.bobAmplitude = bob;
            }
            return root;
        }

        static GameObject CreateCoin()
        {
            var root = new GameObject("coin");
            var visual = new GameObject("visual").transform;
            visual.SetParent(root.transform, false);
            visual.localPosition = new Vector3(0, 1.5f, 0);
            Part(visual.gameObject, "coin_ring", Torus(16, 6, .85f, .22f), Vector3.zero, Vector3.zero, Vector3.one,
                new Color(1f, .78f, .20f), 1.8f);
            var inner = Part(visual.gameObject, "coin_core", Cylinder(12, .68f, .68f, .05f, true), Vector3.zero, new Vector3(90, 0, 0),
                Vector3.one * .85f, new Color(1f, .62f, .10f), 1.2f);
            var motion = visual.gameObject.AddComponent<BobSpin>();
            motion.spinSpeed = 150f;
            motion.bobAmplitude = .25f;
            return root;
        }

        static GameObject CreateHeart()
        {
            var root = new GameObject("heart");
            var visual = new GameObject("visual").transform;
            visual.SetParent(root.transform, false);
            visual.localPosition = new Vector3(0, 1.6f, 0);
            Color c = new Color(1f, .32f, .42f);
            Part(visual.gameObject, "heart_l", Icosphere(2), new Vector3(-.28f, .22f, 0), Vector3.zero, Vector3.one * .52f, c, 1.2f);
            Part(visual.gameObject, "heart_r", Icosphere(2), new Vector3(.28f, .22f, 0), Vector3.zero, Vector3.one * .52f, c, 1.2f);
            Part(visual.gameObject, "heart_b", Cube(), new Vector3(0, -.05f, 0), new Vector3(0, 0, 45), new Vector3(.72f, .72f, .35f), c, 1.2f);
            var motion = visual.gameObject.AddComponent<BobSpin>();
            motion.spinSpeed = 90f;
            motion.bobAmplitude = .22f;
            return root;
        }

        static GameObject CreateBolt()
        {
            var root = new GameObject("bolt");
            var visual = new GameObject("visual").transform;
            visual.SetParent(root.transform, false);
            visual.localPosition = new Vector3(0, 1.7f, 0);
            Color c = new Color(.35f, 1f, .45f);
            Part(visual.gameObject, "bolt_a", Cube(), new Vector3(.14f, .38f, 0), new Vector3(0, 0, -24), new Vector3(.22f, 1.0f, .16f), c, 2.2f);
            Part(visual.gameObject, "bolt_b", Cube(), new Vector3(-.13f, -.32f, 0), new Vector3(0, 0, -24), new Vector3(.22f, .95f, .16f), c, 2.2f);
            Part(visual.gameObject, "bolt_c", Cube(), new Vector3(.02f, .05f, 0), new Vector3(0, 0, 42), new Vector3(.2f, .5f, .16f), c, 2.2f);
            var motion = visual.gameObject.AddComponent<BobSpin>();
            motion.spinSpeed = 140f;
            motion.bobAmplitude = .3f;
            return root;
        }

        static GameObject CreateRamp()
        {
            var root = new GameObject("ramp");
            var body = Part(root, "ramp_body", Wedge(8f, 10f, 3.2f), Vector3.zero, Vector3.zero, Vector3.one, Color.white);
            body.transform.localPosition = new Vector3(0, -0.6f, 0);
            return root;
        }

        static GameObject CreateGate(bool checkpoint)
        {
            var root = new GameObject(checkpoint ? "checkpoint" : "gate");
            Color col = checkpoint ? new Color(1f, .78f, .18f) : new Color(.2f, .9f, .95f);
            float half = 7.5f;
            for (int s = -1; s <= 1; s += 2)
            {
                Part(root, "post", Cylinder(8, .35f, .48f, 6f, true), new Vector3(s * half, 3f, 0), Vector3.zero, Vector3.one,
                    new Color(.95f, .95f, .95f));
                Part(root, "post_top", Icosphere(1), new Vector3(s * half, 6.4f, 0), Vector3.zero, Vector3.one * .5f, col, .9f);
            }
            Part(root, "beam", Cube(), new Vector3(0, 6.4f, 0), Vector3.zero, new Vector3(half * 2.05f, .45f, .45f), col, .5f);
            Part(root, "banner", Cube(), new Vector3(0, 5.35f, 0), Vector3.zero, new Vector3(half * 2f, .9f, .14f), col, .7f);
            if (checkpoint)
            {
                // tall beacon so the checkpoint reads from far away
                var beam = Part(root, "beacon", Cylinder(8, .16f, .3f, 34f, false), new Vector3(0, 17f, 0), Vector3.zero, Vector3.one,
                    col, 2.2f, true);
                beam.GetComponent<MeshRenderer>().sharedMaterial = SurfMaterials.Additive;
            }
            return root;
        }

        static GameObject CreateSurfer(bool rival, int variant)
        {
            var root = new GameObject(rival ? "rival" : "surfer");
            Color[] shirts =
            {
                new Color(1f, .45f, .30f), new Color(.35f, .85f, .95f), new Color(.95f, .8f, .25f),
                new Color(.65f, .45f, .95f), new Color(.9f, .3f, .5f),
            };
            Color shirt = shirts[(rival ? variant + 1 : 0) % shirts.Length];
            Color skin = rival ? new Color(.80f, .60f, .42f) : new Color(.94f, .72f, .55f);
            Color shorts = rival ? new Color(.2f, .25f, .4f) : new Color(.10f, .22f, .35f);
            Color boardCol = rival ? new Color(.95f, .55f, .2f) : new Color(.2f, .85f, .80f);
            Color hair = rival ? new Color(.1f, .1f, .12f) : new Color(.25f, .16f, .1f);

            var board = new GameObject("board");
            board.transform.SetParent(root.transform, false);
            board.transform.localPosition = new Vector3(0, .08f, 0);
            var boardMesh = Part(board, "board_mesh", Board(), Vector3.zero, Vector3.zero, Vector3.one, boardCol);
            Part(board, "board_stripe", Cube(), new Vector3(0, .05f, -.15f), Vector3.zero, new Vector3(.06f, .02f, 1.9f), Color.white);
            Part(board, "fin", Cube(), new Vector3(0, -.18f, -.95f), new Vector3(20, 0, 0), new Vector3(.06f, .35f, .35f), new Color(.12f, .16f, .2f));

            var body = new GameObject("body").transform;
            body.SetParent(root.transform, false);
            body.localPosition = new Vector3(0, .14f, 0);

            // legs
            Part(body.gameObject, "leg_l", Cylinder(7, .11f, .13f, .58f, true), new Vector3(-.22f, .31f, .10f), new Vector3(0, 0, 8), Vector3.one, shorts);
            Part(body.gameObject, "leg_r", Cylinder(7, .11f, .13f, .58f, true), new Vector3(.22f, .31f, -.08f), new Vector3(0, 0, -8), Vector3.one, shorts);
            Part(body.gameObject, "hip", Cube(), new Vector3(0, .64f, .02f), new Vector3(0, 8, 0), new Vector3(.5f, .28f, .34f), shorts);

            var torso = Part(body.gameObject, "torso", Cylinder(8, .24f, .3f, .8f, true), new Vector3(0, 1.06f, .03f), new Vector3(8, 0, 0), Vector3.one, shirt);
            torso.transform.localPosition = new Vector3(0, 1.05f, .03f);
            var head = Part(body.gameObject, "head", Icosphere(2), new Vector3(0, 1.62f, .06f), Vector3.zero, Vector3.one * .48f, skin);
            Part(body.gameObject, "hair", Icosphere(2), new Vector3(0, 1.70f, .02f), new Vector3(-12, 0, 0), new Vector3(.5f, .34f, .46f), hair);
            Part(body.gameObject, "shades", Cube(), new Vector3(0, 1.63f, .25f), new Vector3(0, 0, 0), new Vector3(.36f, .09f, .1f), new Color(.05f, .06f, .08f));

            var armL = new GameObject("arm_l").transform;
            armL.SetParent(body, false);
            armL.localPosition = new Vector3(-.34f, 1.32f, .02f);
            Part(armL.gameObject, "upper", Cylinder(6, .075f, .09f, .52f, true), new Vector3(0, -.24f, 0), Vector3.zero, Vector3.one, skin);
            Part(armL.gameObject, "hand", Icosphere(1), new Vector3(0, -.5f, 0), Vector3.zero, Vector3.one * .13f, skin);
            armL.localRotation = Quaternion.Euler(0, 0, 62f);

            var armR = new GameObject("arm_r").transform;
            armR.SetParent(body, false);
            armR.localPosition = new Vector3(.34f, 1.32f, .02f);
            Part(armR.gameObject, "upper", Cylinder(6, .075f, .09f, .52f, true), new Vector3(0, -.24f, 0), Vector3.zero, Vector3.one, skin);
            Part(armR.gameObject, "hand", Icosphere(1), new Vector3(0, -.5f, 0), Vector3.zero, Vector3.one * .13f, skin);
            armR.localRotation = Quaternion.Euler(0, 0, -62f);

            var visual = root.AddComponent<SurferVisual>();
            visual.body = body;
            visual.armL = armL;
            visual.armR = armR;
            visual.board = board.transform;
            visual.root = root.transform;

            // wake trail
            var trailGo = new GameObject("wake");
            trailGo.transform.SetParent(board.transform, false);
            trailGo.transform.localPosition = new Vector3(0, .02f, -.9f);
            var trail = trailGo.AddComponent<TrailRenderer>();
            trail.time = .85f;
            trail.startWidth = 1.5f;
            trail.endWidth = .05f;
            trail.minVertexDistance = .25f;
            trail.material = SurfMaterials.Trail;
            var grad = new Gradient();
            grad.SetKeys(
                new[] { new GradientColorKey(new Color(.8f, 1f, 1f), 0f), new GradientColorKey(new Color(.3f, .85f, .9f), 1f) },
                new[] { new GradientAlphaKey(.55f, 0f), new GradientAlphaKey(0f, 1f) });
            trail.colorGradient = grad;
            trail.emitting = false;
            visual.trail = trail;

            var shadow = CreateShadow();
            shadow.name = "surfer_shadow";
            visual.shadow = shadow;
            shadow.transform.SetParent(root.transform, false);
            shadow.transform.localScale = new Vector3(2.1f, 1f, 3.6f);
            return root;
        }

        static GameObject CreateKraken()
        {
            var root = new GameObject("kraken");
            var visual = root.AddComponent<KrakenVisual>();
            Color bodyCol = new Color(.32f, .16f, .40f);
            Color dark = new Color(.20f, .09f, .26f);
            Part(root, "head", Icosphere(2), new Vector3(0, 1.6f, 0), Vector3.zero, new Vector3(3.1f, 2.2f, 3.1f), bodyCol);
            Part(root, "mantle", Icosphere(1), new Vector3(0, 3.1f, -.2f), new Vector3(0, 0, 0), new Vector3(2.2f, 1.9f, 2.2f), dark);
            for (int s = -1; s <= 1; s += 2)
            {
                Part(root, "eye_white", Icosphere(1), new Vector3(s * .9f, 2.3f, 2.55f), Vector3.zero, Vector3.one * .55f, Color.white, .4f);
                Part(root, "pupil", Icosphere(1), new Vector3(s * .9f, 2.35f, 2.95f), Vector3.zero, Vector3.one * .28f, new Color(.05f, .02f, .08f), 0f);
            }
            var tentacles = new List<Transform>();
            for (int i = 0; i < 8; i++)
            {
                float ang = i * 45f;
                var group = new GameObject("tentacle").transform;
                group.SetParent(root.transform, false);
                group.localRotation = Quaternion.Euler(0, ang, 0);
                var pivot = new GameObject("seg1").transform;
                pivot.SetParent(group, false);
                pivot.localRotation = Quaternion.Euler(72f, 0, 0);
                Part(pivot.gameObject, "seg", Cylinder(6, .34f, .46f, 2.6f, true), new Vector3(0, 1.3f, 0), Vector3.zero, Vector3.one, bodyCol);
                var pivot2 = new GameObject("seg2").transform;
                pivot2.SetParent(pivot, false);
                pivot2.localPosition = new Vector3(0, 2.6f, 0);
                pivot2.localRotation = Quaternion.Euler(-28f, 0, 0);
                Part(pivot2.gameObject, "seg", Cylinder(6, .18f, .32f, 2.4f, true), new Vector3(0, 1.2f, 0), Vector3.zero, Vector3.one, dark);
                var pivot3 = new GameObject("seg3").transform;
                pivot3.SetParent(pivot2, false);
                pivot3.localPosition = new Vector3(0, 2.4f, 0);
                pivot3.localRotation = Quaternion.Euler(-34f, 0, 0);
                Part(pivot3.gameObject, "seg", Cylinder(5, .05f, .17f, 2.2f, false), new Vector3(0, 1.1f, 0), Vector3.zero, Vector3.one, dark);
                visual.tentacles.Add(pivot);
                visual.tentacleTips.Add(pivot2);
                tentacles.Add(pivot3);
            }
            var shadow = CreateShadow();
            shadow.name = "kraken_shadow";
            visual.shadow = shadow;
            shadow.transform.SetParent(root.transform, false);
            shadow.transform.localScale = new Vector3(9f, 1f, 9f);
            return root;
        }

        static GameObject CreateShark()
        {
            var root = new GameObject("shark");
            var fin = Part(root, "fin", Fin(), new Vector3(0, -.1f, 0), Vector3.zero, Vector3.one, new Color(.30f, .35f, .38f));
            fin.transform.localPosition = new Vector3(0, .15f, 0);
            var body = Part(root, "body", Cylinder(8, .28f, .5f, 2.6f, true), new Vector3(0, -.4f, -.2f), new Vector3(90, 0, 0), Vector3.one, new Color(.24f, .28f, .32f));
            return root;
        }

        static GameObject CreateShadow()
        {
            var go = new GameObject("shadow");
            var mf = go.AddComponent<MeshFilter>();
            mf.sharedMesh = Quad();
            var mr = go.AddComponent<MeshRenderer>();
            mr.sharedMaterial = SurfMaterials.BlobShadow;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            mr.receiveShadows = false;
            return go;
        }

        public static void ClearCache()
        {
            Cache.Clear();
        }
    }
}
