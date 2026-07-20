#!/usr/bin/env python3
"""Generate 11 short vertical (1080x1920) marketing videos for SunHat:
title flash -> animated pan/zoom on real app UI -> Download Now end card.
"""

import os
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
FPS = 30
BASE = os.path.dirname(__file__)
RAW_DIR = os.path.join(BASE, "..", "Screenshots_v2", "Raw")
ASSETS_DIR = os.path.join(BASE, "Assets")
CLIPS_DIR = os.path.join(BASE, "Clips")
FINAL_DIR = os.path.join(BASE, "Final")
THUMBS_DIR = os.path.join(BASE, "Thumbnails")
ICON_PATH = os.path.join(BASE, "..", "..", "SunHat", "Assets.xcassets", "AppIcon.appiconset", "SunhatLogo.png")

for d in (ASSETS_DIR, CLIPS_DIR, FINAL_DIR, THUMBS_DIR):
    os.makedirs(d, exist_ok=True)

FONT_HEAVY = "/Library/Fonts/SF-Pro-Display-Heavy.otf"
FONT_BOLD = "/Library/Fonts/SF-Pro-Display-Bold.otf"
FONT_SEMI = "/Library/Fonts/SF-Pro-Display-Semibold.otf"
FONT_MEDIUM = "/Library/Fonts/SF-Pro-Display-Medium.otf"

TITLE_DUR = 0.7
END_DUR = 1.3
FADE = 0.15


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def make_gradient(size, c1, c2):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        for x in range(w):
            diagonal = (x / max(w - 1, 1)) * 0.2
            tt = min(1, max(0, t * 0.9 + diagonal))
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * tt) for i in range(3))
    return img


def text_centered(draw, text, y, font, fill, cw, spacing=1.16):
    total = 0
    for line in text.split("\n"):
        bb = draw.textbbox((0, 0), line, font=font)
        lh, tw = bb[3] - bb[1], bb[2] - bb[0]
        draw.text(((cw - tw) // 2, y + total), line, font=font, fill=fill)
        total += int(lh * spacing)
    return total


def make_title_card(text, g1, g2, out_path):
    img = make_gradient((W, H), g1, g2)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_HEAVY, 88)
    lines = text.split("\n")
    heights = []
    for line in lines:
        bb = draw.textbbox((0, 0), line, font=font)
        heights.append(bb[3] - bb[1])
    block_h = int(sum(heights) * 1.16)
    y = (H - block_h) // 2
    text_centered(draw, text, y, font, (255, 255, 255), W)
    img.save(out_path)


def make_end_card(out_path):
    img = make_gradient((W, H), (10, 20, 55), (25, 60, 120)).convert("RGBA")

    icon = Image.open(ICON_PATH).convert("RGBA")
    icon_size = 300
    mask = Image.new("L", (1024, 1024), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (1023, 1023)], radius=220, fill=255)
    icon.putalpha(mask)
    icon = icon.resize((icon_size, icon_size), Image.LANCZOS)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse(
        [W // 2 - 260, H // 2 - 560, W // 2 + 260, H // 2 - 40],
        fill=(255, 190, 90, 60),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(60))
    img = Image.alpha_composite(img, glow)

    icon_y = int(H * 0.30)
    img.paste(icon, ((W - icon_size) // 2, icon_y), icon)

    draw = ImageDraw.Draw(img)
    f_download = ImageFont.truetype(FONT_HEAVY, 96)
    f_sub = ImageFont.truetype(FONT_MEDIUM, 42)
    f_available = ImageFont.truetype(FONT_SEMI, 40)

    y = icon_y + icon_size + 70
    text_centered(draw, "DOWNLOAD NOW", y, f_download, (255, 255, 255), W)
    y += 120
    text_centered(draw, "SunHat: Weather Reminders", y, f_sub, (255, 255, 255), W)
    y += 140
    # Plain-text CTA rather than a hand-drawn imitation of Apple's official
    # App Store badge artwork, which is trademarked and licensed separately.
    text_centered(draw, "Available on the App Store", y, f_available, (255, 255, 255), W)

    img.convert("RGB").save(out_path)


def crop_source(name, box=None):
    im = Image.open(os.path.join(RAW_DIR, name)).convert("RGB")
    if box:
        im = im.crop(box)
    return im


def zoompan_filter(effect, duration_s):
    frames = int(duration_s * FPS)
    if effect == "zoom_in":
        z = "min(zoom+0.0016,1.4)"
        x = "iw/2-(iw/zoom/2)"
        y = "ih/2-(ih/zoom/2)"
    elif effect == "zoom_out":
        z = "if(eq(on,0),1.4,max(zoom-0.0016,1.0))"
        x = "iw/2-(iw/zoom/2)"
        y = "ih/2-(ih/zoom/2)"
    elif effect == "pan_down":
        z = "1.16"
        x = "iw/2-(iw/zoom/2)"
        y = f"(ih-ih/zoom)*on/{frames}"
    elif effect == "pan_across":
        z = "1.16"
        x = f"(iw-iw/zoom)*on/{frames}"
        y = "ih/2-(ih/zoom/2)"
    elif effect == "zoom_pan_down":
        z = "min(zoom+0.0013,1.35)"
        x = "iw/2-(iw/zoom/2)"
        y = f"(ih-ih/zoom)*on/{frames}"
    else:
        raise ValueError(effect)
    return f"zoompan=z='{z}':x='{x}':y='{y}':d={frames}:s={W}x{H}:fps={FPS}"


def render_static_clip(image_path, duration_s, out_path, fade_in=True, fade_out=True):
    filters = [f"scale={W}:{H}"]
    if fade_in:
        filters.append(f"fade=t=in:st=0:d={FADE}")
    if fade_out:
        filters.append(f"fade=t=out:st={duration_s - FADE}:d={FADE}")
    vf_chain = ",".join(filters)
    run([
        "ffmpeg", "-y", "-loop", "1", "-i", image_path, "-t", str(duration_s),
        "-vf", vf_chain, "-r", str(FPS), "-pix_fmt", "yuv420p", out_path,
    ])


MAX_ZOOM = {"zoom_in": 1.4, "zoom_out": 1.4, "pan_down": 1.16, "pan_across": 1.16, "zoom_pan_down": 1.35}
SCALE_TARGET_W = 3600


def assert_crop_has_headroom(image_path, effect):
    """The zoompan filter crops a 1080x1920 window out of the (upscaled) source.
    If the source's height/width ratio is too small for the effect's max zoom,
    zoompan silently samples an out-of-bounds/degenerate region instead of
    erroring, producing a nonsensical extreme close-up. Catch that here instead."""
    with Image.open(image_path) as im:
        w, h = im.size
    scaled_h = SCALE_TARGET_W * (h / w)
    needed_h = H * MAX_ZOOM[effect]
    if scaled_h < needed_h:
        min_ratio = needed_h / SCALE_TARGET_W
        raise ValueError(
            f"{image_path}: crop {w}x{h} (ratio {h / w:.3f}) has insufficient height "
            f"for effect '{effect}' (needs ratio >= {min_ratio:.3f}). Use a taller crop box."
        )


def render_zoompan_clip(image_path, duration_s, effect, out_path):
    assert_crop_has_headroom(image_path, effect)
    zf = zoompan_filter(effect, duration_s)
    filters = [
        "scale=3600:-1", zf,
        f"fade=t=in:st=0:d={FADE}",
        f"fade=t=out:st={duration_s - FADE}:d={FADE}",
    ]
    vf_chain = ",".join(filters)
    run([
        "ffmpeg", "-y", "-loop", "1", "-i", image_path, "-t", str(duration_s),
        "-vf", vf_chain, "-r", str(FPS), "-pix_fmt", "yuv420p", out_path,
    ])


def concat_clips(clip_paths, out_path):
    list_path = out_path + ".txt"
    with open(list_path, "w") as f:
        for p in clip_paths:
            f.write(f"file '{os.path.abspath(p)}'\n")
    run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list_path,
        "-c", "copy", out_path,
    ])
    os.remove(list_path)


def extract_thumbnail(video_path, at_seconds, out_path):
    run(["ffmpeg", "-y", "-ss", str(at_seconds), "-i", video_path, "-frames:v", "1", out_path])


VIDEOS = [
    {
        "id": "01", "name": "Hero", "title": "Weather-Aware\nReminders",
        "g1": (12, 18, 55), "g2": (28, 55, 115),
        "source": "01_hero_welcome.png", "crop": None, "effect": "zoom_in",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 1.5,
    },
    {
        "id": "02", "name": "ExactMatch", "title": "Know The Instant\nIt's Right",
        "g1": (18, 8, 48), "g2": (55, 18, 95),
        "source": "02_dashboard_ready_now.png", "crop": (0, 0, 1320, 2430), "effect": "zoom_in",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 1.5,
    },
    {
        "id": "03", "name": "Predictions", "title": "Predicts What's\nComing",
        "g1": (8, 38, 48), "g2": (18, 75, 95),
        "source": "03_weather_predictions.png", "crop": (0, 880, 1320, 2868), "effect": "pan_down",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 2.0,
    },
    {
        "id": "04", "name": "Range", "title": "Set A Comfort\nRange",
        "g1": (38, 12, 48), "g2": (75, 28, 95),
        "source": "04_creation_range.png", "crop": (0, 100, 1320, 1400), "effect": "zoom_in",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 1.5,
    },
    {
        "id": "05", "name": "ExactSky", "title": "Filter By\nSky Too",
        "g1": (48, 18, 12), "g2": (95, 45, 28),
        "source": "05_creation_exact_sky.png", "crop": (0, 100, 1320, 1300), "effect": "pan_across",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 1.5,
    },
    {
        "id": "06", "name": "TimeQuietHours", "title": "Mornings Only,\nYour Call",
        "g1": (8, 32, 52), "g2": (22, 65, 105),
        "source": "06_creation_time_quiet_hours.png", "crop": (0, 1000, 1320, 2200), "effect": "zoom_out",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 0.3,
    },
    {
        "id": "07", "name": "SevenTypes", "title": "7 Ways To\nTrigger",
        "g1": (42, 8, 28), "g2": (85, 22, 60),
        "source": "07_edit_seven_trigger_types.png", "crop": (0, 800, 1320, 1800), "effect": "pan_across",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 1.5,
    },
    {
        "id": "08", "name": "RemindersList", "title": "Every Task,\nOne List",
        "g1": (8, 28, 42), "g2": (18, 55, 85),
        "source": "08_reminders_list.png", "crop": (0, 580, 1320, 2868), "effect": "pan_down",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 2.0,
    },
    {
        "id": "09", "name": "HistoryTrend", "title": "See What\nAlready Happened",
        "g1": (22, 12, 42), "g2": (48, 28, 85),
        "source": "09_history_timeline.png", "crop": (0, 750, 1320, 2868), "effect": "zoom_pan_down",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 1.5,
    },
    {
        "id": "10", "name": "SettingsPrivacy", "title": "Total Privacy\nControl",
        "g1": (22, 22, 38), "g2": (48, 48, 75),
        "source": "10_settings.png", "crop": (0, 240, 1320, 2500), "effect": "pan_down",
        "feature_dur": 4.0, "thumb_at": TITLE_DUR + 2.0,
    },
]

FINALE = {
    "id": "11", "name": "Finale", "title": "One App,\nEvery Condition",
    "g1": (16, 12, 40), "g2": (60, 30, 90),
    "clips": [
        ("01_hero_welcome.png", None),
        ("02_dashboard_ready_now.png", (0, 0, 1320, 2430)),
        ("03_weather_predictions.png", (0, 880, 1320, 2868)),
        ("07_edit_seven_trigger_types.png", (0, 800, 1320, 1800)),
        ("08_reminders_list.png", (0, 580, 1320, 2868)),
        ("09_history_timeline.png", (0, 750, 1320, 2868)),
    ],
    "clip_dur": 0.55,
}


def build_video(cfg):
    vid = cfg["id"]
    print(f"[{vid}] {cfg['name']}")

    title_png = os.path.join(ASSETS_DIR, f"title_{vid}.png")
    make_title_card(cfg["title"], cfg["g1"], cfg["g2"], title_png)
    title_clip = os.path.join(CLIPS_DIR, f"{vid}_title.mp4")
    render_static_clip(title_png, TITLE_DUR, title_clip)

    src_crop_png = os.path.join(ASSETS_DIR, f"src_{vid}.png")
    crop_source(cfg["source"], cfg["crop"]).save(src_crop_png)
    feature_clip = os.path.join(CLIPS_DIR, f"{vid}_feature.mp4")
    render_zoompan_clip(src_crop_png, cfg["feature_dur"], cfg["effect"], feature_clip)

    end_png = os.path.join(ASSETS_DIR, "end_card.png")
    if not os.path.exists(end_png):
        make_end_card(end_png)
    end_clip = os.path.join(CLIPS_DIR, f"{vid}_end.mp4")
    render_static_clip(end_png, END_DUR, end_clip)

    final_path = os.path.join(FINAL_DIR, f"{vid}_{cfg['name']}.mp4")
    concat_clips([title_clip, feature_clip, end_clip], final_path)

    thumb_path = os.path.join(THUMBS_DIR, f"{vid}_{cfg['name']}_thumb.png")
    extract_thumbnail(final_path, cfg["thumb_at"], thumb_path)
    print(f"  -> {final_path}")


def build_finale(cfg):
    vid = cfg["id"]
    print(f"[{vid}] {cfg['name']}")

    title_png = os.path.join(ASSETS_DIR, f"title_{vid}.png")
    make_title_card(cfg["title"], cfg["g1"], cfg["g2"], title_png)
    title_clip = os.path.join(CLIPS_DIR, f"{vid}_title.mp4")
    render_static_clip(title_png, TITLE_DUR, title_clip)

    seg_clips = [title_clip]
    for i, (source, box) in enumerate(cfg["clips"]):
        src_crop_png = os.path.join(ASSETS_DIR, f"src_{vid}_{i}.png")
        crop_source(source, box).save(src_crop_png)
        seg_clip = os.path.join(CLIPS_DIR, f"{vid}_seg{i}.mp4")
        render_zoompan_clip(src_crop_png, cfg["clip_dur"], "zoom_in", seg_clip)
        seg_clips.append(seg_clip)

    end_png = os.path.join(ASSETS_DIR, "end_card.png")
    if not os.path.exists(end_png):
        make_end_card(end_png)
    end_clip = os.path.join(CLIPS_DIR, f"{vid}_end.mp4")
    render_static_clip(end_png, END_DUR, end_clip)
    seg_clips.append(end_clip)

    final_path = os.path.join(FINAL_DIR, f"{vid}_{cfg['name']}.mp4")
    concat_clips(seg_clips, final_path)

    thumb_path = os.path.join(THUMBS_DIR, f"{vid}_{cfg['name']}_thumb.png")
    extract_thumbnail(final_path, TITLE_DUR + 1.0, thumb_path)
    print(f"  -> {final_path}")


if __name__ == "__main__":
    import sys
    only = sys.argv[1] if len(sys.argv) > 1 else None

    for cfg in VIDEOS:
        if only and cfg["id"] != only:
            continue
        build_video(cfg)

    if not only or only == FINALE["id"]:
        build_finale(FINALE)

    print("\nDone.")
