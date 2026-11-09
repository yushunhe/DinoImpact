using System;
using System.IO;
using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;
using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// Entry point. Builds the Unity side, boots MoonSharp and pumps the Lua game
    /// loop. All gameplay lives in Assets/StreamingAssets/Lua and can be edited
    /// without touching C# or restarting the editor.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class SurfBootstrap : MonoBehaviour
    {
        public static SurfBootstrap Instance { get; private set; }

        public bool Ready { get; private set; }
        public string LastError { get; private set; }
        public int ErrorCount { get; private set; }
        public Script Script => _script;
        public SurfHost Host => _host;

        SurfHost _host;
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
                _host = new SurfHost(this);
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
                candidate = Path.Combine(Application.dataPath, "StreamingAssets", "Lua");
                return candidate;
            }
        }

        void BootLua()
        {
            string dir = LuaDirectory;
            string main = Path.Combine(dir, "main.lua");
            if (!File.Exists(main))
                throw new FileNotFoundException("Lua entry point missing: " + main);

            Script.DefaultOptions.DebugPrint = s => Debug.Log("[Lua] " + s);
            var loader = new FileSystemScriptLoader
            {
                ModulePaths = new[] { Path.Combine(dir, "?.lua"), Path.Combine(dir, "?", "init.lua") },
            };
            Script.DefaultOptions.ScriptLoader = loader;

            _script = new Script(CoreModules.Preset_SoftSandbox | CoreModules.LoadMethods);
            _script.Options.DebugPrint = s => Debug.Log("[Lua] " + s);

            _host.AttachScript(_script);
            _script.DoFile(main);
            CallLua("Game", "init");
            Ready = true;
            Debug.Log("[Surf] Lua game loaded from " + dir);
        }

        void Update()
        {
            if (!Ready || _fatal) return;

            try
            {
                _host.Tick();
                float dt = Mathf.Min(Time.deltaTime, .05f);
                if (dt > 0f) CallLua("Game", "update", dt);
            }
            catch (Exception e)
            {
                ErrorCount++;
                Debug.LogError("[Surf] Lua update error (" + ErrorCount + "): " + e.Message + "\n" + e.StackTrace);
                if (ErrorCount == 1) ShowError("Lua error:\n" + e.Message);
                if (ErrorCount >= 10)
                {
                    _fatal = true;
                    Debug.LogError("[Surf] Too many Lua errors, stopping game loop.");
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

        void ShowError(string message)
        {
            try
            {
                if (_host?.UI == null) return;
                _host.UI.Clear();
                _host.UI.Panel("err_bg", .5f, .5f, 1200f, 420f, new Color(.08f, .05f, .08f, .92f));
                _host.UI.Label("err_title", "SURF IMPACT - LUA ERROR", .5f, .34f, 46, new Color(1f, .35f, .35f), "center");
                _host.UI.Label("err_body", message, .5f, .52f, 24, Color.white, "center");
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
