#!/usr/bin/env python3
"""Generate all launcher icons from the checked-in master image."""

from __future__ import annotations

import json
from decimal import Decimal
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "app_icon_master.png"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS_APP_ICON = (
    ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
)

ANDROID_DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    if source.width != source.height or source.width < 1024:
        raise ValueError("App icon master must be square and at least 1024 px.")

    legacy = _legacy_artwork(source)
    round_legacy = _round_artwork(source)

    for density, (legacy_size, adaptive_size) in ANDROID_DENSITIES.items():
        output_dir = ANDROID_RES / f"mipmap-{density}"
        output_dir.mkdir(parents=True, exist_ok=True)

        _save(_resize(legacy, legacy_size), output_dir / "ic_launcher.png")
        _save(
            _resize(round_legacy, legacy_size),
            output_dir / "ic_launcher_round.png",
        )

        background, foreground, monochrome = _adaptive_layers(
            source,
            adaptive_size,
        )
        _save(background, output_dir / "ic_launcher_background.png")
        _save(foreground, output_dir / "ic_launcher_foreground.png")
        _save(monochrome, output_dir / "ic_launcher_monochrome.png")

    _save(
        _resize(source, 512),
        ROOT / "assets" / "store" / "google_play_icon_512.png",
    )
    _generate_ios_icons(source)


def _legacy_artwork(source: Image.Image) -> Image.Image:
    marked = source.copy()
    marker = (255, 0, 255)
    draw = ImageDraw.Draw(marked)
    for corner in [
        (0, 0),
        (source.width - 1, 0),
        (0, source.height - 1),
        (source.width - 1, source.height - 1),
    ]:
        ImageDraw.floodfill(marked, corner, marker, thresh=34)

    marker_image = Image.new("RGB", source.size, marker)
    difference = ImageChops.difference(marked, marker_image).convert("L")
    alpha = difference.point(lambda value: 0 if value == 0 else 255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=1.2))

    artwork = source.convert("RGBA")
    artwork.putalpha(alpha)
    del draw
    return artwork


def _round_artwork(source: Image.Image) -> Image.Image:
    inset = round(source.width * 0.04)
    artwork = source.crop(
        (inset, inset, source.width - inset, source.height - inset)
    ).resize(source.size, Image.Resampling.LANCZOS)
    rounded = artwork.convert("RGBA")

    circle = Image.new("L", source.size, 0)
    draw = ImageDraw.Draw(circle)
    mask_inset = round(source.width * 0.008)
    draw.ellipse(
        (
            mask_inset,
            mask_inset,
            source.width - mask_inset - 1,
            source.height - mask_inset - 1,
        ),
        fill=255,
    )
    circle = circle.filter(ImageFilter.GaussianBlur(radius=1.2))
    rounded.putalpha(circle)
    return rounded


def _adaptive_layers(
    source: Image.Image,
    size: int,
) -> tuple[Image.Image, Image.Image, Image.Image]:
    background = _adaptive_background(size)

    safe_size = round(size * 66 / 108)
    foreground_art = _adaptive_foreground_art(source)
    foreground_art.thumbnail(
        (safe_size, safe_size),
        Image.Resampling.LANCZOS,
    )
    foreground = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    foreground.alpha_composite(
        foreground_art,
        (
            (size - foreground_art.width) // 2,
            (size - foreground_art.height) // 2,
        ),
    )

    monochrome = _monochrome_bookshelf(size)
    return background, foreground, monochrome


def _adaptive_background(size: int) -> Image.Image:
    center = (129, 70, 27)
    edge = (82, 42, 17)
    background = Image.new("RGB", (size, size))
    pixels = background.load()
    center_point = (size - 1) / 2
    max_distance = center_point * 1.41421356237
    for y in range(size):
        for x in range(size):
            distance = (
                ((x - center_point) ** 2 + (y - center_point) ** 2) ** 0.5
                / max_distance
            )
            amount = min(1.0, distance * 0.82)
            pixels[x, y] = tuple(
                round(start + (finish - start) * amount)
                for start, finish in zip(center, edge)
            )
    return background


def _adaptive_foreground_art(source: Image.Image) -> Image.Image:
    scale = source.width / 1254

    def points(values: list[tuple[int, int]]) -> list[tuple[int, int]]:
        return [(round(x * scale), round(y * scale)) for x, y in values]

    mask = Image.new("L", source.size, 0)
    draw = ImageDraw.Draw(mask)
    book_shapes = [
        [(126, 288), (283, 265), (319, 294), (389, 890), (365, 943), (211, 960), (186, 927)],
        [(298, 343), (428, 326), (459, 348), (554, 891), (537, 936), (496, 958), (412, 956), (389, 931)],
        [(731, 285), (868, 262), (902, 274), (925, 303), (980, 900), (966, 939), (928, 959), (793, 963), (772, 943)],
        [(962, 276), (998, 256), (1099, 257), (1127, 283), (1122, 914), (1105, 945), (986, 954), (964, 930)],
    ]
    for shape in book_shapes:
        draw.polygon(points(shape), fill=255)

    draw.rounded_rectangle(
        (
            round(102 * scale),
            round(923 * scale),
            round(1150 * scale),
            round(1066 * scale),
        ),
        radius=round(18 * scale),
        fill=255,
    )

    source_pixels = source.load()
    mask_pixels = mask.load()
    highlight_regions = [
        (480, 130, 770, 285, "gold"),
        (490, 275, 755, 950, "light"),
        (625, 555, 930, 750, "light"),
    ]
    for left, top, right, bottom, kind in highlight_regions:
        for y in range(round(top * scale), round(bottom * scale)):
            for x in range(round(left * scale), round(right * scale)):
                red, green, blue = source_pixels[x, y]
                if kind == "gold":
                    selected = red > 205 and green > 120 and blue < 155
                else:
                    selected = min(red, green, blue) > 145
                if selected:
                    mask_pixels[x, y] = 255

    mask = mask.filter(ImageFilter.GaussianBlur(radius=max(1.0, 1.4 * scale)))
    artwork = source.convert("RGBA")
    artwork.putalpha(mask)
    crop_box = tuple(
        round(value * scale) for value in (95, 125, 1155, 1072)
    )
    return artwork.crop(crop_box)


def _monochrome_bookshelf(size: int) -> Image.Image:
    reference_size = 432
    scale = size / reference_size

    def points(values: list[tuple[int, int]]) -> list[tuple[int, int]]:
        return [(round(x * scale), round(y * scale)) for x, y in values]

    icon = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    alpha = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(alpha)

    draw.polygon(points([(109, 142), (146, 135), (171, 292), (134, 300)]), fill=255)
    draw.polygon(points([(151, 151), (182, 145), (207, 294), (174, 302)]), fill=255)
    draw.polygon(points([(225, 145), (263, 137), (287, 299), (248, 303)]), fill=255)
    draw.polygon(points([(286, 138), (323, 138), (325, 298), (288, 299)]), fill=255)
    draw.rounded_rectangle(
        (
            round(104 * scale),
            round(302 * scale),
            round(329 * scale),
            round(318 * scale),
        ),
        radius=max(1, round(8 * scale)),
        fill=255,
    )

    icon.putalpha(alpha)
    return icon


def _generate_ios_icons(source: Image.Image) -> None:
    contents = json.loads((IOS_APP_ICON / "Contents.json").read_text())
    generated: set[str] = set()
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename or filename in generated:
            continue
        point_size = Decimal(entry["size"].split("x", maxsplit=1)[0])
        scale = Decimal(entry["scale"].removesuffix("x"))
        pixels = int(point_size * scale)
        _save(_resize(source, pixels), IOS_APP_ICON / filename)
        generated.add(filename)


def _resize(image: Image.Image, size: int) -> Image.Image:
    resized = image.resize((size, size), Image.Resampling.LANCZOS)
    if size <= 192:
        resized = resized.filter(
            ImageFilter.UnsharpMask(radius=0.55, percent=55, threshold=2)
        )
    return resized


def _save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True, compress_level=9)


if __name__ == "__main__":
    main()
