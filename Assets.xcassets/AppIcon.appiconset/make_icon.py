#!/usr/bin/env python3
"""Generate the BrainDump app icon.

Design: bold white "B" monogram on a vertical purple→blue gradient,
with a single AI-style sparkle accent in the upper-right corner.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

SIZE = 1024
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "AppIcon.png")

TOP = (154, 140, 254)      # #9A8CFE
BOTTOM = (63, 93, 227)     # #3F5DE3
SHADOW = (27, 27, 107)


def vertical_gradient(size, top, bottom):
    """Build a vertical gradient by resizing a 1×N strip — fast and smooth."""
    strip = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        strip.putpixel((0, y), tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return strip.resize((size, size), Image.BILINEAR)


def find_font(size):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Black.ttf",
        "/System/Library/Fonts/Avenir Next.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                # For .ttc collections, try the bold/black variant
                if path.endswith(".ttc"):
                    for index in (8, 7, 1, 0):
                        try:
                            return ImageFont.truetype(path, size, index=index)
                        except Exception:
                            continue
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_sparkle(draw, cx, cy, radius, fill=(255, 255, 255, 255)):
    """Apple-Intelligence-style 4-point sparkle: sharp cardinal tips with deep concave bays."""
    import math
    tip_d = radius
    valley_d = radius * 0.18      # smaller → deeper concave bays
    ctrl_frac = 0.45              # control points pulled toward center → curved sides

    # 8 alternating keypoints around the shape (tip, valley, tip, valley, …)
    keypoints = []
    for i in range(8):
        theta = (i / 8) * 2 * math.pi - math.pi / 2  # start at top tip
        d = tip_d if i % 2 == 0 else valley_d
        keypoints.append((math.cos(theta) * d, math.sin(theta) * d))

    polygon = []
    for i in range(8):
        a = keypoints[i]
        b = keypoints[(i + 1) % 8]
        ctrl_a = (a[0] * ctrl_frac, a[1] * ctrl_frac)
        ctrl_b = (b[0] * ctrl_frac, b[1] * ctrl_frac)
        for j in range(20):
            t = j / 20
            mt = 1 - t
            x = mt**3 * a[0] + 3 * mt**2 * t * ctrl_a[0] + 3 * mt * t**2 * ctrl_b[0] + t**3 * b[0]
            y = mt**3 * a[1] + 3 * mt**2 * t * ctrl_a[1] + 3 * mt * t**2 * ctrl_b[1] + t**3 * b[1]
            polygon.append((cx + x, cy + y))

    draw.polygon(polygon, fill=fill)


# 1. Background gradient
img = vertical_gradient(SIZE, TOP, BOTTOM).convert("RGBA")

# 2. Letter mark layer with subtle drop shadow
text_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
text_draw = ImageDraw.Draw(text_layer)
font = find_font(820)
text = "B"
bbox = text_draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
# Center, slight upward bias to compensate for visual weight
tx = (SIZE - tw) / 2 - bbox[0]
ty = (SIZE - th) / 2 - bbox[1] + 18
text_draw.text((tx, ty), text, fill=(255, 255, 255, 255), font=font)

# Shadow under the letter
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.text((tx, ty + 22), text, fill=SHADOW + (95,), font=font)
shadow = shadow.filter(ImageFilter.GaussianBlur(28))

img = Image.alpha_composite(img, shadow)
img = Image.alpha_composite(img, text_layer)

# 3. Sparkle accent in upper-right
sparkle_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sparkle_draw = ImageDraw.Draw(sparkle_layer)
draw_sparkle(sparkle_draw, cx=830, cy=210, radius=110)
# Soft glow behind the sparkle
glow = sparkle_layer.filter(ImageFilter.GaussianBlur(22))
img = Image.alpha_composite(img, Image.eval(glow, lambda v: int(v * 0.6)) if False else glow)
img = Image.alpha_composite(img, sparkle_layer)

img.convert("RGB").save(OUT, "PNG", optimize=True)
print(f"Wrote {OUT}")
