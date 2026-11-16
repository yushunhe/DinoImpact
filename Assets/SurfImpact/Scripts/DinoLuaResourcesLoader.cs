using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;
using UnityEngine;

namespace DinoImpact
{
    /// <summary>
    /// Serves Lua modules from a Resources folder. StreamingAssets is a jar:
    /// URL on Android and HTTP on WebGL, so File/Directory APIs cannot see
    /// main.lua there; the editor build pipeline mirrors the Lua files into
    /// Assets/Resources/DinoLua as TextAssets and this loader feeds them to
    /// MoonSharp.
    /// </summary>
    public class DinoLuaResourcesLoader : ScriptLoaderBase
    {
        readonly string _root;

        public DinoLuaResourcesLoader(string root)
        {
            _root = (root ?? "DinoLua").TrimEnd('/');
            ModulePaths = new[] { "?.lua", "?/init.lua" };
        }

        static string ResourceName(string file)
        {
            return (file ?? "").Replace('\\', '/').TrimStart('/');
        }

        TextAsset Load(string file)
        {
            string name = ResourceName(file);
            // Mirrored files are named "<module>.lua.txt", so the resource is
            // "<module>.lua". MoonSharp usually passes the .lua suffix, but
            // accept the bare module name too.
            TextAsset asset = Resources.Load<TextAsset>(_root + "/" + name);
            if (asset == null && name.EndsWith(".lua"))
                asset = Resources.Load<TextAsset>(_root + "/" + name.Substring(0, name.Length - 4));
            if (asset == null)
                asset = Resources.Load<TextAsset>(_root + "/" + name + ".lua");
            return asset;
        }

        public override object LoadFile(string file, Table globalContext)
        {
            TextAsset asset = Load(file);
            if (asset == null)
                throw new ScriptRuntimeException("Lua module missing from Resources: " + file);
            return asset.text;
        }

        public override bool ScriptFileExists(string name)
        {
            return Load(name) != null;
        }
    }
}
