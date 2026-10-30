# Milsim-TD

Art assets for Last Perimeter, a milsim tower defense game for iPhone. Models are built in Blender and rendered to 2D top-down sprite sheets. No app code lives here yet.

## Layout

```
assets/
  zombies/          enemy types
  positions/        player defensive positions and units
  terrain/          ground tiles and map pieces
  fortifications/   walls, sandbags, barricades
  vehicles/         vehicles
  effects/          muzzle flash, explosions, smoke
  ui/               icons and HUD art
  concept/          style tests and concept renders
scripts/            Blender Python scripts for building and rendering assets
```

Each asset category has three folders:

- `source/` the working `.blend` files
- `exports/` finished sprite sheets and exported models (`.png`, `.glb`, `.fbx`)
- `renders/` preview renders and screenshots for review

## Big files

`.blend`, `.glb`, `.fbx` files and PNGs under any `exports/` folder are stored with Git LFS. To clone with them, install Git LFS first:

```
git lfs install
```

Blender backup files (`.blend1`, `.blend2` and so on) and macOS clutter are ignored.
