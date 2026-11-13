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
- 命令行：`Unity -batchmode -nographics -quit -projectPath . -buildTarget Win64 -executeMethod DinoBuildMenu.BuildWindows`
- Windows 目标需要编辑器装 **Windows Build Support (Mono)** 模块（Windows 电脑 Hub 直接勾；国服 Hub 在 Linux 上给的链接是 Mac .pkg，坏链——绕过办法见下）：下载 .pkg 后 `bsdtar -xf` 解 xar，再 `bsdtar -xpf TargetSupport.pkg.tmp/Payload`，把结果拷进 `<编辑器>/Data/PlaybackEngines/WindowsStandaloneSupport/`。
- 分发 exe：把 `DinoImpact.exe + DinoImpact_Data/`（可再含 MonoBleedingEdge/UnityPlayer.dll）**整个文件夹**压 zip，只发 exe 跑不了。未签名，对方首次运行会遇 SmartScreen 提示。

## 关键调参 / 已知设计点（`dino_config.lua` 集中所有数值）

- 五档朝向 `C.heading.angleDeg`（±48°/±20°/0）；W 归中。按键（1113 反馈版）：**S 按住=停止前进**（干扰龙仍会就近上门，见 `T.brakeT`）、**J 射箭**、**K 换乘**、Space 技能；没有跳跃键；暂停用 Esc/P。
- **没有空气墙**：横向可无限远。内容跟着预测路线走：所有行以 `P:futureX(y)`（沿当前朝向精确投影）为锚点生成；`C.spawn.anchorLimit=36` 和 `C.world.cullX=44` 都是**相对玩家**的存在性裁剪，不是墙。改生成逻辑时别把内容锚回旧坐标 `P.x`（会重现“两边空荡荡”bug）。
- 受击模型：停跑 + 无敌闪烁，任意 A/W/D 按键恢复并按下即转向（1.2.2）。测试里用 `resumeSteps` 模拟这个行为。障碍碰撞**每帧只结算重叠最深的一个**（`T.update` 里的 deepest 选择）——障碍判定圈放大后，逐条法线推出会互相抵消把玩家永久卡死，改这块别退回去。
- Lua 坑：`function P.foo()` 点号定义却 `P:foo()` 冒号调用会把表自身传成第一个参数；`U.rad` 是常量不是函数。
- Canvas API（C#）：`Rect` 要 int、`Ellipse/Triangle` 要 float——CS1503 常见来源。

## Git 约定

- 提交信息**不要**带 Claude 署名/Co-Authored-By 行。
- 默认只做本地 commit，`git push` 由用户本人跑（除非点名让推）。
