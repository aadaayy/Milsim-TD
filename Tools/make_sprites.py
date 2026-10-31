"""Make the game's sprites from the finished art.

Reads the Blender renders under assets/*/exports, shrinks them to the size the
phone needs, and writes them into the app's asset catalog as sprite atlases
(Xcode packs and trims them). Also writes LastPerimeter/Data/sprites.json, which
tells the game each sprite's real size in meters, its frames and facings, so
the code never guesses from pixel sizes.

Run from the repository root:  python3 Tools/make_sprites.py
Needs Pillow and numpy. The terrain (grass, dirt road, trees, roofs, build pads)
has no Blender art yet, so it is drawn here from noise.
"""
import json
import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "assets"
APP = ROOT / "LastPerimeter"
CATALOG = APP / "Assets.xcassets"
SPRITES = CATALOG / "Sprites"
UI = CATALOG / "UI"
PPM = 128  # pixels per meter in the Blender renders

# What the prototype uses. Add names here to bring more art into the game.
POSITIONS = ["rifle_squad_1", "rifle_squad_2", "mg_nest_1", "mg_nest_2", "sniper_1", "sniper_2"]
ZOMBIES = ["walker", "runner"]
EFFECTS = ["muzzle_flash", "tracer", "hit_puff", "smoke_puff", "explosion_small"]
PORTRAITS = POSITIONS + ZOMBIES + ["command_post"]
BADGES = ["supply", "star", "star_empty", "upgrade", "sell", "level_1", "level_2", "noise_meter",
          "priority_first", "priority_strongest", "priority_closest", "ammo"]

# How much each kind of sprite is shrunk from the 128 px/m renders.
SCALE = {"position": 0.5, "zombie": 0.6, "effect": 0.5, "structure": 0.3}


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def folder(path, contents=None):
    path.mkdir(parents=True, exist_ok=True)
    write_json(path / "Contents.json", contents or {"info": {"author": "xcode", "version": 1}})


def imageset(parent, name, image):
    """One image in the catalog. Single scale: the game sets every sprite's size itself."""
    path = parent / f"{name}.imageset"
    path.mkdir(parents=True, exist_ok=True)
    image.save(path / f"{name}.png", optimize=True)
    write_json(path / "Contents.json", {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    })


def atlas(name):
    path = SPRITES / f"{name}.spriteatlas"
    folder(path)
    return path


def shrink(image, factor):
    w, h = image.size
    return image.resize((max(1, round(w * factor)), max(1, round(h * factor))), Image.LANCZOS)


def crop(sheet, rect):
    x, y, w, h = rect
    return sheet.crop((x, y, x + w, y + h))


def meters(px):
    return round(px / PPM, 4)


def turreted(group, name, kind, prefix):
    """A base image plus a sheet of turret frames by facing (positions, structures)."""
    src = ART / group / "exports" / name
    info = json.loads((src / "turret_sheet.json").read_text())
    factor = SCALE[kind]
    out = atlas(name)
    imageset(out, f"{prefix}base", shrink(Image.open(src / "base.png"), factor))
    sheet = Image.open(src / info["turret"]["file"])
    for key, rect in info["turret"]["rects"].items():
        imageset(out, f"{prefix}{key}", shrink(crop(sheet, rect), factor))
    cw, ch = info["turret"]["cell"]
    bw, bh = info["base"]["size"]
    ox, oy = info["turret"].get("offset", [0, 0])
    return {
        "atlas": name,
        "label": info.get("label", name),
        "frames": info["frames"],
        "dirs": info["dirs"],
        "base_m": [meters(bw), meters(bh)],
        "cell_m": [meters(cw), meters(ch)],
        "offset_m": [meters(ox), meters(oy)],  # +y is up the screen
    }


def zombie(name):
    src = ART / "zombies" / "exports" / name
    info = json.loads((src / "sheet.json").read_text())
    factor = SCALE["zombie"]
    out = atlas(name)
    sheet = Image.open(src / "sheet.png")
    dirs = {}
    for key, rect in info["rects"].items():
        anim, _, facing = key.split("_")
        imageset(out, f"{name}_{key}", shrink(crop(sheet, rect), factor))
        dirs.setdefault(anim, [])
        if facing not in dirs[anim]:
            dirs[anim].append(facing)
    cw, ch = info["cell"]
    return {
        "atlas": name,
        "label": info["label"],
        "cell_m": [meters(cw), meters(ch)],
        "anims": {anim: {"frames": count, "fps": info["fps"][anim], "dirs": dirs[anim]}
                  for anim, count in info["anims"].items()},
    }


def effect(name, out):
    src = ART / "effects" / "exports" / name
    info = json.loads((src / "sheet.json").read_text())
    factor = SCALE["effect"]
    count = info["frames"]
    for i in range(count):
        imageset(out, f"{name}_{i}", shrink(Image.open(src / "frames" / f"{i}.png"), factor))
    cw, ch = info["cell"]
    return {"frames": count, "fps": info["fps"], "loop": info["loop"], "cell_m": [meters(cw), meters(ch)]}


# ---------------------------------------------------------------- terrain

RNG = np.random.default_rng(7)


def tile_noise(size, scale):
    """Seamless noise: random phases filtered in frequency space, so it wraps."""
    f = np.fft.fftfreq(size)
    fx, fy = np.meshgrid(f, f)
    radius = np.sqrt(fx ** 2 + fy ** 2) * size
    spectrum = np.exp(-(radius / scale) ** 2) * (radius > 0)
    phase = np.exp(2j * np.pi * RNG.random((size, size)))
    field = np.real(np.fft.ifft2(spectrum * phase))
    field -= field.min()
    return field / max(field.max(), 1e-9)


def colorize(field, low, high):
    low, high = np.array(low, float), np.array(high, float)
    rgb = low + (high - low) * field[..., None]
    return np.clip(rgb, 0, 255).astype(np.uint8)


def grass(size=512):
    field = 0.55 * tile_noise(size, 6) + 0.3 * tile_noise(size, 24) + 0.15 * tile_noise(size, 120)
    field = (field - field.min()) / (field.max() - field.min())
    rgb = colorize(field, (78, 88, 52), (122, 128, 76)).astype(float)
    # Dry patches and blades
    dry = tile_noise(size, 10) > 0.72
    rgb[dry] = rgb[dry] * 0.7 + np.array([150, 135, 92]) * 0.3
    blades = RNG.random((size, size)) > 0.985
    rgb[blades] *= 0.75
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def soft_blob(size, color_low, color_high, edge=0.32, wobble=0.18, seed_scale=8, ruts=False):
    """A round, soft-edged patch with a ragged outline (dirt road pieces, trampled ground)."""
    y, x = np.mgrid[0:size, 0:size] / (size - 1) * 2 - 1
    r = np.sqrt(x ** 2 + y ** 2)
    outline = 1 - wobble * (tile_noise(size, seed_scale) - 0.5) * 2
    alpha = np.clip((outline - r) / edge, 0, 1)
    field = 0.6 * tile_noise(size, 10) + 0.4 * tile_noise(size, 40)
    field = (field - field.min()) / (field.max() - field.min())
    rgb = colorize(field, color_low, color_high).astype(float)
    if ruts:
        for offset in (-0.28, 0.28):
            band = np.exp(-((x - offset) / 0.06) ** 2)
            rgb *= (1 - 0.18 * band)[..., None]
    pebbles = RNG.random((size, size)) > 0.993
    rgb[pebbles] = rgb[pebbles] * 0.6 + 60
    rgba = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def tree(size, seed, tone):
    """A top-down tree canopy with its shadow cast down-right (sun upper left)."""
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow = Image.new("L", (size, size), 0)
    sd = ImageDraw.Draw(shadow)
    puffs = []
    c = size / 2
    for _ in range(9):
        a = rng.random() * 2 * math.pi
        d = rng.random() * size * 0.17
        rad = size * (0.15 + rng.random() * 0.1)
        puffs.append((c + math.cos(a) * d, c + math.sin(a) * d, rad))
    for px, py, rad in puffs:
        sd.ellipse((px - rad + size * 0.08, py - rad + size * 0.1, px + rad + size * 0.08, py + rad + size * 0.1), fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
    img.paste(Image.new("RGBA", (size, size), (20, 26, 12, 255)), (0, 0), shadow)
    yy, xx = np.mgrid[0:size, 0:size]
    leaf = tile_noise(size, 30)
    canopy = np.zeros((size, size, 4))
    for px, py, rad in sorted(puffs, key=lambda p: p[1]):
        dist = np.sqrt((xx - px) ** 2 + (yy - py) ** 2) / rad
        inside = dist < 1
        # Lit from the upper left
        light = np.clip(1.0 - ((xx - px + rad * 0.35) ** 2 + (yy - py + rad * 0.35) ** 2) ** 0.5 / (rad * 1.6), 0, 1)
        shade = 0.45 + 0.55 * light + 0.25 * (leaf - 0.5)
        col = np.array(tone)[None, None, :] * shade[..., None]
        canopy[inside, :3] = col[inside]
        canopy[inside, 3] = 255
    leaves = Image.fromarray(np.clip(canopy, 0, 255).astype(np.uint8), "RGBA")
    edge = leaves.split()[3].filter(ImageFilter.MaxFilter(3))
    outline = Image.new("RGBA", (size, size), (16, 20, 10, 255))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(outline, (0, 0), edge)
    img.alpha_composite(out)
    img.alpha_composite(leaves)
    return img


def roof(w, h, kind):
    """A small building seen from above: a gabled tin roof or a flat concrete roof."""
    pad = int(min(w, h) * 0.16)
    img = Image.new("RGBA", (w + pad, h + pad), (0, 0, 0, 0))
    shadow = Image.new("L", img.size, 0)
    ImageDraw.Draw(shadow).rectangle((pad * 0.9, pad * 1.0, w + pad * 0.9, h + pad * 1.0), fill=130)
    img.paste(Image.new("RGBA", img.size, (20, 22, 16, 255)), (0, 0), shadow.filter(ImageFilter.GaussianBlur(pad * 0.25)))
    field = tile_noise(max(w, h), 40)[:h, :w]
    if kind == "tin":
        base = colorize(field, (96, 70, 52), (128, 92, 66)).astype(float)
        ridges = (np.arange(w) % 10 < 2)[None, :]
        base *= np.where(ridges, 0.85, 1.0)[..., None]
        base[: h // 2] *= 1.12  # the half facing the sun
        base[h // 2 - 2: h // 2 + 2] *= 0.7
    else:
        base = colorize(field, (128, 126, 118), (160, 158, 148)).astype(float)
        base[h // 6: h // 6 + h // 5, w // 6: w // 6 + w // 4] *= 0.75  # a vent unit
        stain = tile_noise(max(w, h), 8)[:h, :w] > 0.7
        base[stain] *= 0.88
    body = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    ImageDraw.Draw(body).rectangle((0, 0, w - 1, h - 1), outline=(28, 26, 22, 255), width=3)
    img.alpha_composite(body, (0, 0))
    return img


def build_pad(size=256):
    """A trampled square where a position can be built, with white stake corners."""
    pad = soft_blob(size, (96, 84, 58), (128, 112, 78), edge=0.25, wobble=0.1)
    d = ImageDraw.Draw(pad)
    m, L, wdt = size * 0.2, size * 0.14, max(3, size // 40)
    for cx, cy, sx, sy in [(m, m, 1, 1), (size - m, m, -1, 1), (m, size - m, 1, -1), (size - m, size - m, -1, -1)]:
        d.line((cx, cy, cx + sx * L, cy), fill=(232, 226, 204, 235), width=wdt)
        d.line((cx, cy, cx, cy + sy * L), fill=(232, 226, 204, 235), width=wdt)
    return pad


def terrain():
    out = atlas("terrain")
    imageset(out, "grass", grass())
    for i in range(3):
        imageset(out, f"dirt_{i}", soft_blob(256, (112, 92, 62), (150, 126, 88), ruts=(i == 0)))
    tones = [(70, 92, 44), (58, 80, 40), (86, 98, 50), (62, 86, 52)]
    for i, tone in enumerate(tones):
        imageset(out, f"tree_{i}", tree(256, 100 + i, tone))
    imageset(out, "roof_tin", roof(240, 180, "tin"))
    imageset(out, "roof_flat", roof(220, 220, "flat"))
    imageset(out, "build_pad", build_pad())
    return {"tree_count": len(tones), "dirt_count": 3}


def main():
    for path in (SPRITES, UI):
        if path.exists():
            shutil.rmtree(path)
    folder(CATALOG)
    folder(SPRITES, {"info": {"author": "xcode", "version": 1}})
    folder(UI, {"info": {"author": "xcode", "version": 1}})

    manifest = {"note": "Made by Tools/make_sprites.py. Sizes are real meters; facing n = up the screen.",
                "positions": {}, "zombies": {}, "structures": {}, "effects": {}}
    for name in POSITIONS:
        manifest["positions"][name] = turreted("positions", name, "position", f"{name}_")
    for name in ZOMBIES:
        manifest["zombies"][name] = zombie(name)
    manifest["structures"]["command_post"] = turreted("fortifications", "command_post", "structure", "command_post_")
    fx = atlas("effects")
    for name in EFFECTS:
        manifest["effects"][name] = effect(name, fx)
    manifest["terrain"] = terrain()

    for name in PORTRAITS:
        imageset(UI, f"portrait_{name}", Image.open(ART / "ui" / "exports" / "portraits" / f"{name}.png"))
    for name in BADGES:
        imageset(UI, f"badge_{name}", Image.open(ART / "ui" / "exports" / "badges" / f"{name}.png"))

    write_json(APP / "Data" / "sprites.json", manifest)
    files = list(CATALOG.rglob("*.png"))
    print(f"{len(files)} images, {sum(f.stat().st_size for f in files) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
