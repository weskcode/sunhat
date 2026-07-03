#!/usr/bin/env python3
"""Generate 10 framed App Store marketing screenshots at 1284×2778px."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
import math

W, H = 1284, 2778
RAW_DIR = os.path.join(os.path.dirname(__file__), "Raw")
PATCHED_DIR = os.path.join(os.path.dirname(__file__), "Patched")
OUT_DIR = os.path.join(os.path.dirname(__file__), "Framed")
os.makedirs(PATCHED_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)

FONT_HEAVY = "/Library/Fonts/SF-Pro-Display-Heavy.otf"
FONT_BOLD = "/Library/Fonts/SF-Pro-Display-Bold.otf"
FONT_SEMI = "/Library/Fonts/SF-Pro-Display-Semibold.otf"
FONT_MEDIUM = "/Library/Fonts/SF-Pro-Display-Medium.otf"
FONT_REG = "/Library/Fonts/SF-Pro-Display-Regular.otf"

RAW_W, RAW_H = 1206, 2622


# ─── Patch functions ─────────────────────────────────────────────────

def patch_dashboard():
    """Replace weather-unavailable card with mock 72° data."""
    img = Image.open(os.path.join(RAW_DIR, "dashboard_with_reminder.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)

    # Weather card: y≈380-1000. Paint it over and redraw with mock data.
    draw.rectangle([(0, 380), (RAW_W, 1010)], fill=(0, 0, 0, 255))
    card_bg = (28, 28, 30, 255)
    draw.rounded_rectangle([(55, 400), (1150, 990)], radius=22, fill=card_bg)

    fl = ImageFont.truetype(FONT_SEMI, 40)
    fb = ImageFont.truetype(FONT_BOLD, 100)
    fm = ImageFont.truetype(FONT_MEDIUM, 40)
    fs = ImageFont.truetype(FONT_REG, 30)

    draw.text((90, 420), "↗  San Francisco", font=fl, fill=(255, 255, 255))
    draw.ellipse([(1085, 420), (1125, 460)], fill=(52, 199, 89))
    draw.text((90, 490), "72°", font=fb, fill=(255, 255, 255))
    draw.text((320, 530), "Partly Cloudy", font=fm, fill=(200, 200, 200))
    draw.text((90, 640), "Feels like 68°  ·  Humidity 55%  ·  Wind 8 mph",
              font=fs, fill=(145, 145, 150))

    hours = [("Now", "72°"), ("1PM", "74°"), ("2PM", "73°"), ("3PM", "71°"), ("4PM", "69°")]
    x = 90
    for t, tmp in hours:
        draw.text((x, 730), t, font=fs, fill=(145, 145, 150))
        draw.text((x, 790), tmp, font=fs, fill=(220, 220, 225))
        x += 200
    draw.text((90, 910), "H: 76°  L: 62°", font=fs, fill=(145, 145, 150))
    draw.text((600, 910), "Updated just now", font=fs, fill=(100, 100, 105))

    out = os.path.join(PATCHED_DIR, "dashboard_patched.png")
    img.save(out)
    return out


def patch_reminders():
    """Add 3 more sample reminders below the existing Garden card."""
    img = Image.open(os.path.join(RAW_DIR, "reminders_tab.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)

    fn = ImageFont.truetype(FONT_SEMI, 40)
    fd = ImageFont.truetype(FONT_REG, 30)
    fm = ImageFont.truetype(FONT_REG, 26)
    card_bg = (38, 38, 40, 255)

    items = [
        ("Morning Run", "Perfect jogging weather", "Temp 55°‑70°", "Jun 14", True),
        ("Beach Day", "Sunny and warm enough", "Temp above 80°", "Jun 13", True),
        ("Plant Watering", "Skip if rain expected", "Humidity below 40%", "Jun 11", False),
    ]
    y = 680
    for name, desc, trigger, date, active in items:
        draw.rounded_rectangle([(45, y), (1160, y + 180)], radius=18, fill=card_bg)
        draw.ellipse([(75, y + 20), (140, y + 85)], fill=(55, 55, 58))
        draw.text((165, y + 22), name, font=fn, fill=(230, 230, 230))
        draw.text((165, y + 72), desc, font=fd, fill=(150, 150, 155))
        draw.text((85, y + 130), trigger, font=fm, fill=(150, 150, 155))
        draw.text((1050, y + 130), date, font=fm, fill=(120, 120, 125))
        dot = (52, 199, 89) if active else (100, 100, 105)
        draw.ellipse([(1105, y + 25), (1120, y + 40)], fill=dot)
        draw.text((1020, y + 20), "Active" if active else "Paused", font=fm, fill=(130, 130, 135))
        y += 200

    out = os.path.join(PATCHED_DIR, "reminders_patched.png")
    img.save(out)
    return out


def patch_create():
    """Hide both 'Weather unavailable' occurrences in create form."""
    img = Image.open(os.path.join(RAW_DIR, "create_task.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT_MEDIUM, 34)

    # Patch 1: y=1310-1470, between Notes field and Current Location card
    card_fill_1 = (34, 41, 48, 255)
    draw.rectangle([(55, 1310), (1150, 1470)], fill=card_fill_1)
    draw.text((80, 1360), "72° Partly Cloudy  ·  Feels like 68°", font=f, fill=(180, 180, 185))

    # Patch 2: y=1820-1880, "Weather unavailable" below "Current Location" header
    card_fill_2 = (25, 32, 39, 255)
    draw.rectangle([(60, 1820), (1145, 1880)], fill=card_fill_2)
    draw.text((80, 1835), "72° Partly Cloudy  ·  Humidity 55%", font=f, fill=(150, 150, 155))

    out = os.path.join(PATCHED_DIR, "create_patched.png")
    img.save(out)
    return out


# ─── Frame helpers ───────────────────────────────────────────────────

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
    grid = (255, 255, 255, 24)
    for i in range(-2, 10):
        x = int(i * w / 7)
        draw.line([(x, int(h * 0.08)), (x + int(w * 0.24), h)], fill=grid, width=2)
    for i in range(0, 11):
        y = int(h * (0.10 + i * 0.085))
        draw.line([(0, y), (w, y - int(h * 0.04))], fill=(255, 255, 255, 18), width=2)

    # Pressure contour lines give every frame a subject-specific signature.
    for i in range(9):
        y = int(h * (0.20 + i * 0.065))
        amp = 28 + i * 5
        points = []
        for x in range(-80, w + 100, 42):
            yy = y + int(math.sin((x / 130) + i * 0.75) * amp)
            points.append((x, yy))
        draw.line(points, fill=(255, 255, 255, max(18, 54 - i * 4)), width=2)

    # Fine grain keeps large color fields from feeling machine-flat.
    for y in range(0, h, 6):
        alpha = 6 if (y // 6) % 2 == 0 else 3
        draw.line([(0, y), (w, y)], fill=(255, 255, 255, alpha), width=1)
    return img


def round_corners(img, radius):
    rgba = img.convert("RGBA")
    mask = Image.new("L", rgba.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [(0, 0), (rgba.width - 1, rgba.height - 1)], radius=radius, fill=255)
    rgba.putalpha(mask)
    return rgba


def add_shadow(img, blur=40, alpha=110):
    w, h = img.size
    pad = blur * 2
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, alpha))
    if img.mode == "RGBA":
        shadow.putalpha(img.split()[3])
    canvas.paste(shadow, (pad, pad + 14))
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

    # Accent weather-front flare
    a = cfg["ac"]
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(900, 0, -8):
        al = max(0, int(24 * (1 - r / 900)))
        gd.rounded_rectangle(
            [W // 2 - r, 305 - r // 5, W // 2 + r, 470 + r // 4],
            radius=220,
            fill=(*a, al),
        )
    canvas = Image.alpha_composite(canvas, glow)

    draw = ImageDraw.Draw(canvas)
    fc = ImageFont.truetype(FONT_HEAVY, 100)
    fs = ImageFont.truetype(FONT_MEDIUM, 40)

    ch = text_centered(draw, cfg["cap"], 120, fc, (255, 255, 255, 255), W)
    sy = 120 + ch + 16
    text_centered(draw, cfg["sub"], sy, fs, (255, 255, 255, 170), W)

    # Load screenshot
    raw_path = cfg.get("pp") or os.path.join(RAW_DIR, cfg["raw"])
    raw = Image.open(raw_path).convert("RGBA")
    if "crop" in cfg:
        raw = raw.crop(cfg["crop"])

    # Scale to fit available area
    top = sy + 100
    area_h = H - top - 130
    area_w = W - 90
    rw, rh = raw.size

    if cfg.get("fill_h"):
        # Fill height, center-crop width (zoomed-in look)
        sc = area_h / rh
        raw = raw.resize((int(rw * sc), int(rh * sc)), Image.LANCZOS)
        if raw.width > area_w:
            excess = raw.width - area_w
            raw = raw.crop((excess // 2, 0, raw.width - excess // 2, raw.height))
    else:
        sc = min(area_w / rw, area_h / rh)
        raw = raw.resize((int(rw * sc), int(rh * sc)), Image.LANCZOS)

    # Round corners + shadow
    raw = round_corners(raw, 44)
    shadowed, pad = add_shadow(raw)

    px = (W - shadowed.width) // 2
    canvas.paste(shadowed, (px, top), shadowed)

    # Flatten to RGB (no alpha for App Store)
    final = Image.new("RGB", (W, H), (0, 0, 0))
    final.paste(canvas, mask=canvas)
    out = os.path.join(OUT_DIR, f"{cfg['n']:02d}_screenshot.png")
    final.save(out, "PNG")
    print(f"  ✓ [{cfg['n']:02d}] {cfg['cap'].replace(chr(10), ' ')}")


if __name__ == "__main__":
    print("Patching raw screenshots...")
    dp = patch_dashboard()
    rp = patch_reminders()
    cp = patch_create()
    print("  Done.\n")

    shots = [
        # 1. Hero dashboard with weather + reminders
        {"n": 1, "cap": "Weather-Smart\nReminders",
         "sub": "Get notified when conditions are perfect",
         "pp": dp, "raw": "dashboard_with_reminder.png",
         "g1": (12, 18, 55), "g2": (28, 55, 115), "ac": (255, 165, 0)},

        # 2. Creation form (top half: icon + fields + location, no "Weather unavailable")
        {"n": 2, "cap": "Create Tasks\nin Seconds",
         "sub": "Simple, streamlined weather task creation",
         "pp": cp, "raw": "create_task.png",
         "g1": (18, 8, 48), "g2": (55, 18, 95), "ac": (100, 180, 255)},

        # 3. Weather trigger section (fields through slider, tall crop)
        {"n": 3, "cap": "Smart Weather\nTriggers",
         "sub": "Set temperature, sky & time conditions",
         "pp": cp, "raw": "create_task.png", "crop": (0, 700, RAW_W, 2500),
         "g1": (8, 38, 48), "g2": (18, 75, 95), "ac": (0, 200, 180)},

        # 4. Reminders list with 4 items
        {"n": 4, "cap": "Track Active\nReminders",
         "sub": "Monitor all your weather tasks at a glance",
         "pp": rp, "raw": "reminders_tab.png",
         "g1": (38, 12, 48), "g2": (75, 28, 95), "ac": (200, 130, 255)},

        # 5. Settings (full view: notifications + location)
        {"n": 5, "cap": "Powerful\nNotifications",
         "sub": "Quiet hours, daily limits & smart alerts",
         "raw": "settings_tab.png",
         "g1": (48, 18, 12), "g2": (95, 45, 28), "ac": (255, 140, 50)},

        # 6. Settings cropped to Location section
        {"n": 6, "cap": "Location-Aware\nAlerts",
         "sub": "Weather data for your exact location",
         "raw": "settings_tab.png", "crop": (0, 750, RAW_W, 2000),
         "g1": (8, 32, 52), "g2": (22, 65, 105), "ac": (50, 180, 255)},

        # 7. Dashboard weather card showing live temperature data
        {"n": 7, "cap": "Temperature\nRange Alerts",
         "sub": "Precise triggers for any weather condition",
         "pp": dp, "raw": "dashboard_with_reminder.png",
         "crop": (0, 300, RAW_W, 1800),
         "g1": (42, 8, 28), "g2": (85, 22, 60), "ac": (255, 100, 130)},

        # 8. Dashboard cropped to Ready Now + Watching
        {"n": 8, "cap": "Always\nMonitoring",
         "sub": "Background weather checks keep you ready",
         "pp": dp, "raw": "dashboard_with_reminder.png",
         "crop": (0, 950, RAW_W, 2200),
         "g1": (8, 28, 42), "g2": (18, 55, 85), "ac": (80, 220, 150)},

        # 9. Settings scrolled (shows General + privacy text)
        {"n": 9, "cap": "Privacy-First\nDesign",
         "sub": "Your reminders stay on your device",
         "raw": "settings_tab.png",
         "g1": (22, 22, 38), "g2": (48, 48, 75), "ac": (160, 170, 200)},

        # 10. Welcome/brand shot (dashboard patched, different gradient)
        {"n": 10, "cap": "Your Weather\nCompanion",
         "sub": "Beautiful Liquid Glass interface on iOS",
         "pp": dp, "raw": "dashboard_with_reminder.png",
         "crop": (0, 0, RAW_W, 1800),
         "g1": (4, 12, 32), "g2": (12, 38, 75), "ac": (100, 160, 255)},
    ]

    print(f"Generating {len(shots)} screenshots at {W}×{H}px...\n")
    for s in shots:
        generate(s)

    print(f"\nDone! → {OUT_DIR}")
    print("\nValidation:")
    for f in sorted(os.listdir(OUT_DIR)):
        if f.endswith(".png"):
            sz = Image.open(os.path.join(OUT_DIR, f)).size
            ok = "✅" if sz == (W, H) else "❌"
            print(f"  {ok} {f}: {sz[0]}×{sz[1]}")
