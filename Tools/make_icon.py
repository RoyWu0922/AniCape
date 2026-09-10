#!/usr/bin/env python3
"""Generate Resources/AppIcon.icns — the AniCape app icon.

The mark fuses the three things this tool sits between. The macOS Apple
mark stands centred at the back, a Windows cursor stands in front of it,
and the Windows four-colour flag is inlaid into the cursor itself: the
panes are cut to the arrow's silhouette rather than laid over it, so the
arrow's dark outline runs unbroken around the colours.

Drawing order is part of the design. The four panes are sized from the
arrow's bounding box and drawn top-left, top-right, bottom-left,
bottom-right; each is wider than its quadrant, so every later pane laps
over the one before it and the cross between them sits left of centre.
That overlap is the approved artwork — change the pane offset or the order
and the mark changes with it.

Each size is rendered natively and downsampled rather than scaled from a
single master, supersampled just enough to antialias (8x up to 128px, 4x
up to 512px, 2x for the 1024px slice). The outline has a floor in final
pixels so it survives downsampling at 16 and 32px; the composition is
otherwise identical at every size.

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

# graphite ground, cursor body, cursor outline
GT, GB = (66, 72, 80), (26, 29, 34)
WHITE = (252, 252, 254)
DARK = (10, 12, 16)

# the Apple mark reads as "behind" because it is a flat grey, not white
APPLE_FILL = (178, 186, 196)

# Windows flag: red, green, cyan, yellow — drawn in this order
WIN = [(242, 80, 34), (127, 186, 0), (0, 164, 239), (255, 185, 0)]

# classic cursor arrow, normalised to its own bbox (y down, tip at origin)
ARROW = [(0.00, 0.00), (0.00, 0.72), (0.19, 0.55), (0.33, 0.95),
         (0.47, 0.88), (0.33, 0.49), (0.56, 0.49)]

# placement inside the design box, and the cross gap as a fraction of the
# arrow's mean span
ARROW_X, ARROW_Y, ARROW_SC = 0.16, 0.07, 0.66
APPLE_X, APPLE_Y, APPLE_H = 0.50, 0.50, 0.68
GAP = 0.16

# The Apple mark, as an SVG path (viewBox 0 0 814 1000) — flattened below so
# the icon carries the real mark rather than an approximation of it.
APPLE_D = (
    "M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 "
    "71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 "
    "40.8s-105.6-57-155.5-127C46.7 790.7 0 663 0 541.8c0-194.4 126.4-297.5 250.8-297.5 66.1 0 121.2 "
    "43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 "
    "53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 "
    "83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z")

# (filename, pixels) — the ten entries iconutil expects
ICONSET = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]


def tokenize(d):
    """Path data -> command letters and numbers.

    Numbers run together without separators ("4.5-108.2", "3.2.6"), so a
    sign starts a new number and a second '.' ends the current one.
    """
    out = []
    i = 0
    while i < len(d):
        c = d[i]
        if c.isalpha():
            out.append(c)
            i += 1
        elif c in ' ,\t\n\r':
            i += 1
        else:
            j = i
            if d[j] in '+-':
                j += 1
            seen = False
            while j < len(d):
                c = d[j]
                if c == '.':
                    if seen:
                        break
                    seen = True
                    j += 1
                elif c.isdigit():
                    j += 1
                else:
                    break
            out.append(float(d[i:j]))
            i = j
    return out


def subpaths(d, steps=20):
    """Flatten the path into one point list per subpath.

    The leaf and the body are separate subpaths; filling them as a single
    polygon would bridge the two with a stray line.
    """
    t = tokenize(d)
    i = 0
    subs = []
    pts = []
    cur = (0.0, 0.0)
    start = cur
    last_c = None
    cmd = None

    def flush():
        if len(pts) > 2:
            subs.append(list(pts))

    def bez(p0, p1, p2, p3):
        for s in range(1, steps + 1):
            u = 1 - s / steps
            w = s / steps
            pts.append((u ** 3 * p0[0] + 3 * u * u * w * p1[0] + 3 * u * w * w * p2[0] + w ** 3 * p3[0],
                        u ** 3 * p0[1] + 3 * u * u * w * p1[1] + 3 * u * w * w * p2[1] + w ** 3 * p3[1]))

    while i < len(t):
        if isinstance(t[i], str):
            cmd = t[i]
            i += 1
        if cmd in 'Mm':
            flush()
            pts = []
            x, y = t[i], t[i + 1]
            i += 2
            if cmd == 'm':
                x += cur[0]
                y += cur[1]
            cur = (x, y)
            start = cur
            pts.append(cur)
            last_c = None
        elif cmd in 'Ll':
            x, y = t[i], t[i + 1]
            i += 2
            if cmd == 'l':
                x += cur[0]
                y += cur[1]
            cur = (x, y)
            pts.append(cur)
            last_c = None
        elif cmd in 'Cc':
            p = [(t[i + k * 2], t[i + k * 2 + 1]) for k in range(3)]
            i += 6
            if cmd == 'c':
                p = [(cur[0] + a, cur[1] + b) for a, b in p]
            bez(cur, p[0], p[1], p[2])
            last_c = p[1]
            cur = p[2]
        elif cmd in 'Ss':
            p = [(t[i], t[i + 1]), (t[i + 2], t[i + 3])]
            i += 4
            if cmd == 's':
                p = [(cur[0] + a, cur[1] + b) for a, b in p]
            c1 = (2 * cur[0] - last_c[0], 2 * cur[1] - last_c[1]) if last_c else cur
            bez(cur, c1, p[0], p[1])
            last_c = p[0]
            cur = p[1]
        elif cmd in 'Zz':
            pts.append(start)
            cur = start
            last_c = None
        else:
            i += 1
    flush()
    return subs


APPLE = subpaths(APPLE_D)
APPLE_X0 = min(p[0] for s in APPLE for p in s)
APPLE_Y0 = min(p[1] for s in APPLE for p in s)
APPLE_BW = max(p[0] for s in APPLE for p in s) - APPLE_X0
APPLE_BH = max(p[1] for s in APPLE for p in s) - APPLE_Y0

# arrow in design-box units, and its centroid — where the pane cross goes
_ARROW = [(ARROW_X + q * ARROW_SC, ARROW_Y + r * ARROW_SC) for q, r in ARROW]


def _centroid(pts):
    a = cx = cy = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        cr = x0 * y1 - x1 * y0
        a += cr
        cx += (x0 + x1) * cr
        cy += (y0 + y1) * cr
    a *= 0.5
    return cx / (6 * a), cy / (6 * a)


CROSS = _centroid(_ARROW)


def render(px, ss=None):
    # Supersample enough to antialias, no more: the 1024px slice at 8x would
    # be an 8192px canvas, and the canvas-wide filtering below makes that
    # cost minutes for detail no one can see after the downsample.
    if ss is None:
        ss = 8 if px <= 128 else (4 if px <= 512 else 2)
    S = px * ss
    ins = int(round(INSET_R * S))
    rect = S - 2 * ins
    rad = int(round(RADIUS_R * S))

    col = Image.new("RGBA", (1, S))
    d = ImageDraw.Draw(col)
    for y in range(S):
        t = y / (S - 1)
        d.point((0, y), fill=tuple(int(round(GT[i] + (GB[i] - GT[i]) * t)) for i in range(3)) + (255,))
    ground = Image.new("L", (S, S), 0)
    ImageDraw.Draw(ground).rounded_rectangle(
        [ins, ins, ins + rect, ins + rect], radius=rad, fill=255)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.paste(col.resize((S, S)), (0, 0), ground)

    # design box -> canvas
    dw, dh = 1.00, 1.10
    sc = rect * 0.86 / max(dw, dh)
    ox = ins + (rect - dw * sc) / 2
    oy = ins + (rect - dh * sc) / 2
    T = lambda x, y: (ox + x * sc, oy + y * sc)  # noqa: E731

    # floor the outline in final pixels, or it vanishes when downsampled
    lw = max(int(S * 0.016), int(ss * (1.0 if px <= 32 else 1.3)))
    AP = [T(q, r) for q, r in _ARROW]

    # Apple mark first, so the cursor stands in front of it
    ax, ay = T(APPLE_X, APPLE_Y)
    ah = APPLE_H * sc
    s2 = ah / APPLE_BH
    wo = ax - APPLE_BW * s2 / 2 - APPLE_X0 * s2
    ho = ay - ah / 2 - APPLE_Y0 * s2
    apple = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    da = ImageDraw.Draw(apple)
    for sp in APPLE:
        da.polygon([(wo + x * s2, ho + y * s2) for x, y in sp], fill=APPLE_FILL + (255,))
    img = Image.alpha_composite(img, apple)

    cursor = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dc = ImageDraw.Draw(cursor)
    dc.polygon(AP, fill=WHITE + (255,))
    dc.line(AP + [AP[0]], fill=DARK + (255,), width=lw, joint="curve")
    img = Image.alpha_composite(img, cursor)

    # the flag is inlaid: clip the panes to the arrow's interior so the
    # outline runs unbroken around them and cursor body frames every pane
    sil = Image.new("L", (S, S), 0)
    ImageDraw.Draw(sil).polygon(AP, fill=255)
    k = max(1, int(lw * 0.55))
    inner = sil.filter(ImageFilter.MinFilter(2 * k + 1))

    xs = [p[0] for p in AP]
    ys = [p[1] for p in AP]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    g = GAP * (w + h) / 2
    hw, hh = (w - g) / 2, (h - g) / 2
    cx, cy = T(CROSS[0], CROSS[1])
    for (qx, qy), colour in zip(((-1, -1), (1, -1), (-1, 1), (1, 1)), WIN):
        a, b = cx + qx * (hw + g) / 2, cy + qy * (hh + g) / 2
        quad = [(a - hw, b - hh), (a + hw, b - hh), (a + hw, b + hh), (a - hw, b + hh)]
        qm = Image.new("L", (S, S), 0)
        ImageDraw.Draw(qm).polygon(quad, fill=255)
        img.paste(Image.new("RGB", (S, S), colour), (0, 0), ImageChops.multiply(qm, inner))

    return img.resize((px, px), Image.LANCZOS)


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
