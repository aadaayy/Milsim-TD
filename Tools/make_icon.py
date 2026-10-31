"""Draws the app icon from the machine gun nest portrait. Run from the repository root: python3 Tools/make_icon.py"""
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PORTRAITS = ROOT / "assets" / "ui" / "exports" / "portraits"
OUT = ROOT / "LastPerimeter" / "Assets.xcassets" / "AppIcon.appiconset"

size = 1024
# The portraits carry their own card frame; the icon uses only the picture inside it.
nest = Image.open(PORTRAITS / "mg_nest_2@2x.png").convert("RGBA")
inset = 30
icon = nest.crop((inset, inset, nest.width - inset, nest.height - inset)).resize((size, size), Image.LANCZOS)

OUT.mkdir(parents=True, exist_ok=True)
icon.convert("RGB").save(OUT / "icon.png")
(OUT / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1},
}, indent=2) + "\n")
accent = ROOT / "LastPerimeter" / "Assets.xcassets" / "AccentColor.colorset"
accent.mkdir(parents=True, exist_ok=True)
(accent / "Contents.json").write_text(json.dumps({
    "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
        "red": "0.860", "green": "0.780", "blue": "0.580", "alpha": "1.000"}}}],
    "info": {"author": "xcode", "version": 1},
}, indent=2) + "\n")
print("icon written")
