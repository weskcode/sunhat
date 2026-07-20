#!/usr/bin/env python3
"""v2: Generate 11 vertical (1080x1920) marketing videos for SunHat with
eased motion, crossfade transitions, a settling end-card animation, and a
synthesized (license-free) whoosh + chime audio bed.
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

TITLE_DUR = 0.8
END_DUR = 1.5
XFADE = 0.35
SCALE_TARGET_W = 3600


def run(cmd):
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"ffmpeg failed: {e.stderr.decode()[-2000:]}") from e


# ─── Still-image asset generation ────────────────────────────────────

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
    heights = [draw.textbbox((0, 0), line, font=font)[3] for line in text.split("\n")]
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
    gd.ellipse([W // 2 - 260, H // 2 - 560, W // 2 + 260, H // 2 - 40], fill=(255, 190, 90, 60))
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


RAW_DARK_DIR = os.path.join(BASE, "..", "Screenshots_v2", "RawDark")


def crop_source(name, box=None, raw_dir=None):
    im = Image.open(os.path.join(raw_dir or RAW_DIR, name)).convert("RGB")
    if box:
        im = im.crop(box)
    return im


# ─── Eased motion ─────────────────────────────────────────────────────
# Smoothstep (3t^2 - 2t^3) instead of a linear ramp, so every pan/zoom starts
# and ends gently rather than moving at a constant mechanical speed.

def _smoothstep(t_expr):
    return f"({t_expr}*{t_expr}*(3-2*{t_expr}))"


# Reference duration the zoom/pan *ranges* below were tuned for. Shorter
# clips (Reel-length beats) scale their zoom range down proportionally so the
# rate of motion stays constant instead of racing to the same end-zoom in a
# fraction of the time - which was cropping wide text (e.g. the hero
# headline) by the end of a short beat. See `_intensity_for`.
REFERENCE_DUR = 4.0

# (base zoom delta from 1.0, base constant-zoom-above-1.0) per effect, used
# to compute both the animation and the crop-headroom check at any intensity.
EFFECT_ZOOM_DELTA = {
    "zoom_in": 0.40, "zoom_out": 0.40, "settle": 0.06,
    "pan_down": 0.16, "pan_across": 0.16, "zoom_pan_down": 0.35,
}


def _intensity_for(duration_s):
    return max(0.35, min(1.0, duration_s / REFERENCE_DUR))


def max_zoom_for(effect, duration_s):
    return 1.0 + EFFECT_ZOOM_DELTA[effect] * _intensity_for(duration_s)


def zoompan_filter(effect, duration_s):
    frames = int(duration_s * FPS)
    t = f"min(on/{frames},1)"
    s = _smoothstep(t)
    d = EFFECT_ZOOM_DELTA[effect] * _intensity_for(duration_s)
    if effect == "zoom_in":
        z = f"(1.0+{d:.4f}*{s})"
        x, y = "iw/2-(iw/zoom/2)", "ih/2-(ih/zoom/2)"
    elif effect == "zoom_out":
        z = f"({1.0 + d:.4f}-{d:.4f}*{s})"
        x, y = "iw/2-(iw/zoom/2)", "ih/2-(ih/zoom/2)"
    elif effect == "settle":
        z = f"({1.0 + d:.4f}-{d:.4f}*{s})"
        x, y = "iw/2-(iw/zoom/2)", "ih/2-(ih/zoom/2)"
    elif effect == "pan_down":
        z = f"{1.0 + d:.4f}"
        x = "iw/2-(iw/zoom/2)"
        y = f"(ih-ih/zoom)*{s}"
    elif effect == "pan_across":
        z = f"{1.0 + d:.4f}"
        x = f"(iw-iw/zoom)*{s}"
        y = "ih/2-(ih/zoom/2)"
    elif effect == "zoom_pan_down":
        z = f"(1.0+{d:.4f}*{s})"
        x = "iw/2-(iw/zoom/2)"
        y = f"(ih-ih/zoom)*{s}"
    else:
        raise ValueError(effect)
    return f"zoompan=z='{z}':x='{x}':y='{y}':d={frames}:s={W}x{H}:fps={FPS}"


def assert_crop_has_headroom(image_path, effect, duration_s):
    """zoompan crops a 1080x1920 window out of the (upscaled) source. If the
    source's height/width ratio is too small for the effect's max zoom,
    zoompan silently samples a degenerate region instead of erroring, producing
    a nonsensical extreme close-up. Catch that here instead."""
    with Image.open(image_path) as im:
        w, h = im.size
    scaled_h = SCALE_TARGET_W * (h / w)
    needed_h = H * max_zoom_for(effect, duration_s)
    if scaled_h < needed_h:
        min_ratio = needed_h / SCALE_TARGET_W
        raise ValueError(
            f"{image_path}: crop {w}x{h} (ratio {h / w:.3f}) has insufficient height "
            f"for effect '{effect}' at {duration_s}s (needs ratio >= {min_ratio:.3f}). "
            f"Use a taller crop box."
        )


def render_zoompan_clip(image_path, duration_s, effect, out_path, crf=18):
    assert_crop_has_headroom(image_path, effect, duration_s)
    zf = zoompan_filter(effect, duration_s)
    vf_chain = f"scale={SCALE_TARGET_W}:-1,{zf}"
    run([
        "ffmpeg", "-y", "-loop", "1", "-i", image_path, "-t", str(duration_s),
        "-vf", vf_chain, "-r", str(FPS), "-pix_fmt", "yuv420p",
        "-c:v", "libx264", "-crf", str(crf), "-preset", "slow", out_path,
    ])


# ─── Crossfade concatenation ──────────────────────────────────────────

def xfade_concat(clip_paths, durations, out_path, xfade=XFADE, crf=18, transitions=None):
    """Join N video clips with a short transition at each boundary instead of
    independent fade-to-black cuts, so the piece reads as one continuous
    motion rather than stitched-together stills. `transitions` is an optional
    list of ffmpeg xfade transition names, one per boundary (len = N-1);
    defaults to a plain cross-dissolve ("fade") everywhere."""
    inputs = []
    for p in clip_paths:
        inputs += ["-i", p]

    if transitions is None:
        transitions = ["fade"] * (len(clip_paths) - 1)

    filter_parts = []
    running = f"[0:v]"
    running_dur = durations[0]
    for i in range(1, len(clip_paths)):
        offset = running_dur - xfade
        out_label = f"v{i}" if i < len(clip_paths) - 1 else "vout"
        transition = transitions[i - 1]
        filter_parts.append(
            f"{running}[{i}:v]xfade=transition={transition}:duration={xfade}:offset={offset:.3f}[{out_label}]"
        )
        running = f"[{out_label}]"
        running_dur = running_dur + durations[i] - xfade

    filter_complex = ";".join(filter_parts)
    run([
        "ffmpeg", "-y", *inputs,
        "-filter_complex", filter_complex, "-map", "[vout]",
        "-r", str(FPS), "-pix_fmt", "yuv420p",
        "-c:v", "libx264", "-crf", str(crf), "-preset", "slow", out_path,
    ])
    return running_dur


# ─── Synthesized audio bed (no licensed/sampled material) ─────────────

def build_audio(total_duration, whoosh_start, chime_start, out_path):
    """A synthesized riser (sine sweep) leading into the end card, plus a
    two-tone chime when it lands. Fully procedural - no sampled or licensed
    audio - so there's no rights issue, but it's a placeholder for real sound
    design / licensed music, not a substitute for it."""
    whoosh_dur = 0.9
    chime_dur = 0.9
    ws_ms = int(whoosh_start * 1000)
    cs_ms = int(chime_start * 1000)
    cs2_ms = int((chime_start + 0.05) * 1000)

    filter_complex = (
        f"aevalsrc=exprs='0.32*sin(2*PI*(160+760*min(t/{whoosh_dur}\\,1))*t)':"
        f"s=44100:d={whoosh_dur},"
        f"afade=t=in:st=0:d=0.12,afade=t=out:st={whoosh_dur - 0.3:.2f}:d=0.3,"
        f"adelay={ws_ms}|{ws_ms}[whoosh];"

        f"sine=frequency=880:duration={chime_dur}:sample_rate=44100,"
        f"afade=t=out:st=0.06:d={chime_dur - 0.06:.2f}:curve=exp,volume=0.30,"
        f"adelay={cs_ms}|{cs_ms}[chime1];"

        f"sine=frequency=1318.51:duration={chime_dur}:sample_rate=44100,"
        f"afade=t=out:st=0.08:d={chime_dur - 0.08:.2f}:curve=exp,volume=0.22,"
        f"adelay={cs2_ms}|{cs2_ms}[chime2];"

        f"[whoosh][chime1][chime2]amix=inputs=3:normalize=0:duration=longest,"
        f"alimiter=limit=0.9,"
        # amix's "duration=longest" only matches the longest *input* stream,
        # which ends well before the video does - pad with silence out to the
        # full video length or the mux's `-shortest` will clip the end card.
        f"apad=whole_dur={total_duration}[aout]"
    )
    run([
        "ffmpeg", "-y", "-filter_complex", filter_complex, "-map", "[aout]",
        "-t", str(total_duration), "-ar", "44100", "-ac", "2", "-y", out_path,
    ])


def mux_audio(video_path, audio_path, out_path):
    run([
        "ffmpeg", "-y", "-i", video_path, "-i", audio_path,
        "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
        "-map", "0:v:0", "-map", "1:a:0", "-shortest",
        "-movflags", "+faststart", out_path,
    ])


def extract_thumbnail(video_path, at_seconds, out_path):
    run(["ffmpeg", "-y", "-ss", str(at_seconds), "-i", video_path, "-frames:v", "1", out_path])


# ─── Shot list ─────────────────────────────────────────────────────────

VIDEOS = [
    {"id": "01", "name": "Hero", "title": "Weather-Aware\nReminders",
     "g1": (12, 18, 55), "g2": (28, 55, 115),
     "source": "01_hero_welcome.png", "crop": None, "effect": "zoom_in"},
    {"id": "02", "name": "ExactMatch", "title": "Know The Instant\nIt's Right",
     "g1": (18, 8, 48), "g2": (55, 18, 95),
     "source": "02_dashboard_ready_now.png", "crop": (0, 0, 1320, 2430), "effect": "zoom_in"},
    {"id": "03", "name": "Predictions", "title": "Predicts What's\nComing",
     "g1": (8, 38, 48), "g2": (18, 75, 95),
     "source": "03_weather_predictions.png", "crop": (0, 880, 1320, 2868), "effect": "pan_down"},
    {"id": "04", "name": "Range", "title": "Set A Comfort\nRange",
     "g1": (38, 12, 48), "g2": (75, 28, 95),
     "source": "04_creation_range.png", "crop": (0, 100, 1320, 1400), "effect": "zoom_in"},
    {"id": "05", "name": "ExactSky", "title": "Filter By\nSky Too",
     "g1": (48, 18, 12), "g2": (95, 45, 28),
     "source": "05_creation_exact_sky.png", "crop": (0, 100, 1320, 1300), "effect": "pan_across"},
    {"id": "06", "name": "TimeQuietHours", "title": "Mornings Only,\nYour Call",
     "g1": (8, 32, 52), "g2": (22, 65, 105),
     "source": "06_creation_time_quiet_hours.png", "crop": (0, 1000, 1320, 2200), "effect": "zoom_out"},
    {"id": "07", "name": "SevenTypes", "title": "7 Ways To\nTrigger",
     "g1": (42, 8, 28), "g2": (85, 22, 60),
     "source": "07_edit_seven_trigger_types.png", "crop": (0, 800, 1320, 1800), "effect": "pan_across"},
    {"id": "08", "name": "RemindersList", "title": "Every Task,\nOne List",
     "g1": (8, 28, 42), "g2": (18, 55, 85),
     "source": "08_reminders_list.png", "crop": (0, 580, 1320, 2868), "effect": "pan_down"},
    {"id": "09", "name": "HistoryTrend", "title": "See What\nAlready Happened",
     "g1": (22, 12, 42), "g2": (48, 28, 85),
     "source": "09_history_timeline.png", "crop": (0, 750, 1320, 2868), "effect": "zoom_pan_down"},
    {"id": "10", "name": "SettingsPrivacy", "title": "Total Privacy\nControl",
     "g1": (22, 22, 38), "g2": (48, 48, 75),
     "source": "10_settings.png", "crop": (0, 240, 1320, 2500), "effect": "pan_down"},
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
    "clip_dur": 0.65,
}

FEATURE_DUR = 4.0


def ensure_end_card():
    end_png = os.path.join(ASSETS_DIR, "end_card.png")
    if not os.path.exists(end_png):
        make_end_card(end_png)
    return end_png


def build_video(cfg):
    vid = cfg["id"]
    print(f"[{vid}] {cfg['name']}")

    title_png = os.path.join(ASSETS_DIR, f"title_{vid}.png")
    make_title_card(cfg["title"], cfg["g1"], cfg["g2"], title_png)
    title_clip = os.path.join(CLIPS_DIR, f"{vid}_title.mp4")
    render_zoompan_clip(title_png, TITLE_DUR, "settle", title_clip)

    src_crop_png = os.path.join(ASSETS_DIR, f"src_{vid}.png")
    crop_source(cfg["source"], cfg["crop"]).save(src_crop_png)
    feature_clip = os.path.join(CLIPS_DIR, f"{vid}_feature.mp4")
    render_zoompan_clip(src_crop_png, FEATURE_DUR, cfg["effect"], feature_clip)

    end_png = ensure_end_card()
    end_clip = os.path.join(CLIPS_DIR, f"{vid}_end.mp4")
    render_zoompan_clip(end_png, END_DUR, "settle", end_clip)

    durations = [TITLE_DUR, FEATURE_DUR, END_DUR]
    silent_path = os.path.join(CLIPS_DIR, f"{vid}_silent.mp4")
    total_dur = xfade_concat([title_clip, feature_clip, end_clip], durations, silent_path)

    whoosh_start = max(0.0, TITLE_DUR + FEATURE_DUR - XFADE - whoosh_lead())
    chime_start = TITLE_DUR + FEATURE_DUR - 2 * XFADE
    audio_path = os.path.join(CLIPS_DIR, f"{vid}_audio.wav")
    build_audio(total_dur, whoosh_start, chime_start, audio_path)

    final_path = os.path.join(FINAL_DIR, f"{vid}_{cfg['name']}.mp4")
    mux_audio(silent_path, audio_path, final_path)

    thumb_path = os.path.join(THUMBS_DIR, f"{vid}_{cfg['name']}_thumb.png")
    extract_thumbnail(final_path, TITLE_DUR + 1.5, thumb_path)
    print(f"  -> {final_path} ({total_dur:.2f}s)")


def whoosh_lead():
    return 0.7


def build_finale(cfg):
    vid = cfg["id"]
    print(f"[{vid}] {cfg['name']}")

    title_png = os.path.join(ASSETS_DIR, f"title_{vid}.png")
    make_title_card(cfg["title"], cfg["g1"], cfg["g2"], title_png)
    title_clip = os.path.join(CLIPS_DIR, f"{vid}_title.mp4")
    render_zoompan_clip(title_png, TITLE_DUR, "settle", title_clip)

    clip_paths = [title_clip]
    durations = [TITLE_DUR]
    for i, (source, box) in enumerate(cfg["clips"]):
        src_crop_png = os.path.join(ASSETS_DIR, f"src_{vid}_{i}.png")
        crop_source(source, box).save(src_crop_png)
        seg_clip = os.path.join(CLIPS_DIR, f"{vid}_seg{i}.mp4")
        render_zoompan_clip(src_crop_png, cfg["clip_dur"], "zoom_in", seg_clip)
        clip_paths.append(seg_clip)
        durations.append(cfg["clip_dur"])

    end_png = ensure_end_card()
    end_clip = os.path.join(CLIPS_DIR, f"{vid}_end.mp4")
    render_zoompan_clip(end_png, END_DUR, "settle", end_clip)
    clip_paths.append(end_clip)
    durations.append(END_DUR)

    silent_path = os.path.join(CLIPS_DIR, f"{vid}_silent.mp4")
    total_dur = xfade_concat(clip_paths, durations, silent_path, xfade=0.2)

    feature_total = sum(durations[:-1]) - (len(durations) - 2) * 0.2
    whoosh_start = max(0.0, feature_total - 0.2 - whoosh_lead())
    chime_start = feature_total - 2 * 0.2
    audio_path = os.path.join(CLIPS_DIR, f"{vid}_audio.wav")
    build_audio(total_dur, whoosh_start, chime_start, audio_path)

    final_path = os.path.join(FINAL_DIR, f"{vid}_{cfg['name']}.mp4")
    mux_audio(silent_path, audio_path, final_path)

    thumb_path = os.path.join(THUMBS_DIR, f"{vid}_{cfg['name']}_thumb.png")
    extract_thumbnail(final_path, TITLE_DUR + 1.0, thumb_path)
    print(f"  -> {final_path} ({total_dur:.2f}s)")


# ─── Two-shot narrative videos (distinct transitions, not just reskins) ─

NARRATIVES = [
    {
        "id": "12", "name": "SetItTrackIt", "title": "Set It.\nTrack It.",
        "g1": (30, 14, 46), "g2": (68, 24, 90),
        "shots": [
            {"source": "04_creation_range.png", "crop": (0, 100, 1320, 1400), "effect": "zoom_in"},
            {"source": "08_reminders_list.png", "crop": (0, 580, 1320, 1760), "effect": "zoom_in"},
        ],
        "transition": "wipeleft",
        "shot_dur": 2.3,
    },
    {
        "id": "13", "name": "LightDark", "title": "Looks Great,\nDay Or Night",
        "g1": (20, 20, 34), "g2": (46, 46, 70),
        "shots": [
            {"source": "02_dashboard_ready_now.png", "crop": (0, 0, 1320, 2430), "effect": "zoom_in", "raw_dir": RAW_DIR},
            {"source": "02_dashboard_ready_now.png", "crop": (0, 0, 1320, 2430), "effect": "zoom_in", "raw_dir": RAW_DARK_DIR},
        ],
        "transition": "circleopen",
        "shot_dur": 2.3,
    },
    {
        "id": "14", "name": "OverviewToDetail", "title": "See The\nFull Picture",
        "g1": (10, 30, 40), "g2": (20, 60, 78),
        "shots": [
            {"source": "03_weather_predictions.png", "crop": (0, 880, 1320, 2200), "effect": "pan_down"},
            {"source": "09_history_timeline.png", "crop": (0, 750, 1320, 2200), "effect": "pan_down"},
        ],
        "transition": "slideup",
        "shot_dur": 2.3,
    },
]


def build_narrative(cfg):
    vid = cfg["id"]
    print(f"[{vid}] {cfg['name']}")

    title_png = os.path.join(ASSETS_DIR, f"title_{vid}.png")
    make_title_card(cfg["title"], cfg["g1"], cfg["g2"], title_png)
    title_clip = os.path.join(CLIPS_DIR, f"{vid}_title.mp4")
    render_zoompan_clip(title_png, TITLE_DUR, "settle", title_clip)

    clip_paths = [title_clip]
    durations = [TITLE_DUR]
    for i, shot in enumerate(cfg["shots"]):
        src_crop_png = os.path.join(ASSETS_DIR, f"src_{vid}_{i}.png")
        crop_source(shot["source"], shot["crop"], shot.get("raw_dir")).save(src_crop_png)
        seg_clip = os.path.join(CLIPS_DIR, f"{vid}_seg{i}.mp4")
        render_zoompan_clip(src_crop_png, cfg["shot_dur"], shot["effect"], seg_clip)
        clip_paths.append(seg_clip)
        durations.append(cfg["shot_dur"])

    end_png = ensure_end_card()
    end_clip = os.path.join(CLIPS_DIR, f"{vid}_end.mp4")
    render_zoompan_clip(end_png, END_DUR, "settle", end_clip)
    clip_paths.append(end_clip)
    durations.append(END_DUR)

    # title->shot1 and shot(n-1)->end stay a plain dissolve; the transition
    # between the two feature shots is the distinctive one for this video.
    n_boundaries = len(clip_paths) - 1
    transitions = ["fade"] * n_boundaries
    transitions[1] = cfg["transition"]

    silent_path = os.path.join(CLIPS_DIR, f"{vid}_silent.mp4")
    total_dur = xfade_concat(clip_paths, durations, silent_path, transitions=transitions)

    feature_total = sum(durations[:-1]) - (len(durations) - 2) * XFADE
    whoosh_start = max(0.0, feature_total - XFADE - whoosh_lead())
    chime_start = feature_total - 2 * XFADE
    audio_path = os.path.join(CLIPS_DIR, f"{vid}_audio.wav")
    build_audio(total_dur, whoosh_start, chime_start, audio_path)

    final_path = os.path.join(FINAL_DIR, f"{vid}_{cfg['name']}.mp4")
    mux_audio(silent_path, audio_path, final_path)

    thumb_path = os.path.join(THUMBS_DIR, f"{vid}_{cfg['name']}_thumb.png")
    extract_thumbnail(final_path, TITLE_DUR + 1.0, thumb_path)
    print(f"  -> {final_path} ({total_dur:.2f}s)")


# ─── Multi-feature "Reel" cuts (8-10s) for organic TikTok/Reels posts ──
# The single-feature videos above (5.6-5.85s) work well as 6s bumper ads;
# organic posts typically hold attention better with a short multi-beat tour:
# hook -> 3-4 features -> CTA. Same building blocks, longer per-shot holds.

REELS = [
    {
        "id": "15", "name": "WhySunHat", "title": "Why\nSunHat?",
        "g1": (14, 16, 46), "g2": (30, 50, 100),
        "shots": [
            {"source": "01_hero_welcome.png", "crop": None, "effect": "zoom_in", "dur": 1.9},
            {"source": "02_dashboard_ready_now.png", "crop": (0, 0, 1320, 2430), "effect": "zoom_in", "dur": 1.9},
            {"source": "03_weather_predictions.png", "crop": (0, 880, 1320, 2200), "effect": "pan_down", "dur": 1.8},
            {"source": "07_edit_seven_trigger_types.png", "crop": (0, 800, 1320, 1800), "effect": "pan_across", "dur": 1.7},
        ],
    },
    {
        "id": "16", "name": "MakeItYours", "title": "Make It\nYours",
        "g1": (40, 14, 48), "g2": (85, 30, 95),
        "shots": [
            {"source": "04_creation_range.png", "crop": (0, 100, 1320, 1400), "effect": "zoom_in", "dur": 1.8},
            {"source": "05_creation_exact_sky.png", "crop": (0, 100, 1320, 1300), "effect": "pan_across", "dur": 1.8},
            {"source": "06_creation_time_quiet_hours.png", "crop": (0, 1000, 1320, 2200), "effect": "zoom_out", "dur": 1.8},
            {"source": "07_edit_seven_trigger_types.png", "crop": (0, 800, 1320, 1800), "effect": "pan_across", "dur": 1.7},
        ],
    },
    {
        "id": "17", "name": "StayInControl", "title": "Stay In\nControl",
        "g1": (10, 30, 26), "g2": (18, 62, 55),
        "shots": [
            {"source": "08_reminders_list.png", "crop": (0, 580, 1320, 2500), "effect": "pan_down", "dur": 2.0},
            {"source": "09_history_timeline.png", "crop": (0, 750, 1320, 2868), "effect": "zoom_pan_down", "dur": 2.0},
            {"source": "10_settings.png", "crop": (0, 240, 1320, 2500), "effect": "pan_down", "dur": 1.9},
        ],
    },
]


def build_reel(cfg):
    vid = cfg["id"]
    print(f"[{vid}] {cfg['name']}")

    title_png = os.path.join(ASSETS_DIR, f"title_{vid}.png")
    make_title_card(cfg["title"], cfg["g1"], cfg["g2"], title_png)
    title_clip = os.path.join(CLIPS_DIR, f"{vid}_title.mp4")
    render_zoompan_clip(title_png, TITLE_DUR, "settle", title_clip)

    clip_paths = [title_clip]
    durations = [TITLE_DUR]
    for i, shot in enumerate(cfg["shots"]):
        src_crop_png = os.path.join(ASSETS_DIR, f"src_{vid}_{i}.png")
        crop_source(shot["source"], shot["crop"], shot.get("raw_dir")).save(src_crop_png)
        seg_clip = os.path.join(CLIPS_DIR, f"{vid}_seg{i}.mp4")
        render_zoompan_clip(src_crop_png, shot["dur"], shot["effect"], seg_clip)
        clip_paths.append(seg_clip)
        durations.append(shot["dur"])

    end_png = ensure_end_card()
    end_clip = os.path.join(CLIPS_DIR, f"{vid}_end.mp4")
    render_zoompan_clip(end_png, END_DUR, "settle", end_clip)
    clip_paths.append(end_clip)
    durations.append(END_DUR)

    # Plain dissolves throughout - the point of a Reel-length cut is a smooth,
    # confident tour, not a gimmick transition every beat.
    silent_path = os.path.join(CLIPS_DIR, f"{vid}_silent.mp4")
    total_dur = xfade_concat(clip_paths, durations, silent_path)

    feature_total = sum(durations[:-1]) - (len(durations) - 2) * XFADE
    whoosh_start = max(0.0, feature_total - XFADE - whoosh_lead())
    chime_start = feature_total - 2 * XFADE
    audio_path = os.path.join(CLIPS_DIR, f"{vid}_audio.wav")
    build_audio(total_dur, whoosh_start, chime_start, audio_path)

    final_path = os.path.join(FINAL_DIR, f"{vid}_{cfg['name']}.mp4")
    mux_audio(silent_path, audio_path, final_path)

    thumb_path = os.path.join(THUMBS_DIR, f"{vid}_{cfg['name']}_thumb.png")
    extract_thumbnail(final_path, TITLE_DUR + 1.0, thumb_path)
    print(f"  -> {final_path} ({total_dur:.2f}s)")


if __name__ == "__main__":
    import sys
    only = sys.argv[1] if len(sys.argv) > 1 else None

    for cfg in VIDEOS:
        if only and cfg["id"] != only:
            continue
        build_video(cfg)

    if not only or only == FINALE["id"]:
        build_finale(FINALE)

    for cfg in NARRATIVES:
        if only and cfg["id"] != only:
            continue
        build_narrative(cfg)

    for cfg in REELS:
        if only and cfg["id"] != only:
            continue
        build_reel(cfg)

    print("\nDone.")
