# 光照方案（Lighting Plan）

> 状态：**方案，未实施**。本文档记录设计思路、现状依据和分步计划，供后续实施与回顾使用。
> 参考对象：八方旅人2 的光照结构（只做技术思路参考，不引用其资源或参数取值）。

## 1. 目标

让画面获得"统一的氛围"和"立体感"，同时保持像素风精灵的可读性：

- **统一感**：全场景跟随一个时段状态调色（清晨 / 白天 / 黄昏 / 夜晚），而不是每个物件各自调。
- **焦点**：玩家和重要物件（蛋、果实、障碍的危险信号）有局部光，把视线拉过去。
- **立体感**：精灵脚下有接触阴影，平面精灵看起来"立在地面上"。
- **味道**：光晕与暗角，用便宜的近似代替真正的后处理。

非目标：真实阴影贴图、烘焙 GI、URP 迁移、Lumen 类方案。

## 2. 现状（决定方案边界的事实）

依据均来自仓库当前代码，改动前需重新核对：

| 项 | 现状 | 位置 |
|---|---|---|
| 渲染管线 | Built-in，无 URP 包，未设置 SRP 资产 | `Packages/manifest.json`、`ProjectSettings/GraphicsSettings.asset` |
| 光照 | 全部画面无光照；平行光在 `BuildWorld()` 中被停用 | `Assets/SurfImpact/Scripts/DinoHost.cs:81-82` |
| 地面 shader | `Surf/Unlit`（透明队列，`sortingOrder=-30000`） | `DinoHost.cs` `MakeGroundMaterial` |
| 精灵 shader | `Sprites/Default`（不读取全局变量） | `DinoHost.cs:544` 附近 |
| 环境接口 | `world.setAmbient` 为空实现 | `DinoHost.cs:324` |
| 背景接口 | `camera.setBackground` 已存在，默认深绿 | `DinoHost.cs:70`、`:341` |
| 相机 | 正交，`orthographicSize` 由 `C.camera.size` 决定 | `dino_config.lua` |
| 可用 shader | `SurfUnlit`、`SurfAdditive`、`SurfFlat`（含 Lighting.cginc）等 | `Assets/SurfImpact/Shaders/` |
| 测试 | 无头 Lua 测试 `tools/luatest/dino_tests.lua` | — |

**关键约束**：Surf 自定义 shader 与 Built-in 管线绑定；工程里曾因 `Shader.Find` 在包中被剥离导致绿屏（见 `docs/green-screen-fix.md`）。新 shader 必须放在 Always Included 或直接引用，并在 Windows / WebGL 包中验证。

## 3. 技术路线选择

| 候选 | 结论 | 理由 |
|---|---|---|
| 迁移 URP（2D 或 3D） | **不做** | 现有 Surf shader 全部需重写；管线迁移风险高；收益不成比例 |
| 烘焙 GI / Light Probe / Lightmass | **不做** | 正交 2D 精灵没有需要烘焙的 3D 几何 |
| 全局 shader 变量统一调色 | **采用** | 只改 shader 与下发逻辑，兼容 Built-in，跨平台成本低 |
| 自定义 shader 做精灵点光源累加 | **采用** | 上限 8 盏，片元开销可控，WebGL / 手机可接受 |
| 加法光晕贴图代替 Bloom | **采用** | 复用已有 `SurfAdditive`，无需后处理包 |
| 接触阴影（软边椭圆） | **采用** | 性价比最高的"立体感"手段 |
| 自写 `OnRenderImage` 暗角 / 调色 | **采用（第 3 步）** | 无需 Post Processing 包，Blit 即可 |

**对外部分析的修正**（来自参考资料，实施时以本表为准）：

- 参考资料的 Unity 映射基于 URP / Light 2D / Volume，本项目不适用。
- 参考资料中的时段示例 `CurrentBlend()` 没有真正插值（硬切），且假设存在被本项目关闭的平行光，不能照搬。
- "Unity 6 Fog Volume" 在 2022.3 中不存在。

## 4. 分步方案

### 第 0 步：基线与开关
- 截取基线截图（白天、黄昏、夜晚，草地 + 小树林 + 障碍各一张），存入 `docs/` 外的素材目录，作为 A/B 参照。
- 新增 `C.light.enabled`（`dino_config.lua`），关闭时走原有纯色路径，便于对比与回退。

**完成标准**：开关关闭时画面与改动前逐像素一致（或肉眼一致）。

### 第 1 步：全局时段色调
- **配置（Lua）**：`C.light.timeZones` 定义四套预设，字段：
  - `tint`：环境色乘子（RGB）
  - `bg`：相机背景色
  - `lift`：暗部抬升色（防止夜晚草地变成一团黑）
- **插值（Lua，纯函数）**：`blend(zoneA, zoneB, t)`，放入 `dino_tests.lua` 直接测试。切换时长与缓动同样在 Lua 中定义。
- **下发（C#）**：新增 `DinoLighting.cs`，每帧调用：
  - `Shader.SetGlobalColor("_DinoTint", ...)`
  - `Shader.SetGlobalColor("_DinoLift", ...)`
  - 通过已有的 `setBackground` 更新相机背景
- **shader**：
  - 地面 `Surf/Unlit` 读取 `_DinoTint` / `_DinoLift`。
  - 精灵换用新 shader `Surf/Sprite`（基于 `SurfUnlit` 复制，加入全局变量读取）。
  - 所有精灵材质统一替换，不能残留 `Sprites/Default`。

**完成标准**：四个时段切换平滑；夜晚草地与角色仍可辨认；Lua 插值测试通过。

### 第 2 步：局部光源
- **光源来源（Lua）**：每帧收集可见发光物，字段：`x, y, radius, color, intensity, flickerAmp, flickerSeed`。
  - 候选：玩家暖光（常驻）、蛋、果实、危险障碍的提示光。
  - 上限 8 盏；超出时按距离与优先级裁剪。
- **闪烁**：使用项目已有的确定性哈希（与地貌生成同源），保证同一输入回放结果一致。
- **打包（C#）**：`Shader.SetGlobalVectorArray` 上传位置/半径/颜色，`SetGlobalFloatArray` 上传强度。
- **shader 累加**（`Surf/Sprite`）：
  ```
  for i in 0..N-1:
      d = distance(worldXY, lightPos[i])
      f = saturate(1 - d / lightRadius[i])
      col.rgb += lightColor[i].rgb * (f * f) * lightIntensity[i]
  ```
  世界坐标由顶点阶段传入（`o.worldXY = mul(unity_ObjectToWorld, v.vertex).xy`）。

**完成标准**：8 盏灯时帧时间增量在可接受范围（以 Profiler 实测为准，目标见第 6 节）；光源裁剪逻辑有测试覆盖。

### 第 3 步：味道层
- **光晕**：光源位置叠加 `SurfAdditive` 圆形贴图，半径随闪烁轻微脉动。
- **接触阴影**：每个实体脚下一块软边暗椭圆，偏移方向跟随固定"太阳方向"（`C.light.sunDir`），透明度随时段变化。
- **暗角与调色**：相机挂 `OnRenderImage` 脚本，Blit 一个暗角 + 色调曲线 shader，可用 `C.light.vignette` 开关。

**完成标准**：暗角与光晕可单独关闭；接触阴影不遮挡障碍的判定读数（以视觉为准）。

### 第 4 步（可选）：时段随进度切换
- 按跑出距离或阶段切换下一时段，过渡由 Lua 中的 tween 完成。
- 依赖第 1 步的插值函数，不引入新机制。

## 5. 配置草案

```lua
-- dino_config.lua（草案，数值待定）
C.light = {
    enabled = true,
    sunDir = {-0.4, -0.6},          -- 接触阴影偏移方向（XY）
    maxLights = 8,
    timeZones = {
        dawn  = { tint = {1.00, 0.86, 0.72}, lift = {0.10, 0.08, 0.14}, bg = {0.16, 0.14, 0.18} },
        day   = { tint = {1.00, 1.00, 1.00}, lift = {0.00, 0.00, 0.00}, bg = {0.09, 0.15, 0.08} },
        dusk  = { tint = {1.00, 0.74, 0.58}, lift = {0.14, 0.06, 0.10}, bg = {0.20, 0.10, 0.12} },
        night = { tint = {0.52, 0.60, 0.86}, lift = {0.08, 0.10, 0.18}, bg = {0.04, 0.05, 0.10} },
    },
    vignette = 0.25,
}
```

> 上述色值仅为占位，需以第 0 步的基线截图和实际观感调整。

## 6. 验证方式

- **无头测试（每步必做）**：
  - `blend()` 端点与中点正确；
  - 光源裁剪按距离与优先级选出的结果稳定；
  - 闪烁函数对同一种子输出一致。
  - 运行：`lua5.4 tools/luatest/dino_tests.lua`
- **视觉验证**：需要 Unity 编辑器截图比对。截图记录放在第 0 步的基线目录，每步附一张对比图。
- **性能**：用 Unity Profiler 记录一局的帧时间与片元开销，分别在"无光源 / 4 盏 / 8 盏"下测量。性能预算待第 0 步后确定（暂定：8 盏灯相对基线增量不超过 2ms，手机与 WebGL 另测）。
- **平台**：Windows 包与 WebGL 包都要打包验证，确认新 shader 未被剥离（参考绿屏排查记录）。

## 7. 风险与对策

| 风险 | 对策 |
|---|---|
| 乘子压暗画面，夜晚不可读 | `lift` 抬升暗部；夜晚色调以可读性为准，不追求纯黑 |
| 新精灵 shader 被构建剥离 | 放入 Always Included，或参照 `Surf/Unlit` 的引用方式；打包后核对 |
| 8 盏灯在低端设备超预算 | `maxLights` 可配置；超预算时降到 4 盏 |
| 精灵材质替换遗漏 | 实施时全局搜索 `Sprites/Default`，并在调试钩子里统计仍在使用的材质 |
| 光照逻辑侵入玩法判定 | 光照只读取玩法状态，不反向写入；光源与阴影不参与碰撞计算 |
| 时段切换与玩法节奏冲突 | 第 4 步放最后，切换时长由配置控制 |

## 8. 实施顺序与产出

1. 第 0 步：基线截图 + `C.light.enabled` 开关
2. 第 1 步：时段色调（Lua 插值 + `DinoLighting.cs` + `Surf/Sprite`）
3. 第 2 步：局部光源（最多 8 盏）
4. 第 3 步：光晕、接触阴影、暗角
5. 第 4 步（可选）：时段随进度切换

每步独立提交，提交信息与 `docs/design-plan.md` 的既有风格保持一致；本文档在方案变更时同步更新。

## 9. 待决定的事项

- 四个时段的最终色值（需基线截图后确定）
- 接触阴影的"太阳方向"是否固定，还是随时段变化
- 光源优先级规则（距离优先，还是类型优先）
- 第 4 步是否纳入正式版本
