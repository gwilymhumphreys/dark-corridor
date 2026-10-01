# Asset library (source packs)

Where the art and sound we draw from live, and how to find a file by name. The
game only holds the files we have picked; everything else stays in the source
packs outside the repository.

**Source root:** `../dark-corridor-design/` (a sibling of this repository, not
checked in). It is readable during any work on this project.

## Finding a named file

When a file is named in conversation (for example `Leper_nb.png`), search the
source root by name:

```bash
find ../dark-corridor-design -iname '*leper*'
```

Names in the packs are mixed case with underscores, so use `-iname` and a
fragment rather than the exact name.

## Source directories

| Directory | What is in it |
| --- | --- |
| `6000FantasyIcons/` | The 6000 Fantasy Icons pack, about 8,500 PNGs. All icons and portraits come from here. Subfolders below. |
| `Free - Raven Fantasy Icons/` | Pixel-art icon set at 16x16, 32x32 and 64x64, plus full spritesheets. Not used in the game at present. |
| `UI Bundle/` | Interface themes as single sheets, including `BlackandWhiteUI.png`, which the game started from. The theme no longer draws any of it ([ui_theme.md](../systems/ui_theme.md)); the mouse cursors in the same folder are still used. |
| `monsters/` | Painted monster images, sold in dated volumes. Folder names are mojibake from a Japanese archive, so search by file name rather than browsing. |
| `StoneCursorWenrexa/` | Twenty stone mouse cursors at 32x32, as `PNG/01.png` to `20.png` and the same set as `.ico`. Not used in the game at present. |
| `cursors/` | `Cool Cursors/`, TheWiseHedgehog's 32x32 cursor sheet, which the game's hand cursor was drawn from, and the owner's edited hand art (`cursor.aseprite`). |
| `palettes/` | GIMP `.gpl` palettes. The ones in use are copied into `assets/palettes/`. |
| game-icons.net | Not a local folder: single-colour silhouette SVGs fetched from https://github.com/game-icons/icons. Rasterised to white-on-transparent PNG into `assets/icons/mechanics/`, and tinted at runtime. These are the only icons that stay readable at the 16 to 28 pixels an icon gets inside text. |
| `vfx/` | Visual effect packs. `kenney_particle-pack/` is Kenney's Particle Pack (https://kenney.nl/assets/particle-pack): 80 single-frame effect images on transparent or black backgrounds. The attack hit images in `assets/vfx/attack/` the poison, burn and bleed images in `assets/vfx/status/` and the projectile images in `assets/vfx/projectile/` were made from it. The pixel-art effect packs are outside this folder, in `../3rd party assets/`: Beat 'em Up Combat Effects 1 to 4 by Pozac (about 130 animations of hit sparks, dust, flashes, explosions and a few projectiles, in 96 px frames), 500 Bullet 24x24 by BDragon1727 (eight-frame bullet loops in three colourways) and Explosion Pack 13 by ansimuz (six explosions). The sheets in `assets/vfx/projectile/pixel/` are made from the first two by `tools/make_pixel_projectiles.py`. A Machine's `assets/vfx/` holds copies of Beat 'em Up effects. |
| `sound/` | Downloaded sound effects. One folder per Freesound uploader whose whole library was taken, plus `downloads/` for sounds fetched one at a time. Each of those folders has a `credits.csv` listing every sound's id, author, licence and URL. `sonniss/<year>/<library>/` holds every Sonniss GameAudioGDC free bundle from 2015 to 2024 (https://sonniss.com/gameaudiogdc), one folder per donated library, named after the studio and library. The `sfx` skill searches it through `index.sqlite` in that folder; `.sfx_sonniss` in this repository's root points there. |
| `example games/` | Screenshots from Dungeon Master and Eye of the Beholder, kept as reference for the corridor look. |
| `dark-corridor.aseprite`, `ui.aseprite` | The owner's own drawings. |

### Inside `6000FantasyIcons/`

| Directory | What is in it |
| --- | --- |
| `AvatarIconsMegapack/CharacterIcons/` | Character and creature portraits. `Characters_nobg/` has the cut-out versions, `Characters_WithBackground/` the framed ones. |
| `AvatarIconsMegapack/BuildingIcons/` | Buildings, same two-version split. |
| `SkillsIcons/` | Skill and status icons across four volumes plus `Bonus/`. Each volume has a background and a no-background folder. |
| `WeaponIcons/` | Weapons, two volumes. |
| `ArmorIcons/` | Armour, rings and necklaces; `ArmorSet_Icons/` is split by material. |
| `ProfessionIcons/` | Loot, quest and resource icons, plus `ProfessionAndCraftIcons/` split by craft (Alchemy, Herbalism, Blacksmith and so on). |
| `MedievalIcons/` | A separate medieval set: armour, weapons, resources, skills, technologies, formations. |
| `BuildingMaterials/` | Planks, stone, nails and similar. |

A `_nb` or `_nobg` suffix means the icon has no background. The game uses the
no-background versions so the worn frame shows behind the figure.

## Sound downloads are archived automatically

Every sound fetched with `sfx.py download` is copied into the source root before
the game's copy is trimmed or converted, so the original recording survives any
editing. The archive path comes from `.sfx_archive` in this repository's root,
which holds one line: `../dark-corridor-design/sound/downloads`. Archived files
keep the uploader's format and have the Freesound id appended to the name, and
each one adds a row to `downloads/credits.csv`.

Taking a whole uploader's library writes to a folder named after them instead
(`sfx.py library <uploader> ../dark-corridor-design/sound/<uploader>`). Use that
once a few of someone's sounds have proved good, because sounds recorded in one
session sit together.

## Where files land in the game

| Source | Destination in this repository |
| --- | --- |
| Character and enemy portraits | `assets/portraits/characters/`, `assets/portraits/enemies/` |
| Item, potion, status and keyword icons | `assets/icons/items/`, `assets/icons/potions/`, `assets/icons/statuses/`, `assets/icons/keywords/` |
| Mechanic and slot glyphs | `assets/icons/mechanics/<slot>/`, one folder of candidates per [icon slot](../systems/mechanics.md#iconslots) |
| Monster images, cut out of their black backgrounds | `assets/monsters/cut_out/` |
| Interface sheets | `assets/ui/` |
| Sound effects | `assets/sound-effects/<category>/<sound>/`, one folder of variants per sound ([audio.md](../systems/audio.md)) |
| Mouse cursors | `assets/ui/cursors/` |
| Palettes | `assets/palettes/` |

Copy the file, rename it to `snake_case` (keeping the `_nb` suffix, so
`Leper_nb.png` becomes `leper_nb.png`), then run
`tools/import.sh` so Godot imports it.

Art direction and which packs we are considering are in
[art_audio.md](art_audio.md). Every icon and portrait an agent picked is a
placeholder for the owner to swap.
