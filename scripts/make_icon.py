#!/usr/bin/env python3
"""Generate the 1024x1024 app icon (no external assets needed).

Renders at 4x with supersampling for crisp antialiased edges, then downsamples.
Motif: a rising line chart + candlesticks on a deep PANTONE Classic Blue ground,
with an Emerald trend line and a soft glow — matching the app/widget palette.

PANTONE references (sRGB approximations):
  Classic Blue 19-4052, Emerald 17-5641, Living Coral 16-1546,
  Marigold 14-1050, Illuminating 13-0647.
"""
from PIL import Image, ImageDraw, ImageFilter
import os

S = 1024
SS = 4  # supersample factor
W = S * SS

# --- PANTONE-derived palette (brightened a touch for icon vibrancy) ---
bg_top = (16, 50, 92)     # deep Classic Blue
bg_bot = (6, 18, 34)
grid   = (26, 54, 90)
emerald      = (0, 170, 131)     # up / trend line
emerald_soft = (0, 140, 110)
coral        = (255, 111, 97)    # down
mint_node    = (214, 255, 240)
glow_rgb     = (0, 190, 150)

# --- base (RGBA) with vertical gradient ---
img = Image.new("RGBA", (W, W), (bg_bot[0], bg_bot[1], bg_bot[2], 255))
d = ImageDraw.Draw(img)
for y in range(W):
    t = y / W
    r = int(bg_top[0] + (bg_bot[0] - bg_top[0]) * t)
    g = int(bg_top[1] + (bg_bot[1] - bg_top[1]) * t)
    b = int(bg_top[2] + (bg_bot[2] - bg_top[2]) * t)
    d.line([(0, y), (W, y)], fill=(r, g, b, 255))

# Faint baseline grid.
for i in range(1, 5):
    y = int(W * i / 5)
    d.line([(W * 0.10, y), (W * 0.90, y)], fill=(grid[0], grid[1], grid[2], 255), width=SS * 2)

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
    col = (emerald if up else coral) + (255,)
    d.line([(x, W * hi), (x, W * lo)], fill=col, width=SS * 5)            # wick
    y0 = W * min(o, c)
    y1 = W * max(o, c)
    d.rounded_rectangle([x - cw / 2, y0, x + cw / 2, y1], radius=SS * 6, fill=col)

# Rising trend line.
pts = [(0.14, 0.70), (0.26, 0.63), (0.38, 0.66),
       (0.50, 0.52), (0.62, 0.55), (0.74, 0.44), (0.86, 0.34)]
line = [(W * x, W * y) for x, y in pts]

# --- soft glow under the trend line (blurred emerald on its own layer) ---
glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.line(line, fill=glow_rgb + (230,), width=SS * 16, joint="curve")
glow = glow.filter(ImageFilter.GaussianBlur(radius=SS * 16))
img = Image.alpha_composite(img, glow)

# crisp line + nodes on top of the glow
d = ImageDraw.Draw(img)
d.line(line, fill=emerald + (255,), width=SS * 11, joint="curve")
for (x, y) in line:
    d.ellipse([x - SS * 10, y - SS * 10, x + SS * 10, y + SS * 10], fill=mint_node + (255,))

# Up-arrow head at the end of the trend line.
ex, ey = line[-1]
ah = SS * 42
d.polygon([(ex - ah * 0.1, ey - ah), (ex - ah, ey + ah * 0.2),
           (ex + ah, ey + ah * 0.2)], fill=emerald + (255,))
d.ellipse([ex - SS * 10, ey - SS * 10, ex + SS * 10, ey + SS * 10], fill=mint_node + (255,))

img = img.resize((S, S), Image.LANCZOS)

out = os.path.join(os.path.dirname(__file__), "..",
                   "StockWatcher", "App", "Assets.xcassets",
                   "AppIcon.appiconset", "AppIcon-1024.png")
out = os.path.abspath(out)
# iOS app icons must be fully opaque with no alpha channel.
img.convert("RGB").save(out, "PNG")
print("wrote", out)
