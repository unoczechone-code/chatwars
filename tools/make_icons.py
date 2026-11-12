"""Generate all iOS icon PNGs from the project's icon design, using Pillow.

No SVG rasteriser is available on this box, so the artwork is drawn directly.
Run: python tools/make_icons.py
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "art", "icons")

BG_TOP = (27, 36, 64)
BG_BOT = (13, 19, 34)
BODY = (223, 230, 242)
OUTLINE = (127, 143, 179)
DARK = (27, 36, 64)
ACCENT = (63, 143, 212)

# Master render size; everything is drawn at this scale then downsampled.
S = 1024


def draw_master() -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Vertical gradient background (drawn as horizontal bands).
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3))
        d.line([(0, y), (S, y)], fill=c + (255,))

    # Rounded mask for the iOS icon (no transparency needed, but keeps corners tidy).
    sc = S / 512.0
    def sx(v):
        return int(round(v * sc))

    # Head
    d.ellipse([sx(160), sx(100), sx(352), sx(292)], fill=BODY, outline=OUTLINE, width=sx(10))
    # Eyes
    d.ellipse([sx(208), sx(164), sx(240), sx(196)], fill=DARK)
    d.ellipse([sx(272), sx(164), sx(304), sx(196)], fill=DARK)
    # Mouth
    d.rounded_rectangle([sx(212), sx(228), sx(300), sx(242)], radius=sx(7), fill=DARK)
    # Torso
    d.rounded_rectangle([sx(176), sx(300), sx(336), sx(428)], radius=sx(36),
                        fill=BODY, outline=OUTLINE, width=sx(10))
    # Chest panel
    d.rounded_rectangle([sx(228), sx(336), sx(284), sx(392)], radius=sx(12), fill=ACCENT)
    # Arms
    d.rounded_rectangle([sx(118), sx(330), sx(164), sx(416)], radius=sx(23), fill=BODY)
    d.rounded_rectangle([sx(348), sx(330), sx(394), sx(416)], radius=sx(23), fill=BODY)
    return img


def save(img: Image.Image, size: int, name: str, opaque: bool) -> None:
    resized = img.resize((size, size), Image.LANCZOS)
    if opaque:
        bg = Image.new("RGB", (size, size), BG_BOT)
        bg.paste(resized, mask=resized.split()[3])
        resized = bg
    path = os.path.join(OUT, name)
    resized.save(path, "PNG", optimize=True)
    print(f"  {name}  ({size}x{size})")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    master = draw_master()

    # Every icon slot Godot 4.7.2 exposes, filled with the same art.
    # App Store icons must be opaque (no alpha).
    specs = [
        ("icon_1024x1024.png", 1024, True),
        ("icon_1024x1024_dark.png", 1024, True),
        ("icon_1024x1024_tinted.png", 1024, True),
        ("iphone_120x120.png", 120, False),
        ("iphone_120x120_dark.png", 120, False),
        ("iphone_120x120_tinted.png", 120, False),
        ("iphone_180x180.png", 180, False),
        ("iphone_180x180_dark.png", 180, False),
        ("iphone_180x180_tinted.png", 180, False),
        ("ipad_152x152.png", 152, False),
        ("ipad_152x152_dark.png", 152, False),
        ("ipad_152x152_tinted.png", 152, False),
        ("ipad_167x167.png", 167, False),
        ("ipad_167x167_dark.png", 167, False),
        ("ipad_167x167_tinted.png", 167, False),
        ("ios_128x128.png", 128, False),
        ("ios_128x128_dark.png", 128, False),
        ("ios_128x128_tinted.png", 128, False),
        ("ios_136x136.png", 136, False),
        ("ios_136x136_dark.png", 136, False),
        ("ios_136x136_tinted.png", 136, False),
        ("ios_192x192.png", 192, False),
        ("ios_192x192_dark.png", 192, False),
        ("ios_192x192_tinted.png", 192, False),
        ("notification_40x40.png", 40, False),
        ("notification_40x40_dark.png", 40, False),
        ("notification_40x40_tinted.png", 40, False),
        ("notification_60x60.png", 60, False),
        ("notification_60x60_dark.png", 60, False),
        ("notification_60x60_tinted.png", 60, False),
        ("notification_76x76.png", 76, False),
        ("notification_76x76_dark.png", 76, False),
        ("notification_76x76_tinted.png", 76, False),
        ("notification_114x114.png", 114, False),
        ("notification_114x114_dark.png", 114, False),
        ("notification_114x114_tinted.png", 114, False),
        ("settings_58x58.png", 58, False),
        ("settings_58x58_dark.png", 58, False),
        ("settings_58x58_tinted.png", 58, False),
        ("settings_87x87.png", 87, False),
        ("settings_87x87_dark.png", 87, False),
        ("settings_87x87_tinted.png", 87, False),
        ("spotlight_80x80.png", 80, False),
        ("spotlight_80x80_dark.png", 80, False),
        ("spotlight_80x80_tinted.png", 80, False),
        ("spotlight_120x120.png", 120, False),
        ("spotlight_120x120_dark.png", 120, False),
        ("spotlight_120x120_tinted.png", 120, False),
    ]
    print(f"Writing icons to {OUT}")
    for name, size, opaque in specs:
        save(master, size, name, opaque)
    print(f"Done: {len(specs)} files")


if __name__ == "__main__":
    main()
