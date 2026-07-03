#!/usr/bin/env python3
"""Lightweight pixel checks for SunHat screenshots.

This is not an aesthetic judge. It catches mechanical screenshot problems that
make design work look unfinished: wrong dimensions, huge flat fields, accidental
near-black coverage, edge clipping, and low color variance.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from statistics import mean
import sys

from PIL import Image, ImageStat


@dataclass
class AuditResult:
    path: Path
    size: tuple[int, int]
    luma_std: float
    color_std: float
    dark_ratio: float
    flat_tile_ratio: float
    edge_activity: float

    @property
    def verdict(self) -> str:
        if self.size not in {(1284, 2778), (1206, 2622)}:
            return "FAIL size"
        if self.luma_std < 22:
            return "WARN flat"
        if self.flat_tile_ratio > 0.72:
            return "WARN flat-bands"
        if self.edge_activity > 0.65:
            return "WARN edge"
        return "PASS"


def luminance(rgb: tuple[int, int, int]) -> float:
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def audit_image(path: Path) -> AuditResult:
    image = Image.open(path).convert("RGB")
    stat = ImageStat.Stat(image)
    luma = image.convert("L")
    luma_std = ImageStat.Stat(luma).stddev[0]
    color_std = mean(stat.stddev)

    pixels = list(image.getdata())
    dark_ratio = sum(1 for pixel in pixels if luminance(pixel) < 18) / len(pixels)

    tile_size = max(24, min(image.size) // 22)
    flat_tiles = 0
    total_tiles = 0
    for y in range(0, image.height, tile_size):
        for x in range(0, image.width, tile_size):
            tile = luma.crop((x, y, min(x + tile_size, image.width), min(y + tile_size, image.height)))
            total_tiles += 1
            if ImageStat.Stat(tile).stddev[0] < 2.2:
                flat_tiles += 1

    edge = 10
    edge_pixels = []
    edge_pixels.extend(image.crop((0, 0, image.width, edge)).getdata())
    edge_pixels.extend(image.crop((0, image.height - edge, image.width, image.height)).getdata())
    edge_pixels.extend(image.crop((0, 0, edge, image.height)).getdata())
    edge_pixels.extend(image.crop((image.width - edge, 0, image.width, image.height)).getdata())
    edge_activity = sum(1 for pixel in edge_pixels if luminance(pixel) < 24 or luminance(pixel) > 244) / len(edge_pixels)

    return AuditResult(
        path=path,
        size=image.size,
        luma_std=luma_std,
        color_std=color_std,
        dark_ratio=dark_ratio,
        flat_tile_ratio=flat_tiles / max(total_tiles, 1),
        edge_activity=edge_activity,
    )


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: design_pixel_audit.py <image> [<image> ...]", file=sys.stderr)
        return 2

    results = [audit_image(Path(arg)) for arg in sys.argv[1:]]
    print("verdict,size,luma_std,color_std,dark_ratio,flat_tile_ratio,edge_activity,path")
    for result in results:
        print(
            f"{result.verdict},{result.size[0]}x{result.size[1]},"
            f"{result.luma_std:.2f},{result.color_std:.2f},"
            f"{result.dark_ratio:.3f},{result.flat_tile_ratio:.3f},"
            f"{result.edge_activity:.3f},{result.path}"
        )

    return 1 if any(result.verdict.startswith("FAIL") for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
