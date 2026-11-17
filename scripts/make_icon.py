#!/usr/bin/env python3
"""Generate the 1024x1024 app icon (no external assets needed).

Renders at 4x with supersampling for crisp antialiased edges, then downsamples.
Motif: a rising line chart + candlesticks on a deep navy gradient — a clean,
finance-forward mark that reads well at small sizes.
"""
from PIL import Image, ImageDraw
import os

S = 1024
SS = 4  # supersample factor
W = S * SS
img = Image.new("RGB", (W, W), (8, 16, 28))
d = ImageDraw.Draw(img)

# Vertical gradient background (deep navy -> slightly lighter).
top = (10, 22, 40)
bot = (6, 12, 22)
for y in range(W):
    t = y / W
    r = int(top[0] + (bot[0] - top[0]) * t)
    g = int(top[1] + (bot[1] - top[1]) * t)
    b = int(top[2] + (bot[2] - top[2]) * t)
    d.line([(0, y), (W, y)], fill=(r, g, b))

green = (76, 215, 149)
green_d = (54, 170, 118)
red = (235, 83, 92)
grid = (28, 44, 66)

# Faint baseline grid.
for i in range(1, 5):
    y = int(W * i / 5)
    d.line([(W * 0.10, y), (W * 0.90, y)], fill=grid, width=SS * 2)

# Candlesticks across the lower portion.
candles = [
    # (cx_frac, open_frac, close_frac, high_frac, low_frac, up?)
    (0.20, 0.72, 0.64, 0.60, 0.76, True),
    (0.32, 0.66, 0.70, 0.62, 0.74, False),
    (0.44, 0.68, 0.56, 0.52, 0.72, True),
    (0.56, 0.58, 0.50, 0.46, 0.62, True),
    (0.68, 0.52, 0.58, 0.48, 0.62, False),
    (0.80, 0.54, 0.42, 0.38, 0.58, True),
]
cw = W * 0.055
for cx, o, c, hi, lo, up in candles:
    x = W * cx
    col = green if up else red
    # wick
    d.line([(x, W * hi), (x, W * lo)], fill=col, width=SS * 5)
    # body
    y0 = W * min(o, c)
    y1 = W * max(o, c)
    d.rounded_rectangle([x - cw / 2, y0, x + cw / 2, y1],
                        radius=SS * 6, fill=col)

# Rising trend line over the candles.
pts = [(0.14, 0.70), (0.26, 0.63), (0.38, 0.66),
       (0.50, 0.52), (0.62, 0.55), (0.74, 0.44), (0.86, 0.34)]
line = [(W * x, W * y) for x, y in pts]
d.line(line, fill=green, width=SS * 11, joint="curve")
for (x, y) in line:
    d.ellipse([x - SS * 10, y - SS * 10, x + SS * 10, y + SS * 10], fill=(220, 255, 240))

# Up-arrow head at the end of the trend line.
ex, ey = line[-1]
ah = SS * 42
d.polygon([(ex - ah * 0.1, ey - ah), (ex - ah, ey + ah * 0.2),
           (ex + ah, ey + ah * 0.2)], fill=green)
# retouch the tip node on top of the arrow
d.ellipse([ex - SS * 10, ey - SS * 10, ex + SS * 10, ey + SS * 10], fill=(220, 255, 240))

img = img.resize((S, S), Image.LANCZOS)

out = os.path.join(os.path.dirname(__file__), "..",
                   "StockWatcher", "App", "Assets.xcassets",
                   "AppIcon.appiconset", "AppIcon-1024.png")
out = os.path.abspath(out)
# iOS app icons must be fully opaque with no alpha channel.
img.convert("RGB").save(out, "PNG")
print("wrote", out)
