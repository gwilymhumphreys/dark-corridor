# Palettes

A dev tool for trying colour schemes. The **main palette** is one palette file whose colours the
corridor, the pictures, the combat effects and every interface colour take. The **mechanic palette**
is a small named file setting the ten mechanic colours. Both are chosen on the Colours tab of the
[debug panel](debug_panel.md) and saved in the colours part of a [look preset](look_presets.md).

**Location:** `src/debug/main_palette.gd` (class `MainPalette`), `src/debug/mechanic_palette.gd` (class
`MechanicPalette`), `src/debug/colours_panel.*` (the Colours tab), `DebugPanels` (the settings and
`apply_palettes`), `src/data/colours.gd`. Palettes in `assets/palettes/`, mechanic palettes in
`assets/palettes/mechanics/`.

## The main palette

Any palette file the panel lists outside `assets/palettes/mechanics/` (a Lospec PNG strip or a `.gpl`
file, read by `PaletteLoader`, see [palette_clamp.md](palette_clamp.md#palettes)), without repeated
colours, then the darkest colour setting:

| Darkest colour | Colours used |
|---|---|
| Off | The file's colours |
| Add a darker colour | The file's colours and the picked colour |
| Replace the darkest colour | The file's colours with the darkest one (lowest OKLab lightness) swapped for the picked colour |

`DebugPanels.apply_palettes()` then sends the colours to every part:

| Part | How | Switch |
|---|---|---|
| Corridor walls and enemy images | Snapped to them by the [world clamp](palette_clamp.md#world-clamp) | Snap corridor |
| Item, potion, status and keyword icons, portraits, the cursor | Snapped to them by `InterfaceLook.picture_materials` ([Images](#images)) | Snap pictures |
| Combat effects | Snapped to them together with the mechanic colours, by `InterfaceLook.effects_material` ([interface_look.md](interface_look.md#the-combat-effects)) | Snap effects |
| Interface colours | Each takes one of them by brightness ([Interface colours](#interface-colours)) | None |

"Off" in the main palette list means no palette: nothing is snapped and every interface colour keeps
its default from `colours.gd`.

## Interface colours

An **interface colour** is a `Colours` variable that the mechanic palette does not set: the `UI_*`
colours, the health bar colours, the cooldown colours, the downed ally grey, the portrait colours, the
`STATUS_*` colours, `ARCANE`, the `RELIC_*` colours, the `BEAT_*` colours, `MAP_CURRENT_HALO`, the
`RARITY_*` colours, `TOOLTIP_CHANGED` and the `PAPER_BURN_*` colours. `MainPalette.SECTIONS` lists
them in the groups the Colours tab shows.

- Each has a **brightness** from 0 to 1: 0 is the main palette's darkest colour and 1 its lightest. It
  takes the palette colour nearest, in OKLab, to a grey at that brightness, so it prefers the
  palette's least tinted colour at that level (`MainPalette.colour_at`).
- A brightness the preset does not set is the OKLab lightness of the colour's default in `colours.gd`.
- Alpha is kept, so the translucent `HP_BAR_LINE` and `COOLDOWN_FILL` follow the palette too.
- Each brightness row on the Colours tab shows the colour it landed on. Two colours drawn on top of
  each other (a button's fill on the background) should not land on the same palette colour.

After the interface colours are set, the theme is recoloured:

| Part | How |
|---|---|
| Theme font colours | Each is placed by brightness on the `UI_TEXT_*` colours, dark to light, blending between the two nearest |
| `PaletteStyleBox` fills | Set straight from the `Colours` variable named in its `colour_name` ([ui_theme.md](ui_theme.md#flat-palette-following-panels)) |
| Other flat styles and theme images | Placed by brightness on the `UI_PANEL_*` colours. A [`WornStyleBox`](panel_wear.md) is recoloured through its wrapped `base`. The theme holds no images now, so the image case applies only to one added later |
| Colours placed in scenes | Health bars are `NamedColourRect` nodes, which copy their `Colours` variable when they enter the tree and on `DebugPanels.colours_changed`. Screen backgrounds are `ScreenBackground`, which also passes the [background wear](background_wear.md) mark colours |
| Wear, feedback and cursor colours | Pushed again by `apply_palettes`: `PrintLook.push_wear_colours()`, `InterfaceLook.push_wear_colours()`, `ControlFeedback.push_colours()`, `Cursor.apply()` |

`MainPalette.reset()` restores the default colours and the theme.

## The mechanic palette

A `.gpl` file in `assets/palettes/mechanics/` naming the ten mechanic colours in lower case with
spaces (`attack` sets `Colours.ATTACK`), `MechanicPalette.NAMES`. Statuses that come from a mechanic
read that mechanic's colour, so they follow it too.

- A name the file leaves out keeps its `colours.gd` default; a name that is not a mechanic gives a
  warning. A test requires every file in the folder to name all ten.
- `mechanics-default.gpl` holds the `colours.gd` defaults. `mechanics-greys.gpl` gives the greys-only
  look. The others are the mechanic colours of earlier hand-made interface schemes.
- The colour pickers in the Colours tab's Mechanic colours section, and the Colour row on the Icons
  tab, call `MechanicPalette.write_custom`: it writes all ten live colours, with the changed one, to
  `mechanics-custom.gpl` and makes that the active palette, so what is on screen matches the file.
- The colours are used as they are. Value pills, the shield on the health bar and keyword glyphs are
  drawn through the element material, and the coloured square behind a status icon is a panel; none
  of these is snapped.

`assets/palettes/made/` holds the interface greys of the earlier hand-made schemes as plain palettes,
to try as a main palette.

## Images

Interface images are drawn through the picture materials, `InterfaceLook.picture_materials`
([interface_look.md](interface_look.md)), whose shader includes the [palette clamp](palette_clamp.md).
`apply_palettes` writes the main palette's colours into all of them while Snap pictures is on. The
HP bars and value pills use `InterfaceLook.element_material`, which no palette is written to, so they
keep the colours they are filled with. The clamp follows the colour matching (RGB or OKLab) and
dithers when the Colours tab's Picture and effect dithering switch is on (`set_interface_dithering`),
which also applies to the combat effects.

## Limits

- Things that copy `Colours` when built are updated by `apply_palettes`, so the palettes can be
  switched mid-fight: keyword cards (`KeywordCatalog.refresh_colours()`), `NamedColourRect` nodes, and
  statuses in the current fight, which take the colour a new status of their class would have. Item,
  relic and potion definitions read their colours on use.
- Still not updated until rebuilt: the combat sandbox's `BoardView` portraits, combat-scoped summons'
  statuses, and projectiles already in flight.
- Text colours set in scenes as per-instance overrides (the value pill's number and outline) are not
  recoloured.
- Reads files with `FileAccess`, so debug runs only, like the [palette clamp](palette_clamp.md).

## Public API

| Member | Use |
|---|---|
| `DebugPanels.set_main_palette(path)`, `main_palette` | Use a palette file as the main palette; `''` for none. `[` and `]` step through the list |
| `DebugPanels.set_mechanic_palette(path)`, `mechanic_palette` | Use a mechanic palette; `''` for the defaults. `;` and `'` step through the list |
| `DebugPanels.set_palette_setting(name, value)` | Set `darkest` (a `MainPalette.Darkest` value or `off`, `add`, `replace`), `darkest_colour`, `perceptual`, `snap_corridor`, `snap_pictures`, `snap_effects`, `corridor_dithering`, `picture_dithering`, either palette, or an interface colour's brightness by its lower-case name (`ui_background`) |
| `DebugPanels.main_colours() -> PackedColorArray` | The main palette's colours with the darkest colour setting applied |
| `DebugPanels.apply_palettes()`, `colours_changed` | Apply both palettes everywhere; the signal tells nodes that copied colours |
| `DebugPanels.write_palettes(file)`, `read_palettes(file)`, `reset_palettes()` | The `palette` and `interface_colours` sections of a preset's colours part |
| `MainPalette.SECTIONS`, `names()`, `is_interface_colour(variable)` | The interface colours |
| `MainPalette.brightness(variable)`, `set_brightness(variable, level)`, `default_brightness(variable)` | An interface colour's brightness |
| `MainPalette.palette_colours(colours, darkest, colour)`, `colour_at(colours, level)` | The darkest colour setting, and the colour a brightness lands on |
| `MainPalette.apply(colours)`, `reset()` | Set every interface colour and recolour the theme; put them back |
| `MechanicPalette.apply(path)`, `reset()`, `colours()`, `write_custom(variable, colour)` | Apply a mechanic palette file; the live mechanic colours; write the custom file |
| `MechanicPalette.variable_name(name)`, `colour_name(variable)` | `'hp bar fill'` and `'HP_BAR_FILL'` both ways |
| `PaletteLoader.load_named_colours(path)`, `save_named_colours(path, colours)` | Name -> colour for a `.gpl` file, and its write half |

Tests: `tests/debug/test_main_palette.gd`, `tests/debug/test_mechanic_palette.gd`.
