# Repository Guidelines

## Project Structure & Module Organization

DinoImpact is a Unity 2022.3.62f3 game. Open `Assets/Scenes/DinoImpact.unity`; gameplay rules live in Lua under `Assets/StreamingAssets/Lua/`, while the C# layer in `Assets/SurfImpact/Scripts/` bridges Unity rendering, input, UI, audio, and Lua execution. Start with `main.lua` → `dino_game.lua`; active modules are `main.lua`, `dino_*.lua`, `input.lua`, `util.lua`, and `fx.lua`. Keep tunable values in `dino_config.lua` and static entity data in `dino_data.lua`. The other non-prefixed Lua files are legacy Surf code.

Editor and build-menu scripts live in `Assets/Editor/` and `Assets/SurfImpact/Scripts/Editor/`. Pixel art is in `Assets/Art/` and `Assets/Resources/Dino/`; design and troubleshooting notes are in `docs/`. Headless tests are in `tools/luatest/`. `Assets/Resources/DinoLua/` is generated from StreamingAssets for WebGL builds—edit the StreamingAssets source, not the mirror.

## Build, Test, and Development Commands

Open the project in Unity 2022.3.62f3, load `DinoImpact.unity`, and press Play.

```powershell
lua tools/luatest/dino_tests.lua       # Lua 5.4 (Windows)
lua5.4 tools/luatest/dino_tests.lua    # Lua 5.4 (Linux)
dotnet build Assembly-CSharp.csproj
dotnet build Assembly-CSharp-Editor.csproj
```

The Lua suite exercises gameplay headlessly and exits nonzero on failure. The `dotnet` commands are fast C# compile checks after Unity has generated its project files. Build players with `DinoImpact > Build Windows (exe)`, `Build Linux`, or `Build WebGL (itch)`; outputs go to the ignored `Builds/` directory.

## Coding Style & Naming Conventions

Use four-space indentation and match the surrounding style. C# uses `PascalCase` types and methods, `_camelCase` private fields, and the `DinoImpact` namespace. Lua modules use lowercase snake_case filenames such as `dino_player.lua`; prefer `local` state and keep gameplay behavior out of the C# host. No repository-wide linter or formatter is configured.

## Testing Guidelines

Add assertions to `tools/luatest/dino_tests.lua` for gameplay changes, using descriptive `check(...)` messages and a new `io.write` section when appropriate. Run the suite from the repository root because module paths are root-relative. Preserve `tools/luatest/mock_host.lua` as the host contract. `tools/luatest/legacy/` targets the retired Surf prototype. No coverage threshold or CI test job is configured; manually verify the affected Unity scene or build as well.

## Commit & Pull Request Guidelines

Write concise, imperative commit subjects describing one coherent change, for example: `Add one-click Windows/Linux build menu for sharing test builds`. Do not add agent attribution trailers. Pull requests should explain the behavior change, list tests and build targets checked, link relevant issues, and include screenshots or GIFs for visual/UI changes. Keep `Library/`, `Builds/`, `obj/`, and generated IDE files out of commits.
