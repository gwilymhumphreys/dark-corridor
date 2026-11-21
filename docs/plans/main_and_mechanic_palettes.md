# Main palette, mechanic palette and the debug panel tabs (plan)

One palette for the whole screen, a second palette for the colours that tell mechanics apart, and the
debug panel's tabs regrouped so each tab holds one kind of setting. Status: stages 1 (palettes) and 2 (tabs)
built and documented 2026-11-21. The hit effect trials are saved in presets as planned.

## Owner's decisions (2026-11-21)

- The corridor, portraits and icons, the interface and the background wear all use one **main
  palette**.
- Mechanics and their effects use a separate **mechanic palette**. Its colours can be changed on the
  panel.
- The main palette has a setting to add a darker colour or replace its darkest colour (Off, Add,
  Replace). The colour is picked by hand, because many palettes do not go dark enough.
- Each interface colour is taken from the main palette by brightness, with a slider for each.
- The mechanic palette holds only the ten mechanic colours. Everything else, including statuses that
  are not mechanics, the item and relic colours, rarity and the tooltip's changed values, uses the main
  palette.
- The deletions in [fewer_colours.md](fewer_colours.md) are dropped. A greys mechanic palette gives the
  greys-only look instead.
- The portrait, effects and interface palette choices go. The corridor, the pictures and the effects
  each keep a switch that turns snapping off.
- The panel is regrouped by kind of setting (the table under [The tabs](#the-tabs)), and each tab is
  one part of a look preset.
- The default preset is converted. The other presets and the history files are deleted; they stay in
  git history.

## Why

Today the corridor and the pictures are snapped to `2bit-demichrome` (blue-grey), while the interface
is filled from `ui-custom.gpl` (warm brown-grey), and the mechanic colours live in that same file. The
choices are five dropdowns on two tabs, several of them "Same as" another, and the colour matching on F1
also changes the F2 clamps. The existing "Interface clamped to: Same as corridor" option shows the
direction works but has three faults: the background lands on the palette's darkest colour, which is
too light; some interface colours land on the same palette colour (the Report button's fill vanishes
into the background); and the mechanic colours are snapped to greys too.

## The main palette

A palette file (any file the World palette list shows now, outside `assets/palettes/mechanics/`), plus
the darkest colour setting:

| Darkest colour | Colours used |
|---|---|
| Off | The file's colours |
| Add | The file's colours and the picked colour |
| Replace | The file's colours with the darkest one (lowest OKLab lightness) swapped for the picked colour |

The resulting colours are used by:

| Part | How |
|---|---|
| Corridor walls and enemy images | Snapped to them (the world clamp), when Snap corridor is on |
| Item, potion, status and keyword icons, portraits, the cursor | Snapped to them (the picture materials), when Snap pictures is on |
| Interface colours | Each takes one of them by brightness ([Interface colours](#interface-colours)) |
| Combat effects | Snapped to them together with the mechanic palette's colours, when Snap effects is on |

"Off" in the main palette list means no palette: no snapping, and every interface colour keeps its
default from `colours.gd`.

## Interface colours

An **interface colour** is a `Colours` variable that the mechanic palette does not set: the `UI_*`
colours, the health bar colours, `COOLDOWN_RING` and `COOLDOWN_FILL`, `ALLY_DOWNED`, the portrait
colours, the `BEAT_*` colours, `MAP_CURRENT_HALO`, the `PAPER_BURN_*` colours, the `STATUS_*` colours,
`ARCANE`, the `RELIC_*` colours, the `RARITY_*` colours and `TOOLTIP_CHANGED`.

- Each has a **brightness** from 0 to 1, where 0 is the main palette's darkest colour and 1 its
  lightest. It takes the palette colour nearest, in OKLab, to a grey at that brightness, so it prefers
  the palette's least tinted colour at that level.
- A colour's alpha is kept. `HP_BAR_LINE` and `COOLDOWN_FILL` are translucent, and can now be set like
  the others.
- The default brightness of each is the OKLab lightness of its default in `colours.gd`. The converted
  default preset starts from the lightness of each colour in `ui-custom.gpl`, then is tuned from
  screenshots so that colours drawn on top of each other (button fill on background, text on panel)
  do not land on the same palette colour.
- After the colours are set, the theme is recoloured as now (`InterfacePalette._recolour_theme`: font
  colours placed on the `UI_TEXT_*` colours, flat styles on `UI_PANEL_*`, `PaletteStyleBox` from its
  named colour).

## The mechanic palette

A `.gpl` file in `assets/palettes/mechanics/` naming the ten mechanic colours (`ATTACK` to `DECHARGE`
in `colours.gd`). Names are lower case with spaces, as in today's interface palettes. Statuses that
come from a mechanic (poison, burn, shield, haste and the rest) already read their mechanic's colour,
so they follow this palette.

- The colour pickers on the Colours tab, and the Colour row on the Icons tab, write
  `mechanics-custom.gpl` and make it the active file, as `InterfacePalette.write_custom` does now.
- A name the file does not list keeps its `colours.gd` default. A test requires every file in the
  folder to name the same set as `mechanics-default.gpl`.
- The colours are used as they are, not snapped to the main palette. Value pills, the shield on the
  health bar and keyword glyphs are drawn through the element material, and the coloured square behind
  a status icon is a panel; neither is snapped.
- `mechanics-greys.gpl` gives the greys-only look. Its greys are placeholders to tune on the panel.

## Palette files

| Now | After |
|---|---|
| `new/ui/ui-default.gpl`, `ui-custom`, `ui-demichrome`, `ui-gothic-bit`, `ui-muted`, `ui-paper-light` | Each split in two: its ten mechanic colours become `mechanics/mechanics-<name>.gpl`; its other colours, without repeats, become a plain palette `made/ui-<name>.gpl`, so each hand-made scheme can still be tried as a main palette |
| (none) | `mechanics/mechanics-greys.gpl` |
| `new/ui/` | Removed |

The other palette folders are unchanged.

## Snapping and dithering

- Colour matching (RGB or OKLab) is one setting for every snapped part.
- Snap corridor, Snap pictures and Snap effects are switches. Off sets that material's colour count
  to 0, as "Off" does now.
- The corridor keeps its own dithering switch, pattern, size and supersample. The pictures and the
  effects share one set, as now.
- The paper burn's `paper_burn_palette` switch snaps its bands to the effects colours, as now.

## The tabs

Each tab is one preset part and has its "Take this part from" row, except Icons.

| Key | Tab | Holds | Comes from |
|---|---|---|---|
| F1 | Colours | Main palette list and a strip of its colours, darkest colour, colour matching, the snap and dithering switches and dither settings, the interface colour brightness sliders (each with a swatch of the colour it landed on), the mechanic palette list and its colour pickers | F1 palette rows and Dithering section, F2 palette rows, colour sections and Dithering section |
| F2 | Corridor | Corridor filters (pixelate, bloom, grade, colour ramp, halftone, hatching, vignette, grain, posterize, scanlines), View, Light, Environment, Fog | F1 without the palette, dithering and hit lights |
| F3 | Pictures | The same filters on the pictures, health bars, value pills and combat effects, and the copy buttons to and from the corridor | F2 without palettes, colours, picture wear, Effects and Dithering |
| F4 | Wear | Background wear, panel wear, picture wear, the wear and worn edge over the corridor, the border, the pencil grid | F4, the wear parts of F3, F2's picture wear |
| F5 | Layout | Padding and gaps, character panels, token placement, shadow, fill and portraits, item levels, map | F3 Layout, most of F7 |
| F6 | Effects | The combat effects section (switch, transparency dithering, damage numbers), the hit effect trials, hit lights, paper burn | F2 Effects, F5 Hit effects, F1 hit light rows, F7 Paper burn |
| F7 | Motion | Hover and press (timing, text, highlight border and fill), encounter card deal, character photos, page turn, reward spin | F5, F7 Encounter cards, Character photos, Page turn, F8 |
| F8 | Icons | Icon slots, unchanged | F6 |

Interface glow is saved in presets (`interface_glow`, by `InterfaceLook.write_look`) but has no rows on
any tab now; it gets rows on the Pictures tab.

## Presets

The settings keep the sections they are written to now, so each owner's `write_*` and `read_*` stay as
they are. What changes is which part each setting belongs to:

- `LookPresets.Part` becomes `COLOURS, CORRIDOR, PICTURES, WEAR, LAYOUT, EFFECTS, MOTION`.
- `PART_SECTIONS` becomes a list of rules (section, key prefix, part), first match wins. For example
  `dither_` keys in `corridor_shader` and `interface_shader` belong to Colours, `picture_` keys in
  `interface_shader` to Wear, `effects_` keys to Effects, `hit_light` keys in `corridor_light` to
  Effects, and in `print_layout` the `paper_burn_` keys to Effects and the `card_`, `deck_peek`,
  `photo_`, `page_turn_` and `reward_spin` keys to Motion.
- Loading some parts: start from the current look (`capture()`), remove every key of those parts, copy
  in the file's values for those keys, and read the result with every owner's reader. Keys the file
  leaves out go back to their defaults, and the other parts are untouched.
- `corridor_palette` and `interface_palette` are replaced by two sections, `palette` (main palette,
  darkest setting and colour, matching, snap and dithering switches, mechanic palette) and
  `interface_colours` (brightness by colour name).
- The hit effect trials are saved too, in an `effects_trials` section, so that every row on a tab is
  part of its preset part.
- Tests: every key `capture()` writes belongs to exactly one part, and loading one part leaves the
  keys of the others unchanged.

`default.cfg` is converted by hand: `world_palette` becomes `main_palette`, `ui-custom.gpl` becomes
`mechanics-custom.gpl`, `portrait_palette = corridor` and `effects_palette = interface` become the snap
switches on, and the brightness values and the darkest colour are set as described above. Every other
file in `assets/presets/` and `assets/presets/history/` is deleted.

## Keys and start-up arguments

| Now | After |
|---|---|
| `[` `]` World palette | Main palette |
| `;` `'` Interface palette | Mechanic palette |
| `,` `.` Portrait palette | Removed |
| `\` shortlist, Backspace corridor dithering | Unchanged, on the main palette |
| `--world-palette=` | `--main-palette=` |
| `--ui-palette=` | `--mechanic-palette=` |
| `--ui-clamp=`, `--portrait-palette=`, `--effects-palette=` | Removed; `--palette-set=name=value` sets any `palette` or `interface_colours` setting, for example `--palette-set=darkest=add` |
| `--look-panel`, `--interface-panel`, ... | One per new tab: `--colours-panel`, `--corridor-panel`, `--pictures-panel`, `--wear-panel`, `--layout-panel`, `--effects-panel`, `--motion-panel`, `--icon-panel` |

## Code changes

| Where | Change |
|---|---|
| `src/debug/main_palette.gd` (new, `MainPalette`) | The palette's colours with the darkest setting applied; brightness to colour; applying every interface colour; the theme recolour moved here from `InterfacePalette` |
| `src/debug/interface_palette.gd` | Becomes `mechanic_palette.gd` (`MechanicPalette`): applies a mechanic palette file, `write_custom`. The interface clamp, "own greys" and `unclamped` are removed |
| `debug_panels.gd` | Settings `main_palette`, `darkest`, `darkest_colour`, `mechanic_palette`, the three snap switches; `interface_colours` brightness; the portrait, effects and clamp choices and their option ids removed; `interface_palette_changed` renamed `colours_changed` (listener: `NamedColourRect`); `Tab` enum and keys for the new tabs |
| `src/debug/colours_panel.*` (new) | The Colours tab. A new row scene for a brightness slider with its swatch, and a palette strip scene |
| `look_panel.gd` | `_build_shader_sections` takes the uniform groups to include or leave out, so one material's groups can be spread over tabs |
| Tab scenes | `look_panel` becomes the Corridor tab, `interface_look_panel` the Pictures tab; new `wear_panel`, `layout_panel`, `effects_panel`, `motion_panel`; `print_panel`, `background_panel`, `feedback_panel`, `tokens_panel` and `reward_spin_panel` are merged into those |
| `look_presets.gd` | The part rules and part loading above |
| `print_look.gd` | `print_defaults()` leaves out instance uniforms. It reads `underline`, an instance uniform of the pencil grid, as a setting, so presets save it and `set_shader_parameter` is called on it with no effect |
| `vfx_driver.gd` | Write and read the hit effect trials for presets |
| `assets/palettes/` | The split files above |
| Tests | `test_interface_palette.gd` becomes `test_mechanic_palette.gd` and `test_main_palette.gd` (darkest Add and Replace, brightness 0 and 1, alpha kept, Off keeps defaults); `test_debug_panels.gd`, `test_interface_look.gd`, `test_look_presets.gd`, `test_print_look.gd`, `test_paper_burn.gd`, `test_combat_corridor.gd`, `test_icon_panel.gd` follow the new names |

## Stages

1. **Palettes.** Main and mechanic palettes, the Colours tab (added in front of the current tabs), keys,
   arguments, the `palette` and `interface_colours` sections, the split palette files, the converted
   default preset. Screenshots of the same late-run fight for: the current default; the new default;
   the new default with darkest Off; and `mechanics-greys`.
2. **Tabs.** The regrouping, the part rules, the deleted presets, the `underline` fix.
3. **Docs.** The list below.

GUT suite and `tools/lsp_check.sh` at the end of each stage, then grep `_temp/gut.log` for
`SCRIPT ERROR`.

## Docs to update when built

- [interface_palette.md](../systems/interface_palette.md) becomes one doc for both palettes;
  [palette_clamp.md](../systems/palette_clamp.md), [shaders_and_palettes.md](../systems/shaders_and_palettes.md)
  (the "three palette choices" table and the "Snapped to" column).
- [debug_panel.md](../systems/debug_panel.md), [look_presets.md](../systems/look_presets.md),
  [dev_tools.md](../systems/dev_tools.md) (arguments).
- The tab names in [corridor_look.md](../systems/corridor_look.md), [interface_look.md](../systems/interface_look.md),
  [print_frame.md](../systems/print_frame.md), [background_wear.md](../systems/background_wear.md),
  [panel_wear.md](../systems/panel_wear.md), [control_feedback.md](../systems/control_feedback.md),
  [paper_burn.md](../systems/paper_burn.md), [page_turn.md](../systems/page_turn.md),
  [run_screen.md](../systems/run_screen.md), [interface_glow.md](../systems/interface_glow.md).
- [mechanics.md](../systems/mechanics.md): the Colours section points to the mechanic palette.
- [docs/index.md](../index.md) entries for the changed docs.
- [fewer_colours.md](fewer_colours.md): the deletions are dropped; what is left is pill icons, shield
  stripes and one health bar fill, as separate later work.
- [art_audio.md](../design/art_audio.md) describes the separate palettes; it is the owner's doc, so ask
  before changing it.

## Open items

- The default darkest colour. A near-black in demichrome's grey is the starting point, for the owner
  to set on the panel.
- `EncounterDef.Type.REST` and `BEAT_REST` are still in the code although the rest encounter's content
  was removed on 2026-11-21. Ask whether the type and its colour go too.
