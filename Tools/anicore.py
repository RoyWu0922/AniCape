#!/usr/bin/env python3
"""anicore.py — 共享的 ANI/CUR 解析与解码助手（anicap 校验工具专用）。

逐字镜像 Swift 流水线（Ruling T10-2），供 compare_decode.py 与 roundtrip.py 复用：
  - Sources/AniKit/ANIReader.swift       : RIFF/ACON 分帧 + anih/rate/seq + LIST "fram" 的 icon 块
  - Sources/AniKit/CURDecoder.swift      : mini-CUR DIB → RGBA（8/24/32bpp + AND 掩码语义）
  - Sources/AniKit/ANIDocumentBuilder.swift : 显示顺序、>24 步上限、jiffies → 秒
  - Sources/RoleKit/RoleMap.swift        : 13 中文 + 13 英文别名 → identifier，8 个跳过名
"""

import struct

__all__ = [
    "ROLE_TABLE", "SKIPPED_ROLE_NAMES",
    "identifier_for_file_name", "identifier_for_role_name",
    "ANIError", "CURError", "ANIDocumentError",
    "parse_ani", "decode_cur", "build_document", "display_frames",
]


# ---------------------------------------------------------------------------
# RoleMap（镜像 Sources/RoleKit/RoleMap.swift）
# ---------------------------------------------------------------------------
ROLE_TABLE = {
    "正常选择": "com.apple.coregraphics.Arrow",  "Normal": "com.apple.coregraphics.Arrow",
    "帮助选择": "com.apple.cursor.40",            "Help": "com.apple.cursor.40",
    "后台运行": "com.apple.cursor.4",             "Working": "com.apple.cursor.4",
    "忙": "com.apple.coregraphics.Wait",          "Busy": "com.apple.coregraphics.Wait",
    "精确选择": "com.apple.cursor.7",             "Precision": "com.apple.cursor.7",
    "文本选择": "com.apple.coregraphics.IBeam",   "Text": "com.apple.coregraphics.IBeam",
    "垂直调整": "com.apple.cursor.32",            "Vertical": "com.apple.cursor.32",
    "水平调整": "com.apple.cursor.28",            "Horizontal": "com.apple.cursor.28",
    "沿对角线调整1": "com.apple.cursor.34",       "Diagonal1": "com.apple.cursor.34",
    "沿对角线调整2": "com.apple.cursor.30",       "Diagonal2": "com.apple.cursor.30",
    "移动": "com.apple.coregraphics.Move",        "Move": "com.apple.coregraphics.Move",
    "链接选择": "com.apple.cursor.2",             "Link": "com.apple.cursor.2",
    "不可用": "com.apple.cursor.3",               "Unavailable": "com.apple.cursor.3",
}

# 无 macOS 槽 → 跳过（与「未识别」区分，便于打印说明）
SKIPPED_ROLE_NAMES = {"手写", "候选", "位置选择", "个人选择",
                      "Handwriting", "Alternate", "Pin", "Person"}


def identifier_for_file_name(base):
    if base in SKIPPED_ROLE_NAMES:
        return None
    return ROLE_TABLE.get(base)


def identifier_for_role_name(name):
    if "." in name:
        return name
    return identifier_for_file_name(name)


# ---------------------------------------------------------------------------
# 异常
# ---------------------------------------------------------------------------
class ANIError(Exception):
    pass


class CURError(Exception):
    pass


class ANIDocumentError(Exception):
    pass


# ---------------------------------------------------------------------------
# 小端读取
# ---------------------------------------------------------------------------
def _u16(d, o):
    return struct.unpack_from("<H", d, o)[0]


def _u32(d, o):
    return struct.unpack_from("<I", d, o)[0]


def _i32(d, o):
    return struct.unpack_from("<i", d, o)[0]


# ---------------------------------------------------------------------------
# RIFF/ACON 分帧（镜像 ANIReader.parse）
# ---------------------------------------------------------------------------
def _chunks(data, start):
    out = []
    off = start
    n = len(data)
    while off + 8 <= n:
        cid = data[off:off + 4]
        (length,) = struct.unpack_from("<I", data, off + 4)
        body = data[off + 8:off + 8 + length]
        out.append((cid, body))
        off += 8 + length + (length % 2)   # 内容按 2 字节对齐补零
    return out


def parse_ani(path):
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 12 or data[0:4] != b"RIFF":
        raise ANIError("notRIFF")
    if data[8:12] != b"ACON":
        raise ANIError("notACON")

    header = None
    frame_bodies = []
    rates = None
    seq = None

    for cid, body in _chunks(data, 12):
        if cid == b"anih":
            if len(body) < 36:
                raise ANIError("truncated")
            # anih 布局: cbSize(0) frames(4) steps(8) cx(16) cy(20) bitCount(24) planes(26) rate(28) flags(32)
            # anih 的 cx/cy 偏移 16/20 逐字镜像 ANIReader.swift；真实语料这两字段写 0（死字段，
            # 真实尺寸来自每个 icon 的 DIB），故无害且忠实。
            header = {
                "declaredFrames": _u32(body, 4),
                "defaultRateJiffies": _u32(body, 28),
                "width": _u32(body, 16),
                "height": _u32(body, 20),
            }
        elif cid == b"rate":
            rates = [_u32(body, o) for o in range(0, len(body), 4)]
        elif cid == b"seq ":
            seq = [_u32(body, o) for o in range(0, len(body), 4)]
        elif cid == b"LIST":
            if len(body) < 4 or body[0:4] != b"fram":
                continue
            for scid, sbody in _chunks(body, 4):
                if scid == b"icon":
                    frame_bodies.append(sbody)
        # 其它块忽略

    if header is None:
        raise ANIError("truncated")
    if not frame_bodies:
        raise ANIError("noFrames")
    if header["declaredFrames"] <= 0:
        raise ANIError("invalidFrameCount")

    return {"header": header, "frame_bodies": frame_bodies, "rates": rates, "seq": seq}


# ---------------------------------------------------------------------------
# mini-CUR DIB → RGBA（镜像 CURDecoder.decode）
# ---------------------------------------------------------------------------
def decode_cur(mini_cur):
    if len(mini_cur) < 22:
        raise CURError("shortHeader")
    typ = _u16(mini_cur, 2)
    if typ != 2:
        raise CURError("unsupportedType %d" % typ)
    hx = _u16(mini_cur, 10)          # wPlanes = hotspotX
    hy = _u16(mini_cur, 12)          # wBitCount = hotspotY
    image_offset = _u32(mini_cur, 18)
    if image_offset + 40 > len(mini_cur):
        raise CURError("corrupt")

    img = mini_cur[image_offset:]
    bi_size = _u32(img, 0)
    if bi_size != 40:
        raise CURError("notBitmap %d" % bi_size)
    width = _i32(img, 4)
    raw_height = _i32(img, 8)
    height = abs(raw_height)
    top_down = raw_height < 0
    bpp = _u16(img, 14)
    compression = _u32(img, 16)
    clr_used = _u32(img, 32)

    if not (width > 0 and height > 0 and width <= 1024 and height <= 2048):
        raise CURError("corrupt")
    if compression != 0:
        raise CURError("unsupportedCompression %d" % compression)
    if bpp not in (8, 24, 32):
        raise CURError("unsupportedBPP %d" % bpp)
    if height % 2 != 0:
        raise CURError("corrupt")
    frame_h = height // 2             # XOR 高（AND 占另一半）

    pos = 40
    palette = []
    if bpp <= 8:
        n = clr_used if clr_used > 0 else (1 << bpp)
        if pos + n * 4 > len(img):
            raise CURError("corrupt")
        for _ in range(n):
            palette.append((img[pos + 2], img[pos + 1], img[pos]))   # BGRX → RGB
            pos += 4

    xor_row_bytes = ((width * bpp + 31) // 32) * 4
    xor_bytes = xor_row_bytes * frame_h
    if pos + xor_bytes > len(img):
        raise CURError("corrupt")
    xor = img[pos:pos + xor_bytes]
    pos += xor_bytes

    mask_row_bytes = ((width + 31) // 32) * 4
    mask_bytes = mask_row_bytes * frame_h
    if pos + mask_bytes > len(img):
        raise CURError("corrupt")
    and_mask = img[pos:pos + mask_bytes]

    rgba = bytearray(width * frame_h * 4)
    for yy in range(frame_h):
        xor_row = yy if top_down else (frame_h - 1 - yy)   # XOR 的存储行
        and_row = frame_h - 1 - yy                          # AND 与 XOR 同自下而上存储
        for x in range(width):
            out = (yy * width + x) * 4
            bit = and_mask[and_row * mask_row_bytes + x // 8] & (0x80 >> (x % 8))
            if bit != 0:
                continue                                     # AND=1 → 全 0（透明）
            if bpp == 32:
                s = xor_row * xor_row_bytes + x * 4
                rgba[out] = xor[s + 2]
                rgba[out + 1] = xor[s + 1]
                rgba[out + 2] = xor[s]
                rgba[out + 3] = xor[s + 3]
            elif bpp == 24:
                s = xor_row * xor_row_bytes + x * 3
                rgba[out] = xor[s + 2]
                rgba[out + 1] = xor[s + 1]
                rgba[out + 2] = xor[s]
                rgba[out + 3] = 255
            else:  # 8
                p = palette[xor[xor_row * xor_row_bytes + x]]
                rgba[out] = p[0]
                rgba[out + 1] = p[1]
                rgba[out + 2] = p[2]
                rgba[out + 3] = 255

    return {
        "width": width,
        "height": frame_h,
        "rgba": bytes(rgba),
        "hotspotX": hx,
        "hotspotY": hy,
    }


# ---------------------------------------------------------------------------
# 显示顺序 + 时长（镜像 ANIDocumentBuilder.build）
# ---------------------------------------------------------------------------
def build_document(parsed):
    images = [decode_cur(b) for b in parsed["frame_bodies"]]
    if not images:
        raise ANIError("noFrames")

    w0, h0 = images[0]["width"], images[0]["height"]
    for i, im in enumerate(images):
        if im["width"] != w0 or im["height"] != h0:
            raise ANIDocumentError("mismatchedFrameSize %d" % i)

    if parsed["seq"] is not None:
        seq = parsed["seq"]
        if not all(0 <= v < len(images) for v in seq):
            raise ANIDocumentError("badSeq")
        indices = list(seq)
    else:
        indices = list(range(len(images)))

    if len(indices) > 24:
        raise ANIDocumentError("tooManyFrames %d" % len(indices))

    rates = parsed["rates"]
    if rates is not None and len(rates) > 0:
        jiffies = rates[0]             # 语料恒均匀；不均时取首值（已知限制）
    else:
        jiffies = parsed["header"]["defaultRateJiffies"]

    return {
        "frames": images,
        "display_indices": indices,
        "frame_duration": float(jiffies) / 60.0,
    }


def display_frames(parsed):
    """返回显示顺序下的 RGBA 帧列表：第 i 条 == 物理帧 display_indices[i]。"""
    doc = build_document(parsed)
    return [doc["frames"][i]["rgba"] for i in doc["display_indices"]], doc
