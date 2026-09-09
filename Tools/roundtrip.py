#!/usr/bin/env python3
"""roundtrip.py — 端到端 oracle：读生成的 .cape，切片与源 ani 逐像素比对。

步骤：
  1. plistlib 读 .cape → 每个光标的 Representations[0] 是单张 LZW-TIFF；
  2. Pillow 打开该 TIFF（RGBA），按 PointsHigh 行高切成 FrameCount 条（帧 0 在顶，
     Swift 写入端自顶向下堆叠显示步）；
  3. 与源 ani 的对应显示帧（复用 anicore 解析+解码）逐像素比对。

不一致 → 打印 (identifier, 帧号) 与坐标；exit 1。
只比对 cape 里真实存在的 identifier；源文件夹中被跳过（无 mac 槽 / 未识别 /
>24 显示步 / 解码失败）的 ani 记为「按设计跳过」，不算失败。
"""

import io
import os
import plistlib
import sys

from PIL import Image

import anicore


def load_cape(path):
    with open(path, "rb") as f:
        return plistlib.load(f)


def source_index(folder):
    """identifier → 源 ani 路径（每 identifier 一文件）；同时收集被跳过的文件。"""
    mapping = {}
    skipped = []           # (文件名, 原因)
    for name in sorted(os.listdir(folder)):
        p = os.path.join(folder, name)
        if not os.path.isfile(p) or not name.lower().endswith(".ani"):
            continue
        base = os.path.splitext(name)[0]
        ident = anicore.identifier_for_file_name(base)
        if ident is None:
            skipped.append((name, "无 mac 槽或未识别角色名"))
            continue
        mapping[ident] = p
    return mapping, skipped


def band_diffs(expected, band, w, h):
    n = min(len(expected), len(band))
    diffs = 0
    coords = []
    for i in range(0, n, 4):
        if expected[i:i + 4] != band[i:i + 4]:
            diffs += 1
            if len(coords) < 10:
                x = (i // 4) % w
                y = (i // 4) // w
                coords.append((x, y, tuple(expected[i:i + 4]), tuple(band[i:i + 4])))
    if len(expected) != len(band):
        diffs += abs(len(expected) - len(band)) // 4
    return diffs, coords


def main(argv):
    if len(argv) < 2:
        print("用法: roundtrip.py <cape> <源文件夹>", file=sys.stderr)
        return 2
    cape_path, folder = argv[0], argv[1]

    cape = load_cape(cape_path)
    cursors = cape.get("Cursors", {})
    mapping, skipped_files = source_index(folder)

    # 源中已被 Swift pack 记入 skipped（如 >24 步 / 解码失败）→ 合法缺席
    absent = [(ident, path) for ident, path in sorted(mapping.items()) if ident not in cursors]

    mismatches = []          # (identifier, 帧号, [坐标...])
    compared = 0
    for ident in sorted(cursors):
        cur = cursors[ident]
        src = mapping.get(ident)
        if src is None:
            # cape 里存在但源文件夹没有对应文件（通常意味着 cape 非本文件夹生成）
            mismatches.append((ident, None, [("?", "cape 有该 identifier 但源文件夹无对应 ani")]))
            continue

        parsed = anicore.parse_ani(src)
        doc = anicore.build_document(parsed)
        display = [doc["frames"][i]["rgba"] for i in doc["display_indices"]]

        frame_count = int(cur.get("FrameCount"))
        points_high = int(round(cur.get("PointsHigh")))
        points_wide = int(round(cur.get("PointsWide")))
        rep = cur["Representations"][0]
        img = Image.open(io.BytesIO(rep)).convert("RGBA")

        for i in range(frame_count):
            expected = display[i]
            band = img.crop((0, i * points_high, points_wide, (i + 1) * points_high)).tobytes()
            diffs, coords = band_diffs(expected, band, points_wide, points_high)
            if diffs:
                mismatches.append((ident, i, coords))
        compared += 1

    # ---- 输出 ----
    print("对比 %d 个光标（cape 内）" % compared)
    if absent:
        for ident, path in absent:
            print("按设计跳过: %s（%s）" % (ident, os.path.basename(path)))
    if skipped_files:
        for name, reason in skipped_files:
            print("按设计跳过: %s（%s）" % (name, reason))

    if mismatches:
        for ident, fi, coords in mismatches:
            if fi is None:
                print("不一致: %s %s" % (ident, coords[0][1]))
            else:
                print("不一致: %s 帧 %d" % (ident, fi))
                for x, y, a, b in coords:
                    print("    @(%d,%d) 源=%s cape=%s" % (x, y, a, b))
        print("结果: %d 处不一致" % len(mismatches))
        return 1

    print("结果: 0 不一致")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
