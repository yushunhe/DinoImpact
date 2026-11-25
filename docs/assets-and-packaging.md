# 素材与打包规则

> 原则：仓库只放**从头能复现当前游戏**的最小集合——源码 + 当前版本素材 + 生成脚本。
> 多版本素材、构建产物、中间图一律在仓库外归档；怎么打包写在本文档里，而不是把每个版本都塞进 git。

## 1. 入库范围

| 类别 | 路径 | 入库 | 说明 |
| --- | --- | --- | --- |
| 玩法代码 | `Assets/StreamingAssets/Lua/` | ✅ | 唯一源码（桌面版直接读取） |
| 宿主 C# | `Assets/SurfImpact/Scripts/`、`Assets/Editor/` | ✅ | MoonSharp 宿主、构建菜单 |
| 运行时精灵 | `Assets/Resources/Dino/` | ✅ | 虽然是生成物，但运行时直接加载；缺文件会退回占位图 |
| 当前植被源图 | `tools/art/*-atlas.png`、`tools/art/tree-fern.png` | ✅ | 植物和蕨地共用的透明源图 |
| 生成脚本 | `tools/art/pixelate_gemini_plants.py` 等 | ✅ | 必须和源图同版本提交，否则不可复现 |
| 无头测试 | `tools/luatest/` | ✅ | |
| 文档 | `docs/`、各 README | ✅ | |
| Unity `.meta` | 与以上资源同目录 | ✅ | 见第 4 节，漏了会丢引用 |
| Lua 镜像 | `Assets/Resources/DinoLua/` | ❌ | 构建前由 `DinoLuaResources.Sync()` 自动生成 |
| 素材中间图 | `Assets/Art/PlantsCutout/` | ❌ | 去背中间产物，脚本重跑即可 |
| 历史素材集 | `Assets/Art/Plants/`、`Assets/Art/PlantsPixelIt/` | ⚠️ | 体积很小、已在历史里，保留；**新增版本不要再整套提交** |
| 参考图 | `Assets/Art/Reference/`、零散原图 | ❌ | 不参与构建，见第 2 节 |
| Unity 生成/备份 | `Library/`、`Library_old/`、`Temp/`、`obj/`、`Logs/` | ❌ | `Library_old/` 当前约 2.7 GB |
| 构建产物 | `Builds/` | ❌ | 每个 jam 包手动打 zip 传 itch |
| Python 缓存 | `__pycache__/`、`*.pyc` | ❌ | |
| 多版本素材归档 | `ArtArchive/` | ❌ | zip 放这里，见第 2 节 |

对应的忽略规则已写进仓库根目录 `.gitignore`。

### 提交前自检

```powershell
git status --short                                   # 看清将要提交什么
git add -A --dry-run | Select-String 'Library_old'   # 应无输出
git check-ignore -v Library_old Assets/Resources/DinoLua Assets/Art/PlantsCutout
```

- `git status` 里不应出现 `Library_old/`、`DinoLua/`、`PlantsCutout/`、`ArtArchive/`。
- GitHub 单文件硬上限 100 MB；不要用 git 存视频、构建包、整库备份。超限内容一律放 itch / Release / 网盘。
- 大文件一旦进了提交历史，删掉文件也不会变小，得改写历史（`git filter-repo`），所以宁可提交前多看一眼。

## 2. 素材多版本

### 现行植被

`tools/art/canopy-atlas.png`、`tools/art/understory-atlas.png` 和
`tools/art/fern-atlas.png` 是现行源图，树蕨单独使用 `tools/art/tree-fern.png`。运行 `python tools/art/make_vegetation.py`
即可导出独立植物、蕨地、小树林和素材预览。用
`python tools/art/pixelate_gemini_plants.py --check` 检查 12 张独立植物有无白点。
提交时把改动涉及的源图、脚本、运行时贴图和 Unity `.meta` 一起提交。

原先的 Gemini JPG 源图保存在 `Assets/Art/gemini/`，可用
`python tools/art/pixelate_gemini_plants.py --legacy-output Builds/LegacyPlants`
单独导出旧版 PNG。

### 归档旧版本（不进 git）

同一时间**仓库里只保留一套“当前”源图**。想留旧版就打包：

```
ArtArchive/plants-<版本名>-<YYYYMMDD>.zip
  ├─ 源图/          Assets/Art/gemini/*.jpg
  ├─ sprite/        Assets/Resources/Dino/*.png
  ├─ 生成脚本/      pixelate_gemini_plants.py
  └─ README.txt     版本名、日期、PPU/调色参数、已知问题
```

PowerShell 示例：

```powershell
Compress-Archive -Path Assets/Art/gemini/*, Assets/Resources/Dino/*.png, tools/art/pixelate_gemini_plants.py `
  -DestinationPath ArtArchive/plants-gemini-20261114.zip
```

`ArtArchive/` 已在 `.gitignore` 中；zip 可再同步到网盘或 GitHub Release。若确需版本长期可追溯，用 **git tag** 标记提交，而不是把多套源图同时提交。

### 参考图

`Assets/Art/1.webp`、`Assets/Art/地貌.jpg` 这类未进入管线的原图不提交。要保留就移到 `Assets/Art/Reference/`（已忽略）；确认无用则直接删除。

## 3. 三平台打包

产物统一落在 `Builds/`（已 gitignore）。

| 平台 | 输出 | zip 顶层目录 |
| --- | --- | --- |
| Windows | `Builds/Win64/DinoImpact.exe` | `DinoImpact_Win64/` |
| Linux | `Builds/Linux/DinoImpact` | `DinoImpact_Linux/` |
| WebGL | `Builds/WebGL/index.html` | zip 内**不要**再套目录，`index.html` 必须在根 |

### 菜单 / 命令行

Unity 菜单：`DinoImpact → Build Windows (exe)` / `Build Linux` / `Build WebGL (itch)`。

命令行（路径按本机编辑器替换）：

```powershell
# Windows（Linux 编辑器上交叉编译已可用，需 Mono 后端）
"<编辑器>/Unity" -batchmode -nographics -quit -projectPath . -buildTarget Win64 -executeMethod DinoBuildMenu.BuildWindows

# WebGL（自动化入口会抑制弹窗；构建前自动执行 Lua 镜像 Sync）
"<编辑器>/Unity" -batchmode -nographics -quit -projectPath . -buildTarget WebGL -executeMethod DinoBuildMenu.BuildWebGLForAutomation
```

注意：

- 每次构建前先删旧输出目录（`Builds/Win64` 等），避免混入上一次的残留。
- **不要手工修改或提交 `Assets/Resources/DinoLua/`**：WebGL / Android 构建前由 `DinoLuaResources.Sync()` 从 `StreamingAssets/Lua` 自动重建，手改会被覆盖。
- 桌面版从 `StreamingAssets/Lua` 直接读，改 Lua 不重新构建也能生效；WebGL 包里的 Lua 是镜像，改完必须重新构建。

### 打 zip 分发

```powershell
# Windows：先复制成好看的顶层目录名，再压这个目录
Copy-Item Builds/Win64 Builds/DinoImpact_Win64 -Recurse
Remove-Item Builds/DinoImpact_Win64/Dino_BurstDebugInformation_DoNotShip -Recurse -ErrorAction SilentlyContinue
Compress-Archive -Path Builds/DinoImpact_Win64 -DestinationPath DinoImpact_Win64.zip

# Linux 同理，换成 Builds/Linux -> Builds/DinoImpact_Linux

# WebGL：压目录内容，保证 index.html 在 zip 根
Compress-Archive -Path Builds/WebGL/* -DestinationPath DinoImpact_WebGL.zip
```

- 命名：`DinoImpact_<平台>_<YYYYMMDD>[_<素材版本>].zip`，例如 `DinoImpact_Win64_20261116_gemini.zip`。
- exe 未签名，对方首次运行会遇到 SmartScreen 提示；分发时说明。
- itch.io：WebGL 包直接上传 zip，提交页勾 **Playable in browser**；PC 包按平台上传。
- 详细踩坑（绿屏、着色器剥离、Windows 模块安装）见 `docs/green-screen-fix.md` 和 `CLAUDE.md` 的「打包分发」节。

## 4. 常见问题

**`git status` 出现 `Library_old/` 怎么办？**
`.gitignore` 已覆盖。若已经误 `git add`，用 `git rm -r --cached Library_old`（只取消跟踪，磁盘文件保留）。

**漏提交 `.meta` 会怎样？**
Unity 会给资源重新分配 GUID，场景 / 预制体 / Lua 里的引用全部丢失。规则：`Assets/` 下的每个资源都和它的 `.meta` 成对提交；被忽略目录里的 `.meta` 一起忽略。

**已知遗留**
`Assets/Art/Plants/*.png` 在早期提交时漏了 `.meta`（目录本身已跟踪）。在新机器首次打开 Unity 时这些图片会拿到新 GUID；如果发现引用异常，补提交对应 `.meta` 即可。

**素材脚本依赖**
`tools/art/pixelate_gemini_plants.py` 需要 Python 3 + `numpy`、`Pillow`。换机器先 `pip install numpy pillow`。