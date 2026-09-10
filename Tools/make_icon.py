#!/usr/bin/env python3
"""Generate Resources/AppIcon.icns — the AniCape app icon.

The mark is an animated cursor: one solid arrow with a trail of fading
ghosts behind it, which is what this tool moves between platforms.

Each size is rendered natively at 8x and downsampled, rather than scaling
one master, and the artwork simplifies as it shrinks:

    >= 128px   three trailing ghosts, outline, drop shadow
      64px     two ghosts
      32px     one faint ghost
      16px     a plain white silhouette — trail and shadow are mud at
               that size, and the outline alone would eat the arrow

Requires Pillow and macOS's iconutil.
"""
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# macOS icon grid: content sits in a rounded square inset from the canvas
INSET_R = 100 / 1024
RADIUS_R = (824 / 1024) * 0.2246
TOP, BOT = (74, 108, 247), (23, 37, 120)
INK = (12, 18, 48)

# classic cursor arrow, normalised to its own bbox (y down, tip at origin)
ARROW = [(0.00, 0.00), (0.00, 0.72), (0.19, 0.55), (0.33, 0.95),
         (0.47, 0.88), (0.33, 0.49), (0.56, 0.49)]
AB_W, AB_H = 0.56, 0.95

# (filename, pixels) — the ten entries iconutil expects
ICONSET = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def config(px):
    if px >= 128:
        return dict(step=0.30, alphas=(0.62, 0.40, 0.22), fill=0.82,
                    shrink=0.94, shadow=130, outline=True)
    if px >= 64:
        return dict(step=0.28, alphas=(0.58, 0.30), fill=0.86,
                    shrink=0.94, shadow=120, outline=True)
    if px >= 32:
        return dict(step=0.30, alphas=(0.38,), fill=0.90,
                    shrink=1.0, shadow=80, outline=True)
    return dict(step=0.26, alphas=(), fill=0.96,
                shrink=1.0, shadow=0, outline=False)


def render(px, ss=8):
    S = px * ss
    ins = int(round(INSET_R * S))
    rect = S - 2 * ins
    rad = int(round(RADIUS_R * S))
    cfg = config(px)
    alphas, n = cfg["alphas"], len(cfg["alphas"])
    step, fill, shrink = cfg["step"], cfg["fill"], cfg["shrink"]

    def rmask():
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).rounded_rectangle(
            [ins, ins, ins + rect, ins + rect], radius=rad, fill=255)
        return m

    col = Image.new("RGBA", (1, S))
    d = ImageDraw.Draw(col)
    for y in range(S):
        d.point((0, y), fill=lerp(TOP, BOT, y / (S - 1)) + (255,))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(col.resize((S, S)), (0, 0), rmask())

    hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse(
        [ins - rect * .1, ins - rect * .62, ins + rect * 1.1, ins + rect * .52],
        fill=(255, 255, 255, 70))
    hl = hl.filter(ImageFilter.GaussianBlur(S * 0.045))
    hl.putalpha(ImageChops.multiply(hl.getchannel("A"), rmask()))
    img = Image.alpha_composite(img, hl)

    def pts(x0, y0, sc):
        return [(x0 + q * sc, y0 + r * sc) for q, r in ARROW]

    cw, ch = AB_W + n * step, AB_H + n * step
    ah = fill * rect / ch
    sc = ah / AB_H
    x0 = ins + (rect - cw * ah) / 2
    y0 = ins + (rect - ch * ah) / 2

    for k in range(n, 0, -1):
        off = k * step * ah
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(layer).polygon(pts(x0 + off, y0 + off, sc * (shrink ** k)),
                                      fill=(255, 255, 255, 255))
        a = int(255 * alphas[k - 1])
        layer.putalpha(layer.getchannel("A").point(lambda v, a=a: v * a // 255))
        img = Image.alpha_composite(img, layer)

    if cfg["shadow"]:
        sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sh).polygon(pts(x0, y0 + S * 0.012, sc),
                                   fill=(8, 12, 36, cfg["shadow"]))
        img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(S * 0.018)))

    sol = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(sol)
    P = pts(x0, y0, sc)
    dd.polygon(P, fill=(255, 255, 255, 255))
    if cfg["outline"]:
        # floor the outline in final pixels, or it vanishes when downsampled
        floor = ss * 1.0 if px <= 32 else ss * 1.3
        dd.line(list(P) + [P[0]], fill=INK + (255,),
                width=max(int(S * 0.0125), int(floor)), joint="curve")
    return Image.alpha_composite(img, sol).resize((px, px), Image.LANCZOS)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "Resources", "AppIcon.icns")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    tmp = tempfile.mkdtemp(prefix="anicape_iconset_")
    try:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)
        cache = {}
        for name, px in ICONSET:
            if px not in cache:
                cache[px] = render(px)
            cache[px].save(os.path.join(iconset, name))
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"wrote {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    main()
