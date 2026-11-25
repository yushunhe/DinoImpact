# DinoImpact 命令行调试手册

没有打开 Unity 编辑器窗口或双击游戏，也可以运行大部分检查。电脑关机时可以把命令交给另一台在线机器。玩法逻辑可以完全脱离 Unity，画面检查会由 Unity 批处理进程在后台加载真实场景，Windows 候选包则需要运行成品做验证。

| 要验证的问题 | 用什么 | 看什么结果 |
| --- | --- | --- |
| 碰撞、射箭、换乘、刷新、分数 | Lua 5.4 无头测试 | 断言结果和退出码 |
| Unity 导入、场景加载、Lua 桥接 | Unity 批处理进入 Play Mode | 初始化状态、运行错误和日志 |
| 像素图、相机比例、图层、林缘生成 | 同一场景的 RenderTexture 截图 | 同地点、同镜头的新旧截图 |
| Windows 包是否包含当前代码、能否跑动 | Unity Win64 构建、解包核对、运行成品 | 构建结果、包内文件、Player 日志和画面 |

## 1. 先把玩法问题缩到一段 Lua

在仓库根目录执行。Lua 的模块路径以仓库根目录为基准。

```bash
lua5.4 tools/luatest/dino_tests.lua
```

Windows 上可用 `lua`，先用 `lua -v` 确认是 5.4。成功时套件输出 `ALL DINO TESTS PASSED` 并返回 0。筛选或截取输出时记得保留原命令的退出状态，例如 Bash 中先执行 `set -o pipefail`。

套件加载真实的 `main.lua` 和玩法模块，把 Unity 提供给 Lua 的 `Host` 替换成内存实现。可以直接控制输入和时间，因此射箭回填、无敌和刷新频率都能稳定复现。

- 用 `startFresh()` 开局，再用 `Game.debugSpawnObstacle(...)`、`Game.debugSpawnMount(...)` 等只放入所需的对象。
- 用 `step(.05, { shoot = true })` 精确触发单帧输入，用 `steps(...)` 推进冷却。检查 `P`、`T`、`D`、`M` 或 `host._debug.entities()` 中的实际状态。
- 查自然刷新时用 `startLive()`，或者通过 `Game.debugEnableSpawning()` 重新开启普通刷怪、道具和障碍生成。检查依赖随机的场景时把 `math.randomseed(...)` 放在开局前。
- `Game.debugClearTrack()` 清理赛道物件和干扰龙，并暂停常规生成。小树林自己的生成计时器依然有效，纯场景复现需要走很远时可在测试中把 `Game.debugGetTrack().nextGrove` 设到足够远。

玩法改动把断言补在已有的测试小节。Unity 资源的导入设置、真实渲染和字体需要看下一步的场景或成品。 [Lua 套件](../tools/luatest/dino_tests.lua) · [Host 模拟](../tools/luatest/mock_host.lua) · [调试入口](../Assets/StreamingAssets/Lua/dino_game.lua)

## 2. 给 Unity 准备一份隔离副本

批处理会导入资源并写入 Unity 缓存。用临时副本可同时对照提交版和工作区，主项目还能在用户的编辑器里继续开着。下面是 **当前工作区** 的 Bash 示例，保留未提交的已跟踪修改和未忽略的新资源。

```bash
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dino-debug.XXXXXX")
project="$scratch/project"
artifacts="$scratch/artifacts"
mkdir -p "$project" "$artifacts"
cd "$repo"

git ls-files --cached --others --exclude-standard -z -- Assets Packages ProjectSettings |
  while IFS= read -r -d '' path; do
    if [[ -f "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
  done |
  tar --null -T - -cf - |
  tar -xf - -C "$project"

printf 'Debug artifacts: %s\n' "$artifacts"
```

只复现某个提交时，用 `git archive <提交> Assets Packages ProjectSettings | tar -xf - -C "$project"` 来填充一个空副本。两种取材方式择一。复制时包括 `.meta`、`Packages` 和 `ProjectSettings`。可复用一份已退出的同版本隔离工程的 `Library/` 加快导入，首次排查导入问题可用新缓存。

从 [ProjectVersion.txt](../ProjectSettings/ProjectVersion.txt) 读完整编辑器版本。新版素材调试实际使用了国际版 `2022.3.62f3 (96770f904ca7)`，本机的 `2022.3.62f3c1` 是另一份安装。

## 3. 用 Unity 真场景复现并截图

在上一步的 **临时副本** 新建 `Assets/Editor/DinoSceneProbe.cs`，填入下面的脚本。它用 `SessionState` 跨越进入 Play Mode 时的程序集重载，等游戏就绪后固定随机种子，摆一处树林并用锁定的相机取景。

```csharp
using System;
using System.IO;
using DinoImpact;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

[InitializeOnLoad]
public static class DinoSceneProbe
{
    const string Stage = "DinoSceneProbe.Stage";
    const string CaptureFrame = "DinoSceneProbe.CaptureFrame";

    static DinoSceneProbe()
    {
        EditorApplication.update += Poll;
    }

    public static void Run()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/DinoImpact.unity");
        SessionState.SetInt(Stage, 1);
        EditorApplication.EnterPlaymode();
    }

    static void Poll()
    {
        int stage = SessionState.GetInt(Stage, 0);
        if (stage == 0 || !EditorApplication.isPlaying || Time.frameCount < 4)
            return;

        try
        {
            var game = DinoBootstrap.Instance;
            if (game == null || !game.Ready || game.ErrorCount != 0)
                throw new InvalidOperationException("DinoImpact scene failed to start");

            if (stage == 1)
            {
                game.RunLua("math.randomseed(54); Game.startRun(); Game.debugClearTrack()");
                SessionState.SetInt(CaptureFrame, Time.frameCount + 3);
                SessionState.SetInt(Stage, 2);
                return;
            }

            if (Time.frameCount < SessionState.GetInt(CaptureFrame, 0))
                return;

            game.RunLua("Game.debugSpawnGroveField(-4, 1); Host.camera.set2d(-2, 6, 11.5)");
            game.Host.SyncVisuals();
            Capture(Camera.main);
            Debug.Log("DINO SCENE PROBE PASSED");
            Finish(0);
        }
        catch (Exception error)
        {
            Debug.LogException(error);
            Finish(1);
        }
    }

    static void Capture(Camera camera)
    {
        const int width = 960;
        const int height = 540;
        var path = Environment.GetEnvironmentVariable("DINO_PROBE_PNG");
        if (string.IsNullOrEmpty(path))
            throw new ArgumentException("Set DINO_PROBE_PNG to the output path");

        var previousTarget = camera.targetTexture;
        var previousActive = RenderTexture.active;
        float previousAspect = camera.aspect;
        var target = RenderTexture.GetTemporary(width, height, 24);
        var image = new Texture2D(width, height, TextureFormat.RGB24, false);

        try
        {
            camera.targetTexture = target;
            camera.aspect = (float)width / height;
            camera.Render();
            RenderTexture.active = target;
            image.ReadPixels(new Rect(0, 0, width, height), 0, 0);
            image.Apply();
            File.WriteAllBytes(path, image.EncodeToPNG());
        }
        finally
        {
            camera.targetTexture = previousTarget;
            camera.aspect = previousAspect;
            RenderTexture.active = previousActive;
            RenderTexture.ReleaseTemporary(target);
            UnityEngine.Object.Destroy(image);
        }
    }

    static void Finish(int code)
    {
        SessionState.SetInt(Stage, 0);
        EditorApplication.Exit(code);
    }
}
```

用 Linux 命令启动。这里需要能创建图形设备的环境，例如本机已有的图形会话。纯远程 shell 可以在有可用图形设备或软件渲染的显示环境里运行，也可以先跑 Lua 检查。

```bash
unity="${DINO_UNITY:-$HOME/Unity/Hub/Editor/2022.3.62f3/Editor/Unity}"
DINO_PROBE_PNG="$artifacts/woodland.png" \
timeout 300s "$unity" -batchmode -force-glcore \
  -projectPath "$project" -executeMethod DinoSceneProbe.Run \
  -logFile "$artifacts/scene.log"

rg -n 'DINO SCENE PROBE PASSED' "$artifacts/scene.log"
test -s "$artifacts/woodland.png"
```

截图命令要让图形设备初始化，所以只用 `-batchmode`，并在 Linux 上按需要选用 `-force-glcore`。这里由脚本完成后主动退出，提前加 `-quit` 会让进程在 Play Mode 检查完成前退出。日志优先看编译错误、Lua 异常或检查脚本打印的失败原因，进程跑到超时通常需要回看导入、授权和图形初始化停在哪一步。

### 把同一个探针用于不同问题

- 换镜头场景时，先用 `Game.debugSetPlayer({x=..., y=...})` 改玩家位置，再用 `require('dino_world').update(.05, Game.debugGetPlayer())` 生成该处的植被和地形。手动定位沼泽或蕨地时，也能用 `W.debugTerrainPlan(cx, cy).blobs[1]` 读地块中心。先确认该格确实有地貌。
- 查射箭或换乘时，同样通过 `DinoBootstrap.RunLua` 控制 Lua，可用 `require('input').setOverride({ shoot = true })` 后推进一次 `Game.update(.05)`，随后清掉覆盖输入。用 `CallLuaReturn("Game", "debugGetPlayer")` 或检查实际的 `SpriteRenderer` 断言画面所需状态。
- 用相同随机种子、世界坐标、相机尺寸和分辨率截前后两张。拿到 PNG 后，用 AI 的图片查看工具直接读取本地文件，无需从屏幕抓取编辑器窗口。移动相机后先调用 `Host.SyncVisuals()`，让无限地面和相机跟上新的位置。重开游戏后等几帧再截，Unity 会在帧末回收旧对象，同一帧立即重开并截图有时会拍到两份骑手。
- `Camera.Render()` 这条路适合比对游戏世界。主菜单和 HUD 是 Screen Space Overlay，验证按钮、字体或 HUD 要截实际 Game View 或 Player 窗口。 [Unity 启动与 Lua 桥接](../Assets/SurfImpact/Scripts/DinoBootstrap.cs) · [相机和地面同步](../Assets/SurfImpact/Scripts/DinoHost.cs)

### 先在文件层检查美术素材

贴图在游戏里表现不对时，先用 `magick identify` 看实际尺寸和通道，再检查 Unity 的 `.meta` 里对应的过滤模式、压缩和轴心。当前植被可用 `python3 tools/art/pixelate_gemini_plants.py --check` 检查白点。验证生成脚本可复现时，在临时副本连续生成两次，用 `sha256sum` 比较输出。尺寸正确、文件一致之后，再用同镜头截图确认枝叶和小角色在游戏大小下是否看得清。 [美术导出与素材位置](../Assets/Resources/Dino/README.txt)

## 4. 验证最终的 Windows 包

当问题只在打包后出现，或要交付 exe 时，从隔离副本构建 Win64。安装与项目相同版本的 Windows Build Support (Mono)。一键构建方法本身会设置 Mono 后端。

```bash
timeout 300s "$unity" -batchmode -nographics -quit -buildTarget Win64 \
  -projectPath "$project" -executeMethod DinoBuildMenu.BuildWindows \
  -logFile "$artifacts/win-build.log"

rg -n '\[DinoBuildMenu\] Succeeded:' "$artifacts/win-build.log"
player="$project/Builds/Win64"
file "$player/DinoImpact.exe"
diff -qr --exclude='*.meta' "$project/Assets/StreamingAssets" \
  "$player/DinoImpact_Data/StreamingAssets"
```

构建菜单会把结果写到日志，检查成功标记和实际的 exe。通过 `diff` 可确认包内 Lua 对应这次的源码，Unity 的 `.meta` 文件在构建时会被过滤。打 ZIP 时保留 exe、`DinoImpact_Data/`、`MonoBleedingEdge/` 和同目录 DLL，再用 `unzip -tq <包名>.zip` 验证压缩包。

Linux 上有 Wine 和可用显示环境时，可以用一个独立的 Wine prefix 运行解包后的 Windows 成品。让它以窗口模式启动，把 Player 日志写到指定路径，然后按 Enter 开始并截实际画面。下面的 logFile 写法适用于 Wine 的默认 Z 盘映射。

```bash
cd "$player"
WINEPREFIX="$scratch/wine" wine DinoImpact.exe -screen-fullscreen 0 \
  -screen-width 960 -screen-height 540 \
  -logFile "Z:$artifacts/windows-player.log"
```

之前用 Wine 验证 Win64 包能启动并跑动，也观察到新旧包在同一 Wine 环境中都出现菜单和 HUD 文本缺失。对比旧包可帮助判断问题是否由本次修改引入。需要确认目标机器上的字体、手感或分发兼容性时，在原生 Windows 验证成品。 [打包规则](assets-and-packaging.md) · [打包后渲染异常案例](green-screen-fix.md)

## 留下可复现的证据

在交接里写清楚测的是工作区还是某个提交，跑了哪条命令，结果是 Lua 断言、Unity 画面还是成品运行。附最相关的日志位置和同镜头截图。以后再接手时，从失败发生的那一层开始查。
