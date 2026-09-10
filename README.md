# anicap

**Convert Windows `.ani` animated cursors into [Mousecape](https://github.com/alexzielenski/Mousecape) `.cape` cursor packs on macOS.**

**English** · [中文说明](README.zh-CN.md)

Windows cursor themes ship as `.ani` files — RIFF containers holding CUR/DIB frames — while macOS cursor themes live in Mousecape's `.cape` format: an XML plist of per-frame LZW-TIFF slices. Nothing bridged the two, so anicap does it: parse each `.ani`, decode every frame's pixels, hotspot and duration, infer the cursor's role from its filename, map it onto one of the 13 macOS cursor slots, and re-encode the result into a pack Mousecape accepts.

Pure Swift via SwiftPM — no Xcode project, no third-party dependencies, borrowing only system AppKit for LZW-TIFF encoding. It ships as both a command-line tool and a native SwiftUI app.

## Requirements

- macOS 13 or later (`Package.swift` declares `.v13`)
- A Swift 5.9+ toolchain — the Command Line Tools are enough; no Xcode required
- [Mousecape](https://github.com/alexzielenski/Mousecape) to actually apply the finished cursors: `brew install --cask mousecape`

## Build

```bash
make build          # swift build -c release → .build/release/anicap
```

## Test

```bash
make test           # swift run anicap-tests
```

The suite deliberately avoids XCTest, because the Command Line Tools toolchain does not ship it. Instead it is a self-contained harness that prints a `---- N passed, M failed ----` summary and exits non-zero on failure.

## Usage

### `pack` — convert a cursor folder

Converts every `.ani` in a directory into a single `.cape`, identifying each file's role from its name:

```bash
.build/release/anicap pack "指针/轰一/轰一" -o /tmp/hongyi.cape
# ✅ /tmp/hongyi.cape：13 个光标
# 跳过：手写.ani，候选.ani，位置选择.ani，个人选择.ani
```

- Defaults to writing `<folder-name>.cape` beside the source folder.
- Options: `-o <out.cape>`, `--author X`, `--name Y`. The name defaults to the folder name and the author to `anicap`.
- Files whose role has no macOS slot, whose name is unrecognized, or that fail to decode are skipped and listed on a `跳过：` line.
- Exits `1` if no cursors were produced, `0` otherwise.

### `file` — convert one or more individual `.ani` files

```bash
# Single file: role inferred from the filename, written beside the source
.build/release/anicap file "指针/樱巫女/Normal.ani"

# Single file with an explicit output path
.build/release/anicap file "指针/樱巫女/Normal.ani" -o /tmp/normal.cape

# Several files merged into one pack, written into an existing directory
.build/release/anicap file "指针/樱巫女/Normal.ani" "指针/樱巫女/Busy.ani" -o /tmp/out

# Force a role, by alias or by raw identifier
.build/release/anicap file 某文件.ani --role 正常选择 -o /tmp/x.cape
.build/release/anicap file 某文件.ani --role com.apple.coregraphics.Arrow -o /tmp/x.cape
```

Passing more than one file requires `-o` to name an existing directory; the pack is written there as `<directory-name>.cape`. Writing to stdout (`-o -`) is not supported. Exits `1` if nothing was produced and `2` on a usage error.

> `--author` and `--name` apply to `pack` only. The CLI's own usage text is printed in Chinese.

## GUI

```bash
make gui       # run directly from source during development
make app       # assemble a double-clickable build/anicap.app
```

- Drag in `.ani` files or a whole folder — the list shows the role, frame count and dimensions detected for each one.
- Select a row to play that cursor back on the right, looping at its original frame durations.
- Files with no macOS slot or an unrecognized name are excluded by default; assign them to one of the 13 slots with the inline dropdown. Two files targeting the same slot are highlighted, and the later one wins on conversion.
- Set the name, author and output path at the bottom, then press Convert. When it finishes you can reveal the file in Finder or open it in Mousecape.

## Role mapping

| Windows role (Chinese) | Windows role (English) | macOS identifier |
|------------------------|------------------------|------------------|
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

> The following roles have **no macOS slot** and are skipped by design:
> **手写 / 候选 / 位置选择 / 个人选择** (Handwriting / Alternate / Pin / Person).

## Applying the result in Mousecape

1. Install Mousecape: `brew install --cask mousecape`.
2. Double-click the generated `.cape`, or drag it into Mousecape, or use `File → Import`.
3. Select it in Mousecape's cape list and press Apply to replace the system cursors.

Once Mousecape is installed you can also go straight there: `open -a Mousecape /tmp/hongyi.cape`.

## Known limitations

- **Four role-less cursors are skipped** — Handwriting / Alternate / Pin / Person (and their Chinese names) are not converted.
- **1x only** — the output sets `HiDPI = false` and keeps the source's native pixel dimensions; no 2x representation is generated.
- **First frame rate wins** — if an `.ani`'s `rate` array is non-uniform, only its first value is used as the pack-wide frame duration. The reference corpus is always uniform.
- **PNG-compressed frames are unsupported** — an `icon` chunk that is PNG-compressed (`biCompression ≠ 0`) is skipped.

## Verification tools

`Tools/` holds Python and shell checkers that are independent of the Swift implementation. They need `magick` and `python3` with Pillow:

```bash
python3 Tools/compare_decode.py "指针/樱巫女/Normal.ani" "指针/轰一/轰一/正常选择.ani"
python3 Tools/roundtrip.py /tmp/hongyi.cape "指针/轰一/轰一"
bash Tools/run_corpus.sh /tmp/corpus_out
```

- `compare_decode.py` — uses ImageMagick as an oracle to compare the Python-side DIB decode frame by frame.
- `roundtrip.py` — reads the `.cape` slices and compares them pixel by pixel against the source `.ani` display frames, proving the whole Swift pipeline is lossless.
- `run_corpus.sh` — packs every folder under `指针/**` and summarises the results.

## Project layout

```
Sources/
  AniKit/        .ani parsing (RIFF), CUR/DIB decoding, LZW
  CapeKit/       .cape document model and LZW-TIFF writer
  RoleKit/       Windows role name → macOS cursor slot mapping
  Core/          conversion pipeline shared by the CLI and the GUI
  anicap/        command-line entry point
  anicap-gui/    SwiftUI app
  anicap-tests/  dependency-free test harness
Tools/           Python/shell verification scripts
docs/            design specs and implementation plans
```

## Notes

The reference corpus under `指针/` is excluded by `.gitignore` and is not part of this repository.
