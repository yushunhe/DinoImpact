using System;
using System.Collections.Generic;
using MoonSharp.Interpreter;
using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// Everything Lua is allowed to touch. The API surface is deliberately small:
    /// entities, camera, world, ui, audio, save and input. Game rules live in Lua.
    /// </summary>
    public class SurfHost
    {
        class EntityData
        {
            public int id;
            public string kind;
            public GameObject go;
            public SurferVisual surfer;
            public KrakenVisual kraken;
        }

        readonly SurfBootstrap _bootstrap;
        readonly Dictionary<int, EntityData> _entities = new Dictionary<int, EntityData>();
        Script _script;
        int _nextId = 1;
        Camera _camera;
        SurfEnvironment _env;
        SurfUI _ui;
        SurfAudio _audio;
        readonly SurfInput _input = new SurfInput();
        public SurfInput Input => _input;
        public SurfEnvironment Environment => _env;
        public SurfUI UI => _ui;
        public SurfAudio Audio => _audio;
        public Camera Camera => _camera;

        public SurfHost(SurfBootstrap bootstrap)
        {
            _bootstrap = bootstrap;
        }

        // ------------------------------------------------------------- world setup

        public void BuildWorld()
        {
            SurfMaterials.Init();

            var camGo = new GameObject("Main Camera");
            camGo.tag = "MainCamera";
            _camera = camGo.AddComponent<Camera>();
            _camera.clearFlags = CameraClearFlags.Skybox;
            _camera.fieldOfView = 55f;
            _camera.nearClipPlane = .1f;
            _camera.farClipPlane = 750f;
            camGo.AddComponent<AudioListener>();
            camGo.transform.position = new Vector3(0f, 10f, -22f);
            camGo.transform.LookAt(new Vector3(0f, 2f, 0f));

            // make sure a scene-authored camera/light can't fight with ours
            foreach (Camera c in UnityEngine.Object.FindObjectsOfType<Camera>())
                if (c != _camera) c.gameObject.SetActive(false);
            foreach (AudioListener l in UnityEngine.Object.FindObjectsOfType<AudioListener>())
                if (l.gameObject != camGo) l.gameObject.SetActive(false);
            foreach (Light l in UnityEngine.Object.FindObjectsOfType<Light>())
                if (l.type == LightType.Directional) l.gameObject.SetActive(false);

            _audio = SurfAudio.Build();
            _env = new SurfEnvironment();
            _env.Build(_camera);
        }

        public void AttachScript(Script script)
        {
            _script = script;
            _ui = SurfUI.Build(script);
            _ui.OnButtonClick = _ => _audio.Play("click", .8f);
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

            host.Set("version", DynValue.NewString("1.0"));
            host.Set("time", Fn((s, a) => DynValue.NewNumber(Time.time)));
            host.Set("log", Fn((s, a) =>
            {
                Debug.Log("[Lua] " + StrArg(a, 0, ""));
                return DynValue.Nil;
            }));

            // ------------------------------------------------------------- entity
            entity.Set("new", Fn((s, a) =>
            {
                string kind = StrArg(a, 0, "cube");
                float x = FArg(a, 1), y = FArg(a, 2), z = FArg(a, 3);
                int variant = (int)NumArg(a, 4, 0);
                return DynValue.NewNumber(Spawn(kind, x, y, z, variant));
            }));
            entity.Set("kill", Fn((s, a) => { Kill(IntArg(a, 0)); return DynValue.Nil; }));
            entity.Set("clear", Fn((s, a) => { ClearEntities(); return DynValue.Nil; }));
            entity.Set("count", Fn((s, a) => DynValue.NewNumber(_entities.Count)));
            entity.Set("exists", Fn((s, a) => DynValue.NewBoolean(_entities.ContainsKey(IntArg(a, 0)))));
            entity.Set("setPos", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) e.go.transform.position = new Vector3(FArg(a, 1), FArg(a, 2), FArg(a, 3));
                return DynValue.Nil;
            }));
            entity.Set("getPos", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e == null) return DynValue.NewTuple(DynValue.NewNumber(0), DynValue.NewNumber(0), DynValue.NewNumber(0));
                Vector3 p = e.go.transform.position;
                return DynValue.NewTuple(DynValue.NewNumber(p.x), DynValue.NewNumber(p.y), DynValue.NewNumber(p.z));
            }));
            entity.Set("setRot", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) e.go.transform.rotation = Quaternion.Euler(FArg(a, 1), FArg(a, 2), FArg(a, 3));
                return DynValue.Nil;
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
            entity.Set("setColor", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) SurfMaterials.Tint(e.go, ColorArg(a, 1, Color.white));
                return DynValue.Nil;
            }));
            entity.Set("setGlow", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) SurfMaterials.Tint(e.go, ColorArg(a, 1, Color.white), (float)NumArg(a, 2, 1.5));
                return DynValue.Nil;
            }));
            entity.Set("setVisible", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e != null) e.go.SetActive(BoolArg(a, 1, true));
                return DynValue.Nil;
            }));
            entity.Set("setFloat", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e == null) return DynValue.Nil;
                var f = e.go.GetComponent<FloatOnWater>();
                if (f == null) f = e.go.AddComponent<FloatOnWater>();
                f.heightOffset = (float)NumArg(a, 1, 0);
                f.tilt = BoolArg(a, 2, true);
                return DynValue.Nil;
            }));
            entity.Set("setSpin", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e == null) return DynValue.Nil;
                var spin = e.go.GetComponentInChildren<BobSpin>();
                if (spin != null)
                {
                    spin.spinSpeed = (float)NumArg(a, 1, 120);
                    spin.bobAmplitude = (float)NumArg(a, 2, .25);
                }
                return DynValue.Nil;
            }));
            entity.Set("setLean", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.surfer != null) e.surfer.SetPose((float)NumArg(a, 1), (float)NumArg(a, 2), (float)NumArg(a, 3, 10));
                return DynValue.Nil;
            }));
            entity.Set("setAnim", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.kraken != null) e.kraken.SetAggro((float)NumArg(a, 1));
                return DynValue.Nil;
            }));
            entity.Set("setTrail", Fn((s, a) =>
            {
                var e = Get(IntArg(a, 0));
                if (e?.surfer != null)
                    e.surfer.SetTrail(BoolArg(a, 1, false), ColorArg(a, 2, new Color(.6f, 1f, 1f)),
                        (float)NumArg(a, 3, 1.5), (float)NumArg(a, 4, .85));
                return DynValue.Nil;
            }));

            // -------------------------------------------------------------- world
            world.Set("waveHeight", Fn((s, a) =>
            {
                float x = (float)NumArg(a, 0), z = (float)NumArg(a, 1);
                float t = a.Count > 2 ? (float)NumArg(a, 2) : Time.time;
                return DynValue.NewNumber(WaveMath.Height(x, z, t));
            }));
            world.Set("setTimeOfDay", Fn((s, a) =>
            {
                _env.SetTimeOfDay((float)NumArg(a, 0));
                return DynValue.Nil;
            }));
            world.Set("setWeather", Fn((s, a) =>
            {
                _env.SetWeather(StrArg(a, 0, "none"));
                return DynValue.Nil;
            }));
            world.Set("event", Fn((s, a) =>
            {
                string kind = StrArg(a, 0, "splash");
                var pos = new Vector3((float)NumArg(a, 1), (float)NumArg(a, 2), (float)NumArg(a, 3));
                _env.Fx.Event(kind, pos, (float)NumArg(a, 4, 1));
                return DynValue.Nil;
            }));
            world.Set("splash", Fn((s, a) =>
            {
                float x = (float)NumArg(a, 0), z = (float)NumArg(a, 1);
                float y = WaveMath.Height(x, z, Time.time);
                _env.Fx.Splash(new Vector3(x, y + .1f, z), (float)NumArg(a, 2, 1));
                return DynValue.Nil;
            }));

            // ------------------------------------------------------------- camera
            camera.Set("set", Fn((s, a) =>
            {
                _camera.transform.position = new Vector3((float)NumArg(a, 0), (float)NumArg(a, 1), (float)NumArg(a, 2));
                _camera.transform.LookAt(new Vector3((float)NumArg(a, 3), (float)NumArg(a, 4), (float)NumArg(a, 5)));
                if (a.Count > 6) _camera.fieldOfView = (float)NumArg(a, 6, 55);
                return DynValue.Nil;
            }));
            camera.Set("setFov", Fn((s, a) =>
            {
                _camera.fieldOfView = (float)NumArg(a, 0, 55);
                return DynValue.Nil;
            }));
            camera.Set("getPos", Fn((s, a) =>
            {
                Vector3 p = _camera.transform.position;
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

            // -------------------------------------------------------------- audio
            audio.Set("play", Fn((s, a) =>
            {
                _audio.Play(StrArg(a, 0, "click"), (float)NumArg(a, 1, 1));
                return DynValue.Nil;
            }));
            audio.Set("music", Fn((s, a) => { _audio.SetMusic(BoolArg(a, 0, true)); return DynValue.Nil; }));
            audio.Set("ambient", Fn((s, a) => { _audio.SetAmbient(BoolArg(a, 0, true)); return DynValue.Nil; }));
            audio.Set("mute", Fn((s, a) => { _audio.SetMuted(BoolArg(a, 0, false)); return DynValue.Nil; }));
            audio.Set("volume", Fn((s, a) => { _audio.SetMasterVolume((float)NumArg(a, 0, .8)); return DynValue.Nil; }));

            // --------------------------------------------------------------- save
            save.Set("getInt", Fn((s, a) =>
                DynValue.NewNumber(PlayerPrefs.GetInt("surf_" + StrArg(a, 0, "key"), (int)NumArg(a, 1, 0)))));
            save.Set("setInt", Fn((s, a) =>
            {
                PlayerPrefs.SetInt("surf_" + StrArg(a, 0, "key"), (int)NumArg(a, 1, 0));
                PlayerPrefs.Save();
                return DynValue.Nil;
            }));
            save.Set("getStr", Fn((s, a) =>
                DynValue.NewString(PlayerPrefs.GetString("surf_" + StrArg(a, 0, "key"), StrArg(a, 1, "")))));
            save.Set("setStr", Fn((s, a) =>
            {
                PlayerPrefs.SetString("surf_" + StrArg(a, 0, "key"), StrArg(a, 1, ""));
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

            host.Set("entity", DynValue.NewTable(entity));
            host.Set("world", DynValue.NewTable(world));
            host.Set("camera", DynValue.NewTable(camera));
            host.Set("ui", DynValue.NewTable(ui));
            host.Set("audio", DynValue.NewTable(audio));
            host.Set("save", DynValue.NewTable(save));
            host.Set("input", DynValue.NewTable(input));
            _script.Globals.Set("Host", DynValue.NewTable(host));
        }

        // ------------------------------------------------------------- entities

        int Spawn(string kind, float x, float y, float z, int variant)
        {
            int id = _nextId++;
            GameObject go;
            try
            {
                go = SurfMeshFactory.Create(kind, variant);
            }
            catch (Exception e)
            {
                Debug.LogError("[Surf] Failed to create '" + kind + "': " + e);
                go = new GameObject("bad_" + kind);
            }
            go.name = kind + "_" + id;
            go.transform.position = new Vector3(x, y, z);
            var data = new EntityData
            {
                id = id,
                kind = kind,
                go = go,
                surfer = go.GetComponent<SurferVisual>(),
                kraken = go.GetComponent<KrakenVisual>(),
            };
            _entities[id] = data;
            return id;
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
        }

        public void Destroy()
        {
            ClearEntities();
        }
    }
}
