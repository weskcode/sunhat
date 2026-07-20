#!/usr/bin/env python3
"""Generate 10 framed App Store marketing screenshots at 1320x2868px (6.9" class)."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import math

W, H = 1320, 2868
BASE = os.path.dirname(__file__)
RAW_DIR = os.path.join(BASE, "Raw")
OUT_DIR = os.path.join(BASE, "Framed")
os.makedirs(OUT_DIR, exist_ok=True)

FONT_HEAVY = "/Library/Fonts/SF-Pro-Display-Heavy.otf"
FONT_BOLD = "/Library/Fonts/SF-Pro-Display-Bold.otf"
FONT_SEMI = "/Library/Fonts/SF-Pro-Display-Semibold.otf"
FONT_MEDIUM = "/Library/Fonts/SF-Pro-Display-Medium.otf"
FONT_REG = "/Library/Fonts/SF-Pro-Display-Regular.otf"


# ─── Background ──────────────────────────────────────────────────────

def make_gradient(size, c1, c2):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        for x in range(w):
            diagonal = (x / max(w - 1, 1)) * 0.22
            tt = min(1, max(0, t * 0.88 + diagonal))
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * tt) for i in range(3))

    draw = ImageDraw.Draw(img, "RGBA")

    # Horizon light: a wide weather-front glow rather than a generic radial orb.
    horizon_y = int(h * 0.56)
    for offset in range(0, 520, 8):
        alpha = max(0, int(30 * (1 - offset / 520)))
        draw.rounded_rectangle(
            [(-180 - offset, horizon_y - offset // 4), (w + 180 + offset, horizon_y + 110 + offset // 3)],
            radius=180 + offset // 2,
            fill=(255, 191, 112, alpha),
        )

    # Forecast grid, skewed like a meteorology map.
    grid = (255, 255, 255, 22)
    for i in range(-2, 10):
        x = int(i * w / 7)
        draw.line([(x, int(h * 0.08)), (x + int(w * 0.24), h)], fill=grid, width=2)
    for i in range(0, 11):
        y = int(h * (0.10 + i * 0.085))
        draw.line([(0, y), (w, y - int(h * 0.04))], fill=(255, 255, 255, 16), width=2)

    # Pressure contour lines give every frame a subject-specific signature.
    for i in range(9):
        y = int(h * (0.20 + i * 0.065))
        amp = 28 + i * 5
        points = []
        for x in range(-80, w + 100, 42):
            yy = y + int(math.sin((x / 130) + i * 0.75) * amp)
            points.append((x, yy))
        draw.line(points, fill=(255, 255, 255, max(16, 50 - i * 4)), width=2)

    # Fine grain keeps large color fields from feeling machine-flat.
    for y in range(0, h, 6):
        alpha = 6 if (y // 6) % 2 == 0 else 3
        draw.line([(0, y), (w, y)], fill=(255, 255, 255, alpha), width=1)
    return img


# ─── Device presentation ─────────────────────────────────────────────

def round_corners(img, radius):
    rgba = img.convert("RGBA")
    mask = Image.new("L", rgba.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (rgba.width - 1, rgba.height - 1)], radius=radius, fill=255)
    rgba.putalpha(mask)
    return rgba


def add_bezel_rim(img, radius, width=3):
    """A thin light rim + inner shadow line around the screenshot corners to
    read as a physical device edge rather than a flat cropped rectangle."""
    rgba = img.convert("RGBA")
    draw = ImageDraw.Draw(rgba)
    draw.rounded_rectangle(
        [(width / 2, width / 2), (rgba.width - 1 - width / 2, rgba.height - 1 - width / 2)],
        radius=radius, outline=(255, 255, 255, 130), width=width)
    draw.rounded_rectangle(
        [(width + 1, width + 1), (rgba.width - 2 - width, rgba.height - 2 - width)],
        radius=radius - width, outline=(0, 0, 0, 40), width=1)
    return rgba


def add_glass_reflection(img):
    """A soft diagonal glossy streak across the upper third — reads as glass."""
    rgba = img.convert("RGBA")
    w, h = rgba.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    band_w = int(w * 0.55)
    draw.polygon(
        [(-40, 0), (band_w, 0), (band_w - int(w * 0.35), int(h * 0.5)), (-40 - int(w * 0.1), int(h * 0.5))],
        fill=(255, 255, 255, 22),
    )
    draw.polygon(
        [(band_w + int(w * 0.08), 0), (band_w + int(w * 0.2), 0),
         (band_w + int(w * 0.2) - int(w * 0.35), int(h * 0.5)), (band_w + int(w * 0.08) - int(w * 0.35), int(h * 0.5))],
        fill=(255, 255, 255, 14),
    )
    overlay = overlay.filter(ImageFilter.GaussianBlur(18))
    return Image.alpha_composite(rgba, overlay)


def add_shadow(img, blur=44, alpha=120):
    w, h = img.size
    pad = blur * 2
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, alpha))
    if img.mode == "RGBA":
        shadow.putalpha(img.split()[3])
    canvas.paste(shadow, (pad, pad + 16))
    canvas = canvas.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(img, (pad, pad), img)
    return canvas, pad


def text_centered(draw, text, y, font, fill, cw, spacing=1.18):
    total = 0
    for line in text.split("\n"):
        bb = draw.textbbox((0, 0), line, font=font)
        lh, tw = bb[3] - bb[1], bb[2] - bb[0]
        draw.text(((cw - tw) // 2, y + total), line, font=font, fill=fill)
        total += int(lh * spacing)
    return total


def generate(cfg):
    canvas = make_gradient((W, H), cfg["g1"], cfg["g2"]).convert("RGBA")

    # Accent weather-front flare behind the caption
    a = cfg["ac"]
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(950, 0, -8):
        al = max(0, int(24 * (1 - r / 950)))
        gd.rounded_rectangle(
            [W // 2 - r, 315 - r // 5, W // 2 + r, 485 + r // 4],
            radius=230,
            fill=(*a, al),
        )
    canvas = Image.alpha_composite(canvas, glow)

    draw = ImageDraw.Draw(canvas)
    fc = ImageFont.truetype(FONT_HEAVY, 103)
    fs = ImageFont.truetype(FONT_MEDIUM, 42)

    ch = text_centered(draw, cfg["cap"], 124, fc, (255, 255, 255, 255), W)
    sy = 124 + ch + 18
    text_centered(draw, cfg["sub"], sy, fs, (255, 255, 255, 176), W)

    # Load + crop the raw capture
    raw_path = os.path.join(RAW_DIR, cfg["raw"])
    raw = Image.open(raw_path).convert("RGBA")
    if "crop" in cfg:
        raw = raw.crop(cfg["crop"])

    top = sy + 104
    area_h = H - top - 136
    area_w = W - 96
    rw, rh = raw.size

    sc = min(area_w / rw, area_h / rh)
    raw = raw.resize((int(rw * sc), int(rh * sc)), Image.LANCZOS)

    raw = round_corners(raw, 46)
    raw = add_bezel_rim(raw, 46)
    raw = add_glass_reflection(raw)
    shadowed, pad = add_shadow(raw)

    px = (W - shadowed.width) // 2
    # Center vertically within the available area rather than pinning to the top, so a
    # shot whose crop is proportionally shorter (e.g. one avoiding an unusable region of
    # the raw capture) doesn't dump all the leftover space as a gap at the bottom.
    py = top + max(0, (area_h - shadowed.height) // 2)
    canvas.paste(shadowed, (px, py), shadowed)

    # Flatten to RGB (no alpha for App Store)
    final = Image.new("RGB", (W, H), (0, 0, 0))
    final.paste(canvas, mask=canvas)
    out = os.path.join(OUT_DIR, cfg["out"])
    final.save(out, "PNG")
    print(f"  ✓ {cfg['out']}: {cfg['cap'].replace(chr(10), ' ')}")


if __name__ == "__main__":
    shots = [
        {
            "out": "01_iOS_Hero.png", "raw": "01_hero_welcome.png",
            "cap": "Weather-Aware\nReminders", "sub": "Ready the moment conditions are right",
            "g1": (12, 18, 55), "g2": (28, 55, 115), "ac": (255, 165, 0),
        },
        {
            "out": "02_TimerStyle_ExactMatch.png", "raw": "02_dashboard_ready_now.png",
            "crop": (0, 0, 1320, 2430),
            "cap": "Know The Instant\nIt's Perfect", "sub": "SunHat watches, then tells you",
            "g1": (18, 8, 48), "g2": (55, 18, 95), "ac": (100, 180, 255),
        },
        {
            "out": "03_Differentiator_Predictions.png", "raw": "03_weather_predictions.png",
            "crop": (0, 300, 1320, 2868),
            "cap": "Built To Predict,\nNot Just Report", "sub": "See which reminders are about to fire",
            "g1": (8, 38, 48), "g2": (18, 75, 95), "ac": (0, 200, 180),
        },
        {
            "out": "04_TimerStyle_Range.png", "raw": "04_creation_range.png",
            "cap": "Dial In A\nComfort Zone", "sub": "Trigger only inside your ideal range",
            "g1": (38, 12, 48), "g2": (75, 28, 95), "ac": (200, 130, 255),
        },
        {
            "out": "05_TimerStyle_ExactPlusSky.png", "raw": "05_creation_exact_sky.png",
            "cap": "Filter By Sky,\nNot Just Temp", "sub": "Match the exact conditions you want",
            "g1": (48, 18, 12), "g2": (95, 45, 28), "ac": (255, 140, 50),
        },
        {
            "out": "06_TimerStyle_TimeQuietHours.png", "raw": "06_creation_time_quiet_hours.png",
            "cap": "Mornings Only.\nOr All Day.", "sub": "Reminders that respect quiet hours",
            "g1": (8, 32, 52), "g2": (22, 65, 105), "ac": (50, 180, 255),
        },
        {
            "out": "07_TimerStyle_SevenTypes.png", "raw": "07_edit_seven_trigger_types.png",
            "cap": "7 Ways To Read\nThe Weather", "sub": "From one degree to seasonal shifts",
            "g1": (42, 8, 28), "g2": (85, 22, 60), "ac": (255, 100, 130),
        },
        {
            "out": "08_ActiveReminders_List.png", "raw": "08_reminders_list.png",
            "crop": (0, 0, 1320, 2500),
            "cap": "Every Plan,\nWeather-Ready", "sub": "Track all your conditions at a glance",
            "g1": (8, 28, 42), "g2": (18, 55, 85), "ac": (80, 220, 150),
        },
        {
            "out": "09_TimerStyle_HistoryTrend.png", "raw": "09_history_timeline.png",
            "crop": (0, 860, 1320, 2868),
            "cap": "See What's\nCome And Gone", "sub": "A full history behind every reminder",
            "g1": (22, 12, 42), "g2": (48, 28, 85), "ac": (170, 130, 255),
        },
        {
            "out": "10_Settings_Privacy.png", "raw": "10_settings.png",
            "crop": (0, 300, 1320, 2868),
            "cap": "Total Control,\nOn Your Terms", "sub": "No account required. Data stays on device.",
            "g1": (22, 22, 38), "g2": (48, 48, 75), "ac": (160, 170, 200),
        },
    ]

    print(f"Generating {len(shots)} screenshots at {W}x{H}px...\n")
    for s in shots:
        generate(s)

    print(f"\nDone -> {OUT_DIR}")
    print("\nValidation:")
    for f in sorted(os.listdir(OUT_DIR)):
        if f.endswith(".png"):
            im = Image.open(os.path.join(OUT_DIR, f))
            ok = "OK" if im.size == (W, H) and im.mode == "RGB" else "FAIL"
            print(f"  [{ok}] {f}: {im.size[0]}x{im.size[1]} {im.mode}")
