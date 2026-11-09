# DINO IMPACT

2D 侏罗纪恐龙跑酷原型。固定 45° 俯视视角，角色从屏幕下方朝上方跑，可以左右移动、停下，但不能倒退回起点。游戏规则、UI、刷怪和状态机全部写在 Lua 里，Unity 只负责显示、输入和音画宿主。

## 运行

1. 用 Unity 2022.3 打开项目。
2. 打开 `Assets/Scenes/DinoImpact.unity`，点击 Play。
3. 如果场景丢失，执行菜单 `Dino Impact / Build Play Scene` 重新生成并加入 Build Settings。

入口场景是 `DinoImpact.unity`。旧的 `SurfImpact.unity` 和 Surf 相关脚本仍保留在项目里，但当前游戏已经不使用它们，后续可以清理。

## 操作

| 按键 | 功能 |
| --- | --- |
| `W` / `↑` | 向前跑 |
| `S` / `↓` | 减速停下（不会后退） |
| `A` `D` / `←` `→` | 左右移动 |
| `Esc` / `Space` | 暂停 / 继续 |
| `R` | 重开 |
| `Enter` | 开始 / 结算后重开 |

第一版只包含基础循环：前进、停止、左右移动、收集恐龙蛋、撞到岩石 / 倒木 / 灌木后结束、分数与最高分。没有做加速、追逐恐龙、昼夜、模式选择等系统。

目前 UI 使用英文，因为 Unity 内置的 LegacyRuntime 字体不包含中文字形；如果需要中文界面，需要导入一个中文字体并替换 `SurfUI` 里的字体加载。

## 代码结构

- `Assets/SurfImpact/Scripts/DinoBootstrap.cs`：加载 `Assets/StreamingAssets/Lua/main.lua`，每帧调用 `Game.update(dt)`。
- `Assets/SurfImpact/Scripts/DinoHost.cs`：向 Lua 暴露 2D 精灵、相机、UI、存档和输入；负责地面 / 土路的滚动显示。
- `Assets/SurfImpact/Scripts/DinoPixelArt.cs`：生成像素风占位图；如果 `Assets/Resources/Dino/` 里有同名 Sprite，会优先使用你的素材。
- `Assets/StreamingAssets/Lua/dino_game.lua`：菜单、游玩、暂停、结算状态机。
- `Assets/StreamingAssets/Lua/dino_player.lua`：移动、停止、动画、相机跟随。
- `Assets/StreamingAssets/Lua/dino_world.lua`：树、蕨类、石头等场景装饰的生成和回收。
- `Assets/StreamingAssets/Lua/dino_track.lua`：障碍物、恐龙蛋、碰撞和生成节奏。
- `Assets/StreamingAssets/Lua/dino_ui.lua`：HUD、菜单、暂停、结算界面。
- `Assets/StreamingAssets/Lua/dino_config.lua`：移动速度、生成间距、分数、颜色等可调参数。

## 替换人物 / 场景素材

把 PNG 放到 `Assets/Resources/Dino/`，文件名与 `Assets/Resources/Dino/README.txt` 中列出的一致即可，不需要改代码。玩家素材建议朝上、脚底朝向画面下方；导入后设置 `Texture Type = Sprite (2D and UI)` 和 `Filter Mode = Point`。

当前主角是白羽毛、似鸟龙（Ornithomimus）风格的像素素材，背上坐着一位穿兽皮衣、背弓箭筒的骑手：`dino_idle / dino_idle2` 两帧待机，`dino_run0 / dino_run1 / dino_run2 / dino_run3` 四帧跑步循环。素材由 `tools/art/make_ornithomimus.py` 生成（46x56、PPU 22、脚底 pivot），运行该脚本会同时输出 Unity 的 `.meta` 和 `tools/art/preview/` 下的预览图。如果删掉这些 PNG，运行时会回退到 `DinoPixelArt.cs` 生成的绿色小恐龙占位图。

## 测试

无头逻辑测试不需要打开 Unity：

```bash
lua5.4 tools/luatest/dino_tests.lua
```

测试覆盖菜单启动、前进、停止 / 不后退、左右移动、收集蛋、撞障碍结算、最高分保存、暂停、重开、菜单往返和长时间运行的实体数量上限。

## 说明

占位像素素材均由本项目脚本程序化生成，没有使用 Microsoft Edge Surf 的素材或代码。
