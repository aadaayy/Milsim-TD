# Milsim-TD

Last Perimeter, a milsim tower defense game for iPhone, and its art. Models are built in Blender and rendered to 2D top-down sprite sheets; the game draws them with SpriteKit, with a SwiftUI control panel around the battlefield. The design doc is the blueprint.

## The app

The app plays chapter 1, level 1 ("Crossroads"): build rifle squads, machine gun nests and sniper teams on the pads beside the road, start each round, upgrade or sell positions, and hold the Command Post for 50 rounds. Each position goes to level 2, then to one of two level 3 versions (3A or 3B). Walkers and runners come first; crawlers, screamers, bloaters and armored zombies join over the rounds, with a Brute boss every tenth round and the Behemoth at rounds 25 and 50. Pause and the speed button (1x, 2x, 3x) are on every layout.

It fits four phones:

- a regular iPhone and the iPhone Pro Max, in portrait: battlefield on top, controls under it for one thumb
- the iPhone Duo folded: the level strip across the top, the battlefield on the left with the next round under it, and a side bar on the right with supply, the build menu or position card, and the round, pause and speed buttons
- the iPhone Duo open: battlefield on one half, the full command panel (build menu with descriptions, position card with its next upgrade or level 3 choice, round intel) on the other

```
LastPerimeter/
  Core/        game rules in plain Swift (waves, targeting, damage, supply)
  Data/        positions, zombies, the level and the sprite list, as JSON
  Game/        the SpriteKit battlefield and the session that runs a level
  Views/       SwiftUI screens and controls
  Assets.xcassets/  sprite atlases and UI art made from assets/ (Tools/make_sprites.py)
LastPerimeterUITests/  the walk-through the checks run on each phone
Tests/         logic tests (swift test)
Tools/         scripts that turn the art into app images and the app icon
```

To change balance, edit the JSON in `LastPerimeter/Data`. The rounds are made by `python3 Tools/make_waves.py` from a few dials (how fast the horde and its health grow, when each zombie type arrives, the boss rounds), so retune them there and rerun it. The logic tests play all 50 rounds for real: a strong build order (`AutoPlayer.firstMap`) must win, the same build without level 3 must fall in the late rounds, and no defense must fall at once. After new art is exported, run `python3 Tools/make_sprites.py` from the repository root.

### Run it on your phone

You need a Mac with Xcode 27.1 or later. A free Apple account is enough to put it on your own phone.

1. Open `LastPerimeter.xcodeproj` in Xcode.
2. In Xcode, Settings, Accounts, sign in with your Apple account.
3. Click the LastPerimeter project, then the LastPerimeter target, then Signing & Capabilities, and pick your account as the Team.
4. Plug the phone into the Mac with a cable and tap Trust on the phone.
5. Pick the phone at the top of the Xcode window and press Run.
6. The first time, on the phone open Settings, General, VPN & Device Management, and trust your developer account.

### Automatic checks

Every push runs `.github/workflows/checks.yml`:

1. Logic tests on Linux: level data, build and upgrade costs, targeting, and that the first level can be lost and won.
2. The app on a Mac: it's built once, then played through on iPhone Pro Max, a regular iPhone and iPhone Duo simulators, with screenshots at each step. The Duo simulator can't be unfolded, so the open Duo layout is drawn at the open Duo's size on the Pro Max.
3. The newest screenshots go to the `screenshots` branch, named after the phone and the step.

## Art layout

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

Art files are stored as normal git files (no Git LFS); `.gitattributes` marks them binary. Blender backup files (`.blend1`, `.blend2` and so on) and macOS clutter are ignored.
