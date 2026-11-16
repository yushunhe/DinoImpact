using System;
using System.IO;
using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;
using UnityEngine;

namespace DinoImpact
{
    /// <summary>
    /// Loads Assets/StreamingAssets/Lua/main.lua and ticks the Lua game.
    /// Add this component to a scene object to boot Dino Impact.
    /// </summary>
    public class DinoBootstrap : MonoBehaviour
    {
        public static DinoBootstrap Instance { get; private set; }

        public bool Ready { get; private set; }
        public string LastError { get; private set; }
        public int ErrorCount { get; private set; }
        public Script Script => _script;
        public DinoHost Host => _host;

        DinoHost _host;
        Script _script;
        bool _fatal;

        void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            Application.targetFrameRate = 60;
            Application.runInBackground = true;
            QualitySettings.vSyncCount = 0;

            try
            {
                _host = new DinoHost(this);
                _host.BuildWorld();
                BootLua();
            }
            catch (Exception e)
            {
                Fail(e);
            }
        }

        string LuaDirectory
        {
            get
            {
                string candidate = Path.Combine(Application.streamingAssetsPath, "Lua");
                if (Directory.Exists(candidate)) return candidate;
                return Path.Combine(Application.dataPath, "StreamingAssets", "Lua");
            }
        }

        void BootLua()
        {
            string dir = LuaDirectory;
            string main = Path.Combine(dir, "main.lua");
            // Android ships StreamingAssets inside the APK (a jar: URL) and WebGL
            // serves it over HTTP, so the normal file APIs cannot read it there.
            // The build pipeline mirrors the same .lua files into
            // Assets/Resources/DinoLua for those platforms.
            bool packed = Application.platform == RuntimePlatform.Android ||
                          Application.platform == RuntimePlatform.WebGLPlayer ||
                          !File.Exists(main);
            if (packed && Resources.Load<TextAsset>("DinoLua/main.lua") == null)
                throw new FileNotFoundException("Lua entry point missing: " + main +
                    " (Android/WebGL build needs the DinoLua resources mirror)");

            Script.DefaultOptions.DebugPrint = s => Debug.Log("[Lua] " + s);
            if (packed)
            {
                Script.DefaultOptions.ScriptLoader = new DinoLuaResourcesLoader("DinoLua");
            }
            else
            {
                Script.DefaultOptions.ScriptLoader = new FileSystemScriptLoader
                {
                    ModulePaths = new[] { Path.Combine(dir, "?.lua"), Path.Combine(dir, "?", "init.lua") },
                };
            }

            _script = new Script(CoreModules.Preset_SoftSandbox | CoreModules.LoadMethods);
            _script.Options.DebugPrint = s => Debug.Log("[Lua] " + s);

            InstallFallbackRequire();
            _host.AttachScript(_script);
            _script.DoFile(packed ? "main.lua" : main);
            CallLua("Game", "init");
            Ready = true;
            Debug.Log("[Dino] Lua game loaded from " + (packed ? "Resources/DinoLua" : dir));
        }

        /// <summary>
        /// IL2CPP builds (WebGL/Android) can strip MoonSharp's managed
        /// registration of Lua's "require"; install an equivalent callback
        /// that goes through the active script loader. No-op when MoonSharp
        /// already provided require (editor/desktop Mono).
        /// </summary>
        void InstallFallbackRequire()
        {
            if (_script == null || _script.Globals.Get("require").Type == DataType.Function)
                return;

            var loaded = new Table(_script);
            DynValue require = DynValue.NewCallback((ctx, args) =>
            {
                if (args.Count < 1 || args[0].Type != DataType.String)
                    throw new ScriptRuntimeException("require: module name expected");

                string name = args[0].String;
                DynValue hit = loaded.Get(name);
                if (hit.Type != DataType.Nil) return hit;

                IScriptLoader loader = Script.DefaultOptions.ScriptLoader;
                string file = loader.ResolveModuleName(name, _script.Globals);
                if (string.IsNullOrEmpty(file)) file = name + ".lua";

                string source = loader.LoadFile(file, _script.Globals) as string;
                if (source == null)
                    throw new ScriptRuntimeException("require: no source for module '" + name + "'");

                DynValue result = _script.DoString(source, null, name + ".lua");
                if (result.Type == DataType.Nil) result = DynValue.True;
                loaded.Set(name, result);
                return result;
            });

            _script.Globals.Set("require", require);
            Debug.Log("[Dino] MoonSharp did not register require; installed fallback loader.");
        }

        void Update()
        {
            if (!Ready || _fatal) return;
            try
            {
                _host.Tick();
                float dt = Mathf.Min(Time.deltaTime, .05f);
                if (dt > 0f) CallLua("Game", "update", dt);
                _host.SyncVisuals();
            }
            catch (Exception e)
            {
                ErrorCount++;
                string detail = e is ScriptRuntimeException lua ? lua.DecoratedMessage : e.Message;
                Debug.LogError("[Dino] Lua update error (" + ErrorCount + "): " + detail + "\n" + e.StackTrace);
                if (ErrorCount == 1) ShowError("Lua error:\n" + e.Message);
                if (ErrorCount >= 10)
                {
                    _fatal = true;
                    Debug.LogError("[Dino] Too many Lua errors, stopping game loop.");
                }
            }
        }

        public DynValue CallLuaReturn(string table, string func, params object[] args)
        {
            if (_script == null) return DynValue.Nil;
            DynValue t = _script.Globals.Get(table);
            if (t == null || t.Type != DataType.Table) return DynValue.Nil;
            DynValue f = t.Table.Get(func);
            if (f == null || f.Type != DataType.Function) return DynValue.Nil;
            return _script.Call(f, args);
        }

        public void CallLua(string table, string func, params object[] args)
        {
            CallLuaReturn(table, func, args);
        }

        public void DebugStart()
        {
            CallLua("Game", "startRun");
        }

        /// <summary>Runs a Lua snippet in the live game. Handy from the editor.</summary>
        public void RunLua(string code)
        {
            if (_script != null) _script.DoString(code);
        }

        void ShowError(string message)
        {
            try
            {
                if (_host?.UI == null) return;
                _host.UI.Clear();
                _host.UI.Panel("err_bg", .5f, .5f, 1100f, 360f, new Color(.08f, .05f, .04f, .94f));
                _host.UI.Label("err_title", "DINO IMPACT - LUA ERROR", .5f, .34f, 44, new Color(1f, .35f, .3f), "center");
                _host.UI.Label("err_body", message, .5f, .52f, 22, Color.white, "center");
            }
            catch
            {
                // presentation error while presenting an error: ignore
            }
        }

        void Fail(Exception e)
        {
            LastError = e.ToString();
            Ready = false;
            if (e is ScriptRuntimeException lua)
                Debug.LogError("[Dino] Lua boot error: " + lua.DecoratedMessage);
            Debug.LogException(e);
            ShowError(e.Message);
        }

        void OnDestroy()
        {
            if (Instance == this) Instance = null;
            _host?.Destroy();
            PlayerPrefs.Save();
        }
    }
}
