#!/usr/bin/env python3
"""roundtrip.py — 端到端 oracle：读生成的 .cape，切片与源 ani 逐像素比对。

步骤：
  1. plistlib 读 .cape → 每个光标的 Representations[0] 是单张 LZW-TIFF；
  2. Pillow 打开该 TIFF（RGBA），按 PointsHigh 行高切成 FrameCount 条（帧 0 在顶，
     Swift 写入端自顶向下堆叠显示步）；
  3. 与源 ani 的对应显示帧（复用 anicore 解析+解码）逐像素比对，并断言
     cape 的 FrameCount == 源 ani 的显示步数（spec §7-2）。

退出码语义：
  - 像素不一致 / 帧数不一致 / 有效角色却缺失光标 → 打印原因并 exit 1。
  - 无 mac 槽角色、未识别名、>24 显示步、解码失败 → 「按设计跳过」（不 exit 1）。
  - 同 identifier 的多个源文件（如 正常选择.ani 与 Normal.ani）→ 镜像 Swift pack 的
    排序后 last-wins，靠前者记为「按 pack 覆盖」，只比对最后一个，不静默覆盖。
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
    """镜像 Converter.pack 的遍历：按文件名升序遍历，同 identifier last-wins。

    返回 (last_wins, overwritten, no_slot)：
      - last_wins: identifier → 排序后最后一个源文件路径（pack 的最终胜者）。
      - overwritten: [(identifier, 被覆盖的靠前文件, 胜者文件)]，不参与比对。
      - no_slot:     [(文件名, 原因)]，identifier 为 None（无 mac 槽 / 未识别）。
    """
    last_wins = {}
    overwritten = []
    no_slot = []
    for name in sorted(os.listdir(folder)):
        p = os.path.join(folder, name)
        if not os.path.isfile(p) or not name.lower().endswith(".ani"):
            continue
        base = os.path.splitext(name)[0]
        ident = anicore.identifier_for_file_name(base)
        if ident is None:
            no_slot.append((name, "无 mac 槽或未识别角色名"))
            continue
        if ident in last_wins:
            overwritten.append((ident, last_wins[ident], p))
        last_wins[ident] = p
    return last_wins, overwritten, no_slot


def probe_source(path):
    """解析+解码源 ani，返回 (显示帧 RGBA 列表, 显示步数)；失败则抛异常。"""
    parsed = anicore.parse_ani(path)
    doc = anicore.build_document(parsed)
    return [doc["frames"][i]["rgba"] for i in doc["display_indices"]], len(doc["display_indices"])


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
    last_wins, overwritten, no_slot = source_index(folder)

    problems = []          # 硬性不一致（像素 / 帧数 / 缺光标 / 源解码失败）
    compared = 0

    # ---- 1) 逐光标比对（仅比对 cape 中真实存在的 identifier） ----
    for ident in sorted(cursors):
        cur = cursors[ident]
        src = last_wins.get(ident)
        if src is None:
            problems.append("缺少源: %s（cape 有该 identifier 但源文件夹无对应 .ani）" % ident)
            continue
        try:
            display, src_count = probe_source(src)
        except Exception as e:
            problems.append("源解码失败: %s（%s）%r" % (ident, os.path.basename(src), e))
            continue

        frame_count = int(cur.get("FrameCount"))
        if frame_count != src_count:
            problems.append("帧数不一致: %s cape=%d 源=%d（%s）"
                            % (ident, frame_count, src_count, os.path.basename(src)))
            continue

        points_high = int(round(cur.get("PointsHigh")))
        points_wide = int(round(cur.get("PointsWide")))
        rep = cur["Representations"][0]
        img = Image.open(io.BytesIO(rep)).convert("RGBA")
        for i in range(frame_count):
            expected = display[i]
            band = img.crop((0, i * points_high, points_wide, (i + 1) * points_high)).tobytes()
            diffs, coords = band_diffs(expected, band, points_wide, points_high)
            if diffs:
                problems.append("像素不一致: %s 帧 %d" % (ident, i))
                for x, y, a, b in coords:
                    problems.append("    @(%d,%d) 源=%s cape=%s" % (x, y, a, b))
        compared += 1

    # ---- 2) 同 identifier 覆盖提示（不比对） ----
    for ident, earlier, winner in overwritten:
        print("按 pack 覆盖: %s（%s 被 %s 覆盖，不比对）"
              % (ident, os.path.basename(earlier), os.path.basename(winner)))

    # ---- 3) 无槽角色 → 设计内跳过 ----
    for name, reason in no_slot:
        print("按设计跳过: %s（%s）" % (name, reason))

    # ---- 4) 有效 identifier 却缺席 cape → 探测定性（T10-i1） ----
    for ident, src in sorted(last_wins.items()):
        if ident in cursors:
            continue
        try:
            _, src_count = probe_source(src)
        except Exception as e:
            print("按设计跳过: %s（%s，%r）" % (ident, os.path.basename(src), e))
        else:
            problems.append("缺少光标: %s（%s，源 %d 显示步，可解码却缺失于 cape）"
                            % (ident, os.path.basename(src), src_count))

    # ---- 输出 ----
    print("对比 %d 个光标（cape 内）" % compared)
    if problems:
        for m in problems:
            print("不一致: " + m)
        print("结果: %d 处不一致" % len(problems))
        return 1

    print("结果: 0 不一致")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
