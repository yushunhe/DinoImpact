# DinoImpact（恐龙冲击）— 项目须知

Unity 原型 + Lua 玩法。设计文档：`docs/design-plan.md`（五档朝向、3 心、射箭、六类障碍、干扰龙事件、换骑、技能、四项结算——全部已实现）。

## 环境与版本

- Unity **2022.3.62f3c1**（国服版；国际版对应 2022.3.62f3，工程可开，仅版本差异提示）。场景：`Assets/Scenes/DinoImpact.unity`。
- C# 只做宿主：`Assets/SurfImpact/Scripts/DinoHost.cs`（MoonSharp 跑 Lua）、`DinoPixelArt.cs`（运行时生成占位像素图，美术后续会换）。
- **玩法全在 Lua**：`Assets/StreamingAssets/Lua/`。入口 `main.lua` → `dino_game.lua`。
  - 活跃文件：`main.lua`、`dino_*.lua`、`input.lua`、`util.lua`、`fx.lua`
  - **遗留勿动**（旧 Surf 游戏，未被 require）：`config.lua`、`entities.lua`、`game.lua`、`modes.lua`、`obstacles.lua`、`player.lua`、`ui.lua`、`world.lua`

## 最快的调试回路：无头测试（不用开 Unity）

```
lua5.4 tools/luatest/dino_tests.lua      # 需 lua5.4，仓库根目录运行
```

- `tools/luatest/mock_host.lua` 模拟 Host API；测试里可 `I.setOverride(keys)` 注入虚拟按键、`host._debug` 查实体/文本/点击按钮。
- Lua 改动即时生效（StreamingAssets 直接加载），改完就跑测试。
- 调试钩子（`dino_game.lua`）：`Game.debugClearTrack()`（拆掉生成器）、`Game.debugEnableSpawning("all"|"eggs"|"obstacles"|"enemies")`、`Game.debugSpawnObstacle(kind,x,y)`、`Game.debugSpawnMount(key,x,y)`。

## C# 快速编译检查（不用开 Editor）

```
dotnet build Assembly-CSharp.csproj        # 运行时/宿主代码
dotnet build Assembly-CSharp-Editor.csproj # 编辑器脚本（打包菜单）
```

`.csproj/.sln` 不进 git——新机器先打开一次 Unity 让它生成，才有这些文件。Editor.log 位置：`~/.config/unity3d/Editor.log`（Linux）。

## 打包分发

- 菜单 `DinoImpact → Build Windows (exe)` / `Build Linux`（`Assets/Editor/DinoBuildMenu.cs`），产物在 `Builds/`（已 gitignore）。
- 命令行（Linux 编辑器上直接出 Windows 包，已验证可用）：
  `/home/corvus/Unity/Hub/Editor/2022.3.62f3c1/Unity -batchmode -nographics -quit -projectPath . -buildTarget Win64 -executeMethod DinoBuildMenu.BuildWindows`
  先删 `Builds/Win64` 再打，产物核对 `DinoImpact_Data/StreamingAssets/Lua/`（应有 21 个 .lua）。
- Windows 目标需要编辑器装 **Windows Build Support (Mono)** 模块（Windows 电脑 Hub 直接勾；国服 Hub 在 Linux 上给的链接是 Mac .pkg，坏链——绕过办法见下）：下载 .pkg 后 `bsdtar -xf` 解 xar，再 `bsdtar -xpf TargetSupport.pkg.tmp/Payload`，把结果拷进 `<编辑器>/Data/PlaybackEngines/WindowsStandaloneSupport/`。
- 分发 exe：把 `DinoImpact.exe + DinoImpact_Data/`（可再含 MonoBleedingEdge/UnityPlayer.dll）**整个文件夹**压 zip，只发 exe 跑不了。未签名，对方首次运行会遇 SmartScreen 提示。压 zip 时顶层目录起个像样的名字（如 `DinoImpact_Win64/`），并剔除 `Dino_BurstDebugInformation_DoNotShip/`。
- **绿屏只发生在 Linux 原生 build**；上面这条 Windows 管线在 Windows 上运行正常，gamejam 分发一律用它。

## Game Jam / itch.io 上传决策（2026-11-13 定）

- **源码放同一个仓库**：WebGL 版与 PC 版是同一工程、同一套 Lua，只是 build target 不同；拆仓库会造成双份提交、必然失同步。
- **编译产物不进 git**：WebGL 输出是几百个小文件 + 几十 MB 的 `.wasm.data`，进 git 历史就是永久 blob。产物统一落在 `Builds/`（已 gitignore）。
- **分发只走 itch 上传 zip**：itch 的 web player 会自动解包托管；game jam 提交页勾上 "Playable in browser"（HTML5）即可。
- 例外（暂不做）：想要 push 自动更新 itch，用 butler / game-ci（需 Unity 许可登录，国服编辑器未必兼容）；想把网页版挂 GitHub 直接玩，用 orphan 分支（如 `web`）+ GitHub Pages，与主历史隔离。
- 结论：**当前保持一仓库、只提交源码；每个 jam 包手动打 zip 传 itch。**

## 网页/手机版待办（还没动工，GitHub 上也没有现成实现）

现状检查过：远端只有 main 分支、没有 webgl/mobile 代码；工程里唯一触屏代码是旧 Surf 遗留的 `SurfInput.cs`（当前未被 require）；`DinoHost` 输入层纯键盘；编辑器只装了 Linux + Windows 两个 PlaybackEngines 模块（**WebGL 模块未安装**）。

要出浏览器可玩版，四步按依赖顺序：

1. **装 WebGL 模块**——国服 Hub 大概率和 Windows 模块一样给坏链，需手动下载 `WebGL 2022.3.62f3c1` 支持包解包进 `<编辑器>/Data/PlaybackEngines/WebGLSupport/`（同当年 Windows 模块套路）。
2. **StreamingAssets 加载改造**（最大拦路石）：WebGL 下 `StreamingAssets` 变成**异步**资源，`DinoHost.cs` 现在的同步文件读取会直接失败（表现为白屏）。需要改成 UnityWebRequest 预载，或把 Lua 打进 `Resources`/`TextAsset`。
3. **触屏输入层**：`DinoHost` 透出 `Input.GetTouch` 给 Lua（如 `I.touch(x,y,phase)`），UI 加虚拟按键——左半屏控制五档转向 + W 归中，右下 J 射箭、K 换乘、S 按住停止、Space 技能，Esc 暂停；以横屏为主。
4. **出包**：WebGL 产物压 zip 传 itch，勾 "Playable in browser"；注意手机浏览器内存吃紧（本项目像素风、体量小，风险低）。

## 关键调参 / 已知设计点（`dino_config.lua` 集中所有数值）

- 五档朝向 `C.heading.angleDeg`（±48°/±20°/0）；W 归中。按键（1113 反馈版）：**S 按住=停止前进**（干扰龙仍会就近上门，见 `T.brakeT`）、**J 射箭**、**K 换乘**、Space 技能；没有跳跃键；暂停用 Esc/P。
- **没有空气墙**：横向可无限远。内容跟着预测路线走：所有行以 `P:futureX(y)`（沿当前朝向精确投影）为锚点生成；`C.spawn.anchorLimit=36` 和 `C.world.cullX=44` 都是**相对玩家**的存在性裁剪，不是墙。改生成逻辑时别把内容锚回旧坐标 `P.x`（会重现“两边空荡荡”bug）。
- 受击模型：停跑 + 无敌闪烁，任意 A/W/D 按键恢复并按下即转向（1.2.2）。测试里用 `resumeSteps` 模拟这个行为。障碍碰撞**每帧只结算重叠最深的一个**（`T.update` 里的 deepest 选择）——障碍判定圈放大后，逐条法线推出会互相抵消把玩家永久卡死，改这块别退回去。
- Lua 坑：`function P.foo()` 点号定义却 `P:foo()` 冒号调用会把表自身传成第一个参数；`U.rad` 是常量不是函数。
- Canvas API（C#）：`Rect` 要 int、`Ellipse/Triangle` 要 float——CS1503 常见来源。

## Git 约定

- 提交信息**不要**带 Claude 署名/Co-Authored-By 行。
- 默认只做本地 commit，`git push` 由用户本人跑（除非点名让推）。
