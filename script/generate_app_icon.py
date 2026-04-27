#!/usr/bin/env python3
"""Generate TinySigner macOS app icon renditions.

Requires Pillow:
    python3 -m pip install Pillow
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import json

ROOT = Path(__file__).resolve().parents[1]
APPICON = ROOT / "TinySigner/Assets.xcassets/AppIcon.appiconset"
DOCS_IMG = ROOT / "docs/images"
APPICON.mkdir(parents=True, exist_ok=True)
DOCS_IMG.mkdir(parents=True, exist_ok=True)

S = 2048
r = lambda value: int(round(value * S / 1024))
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
blank = Image.new("RGBA", (S, S), (0, 0, 0, 0))

shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((r(60), r(72), r(964), r(976)), radius=r(212), fill=(0, 0, 0, 92))
img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(r(26))))

grad_small = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
gp = grad_small.load()
for y in range(1024):
    for x in range(1024):
        t = (x * 0.72 + y * 0.55) / (1024 * 1.27)
        gp[x, y] = (int(12 + 19 * t), int(42 + 74 * t), int(65 + 85 * t), 255)
grad = grad_small.resize((S, S), Image.Resampling.BICUBIC)
mask = Image.new("L", (S, S), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle((r(64), r(56), r(960), r(952)), radius=r(208), fill=255)
img.alpha_composite(Image.composite(grad, blank, mask))

glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse((r(80), r(670), r(1020), r(1160)), fill=(29, 205, 213, 58))
img.alpha_composite(Image.composite(glow.filter(ImageFilter.GaussianBlur(r(58))), blank, mask))

page_shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ps = ImageDraw.Draw(page_shadow)
ps.rounded_rectangle((r(258), r(176), r(744), r(822)), radius=r(52), fill=(0, 0, 0, 80))
img.alpha_composite(page_shadow.filter(ImageFilter.GaussianBlur(r(16))))

d = ImageDraw.Draw(img)
d.rounded_rectangle((r(238), r(154), r(724), r(800)), radius=r(50), fill=(250, 248, 241, 255))
d.polygon([(r(625), r(154)), (r(724), r(252)), (r(625), r(252))], fill=(219, 234, 238, 255))
d.line([(r(625), r(154)), (r(625), r(252)), (r(724), r(252))], fill=(157, 178, 187, 220), width=r(4))
for y, width in [(322, 340), (370, 390), (418, 305), (516, 380), (566, 300), (646, 372)]:
    d.rounded_rectangle((r(304), r(y), r(304 + width), r(y + 12)), radius=r(6), fill=(37, 70, 86, 42))
d.rounded_rectangle((r(302), r(700), r(660), r(709)), radius=r(4), fill=(26, 47, 60, 72))


def cubic(p0, p1, p2, p3, n=120):
    points = []
    for i in range(n):
        t = i / (n - 1)
        x = (1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t ** 2 * p2[0] + t ** 3 * p3[0]
        y = (1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t ** 2 * p2[1] + t ** 3 * p3[1]
        points.append((r(x), r(y)))
    return points


def round_stroke(draw, points, width, fill):
    draw.line(points, fill=fill, width=width)
    radius = width // 2
    step = max(1, len(points) // 80)
    for x, y in points[::step]:
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=fill)


signature = cubic((312, 676), (362, 592), (408, 764), (458, 684), 70)
signature += cubic((458, 684), (510, 612), (552, 730), (604, 670), 70)[1:]
signature += cubic((604, 670), (636, 632), (664, 676), (690, 650), 45)[1:]
round_stroke(d, signature, r(50), (250, 248, 241, 255))
round_stroke(d, signature, r(26), (8, 29, 43, 255))
round_stroke(d, signature, r(7), (32, 188, 205, 255))

d.rounded_rectangle((r(612), r(602), r(812), r(730)), radius=r(42), fill=(23, 190, 201, 255))
d.line([(r(654), r(666)), (r(704), r(710)), (r(768), r(626))], fill=(250, 255, 253, 255), width=r(22), joint="curve")

master = img.resize((1024, 1024), Image.Resampling.LANCZOS)
master.save(DOCS_IMG / "app-icon-preview.png")

sizes = [
    ("16x16", "1x", 16), ("16x16", "2x", 32),
    ("32x32", "1x", 32), ("32x32", "2x", 64),
    ("128x128", "1x", 128), ("128x128", "2x", 256),
    ("256x256", "1x", 256), ("256x256", "2x", 512),
    ("512x512", "1x", 512), ("512x512", "2x", 1024),
]
images = []
for logical_size, scale, pixels in sizes:
    filename = f"app-icon-{logical_size}.png" if scale == "1x" else f"app-icon-{logical_size}@{scale}.png"
    master.resize((pixels, pixels), Image.Resampling.LANCZOS).save(APPICON / filename)
    images.append({"idiom": "mac", "size": logical_size, "scale": scale, "filename": filename})

(APPICON / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
print(f"Generated {len(images)} icon renditions in {APPICON}")
