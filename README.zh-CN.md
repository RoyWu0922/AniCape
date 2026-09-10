# AniCape

把 Windows 的 `.ani` 动画光标批量转换为 macOS [Mousecape](https://github.com/alexzielenski/Mousecape) 的 `.cape` 光标包。

[English](README.md) · **中文说明**

纯 Swift（SwiftPM 命令行工具），无需 Xcode 工程，仅依赖系统自带 AppKit 做 LZW-TIFF 编码。

## 构建

```bash
make build          # swift build -c release → .build/release/AniCape
```

## 测试

```bash
make test           # 无 XCTest 门禁：swift run AniCapeTests（命令行工具环境无 Xcode）
```

## 用法

### `pack` —— 打包一个光标文件夹

把一个目录里所有 `.ani` 按文件名角色打包成一个 `.cape`：

```bash
.build/release/AniCape pack "指针/轰一/轰一" -o /tmp/hongyi.cape
# ✅ /tmp/hongyi.cape：13 个光标
# 跳过：手写.ani，候选.ani，位置选择.ani，个人选择.ani
```

- 缺省输出到源目录同级的 `<文件夹名>.cape`。
- 可选参数：`-o <输出.cape>`、`--author X`、`--name Y`。
- 无 mac 槽 / 未识别 / 解码失败的角色会被跳过并在「跳过」行列出。

### `file` —— 转换单个或多个 `.ani`

```bash
# 单个文件，按文件名自动识别角色，输出到同目录
.build/release/AniCape file "指针/樱巫女/Normal.ani"

# 单个文件，指定输出文件
.build/release/AniCape file "指针/樱巫女/Normal.ani" -o /tmp/normal.cape

# 多个文件合并到一个输出目录（生成 <目录名>.cape）
.build/release/AniCape file "指针/樱巫女/Normal.ani" "指针/樱巫女/Busy.ani" -o /tmp/out

# 用 --role 显式指定角色（角色别名或直接给 identifier）
.build/release/AniCape file 某文件.ani --role 正常选择 -o /tmp/x.cape
.build/release/AniCape file 某文件.ani --role com.apple.coregraphics.Arrow -o /tmp/x.cape
```

## 图形界面（GUI）

```bash
make gui       # 开发期直接运行
make app       # 组装可双击的 build/AniCape.app
```

- 拖入 `.ani` 或整个文件夹 → 列表显示每个文件识别到的角色与帧数/尺寸。
- 左侧选中一行，右侧按原始帧时长循环播放预览。
- 「无 mac 槽」或「未识别」的文件默认不纳入，可用行内下拉指派到 13 个 macOS 光标槽之一；两个文件指向同一槽位时高亮提示，转换时后者覆盖前者。
- 底部可改名称/作者与输出路径，点「转换」写出 `.cape`；完成后可直接在 Finder 中显示或用 Mousecape 打开。
- 界面支持**中文 / English** 切换：底栏右侧的分段控件即改即生效，选择记在 `UserDefaults`（键 `appLanguage`）里，下次启动沿用。默认中文，且刻意不跟随系统语言。
- `.cape` 的 identifier 取 `local.anicap.<名称的 slug>`；若把名称留空则用 `cape`。
  注意命令行 `AniCape pack` 取的是**文件夹名**——名称字段未改动时两者相同。

> 需要 macOS 13 或更高版本（`Package.swift` 的 platforms 已声明 `.v13`）。

## 角色映射表

| 中文 | English | macOS identifier |
|------|---------|------------------|
| 正常选择 | Normal | `com.apple.coregraphics.Arrow` |
| 帮助选择 | Help | `com.apple.cursor.40` |
| 后台运行 | Working | `com.apple.cursor.4` |
| 忙 | Busy | `com.apple.coregraphics.Wait` |
| 精确选择 | Precision | `com.apple.cursor.7` |
| 文本选择 | Text | `com.apple.coregraphics.IBeam` |
| 垂直调整 | Vertical | `com.apple.cursor.32` |
| 水平调整 | Horizontal | `com.apple.cursor.28` |
| 沿对角线调整1 | Diagonal1 | `com.apple.cursor.34` |
| 沿对角线调整2 | Diagonal2 | `com.apple.cursor.30` |
| 移动 | Move | `com.apple.coregraphics.Move` |
| 链接选择 | Link | `com.apple.cursor.2` |
| 不可用 | Unavailable | `com.apple.cursor.3` |

> 以下角色 **没有对应的 macOS 槽位**，转换时按设计跳过：
> **手写 / 候选 / 位置选择 / 个人选择**（及英文 **Handwriting / Alternate / Pin / Person**）。

## 在 Mousecape 里应用

1. 先装好 [Mousecape](https://github.com/alexzielenski/Mousecape)（`brew install --cask mousecape`）。
2. 双击生成的 `.cape` 导入；或在 Mousecape 里打开后拖入 / `File → Import`。
3. 在 Mousecape 的 cape 列表里选中它 → 点 Apply，即替换系统光标。

也可以在装好 Cape 后直接 `open -a Mousecape /tmp/hongyi.cape`。

## 已知限制

- **4 个无槽角色跳过**：手写 / 候选 / 位置选择 / 个人选择（及英文名）不转换。
- **仅 1x**：输出 `HiDPI = false`，按原始像素尺寸，不生成 2x 表示。
- **变帧率取首值**：`rate` 数组不均匀时只取第一个值作为整包帧时长（语料恒均匀）。
- **PNG 压缩帧不支持**：`ani` 内 `icon` 若为 PNG 压缩（biCompression ≠ 0）会被跳过。

## 校验工具

`Tools/` 下为独立于 Swift 的 Python/Shell 校验工具（需 `magick` 与 `python3 + Pillow`）：

```bash
python3 Tools/compare_decode.py "指针/樱巫女/Normal.ani" "指针/轰一/轰一/正常选择.ani"
python3 Tools/roundtrip.py /tmp/hongyi.cape "指针/轰一/轰一"
bash Tools/run_corpus.sh /tmp/corpus_out
```

- `compare_decode.py`：以 ImageMagick 为 oracle，逐帧比对 python 端的 DIB 解码。
- `roundtrip.py`：读 `.cape` 切片，与源 ani 显示帧逐像素比对，证明整条 Swift 流水线无损。
- `run_corpus.sh`：遍历 `指针/**` 全量 pack 并汇总。

## 关于「vibe coding」

这个项目是 **vibe coding** 出来的：设计与实现由 [Claude Code](https://claude.com/claude-code) 协作完成，人负责提需求、做设计决策、验收结果。几乎没有哪一行是手敲的。

这是个需要说清楚的前提，所以下面是它凭什么还站得住：

- `make test` 覆盖 RIFF 解析、CUR/DIB 解码、LZW、cape 封装、转换计划与界面文案表，共 **308 项检查**，`0 failed` 才算过。
- `Tools/` 下的校验工具是**独立于** Swift 实现另写的。`roundtrip.py` 把生成的 `.cape` 读回来，与源 `.ani` 逐像素比对——真正证明整条流水线无损的是它，不是单元测试。
- 参考语料全量转换并 roundtrip 过；工具改名成 AniCape 时，命令行输出与改名前的二进制做过逐字节比对。

请按对待任何未经审阅的代码那样对待它：用之前先读。

语料目录 `指针/` 已被 `.gitignore` 排除，不会被提交。
