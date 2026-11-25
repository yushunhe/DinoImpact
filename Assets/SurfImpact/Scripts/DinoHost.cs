using System;
using System.Collections.Generic;
using MoonSharp.Interpreter;
using SurfImpact;
using UnityEngine;

namespace DinoImpact
{
    /// <summary>
    /// Small bridge between Lua and Unity for the 2D dinosaur runner.
    /// All rules live in Lua; this only exposes sprites, camera, UI and input.
    /// </summary>
    public class DinoHost
    {
        class EntityData
        {
            public int id;
            public string kind;
            public GameObject go;
            public SpriteRenderer sprite;
        }

        class TerrainData
        {
            public int id;
            public string kind;
            public GameObject go;
        }

        readonly DinoBootstrap _bootstrap;
        readonly Dictionary<int, EntityData> _entities = new Dictionary<int, EntityData>();
        readonly Dictionary<int, TerrainData> _terrain = new Dictionary<int, TerrainData>();
        readonly SurfInput _input = new SurfInput();

        Script _script;
        int _nextId = 1;
        int _nextTerrainId = 1;
        Camera _camera;
        SurfUI _ui;
        SurfAudio _audio;
        SurfParticles _fx;
        MeshRenderer _ground;
        Material _groundMat;
        Vector2 _groundUvPerUnit;
        Vector3 _camBase;

        // additive screen shake, decayed over _shakeTime
        float _shakeAmp;
        float _shakeDur;
        float _shakeTime;

        public SurfInput Input => _input;
        public SurfUI UI => _ui;
        public Camera Camera => _camera;

        public DinoHost(DinoBootstrap bootstrap)
        {
            _bootstrap = bootstrap;
        }

        // ------------------------------------------------------------- world setup

        public void BuildWorld()
        {
            var camGo = new GameObject("Main Camera");
            camGo.tag = "MainCamera";
            _camera = camGo.AddComponent<Camera>();
            camGo.AddComponent<DinoVignette>();   // edge darkening, strength from Lua (第 3 步)
            _camera.orthographic = true;
            _camera.orthographicSize = 6.5f;
            _camera.clearFlags = CameraClearFlags.SolidColor;
            _camera.backgroundColor = new Color(.09f, .15f, .08f, 1f);
            _camera.nearClipPlane = .1f;
            _camera.farClipPlane = 50f;
            _camBase = new Vector3(0f, 3.4f, -10f);
            _camera.transform.position = _camBase;
            camGo.AddComponent<AudioListener>();

            foreach (Camera c in UnityEngine.Object.FindObjectsOfType<Camera>())
                if (c != _camera) c.gameObject.SetActive(false);
            foreach (AudioListener l in UnityEngine.Object.FindObjectsOfType<AudioListener>())
                if (l.gameObject != camGo) l.gameObject.SetActive(false);
            foreach (Light l in UnityEngine.Object.FindObjectsOfType<Light>())
                if (l.type == LightType.Directional) l.gameObject.SetActive(false);

            SurfMaterials.Init();

            // One endless grass plane. It follows the camera and scrolls its UVs,
            // so the ground is infinite in every direction (no path edges).
            DinoLighting.Init();   // before any sprite: tint globals must be set first
            Sprite grass = DinoPixelArt.Get("ground_grass");
            const float groundSize = 120f;
            _groundUvPerUnit = new Vector2(grass.pixelsPerUnit / grass.texture.width,
                                           grass.pixelsPerUnit / grass.texture.height);
            _groundMat = MakeGroundMaterial(grass, groundSize * _groundUvPerUnit);
            // Keep the ground behind every gameplay sprite. Sprites are spawned
            // around z=0, so a ground plane at z=3 would depth-occlude them.
            _ground = MakeQuad("Ground", groundSize, _groundMat, 20f);
            // The ground shader also supports tiling/offset (see
            // MakeGroundMaterial); it is a transparent shader, so draw it before
            // every sprite explicitly instead of relying on depth.
            _ground.sortingOrder = -30000;

            _fx = SurfParticles.Build(_camera.transform);
            _audio = SurfAudio.Build(Resources.Load<AudioClip>("Dino/DawnInFernValley"));
            _audio.SetAmbient(true);

            SyncVisuals();
        }

        Material MakeGroundMaterial(Sprite sprite, Vector2 tiling)
        {
            // Surf/Sprite is in Always Included Shaders (player builds strip
            // unreferenced built-ins, see docs/green-screen-fix.md), honours
            // _MainTex_ST for the tiling, and carries the global time-of-day tint.
            var mat = DinoLighting.NewSpriteMaterial("DinoGround");
            mat.mainTexture = sprite.texture;
            mat.mainTextureScale = tiling;
            return mat;
        }

        MeshRenderer MakeQuad(string name, float length, Material mat, float z, float width = 0f)
        {
            float w = width > 0f ? width : length;
            var go = new GameObject(name);
            var filter = go.AddComponent<MeshFilter>();
            var mesh = new Mesh { name = name + "Mesh" };
            float hx = w * .5f, hy = length * .5f;
            mesh.vertices = new[]
            {
                new Vector3(-hx, -hy, 0f), new Vector3(hx, -hy, 0f),
                new Vector3(hx, hy, 0f), new Vector3(-hx, hy, 0f),
            };
            mesh.uv = new[]
            {
                new Vector2(0f, 0f), new Vector2(1f, 0f),
                new Vector2(1f, 1f), new Vector2(0f, 1f),
            };
            mesh.triangles = new[] { 0, 2, 1, 0, 3, 2 };
            mesh.RecalculateBounds();
            filter.sharedMesh = mesh;

            var renderer = go.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = mat;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            go.transform.position = new Vector3(0f, 0f, z);
            return renderer;
        }

        /// <summary>
        /// Keeps the endless ground under the camera base and applies screen shake.
        /// The ground follows the un-shaken base so the shake is actually visible.
        /// </summary>
        public void SyncVisuals()
        {
            if (_camera == null) return;
            Vector3 p = _camBase;

            if (_ground != null)
            {
                _ground.transform.position = new Vector3(p.x, p.y, _ground.transform.position.z);
                if (_groundMat != null)
                    _groundMat.mainTextureOffset = new Vector2(p.x * _groundUvPerUnit.x,
                                                              p.y * _groundUvPerUnit.y);
            }

            Vector3 shake = Vector3.zero;
            if (_shakeTime > 0f && _shakeDur > 0f)
            {
                float k = Mathf.Clamp01(_shakeTime / _shakeDur);
                float amp = _shakeAmp * k;
                shake = new Vector3(UnityEngine.Random.Range(-amp, amp), UnityEngine.Random.Range(-amp, amp), 0f);
            }
            _camera.transform.position = p + shake;
        }

        /// <summary>Starts a decaying screen shake (amplitude in world units).</summary>
        public void Shake(float amplitude, float duration)
        {
            if (amplitude <= 0f || duration <= 0f) return;
            // A stronger shake replaces a weaker one; otherwise add a little.
            _shakeAmp = Mathf.Max(amplitude, _shakeAmp * Mathf.Clamp01(_shakeTime / Mathf.Max(_shakeDur, .0001f)));
            _shakeDur = duration;
            _shakeTime = duration;
        }

        public void AttachScript(Script script)
        {
            _script = script;
            _ui = SurfUI.Build(script);
            _ui.OnButtonClick = _ => { };
            Register();
        }

        // ---------------------------------------------------------------- binding

        void Register()
        {
            var host = new Table(_script);
            var entity = new Table(_script);
            var world = new Table(_script);
            var camera = new Table(_script);
            var ui = new Table(_script);
            var audio = new Table(_script);
            var save = new Table(_script);
            var input = new Table(_script);
            var fx = new Table(_script);
            var terrain = new Table(_script);

            host.Set("version", DynValue.NewString("0.1"));
            host.Set("time", Fn((s, a) => DynValue.NewNumber(Time.time)));
            host.Set("log", Fn((s, a) =>
            {
                Debug.Log("[Dino/Lua] " + StrArg(a, 0, ""));
                return DynValue.Nil;
            }));

            // ------------------------------------------------------------- entity
            entity.Set("new", Fn((s, a) =>
            {
                string kind = StrArg(a, 0, "rock");
                float x = FArg(a, 1), y = FArg(a, 2), z = FArg(a, 3);
                return DynValue.NewNumber(Spawn(kind, x, y, z));
            }));
            entity.Set("kill", Fn((s, a) => { Kill(IntArg(a, 0)); return DynValue.Nil; }));
            entity.Set("clear", Fn((s, a) => { ClearEntities(); return DynValue.Nil; }));
            entity.Set("count", Fn((s, a) => DynValue.NewNumber(_entities.Count)));
            entity.Set("exists", Fn((s, a) => DynValue.NewBoolean(_entities.ContainsKey(IntArg(a, 0)))));
            entity.Set("setPos", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null)
                {
                    e.go.transform.position = new Vector3(FArg(a, 1), FArg(a, 2), FArg(a, 3));
                    Sort(e);
                }
                return DynValue.Nil;
            }));
            entity.Set("getPos", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e == null) return DynValue.NewTuple(DynValue.NewNumber(0), DynValue.NewNumber(0), DynValue.NewNumber(0));
                Vector3 p = e.go.transform.position;
                return DynValue.NewTuple(DynValue.NewNumber(p.x), DynValue.NewNumber(p.y), DynValue.NewNumber(p.z));
            }));
            entity.Set("setScale", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e == null) return DynValue.Nil;
                int n = a.Count;
                float x = FArg(a, 1, 1), y = n > 3 ? FArg(a, 2, 1) : x, z = n > 3 ? FArg(a, 3, 1) : x;
                e.go.transform.localScale = new Vector3(x, y, z);
                return DynValue.Nil;
            }));
            entity.Set("setRot", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) e.go.transform.rotation = Quaternion.Euler(FArg(a, 1), FArg(a, 2), FArg(a, 3));
                return DynValue.Nil;
            }));
            entity.Set("setColor", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.sprite != null) e.sprite.color = ColorArg(a, 1, Color.white);
                return DynValue.Nil;
            }));
            entity.Set("setSprite", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.sprite == null) return DynValue.Nil;
                e.sprite.sprite = DinoPixelArt.Get(StrArg(a, 1, e.kind));
                return DynValue.Nil;
            }));
            entity.Set("setFlip", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.sprite == null) return DynValue.Nil;
                e.sprite.flipX = BoolArg(a, 1, false);
                e.sprite.flipY = BoolArg(a, 2, false);
                return DynValue.Nil;
            }));
            entity.Set("setVisible", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) e.go.SetActive(BoolArg(a, 1, true));
                return DynValue.Nil;
            }));
            entity.Set("setOrder", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.sprite != null) e.sprite.sortingOrder = IntArg(a, 1, 0);
                return DynValue.Nil;
            }));
            // harmless compatibility methods for older scripting snippets
            entity.Set("setGlow", Fn((s, a) => DynValue.Nil));
            entity.Set("setFloat", Fn((s, a) => DynValue.Nil));
            entity.Set("setSpin", Fn((s, a) => DynValue.Nil));
            entity.Set("setLean", Fn((s, a) => DynValue.Nil));
            entity.Set("setAnim", Fn((s, a) => DynValue.Nil));
            entity.Set("setTrail", Fn((s, a) => DynValue.Nil));

            // ------------------------------------------------------------- terrain
            // Ground biome patches (fern / swamp) stamped on the endless grass
            // plane. x,y are the patch centre; w,h its world size.
            terrain.Set("add", Fn((s, a) =>
            {
                string kind = StrArg(a, 0, "fern");
                return DynValue.NewNumber(AddTerrain(kind, FArg(a, 1), FArg(a, 2),
                    FArg(a, 3, 6f), FArg(a, 4, 6f), IntArg(a, 5, 0)));
            }));
            terrain.Set("kill", Fn((s, a) => { KillTerrain(IntArg(a, 0)); return DynValue.Nil; }));
            terrain.Set("clear", Fn((s, a) => { ClearTerrain(); return DynValue.Nil; }));
            terrain.Set("count", Fn((s, a) => DynValue.NewNumber(_terrain.Count)));
            terrain.Set("exists", Fn((s, a) => DynValue.NewBoolean(_terrain.ContainsKey(IntArg(a, 0)))));

            // ----------------------------------------------------------------- fx
            fx.Set("event", Fn((s, a) =>
            {
                _fx?.Event(StrArg(a, 0, "splash"), new Vector3(FArg(a, 1), FArg(a, 2), 0f), FArg(a, 3, 1));
                return DynValue.Nil;
            }));

            // -------------------------------------------------------------- world
            world.Set("event", Fn((s, a) => DynValue.Nil));
            world.Set("setAmbient", Fn((s, a) => DynValue.Nil));
            world.Set("setTimeOfDay", Fn((s, a) => DynValue.Nil));
            // One call per frame from dino_light.lua: tint and lift go to the
            // shader globals, bg to the camera (docs/lighting-plan.md 第 1 步).
            world.Set("setTint", Fn((s, a) =>
            {
                DinoLighting.Apply(
                    new Color(FArg(a, 0, 1f), FArg(a, 1, 1f), FArg(a, 2, 1f)),
                    new Color(FArg(a, 3, 0f), FArg(a, 4, 0f), FArg(a, 5, 0f)),
                    FArg(a, 9, 0f));
                if (_camera != null)
                    _camera.backgroundColor = new Color(FArg(a, 6, .09f), FArg(a, 7, .15f), FArg(a, 8, .08f), 1f);
                return DynValue.Nil;
            }));
            // Local light sources (第 2 步): setLights(count, flat) where flat holds
            // 7 numbers per light: x, y, radius, r, g, b, intensity (1-based).
            world.Set("setLights", Fn((s, a) =>
            {
                int n = IntArg(a, 0, 0);
                Table flat = a.Count > 1 && a[1].Type == DataType.Table ? a[1].Table : null;
                int count = 0;
                if (flat != null)
                {
                    for (int k = 0; k < n && k < DinoLighting.MaxLights; k++)
                    {
                        int b = k * 7;
                        DinoLighting.SetLight(k,
                            (float)flat.Get(b + 1).Number, (float)flat.Get(b + 2).Number, (float)flat.Get(b + 3).Number,
                            new Color((float)flat.Get(b + 4).Number, (float)flat.Get(b + 5).Number, (float)flat.Get(b + 6).Number),
                            (float)flat.Get(b + 7).Number);
                        count++;
                    }
                }
                DinoLighting.CommitLights(count, FArg(a, 2, 0f), FArg(a, 3, 0f));
                return DynValue.Nil;
            }));

            // ------------------------------------------------------------- camera
            camera.Set("set2d", Fn((s, a) =>
            {
                _camBase = new Vector3(FArg(a, 0), FArg(a, 1), -10f);
                _camera.orthographic = true;
                _camera.orthographicSize = FArg(a, 2, 6.5f);
                SyncVisuals();
                return DynValue.Nil;
            }));
            camera.Set("shake", Fn((s, a) =>
            {
                Shake(FArg(a, 0, .3), FArg(a, 1, .3));
                return DynValue.Nil;
            }));
            camera.Set("setBackground", Fn((s, a) =>
            {
                _camera.backgroundColor = ColorArg(a, 0, new Color(.09f, .15f, .08f, 1f));
                return DynValue.Nil;
            }));
            camera.Set("getPos", Fn((s, a) =>
            {
                Vector3 p = _camBase;
                return DynValue.NewTuple(DynValue.NewNumber(p.x), DynValue.NewNumber(p.y), DynValue.NewNumber(p.z));
            }));

            // ----------------------------------------------------------------- ui
            ui.Set("label", Fn((s, a) =>
            {
                _ui.Label(StrArg(a, 0, "label"), StrArg(a, 1, ""), (float)NumArg(a, 2, .5), (float)NumArg(a, 3, .5),
                    (int)NumArg(a, 4, 28), ColorArg(a, 5, Color.white), StrArg(a, 6, "center"));
                return DynValue.Nil;
            }));
            ui.Set("panel", Fn((s, a) =>
            {
                _ui.Panel(StrArg(a, 0, "panel"), (float)NumArg(a, 1, .5), (float)NumArg(a, 2, .5),
                    (float)NumArg(a, 3, 600), (float)NumArg(a, 4, 300), ColorArg(a, 5, new Color(0f, 0f, 0f, .6f)));
                return DynValue.Nil;
            }));
            ui.Set("button", Fn((s, a) =>
            {
                string name = StrArg(a, 0, "button");
                DynValue cb = a.Count > 6 && a[6].Type == DataType.Function ? a[6] : null;
                _ui.Button(name, StrArg(a, 1, ""), (float)NumArg(a, 2, .5), (float)NumArg(a, 3, .5),
                    (float)NumArg(a, 4, 300), (float)NumArg(a, 5, 80), cb);
                return DynValue.Nil;
            }));
            ui.Set("bar", Fn((s, a) =>
            {
                _ui.Bar(StrArg(a, 0, "bar"), (float)NumArg(a, 1, .5), (float)NumArg(a, 2, .9),
                    (float)NumArg(a, 3, 400), (float)NumArg(a, 4, 14),
                    ColorArg(a, 5, new Color(0f, 0f, 0f, .5f)), ColorArg(a, 6, new Color(.3f, 1f, .8f)));
                return DynValue.Nil;
            }));
            ui.Set("setText", Fn((s, a) => { _ui.SetText(StrArg(a, 0, ""), StrArg(a, 1, "")); return DynValue.Nil; }));
            ui.Set("setColor", Fn((s, a) => { _ui.SetColor(StrArg(a, 0, ""), ColorArg(a, 1, Color.white)); return DynValue.Nil; }));
            ui.Set("setSize", Fn((s, a) => { _ui.SetSize(StrArg(a, 0, ""), (int)NumArg(a, 1, 30)); return DynValue.Nil; }));
            ui.Set("show", Fn((s, a) => { _ui.Show(StrArg(a, 0, ""), BoolArg(a, 1, true)); return DynValue.Nil; }));
            ui.Set("destroy", Fn((s, a) => { _ui.Destroy(StrArg(a, 0, "")); return DynValue.Nil; }));
            ui.Set("clear", Fn((s, a) => { _ui.Clear(); return DynValue.Nil; }));
            ui.Set("setBar", Fn((s, a) => { _ui.SetBar(StrArg(a, 0, ""), (float)NumArg(a, 1, 0)); return DynValue.Nil; }));
            ui.Set("setButtonSelected", Fn((s, a) => { _ui.SetButtonSelected(StrArg(a, 0, ""), BoolArg(a, 1, false)); return DynValue.Nil; }));
            ui.Set("setButtonColors", Fn((s, a) =>
            {
                _ui.SetButtonColors(StrArg(a, 0, ""), ColorArg(a, 1, Color.white), ColorArg(a, 2, Color.white));
                return DynValue.Nil;
            }));
            ui.Set("setFade", Fn((s, a) =>
            {
                _ui.SetFade((float)NumArg(a, 0, 0), ColorArg(a, 1, Color.black));
                return DynValue.Nil;
            }));
            ui.Set("setVignette", Fn((s, a) => { _ui.ShowVignette(BoolArg(a, 0, true)); return DynValue.Nil; }));
            ui.Set("exists", Fn((s, a) => DynValue.NewBoolean(_ui.Exists(StrArg(a, 0, "")))));
            ui.Set("setPos", Fn((s, a) =>
            {
                _ui.SetPos(StrArg(a, 0, ""), (float)NumArg(a, 1, .5), (float)NumArg(a, 2, .5));
                return DynValue.Nil;
            }));
            ui.Set("setScale", Fn((s, a) =>
            {
                float sx = FArg(a, 1, 1);
                _ui.SetScale(StrArg(a, 0, ""), sx, FArg(a, 2, sx));
                return DynValue.Nil;
            }));

            // -------------------------------------------------------------- audio
            audio.Set("play", Fn((s, a) =>
            {
                _audio?.Play(StrArg(a, 0, ""), (float)NumArg(a, 1, 1));
                return DynValue.Nil;
            }));
            audio.Set("music", Fn((s, a) =>
            {
                _audio?.SetMusic(BoolArg(a, 0, true));
                return DynValue.Nil;
            }));
            audio.Set("ambient", Fn((s, a) =>
            {
                _audio?.SetAmbient(BoolArg(a, 0, true));
                return DynValue.Nil;
            }));
            audio.Set("mute", Fn((s, a) =>
            {
                _audio?.SetMuted(BoolArg(a, 0, true));
                return DynValue.Nil;
            }));
            audio.Set("volume", Fn((s, a) =>
            {
                _audio?.SetMasterVolume((float)NumArg(a, 0, 1));
                return DynValue.Nil;
            }));

            // --------------------------------------------------------------- save
            save.Set("getInt", Fn((s, a) =>
                DynValue.NewNumber(PlayerPrefs.GetInt("dino_" + StrArg(a, 0, "key"), (int)NumArg(a, 1, 0)))));
            save.Set("setInt", Fn((s, a) =>
            {
                PlayerPrefs.SetInt("dino_" + StrArg(a, 0, "key"), (int)NumArg(a, 1, 0));
                PlayerPrefs.Save();
                return DynValue.Nil;
            }));
            save.Set("getStr", Fn((s, a) =>
                DynValue.NewString(PlayerPrefs.GetString("dino_" + StrArg(a, 0, "key"), StrArg(a, 1, "")))));
            save.Set("setStr", Fn((s, a) =>
            {
                PlayerPrefs.SetString("dino_" + StrArg(a, 0, "key"), StrArg(a, 1, ""));
                PlayerPrefs.Save();
                return DynValue.Nil;
            }));

            // -------------------------------------------------------------- input
            input.Set("axisH", Fn((s, a) => DynValue.NewNumber(_input.Horizontal)));
            input.Set("axisV", Fn((s, a) => DynValue.NewNumber(_input.Vertical)));
            input.Set("pause", Fn((s, a) => DynValue.NewBoolean(_input.PausePressed)));
            input.Set("boost", Fn((s, a) => DynValue.NewBoolean(_input.BoostPressed)));
            input.Set("restart", Fn((s, a) => DynValue.NewBoolean(_input.RestartPressed)));
            input.Set("confirm", Fn((s, a) => DynValue.NewBoolean(_input.ConfirmPressed)));
            input.Set("back", Fn((s, a) => DynValue.NewBoolean(_input.BackPressed)));
            input.Set("mute", Fn((s, a) => DynValue.NewBoolean(_input.MutePressed)));
            input.Set("anyKey", Fn((s, a) => DynValue.NewBoolean(_input.AnyKeyPressed)));
            input.Set("left", Fn((s, a) => DynValue.NewBoolean(_input.SelectLeftPressed)));
            input.Set("right", Fn((s, a) => DynValue.NewBoolean(_input.SelectRightPressed)));
            input.Set("up", Fn((s, a) => DynValue.NewBoolean(_input.SelectUpPressed)));
            input.Set("down", Fn((s, a) => DynValue.NewBoolean(_input.SelectDownPressed)));
            input.Set("number", Fn((s, a) => DynValue.NewBoolean(_input.NumberPressed((int)NumArg(a, 0)))));
            input.Set("shoot", Fn((s, a) => DynValue.NewBoolean(_input.ShootPressed)));
            input.Set("mount", Fn((s, a) => DynValue.NewBoolean(_input.MountPressed)));
            input.Set("skill", Fn((s, a) => DynValue.NewBoolean(_input.SkillPressed)));
            input.Set("stop", Fn((s, a) => DynValue.NewBoolean(_input.StopHeld)));

            host.Set("entity", DynValue.NewTable(entity));
            host.Set("world", DynValue.NewTable(world));
            host.Set("camera", DynValue.NewTable(camera));
            host.Set("ui", DynValue.NewTable(ui));
            host.Set("audio", DynValue.NewTable(audio));
            host.Set("save", DynValue.NewTable(save));
            host.Set("input", DynValue.NewTable(input));
            host.Set("fx", DynValue.NewTable(fx));
            host.Set("terrain", DynValue.NewTable(terrain));
            _script.Globals.Set("Host", DynValue.NewTable(host));
        }

        // ------------------------------------------------------------- entities

        int Spawn(string kind, float x, float y, float z)
        {
            DinoLighting.Init();
            int id = _nextId++;
            var go = new GameObject(kind + "_" + id);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = DinoPixelArt.Get(kind);
            sr.sharedMaterial = DinoLighting.SpriteMaterial;
            sr.color = Color.white;
            go.transform.position = new Vector3(x, y, z);

            var data = new EntityData { id = id, kind = kind, go = go, sprite = sr };
            Sort(data);
            _entities[id] = data;
            return id;
        }

        void Sort(EntityData e)
        {
            if (e?.sprite == null) return;
            e.sprite.sortingOrder = Mathf.RoundToInt(-e.go.transform.position.y * 8f);
        }

        EntityData Get(int id)
        {
            return _entities.TryGetValue(id, out EntityData e) && e.go != null ? e : null;
        }

        void Kill(int id)
        {
            if (!_entities.TryGetValue(id, out EntityData e)) return;
            if (e.go != null) UnityEngine.Object.Destroy(e.go);
            _entities.Remove(id);
        }

        void ClearEntities()
        {
            foreach (var e in _entities.Values)
                if (e.go != null) UnityEngine.Object.Destroy(e.go);
            _entities.Clear();
        }

        // -------------------------------------------------------------- terrain

        int AddTerrain(string kind, float x, float y, float w, float h, int variant)
        {
            if (kind != "fern" && kind != "swamp") kind = "fern";
            // Snap to whole 2-unit ground tiles so the patch pattern matches the
            // base plane's texel grid.
            int tx = Mathf.Clamp(Mathf.RoundToInt(w / 2f), 1, 12);
            int ty = Mathf.Clamp(Mathf.RoundToInt(h / 2f), 1, 12);

            int id = _nextTerrainId++;
            Texture2D tex = DinoPixelArt.GroundPatch(kind, tx, ty, variant);

            var mat = DinoLighting.NewSpriteMaterial("Terrain_" + kind + "_" + id);
            mat.mainTexture = tex;

            // Between the scrolling base plane (z=20) and gameplay sprites (z=0).
            // A tiny per-id offset keeps overlapping patch cores from z-fighting.
            float z = 19f - (id % 512) * .0005f;
            MeshRenderer r = MakeQuad("Terrain_" + kind + "_" + id, ty * 2f, mat, z, tx * 2f);
            r.transform.position = new Vector3(x, y, z);
            r.sortingOrder = -20000;   // under every sprite, over the base ground

            _terrain[id] = new TerrainData { id = id, kind = kind, go = r.gameObject };
            return id;
        }

        void KillTerrain(int id)
        {
            if (!_terrain.TryGetValue(id, out TerrainData d)) return;
            if (d.go != null) UnityEngine.Object.Destroy(d.go);
            _terrain.Remove(id);
        }

        void ClearTerrain()
        {
            foreach (var d in _terrain.Values)
                if (d.go != null) UnityEngine.Object.Destroy(d.go);
            _terrain.Clear();
        }

        // --------------------------------------------------------------- helpers

        static DynValue Fn(Func<ScriptExecutionContext, CallbackArguments, DynValue> f)
        {
            return DynValue.NewCallback(f);
        }

        static float FArg(CallbackArguments a, int i, double def = 0) => (float)NumArg(a, i, def);

        static double NumArg(CallbackArguments a, int i, double def = 0)
        {
            if (i >= a.Count) return def;
            var v = a[i];
            if (v.Type == DataType.Number) return v.Number;
            if (v.Type == DataType.String && double.TryParse(v.String, out double d)) return d;
            return def;
        }

        static int IntArg(CallbackArguments a, int i, int def = 0) => (int)NumArg(a, i, def);

        static string StrArg(CallbackArguments a, int i, string def = "")
        {
            if (i >= a.Count) return def;
            var v = a[i];
            if (v.Type == DataType.String) return v.String;
            if (v.Type == DataType.Nil) return def;
            return v.ToPrintString();
        }

        static bool BoolArg(CallbackArguments a, int i, bool def = false)
        {
            if (i >= a.Count) return def;
            var v = a[i];
            if (v.Type == DataType.Boolean) return v.Boolean;
            if (v.Type == DataType.Nil) return false;
            if (v.Type == DataType.Number) return v.Number != 0;
            return def;
        }

        static Color ColorArg(CallbackArguments a, int i, Color fallback)
        {
            if (i >= a.Count) return fallback;
            var v = a[i];
            if (v.Type == DataType.String) return SurfMaterials.Parse(v.String, fallback);
            if (v.Type == DataType.Number) return new Color(1f, 1f, 1f, (float)v.Number);
            return fallback;
        }

        // ------------------------------------------------------------- lifecycle

        public void Tick()
        {
            _input.Tick();
            if (_shakeTime > 0f)
                _shakeTime = Mathf.Max(0f, _shakeTime - Time.unscaledDeltaTime);
        }

        public void Destroy()
        {
            ClearEntities();
            ClearTerrain();
        }
    }
}
