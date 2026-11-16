# 绿屏问题：排查与修复记录

> 日期：2026-11-14
> 场景：Windows player build（`Builds/Win64/DinoImpact.exe`）
> 结论：不是玩法/Lua 问题，是 **打包时内置 shader 被剥离** 导致的渲染问题。

---

## 一、现象

用 `DinoImpact → Build Windows (exe)` 打包后运行，Editor 里一切正常，但 exe 里：

- 整屏是一片单色草地绿，看不到地形细节；
- 偶尔能看到几个纯色的大矩形色块（像是被极度放大的草地像素）；
- 恐龙、树木、蛋、石头、装饰物**全部消失**；
- 左侧 HUD（距离/蛋数/击杀/换乘）、顶部爱心**正常显示**；
- 游戏逻辑仍在跑：距离在涨、能吃蛋、Player.log 无报错。

---

## 二、根因

### 1. 内置 shader 被剥离

地面材质原本这样找 shader：

```csharp
Shader shader = Shader.Find("Unlit/Texture");
if (shader == null) shader = Shader.Find("Sprites/Default");
```

`Unlit/Texture` 是 Unity 内置 shader，**没有任何场景资源或材质直接引用它**（地面材质是运行时 `new Material(...)` 创建的）。Player build 的 shader stripping 会把它剥掉，于是构建后 `Shader.Find` 返回 `null`，代码落入 `Sprites/Default` 兜底。

Editor 里所有内置 shader 都在，`Shader.Find` 永远找得到，所以编辑器完全没有症状——**这个 bug 只在 player build 出现**。

### 2. 兜底 shader 的两个致命差异

`Sprites/Default` 能用，但并不适合当无限地面：

| 需求 | `Unlit/Texture` | 回退后的 `Sprites/Default` |
| --- | --- | --- |
| `mainTextureScale/Offset`（`_MainTex_ST`） | 支持 | **不应用**，平铺失效 |
| 渲染队列 | Opaque（先画） | Transparent（后画） |
| 默认 sortingOrder | — | 0 |

后果一：地面原本应该在 120 单位里平铺 60 次（每 tile 2 单位），平铺失效后**整块地面只显示一个 32×32 图块**。镜头里看到的就是几个被放大到上百像素的草地调色板颜色，于是表现为"单色绿 + 大色块"。

后果二：`Sprites/Default` 在透明队列里按 sortingOrder 排序。地面默认 0，而精灵的 sortingOrder 是 `-y * 8`（玩家和前方景物都是负数），所以**精灵全部先画、地面后画，整屏被地面盖住**。HUD 是 Screen Space Overlay Canvas，永远在最上层，所以只有 HUD 幸存。

这也解释了两个很容易误判的现象：

- 看起来像"世界没生成"——其实 Lua 里 356 个实体、20 个地貌地块都在，位置也正确；
- 看起来像"绿屏死机"——其实游戏在正常跑，只是画面被一块放大的草地盖住了。

---

## 三、诊断过程（可复用）

1. **先确认逻辑层**：给构建内的 `StreamingAssets/Lua` 临时加一行周期性 `Host.log`，输出玩家坐标、相机参数、实体数、地貌数。结果 `p=0,13.1 cam=0,16.7 size=9.6 ents=356 terr=20 alive=true`，说明生成/更新/相机都正常，问题在渲染。
2. **采样截图像素**：在画面干净区域统计颜色，只有 3 种颜色（`#4C7A2B`、`#7AA539`、`#679430`），正好是草地贴图调色板里的颜色，且每种颜色占上万像素。说明贴图被放大到每个 texel 约 90–120 px，即 **tiling 没生效**。
3. **检查 Player.log**：无 Lua error、无材质/shader 报错（`new Material` 拿到 null shader 时不一定抛异常），排除脚本崩溃。
4. **对照 Editor**：Editor Play 完全正常 → 症状只在 player build → 高度怀疑 shader stripping。

---

## 四、修复

### 1. 地面改用 Always Included 的 `Surf/Unlit`

`Assets/SurfImpact/Scripts/DinoHost.cs` 的 `MakeGroundMaterial`：

```csharp
// Player builds strip built-in shaders that no asset references, so
// Shader.Find("Unlit/Texture") can return null there (the old fallback
// ignored tiling and covered every sprite in the stale build).
Shader shader = Shader.Find("Surf/Unlit");
if (shader == null) shader = Shader.Find("Unlit/Texture");
if (shader == null) shader = Shader.Find("Sprites/Default");
```

为什么选 `Surf/Unlit`：

- 它已经在 `ProjectSettings/GraphicsSettings.asset` 的 **Always Included Shaders** 列表里（GUID `15884506967a80228af032c31c269759`），打包不会丢；
- 顶点着色器使用 `TRANSFORM_TEX(v.uv, _MainTex)`，完整支持 `mainTextureScale` / `mainTextureOffset`，地面滚动逻辑不用改。

### 2. 强制地面渲染层级

地面 shader 本身是透明队列（`Blend SrcAlpha OneMinusSrcAlpha`、`ZWrite Off`），所以必须显式排在所有精灵之前：

```csharp
_ground = MakeQuad("Ground", 120f, _groundMat, 20f);
_ground.sortingOrder = -30000;
```

当前层级约定：

| 内容 | sortingOrder |
| --- | --- |
| 无限地面 | `-30000` |
| 地貌地块（蕨叶地/沼泽地） | `-20000` |
| 游戏精灵 | `-y * 8`（约 -800 ~ +800） |
| HUD / UI | Screen Space Overlay，独立 Canvas |

### 3. 验证

重新打包后直接运行 exe 截图确认：草地有正常像素细节，恐龙、树木、蛋、地貌、HUD 全部显示。

产物：

- `Builds/Win64/DinoImpact.exe`
- `Builds/DinoImpact_Win64.zip`

---

## 五、备选方案与取舍

| 方案 | 结果 | 取舍 |
| --- | --- | --- |
| 把 `Unlit/Texture` 加进 Always Included Shaders | 可行 | 需要改 ProjectSettings 的内置 shader fileID，不如直接用已有 shader 稳 |
| 把平铺烘进地面 mesh 的 UV，材质只管滚动 | 可行 | 滚动逻辑要改成吸附 2 单位网格移动地面，改动更大 |
| 新写一个 opaque 的 tiling shader + 加 Always Included + GUID | 最规范 | 需要新增资源与 .meta，当前原型阶段没必要 |
| **改用已有 `Surf/Unlit` + 显式 sortingOrder**（已采用） | 可行 | 最少改动，保留原有 UV 滚动逻辑 |

---

## 六、防回归检查清单

1. **运行时 `Shader.Find` 的 shader 必须在 Always Included Shaders 里，或放在 `Resources/` 下**。Player build 会剥掉无人引用的 shader，Editor 不会。
2. **用了 `mainTextureScale` / `mainTextureOffset`，就必须用支持 `_MainTex_ST` 的 shader**。`Sprites/Default` 不支持材质平铺。
3. **透明队列的层（地面、地貌、特效）一律显式设 sortingOrder**，不要依赖默认 0 与深度。
4. **验收要跑真正的 player build**，Editor Play 正常不代表打包正常。
5. 若 Linux 原生 build 也绿屏，那是另一个已知问题，不要把两类现象混为一谈。

---

## 七、涉及文件

- `Assets/SurfImpact/Scripts/DinoHost.cs`
  - `BuildWorld()`：地面 sortingOrder
  - `MakeGroundMaterial()`：shader 选择顺序
  - `AddTerrain()`：地貌地块 sortingOrder `-20000`
- `ProjectSettings/GraphicsSettings.asset`
  - `m_AlwaysIncludedShaders`：`Surf/Unlit` 等 shader 的来源
- `CLAUDE.md`：已同步更新"绿屏"说明，避免下次继续误以为是 Linux 专属问题
