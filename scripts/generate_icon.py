#!/usr/bin/env python3
"""
Generate a 1024x1024 app icon for SleepWindow.

Design: crescent moon tucked inside a soft rounded 'window' frame, on a
deep indigo→midnight vertical gradient. No text. No alpha (App Store
requires opaque icons).
"""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__), "..",
    "SleepWindow", "Resources", "Assets.xcassets",
    "AppIcon.appiconset", "AppIcon-1024.png",
)


def lerp(a, b, t):
    return int(a + (b - a) * t)


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        r = lerp(top[0], bottom[0], t)
        g = lerp(top[1], bottom[1], t)
        b = lerp(top[2], bottom[2], t)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    return img


def draw_crescent(img, cx, cy, radius, color, offset_frac=0.35):
    """Draw a crescent by subtracting a shifted disk from a main disk."""
    moon = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(moon)
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=color,
    )
    # Subtract a shifted circle to carve the crescent
    shift = int(radius * offset_frac)
    cut = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(cut)
    cdraw.ellipse(
        [cx - radius + shift, cy - radius, cx + radius + shift, cy + radius],
        fill=(0, 0, 0, 255),
    )
    # Alpha-composite subtraction
    moon_alpha = moon.split()[3]
    cut_alpha = cut.split()[3]
    new_alpha = Image.eval(moon_alpha, lambda a: a)
    for x_off, y_off in [(0, 0)]:
        pass
    # Manual subtract
    pixels_moon = moon.load()
    pixels_cut = cut.load()
    w, h = moon.size
    for y in range(h):
        for x in range(w):
            mr, mg, mb, ma = pixels_moon[x, y]
            cr, cg, cb, ca = pixels_cut[x, y]
            if ca > 0 and ma > 0:
                new_a = max(0, ma - ca)
                pixels_moon[x, y] = (mr, mg, mb, new_a)

    # Glow
    glow = moon.filter(ImageFilter.GaussianBlur(radius=radius * 0.12))
    img.paste(glow, (0, 0), glow)
    img.paste(moon, (0, 0), moon)


def draw_star(img, cx, cy, r, color):
    draw = ImageDraw.Draw(img, "RGBA")
    # Simple four-point sparkle
    draw.polygon(
        [
            (cx, cy - r),
            (cx + r * 0.25, cy - r * 0.25),
            (cx + r, cy),
            (cx + r * 0.25, cy + r * 0.25),
            (cx, cy + r),
            (cx - r * 0.25, cy + r * 0.25),
            (cx - r, cy),
            (cx - r * 0.25, cy - r * 0.25),
        ],
        fill=color,
    )


def draw_window_frame(img):
    """Soft rounded-rect window frame, subtle."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    inset = SIZE * 0.14
    rect = [inset, inset, SIZE - inset, SIZE - inset]
    radius = int(SIZE * 0.12)
    draw.rounded_rectangle(
        rect,
        radius=radius,
        outline=(255, 240, 220, 38),
        width=8,
    )
    img.paste(overlay, (0, 0), overlay)


def main():
    # Background: deep indigo to midnight
    img = vertical_gradient(SIZE, (36, 34, 92), (14, 14, 44))
    # Convert to RGBA for compositing layers
    img = img.convert("RGBA")

    # Subtle window frame
    draw_window_frame(img)

    # Main crescent moon
    moon_color = (245, 230, 200, 255)  # warm cream
    cx, cy = int(SIZE * 0.52), int(SIZE * 0.48)
    radius = int(SIZE * 0.24)
    draw_crescent(img, cx, cy, radius, moon_color, offset_frac=0.38)

    # Two small stars
    star_color = (255, 245, 220, 220)
    draw_star(img, int(SIZE * 0.78), int(SIZE * 0.28), int(SIZE * 0.018), star_color)
    draw_star(img, int(SIZE * 0.22), int(SIZE * 0.68), int(SIZE * 0.014), star_color)
    draw_star(img, int(SIZE * 0.28), int(SIZE * 0.30), int(SIZE * 0.010), star_color)

    # Flatten to RGB for App Store (no alpha)
    final = Image.new("RGB", (SIZE, SIZE), (14, 14, 44))
    final.paste(img, (0, 0), img)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    final.save(OUT, "PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
