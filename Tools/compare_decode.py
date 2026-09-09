#!/usr/bin/env python3
"""compare_decode.py — ImageMagick 解码 oracle：校验 anicore 的 DIB 解码与 magick 一致。

对每个输入 ani 的每个物理帧：
  1. 抽出该帧的 mini-CUR（完整 .cur：ICONDIR + ICONDIRENTRY + DIB）写到临时 `.cur`；
  2. `magick <cur> -background none png:-` 解码，用 Pillow 读成 RGBA；
  3. 与 anicore.decode_cur 的 RGBA 逐像素比对。
全部一致 → 每个样本打印 PASS（0 diff）；否则打印 diff 计数与坐标并 exit 1。
"""

import io
import os
import subprocess
import sys
import tempfile

from PIL import Image

import anicore


def magick_decode_cur(mini_cur):
    """用 ImageMagick 解码一个 mini-CUR，返回 (width, height, rgba_bytes)。"""
    fd, tmp = tempfile.mkstemp(suffix=".cur")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(mini_cur)
        proc = subprocess.run(
            ["magick", tmp, "-background", "none", "png:-"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        if proc.returncode != 0:
            raise RuntimeError("magick 失败: " + proc.stderr.decode("utf-8", "replace"))
        img = Image.open(io.BytesIO(proc.stdout)).convert("RGBA")
        return img.width, img.height, img.tobytes()
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def compare_one(path):
    parsed = anicore.parse_ani(path)
    total_diff = 0
    coords = []           # (帧号, x, y, python_rgba, magick_rgba)
    bad_frames = []
    for fi, mini_cur in enumerate(parsed["frame_bodies"]):
        py = anicore.decode_cur(mini_cur)
        w, h, mbytes = magick_decode_cur(mini_cur)
        py_rgba = py["rgba"]
        if (w, h) != (py["width"], py["height"]):
            total_diff += 1
            coords.append((fi, -1, -1,
                           (py["width"], py["height"]), (w, h)))
            bad_frames.append(fi)
            continue
        n = min(len(py_rgba), len(mbytes))
        frame_diff = 0
        for i in range(0, n, 4):
            if py_rgba[i:i + 4] != mbytes[i:i + 4]:
                frame_diff += 1
                if len(coords) < 20:
                    x = (i // 4) % w
                    y = (i // 4) // w
                    coords.append((fi, x, y, tuple(py_rgba[i:i + 4]), tuple(mbytes[i:i + 4])))
        if len(py_rgba) != len(mbytes):
            frame_diff += abs(len(py_rgba) - len(mbytes)) // 4
        if frame_diff:
            bad_frames.append(fi)
        total_diff += frame_diff
    return total_diff, coords, bad_frames, len(parsed["frame_bodies"])


def main(argv):
    if not argv:
        print("用法: compare_decode.py <ani> [<ani>…]", file=sys.stderr)
        return 2
    all_pass = True
    for path in argv:
        try:
            total_diff, coords, bad_frames, nframes = compare_one(path)
        except Exception as e:
            print("FAIL %s: 解码出错 %r" % (path, e))
            all_pass = False
            continue
        if total_diff == 0:
            print("PASS %s: 0 diff (%d 帧)" % (path, nframes))
        else:
            all_pass = False
            print("FAIL %s: %d diff 像素 / %d 帧 %s" % (path, total_diff, nframes, bad_frames))
            for fi, x, y, a, b in coords:
                if x < 0:
                    print("    帧 %d 尺寸不符 python=%s magick=%s" % (fi, a, b))
                else:
                    print("    帧 %d @(%d,%d) python=%s magick=%s" % (fi, x, y, a, b))
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
