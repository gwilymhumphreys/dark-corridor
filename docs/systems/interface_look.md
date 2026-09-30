# Interface look

A dev tool for trying post-processing effects on interface images (item and potion icons, character
portraits, HP bars, item value pills) and on the combat effects, separately from the
[corridor look](corridor_look.md). Other text and panels, and the corridor, are not affected.

**Location:** `src/shaders/interface_look.gdshaderinc` (the shader, included by `interface_look.gdshader`
and `interface_portrait.gdshader`), `src/shaders/look_effects.gdshaderinc` (the effects
shared with the corridor look), `src/shaders/interface_look_material.tres`,
`src/shaders/interface_framed_material.tres`, `src/shaders/interface_portrait_material.tres`,
`src/shaders/interface_element_material.tres` and `src/shaders/interface_effects_material.tres` (on
`interface_effects.gdshader`),
`InterfaceLook`
(`src/autoloads/interface_look.gd`, class `InterfaceLookAutoload`), the Interface tab in
`src/debug/interface_look_panel.*`. Saved in the interface part of a [look preset](look_presets.md).

## How it works

- There are four material files, each set in the scene of the nodes that use it: three on `interface_look.gdshader` and the portrait material on `interface_portrait.gdshader`, which adds the per-node `picture_zoom`.
  Godot shares one loaded copy of each file, so a setting changed on it changes every node using it
  at once.
  - `interface_look_material.tres` (`InterfaceLook.material`) draws the pictures that are not inside a
    panel frame: status icons and keyword chip icons.
  - `interface_framed_material.tres` (`InterfaceLook.framed_material`) draws the pictures that sit
    inside a panel frame and do not breathe: the item cell icons, which include the potions and, by
    default, the map icons. Picture wear is kept off on
    this material (`FRAMED_OFF_UNIFORMS`), because the frame around them draws its own
    [panel wear](panel_wear.md); everything else applies.
  - `interface_portrait_material.tres` (`InterfaceLook.portrait_material`) draws the breathing
    character portraits. It takes the same settings as the framed material, through
    `interface_portrait.gdshader`, the only version of the shader with `picture_zoom` (below).
    `InterfaceLook.picture_materials` is this material, the framed material and
    `InterfaceLook.material`, which is what the palette clamp is written to.
  - `interface_element_material.tres` (`InterfaceLook.element_material`) draws the interface elements
    that are not pictures: the item value pills and the HP bars. These are filled with colours from the
    [interface palette](interface_palette.md), so the effects that would move a pixel off its palette
    colour are kept off on this material: grade, colour ramp and posterize
    (`ELEMENT_OFF_UNIFORMS`), and no palette clamp colours are written to it, so its colour count stays
    0. Halftone, hatching, vignette, grain, scanlines, pixelate and picture wear all apply.
- Every setting goes through `InterfaceLook.set_setting()`, which writes it to all four materials
  except for the switches above. There is one Interface tab and one set of settings; the split is in
  code, not in the panel or the preset.
- The shader includes `look_effects.gdshaderinc`, which holds the effect settings and functions used by
  both looks under the same names. That is what lets settings be copied between the two looks.
- Each node is drawn on its own, so effects work inside the node's rectangle only. Bloom is left out
  for that reason (`UNUSED_GROUPS` in `interface_look.gd`): its glow would be cut off at the node's
  edge. The vignette is included even though it is per node, so it darkens the corners of each icon or
  portrait rather than the corners of the screen. Glow on specific nodes is a separate system,
  [interface glow](interface_glow.md), with no section in this tab.
- The shader keeps the node's alpha and colour (a `ColorRect`'s colour, modulate), so HP bar colours and
  fades still work.
- Distances are in screen pixels, as in the corridor look. Halftone dots, hatching lines and grain are laid
  out from the node's corner, so they move with an animated node; scanlines are laid out on the screen.
- `picture_zoom` is an instance uniform set per node, not a look setting (`NODE_UNIFORMS`, so it is left
  out of `defaults()`, the Interface tab and presets). Above 1 the shader reads a smaller part of the
  image, so the picture fills the node magnified while the node keeps its size, and the pixelate,
  halftone, hatching and grain patterns stay where they are. `PortraitBreath` drives it for the portrait
  breathing ([ui_juice.md](ui_juice.md#portrait-breathing)). It is applied to the image lookup after the
  pixelate grid is worked out, and below 1 would read outside the image, so nothing sets it there.
- Only `interface_portrait.gdshader` has `picture_zoom` (it defines `PICTURE_ZOOM` before including the
  shader). The compatibility renderer has room for only about 256 nodes using instance uniforms
  ([godot_notes.md](godot_notes.md#instance-uniforms)), and the shared shader is on every icon, pill
  and label, so do not add an instance uniform to `interface_look.gdshaderinc` outside `PICTURE_ZOOM`.
- The shader also includes the [palette clamp](palette_clamp.md), whose colours come from the portrait palette
  ([interface_palette.md](interface_palette.md#images)) and are written to the picture materials only
  (`InterfaceLook.picture_materials`). It runs after the look effects and before picture wear. Its palette, colour matching and on/off dithering switch are set by `DebugPanels` and are not
  look settings; its dither pattern, size and supersample are, and appear in the Dithering section.
  The interface dithering switch is separate from the corridor's, so Backspace and `--dither` do not
  touch it.
- All five materials are also present in release builds, with every effect off. The fifth, the effects
  material, is described in [The combat effects](#the-combat-effects).

| Element | Scene and node | Material |
|---|---|---|
| Item icons (combat boards, draft rewards) | `item_cell.tscn` `Frame/Icon` | framed pictures |
| Potion icons | `potion_slot.tscn` `Cell/Frame/Icon` (an item cell) | framed pictures |
| Status and keyword icons | `status_icon.tscn` `Frame/Icon`, `keyword_chip.tscn` `Margin/Row/Icon`, `keyword_card.tscn` `Header/Icon`; an icon slot glyph takes the element material instead (`KeywordIcon.dress`) | images |
| Character portraits | `character_panel.tscn` `Row/Portrait/Image` (player and enemy panels), `ally_slot.tscn` `Row/Portrait/Image`, `character_card.tscn` `Portrait/Image` | portraits |
| HP bars | `Bar/Background`, `HealthFill`, `ShieldFill` and `Lines` in `health_bar.tscn`, used by every character panel | elements |
| Item value pills (the numbers on items) | `value_pill.tscn` root panel and its `Value` label | elements |
| The Temporary tag on an item cell | `item_cell.tscn` `TemporaryTag` and its `Label` | elements |
| The level tag on an item cell | `item_cell.tscn` `LevelTag` and its `Label` | elements |
| The mouse cursor ([cursor.md](cursor.md)) | `mouse_cursor.tscn` `Hand` | images |

On a pill's number the shader runs on each letter as drawn from the font's texture, so dot, line and
speck patterns are laid out from each letter rather than from the pill's corner.

To add an element, set its node's `material` to `interface_look_material.tres`,
`interface_framed_material.tres` or `interface_element_material.tres` in the scene and add it to
`SCENE_NODES`, `FRAMED_SCENE_NODES` or `ELEMENT_SCENE_NODES` in the test. Which material suits which
element, next to every other shader on screen, is in [shaders_and_palettes.md](shaders_and_palettes.md). A node with its own material
needs a child node for the image instead.

## The combat effects

`InterfaceLook.effects_material` is the material of `VfxWall` in `combat_view_framed.tscn`, the node that
draws every projectile, impact and damage number ([vfx_driver.md](vfx_driver.md)), and of the `Effects`
node in the `hit_effects_preview` dev scene. It takes the same settings, with these differences:

- It runs `interface_effects.gdshader`, which defines `EFFECTS` before including the shader. Effect
  sprites are scaled and turned every frame, and circles and arcs have no image, so every pattern
  (halftone, hatching, grain, pixelate) is laid out on the screen instead of from the drawn rectangle's
  corner. The vignette and picture wear are skipped.
- Grade, colour ramp and posterize are kept off (`EFFECTS_OFF_UNIFORMS`), as on the element material,
  because they move a pixel off its mechanic colour.
- Its palette is the **effects palette** (`DebugPanels.set_effects_palette`), not the portrait palette:
  off, the portrait palette, the interface palette (the default) or any palette file. The interface
  palette holds every mechanic colour, so a solid effect colour stays as it is. The Interface tab's
  dithering switch, matching and dither settings apply to it (`InterfaceLook.clamp_materials`).

The Effects section of the Interface tab holds its own settings (the `effects` uniform group). They are
written to every material but only the effects shader reads them:

| Setting | Does |
|---|---|
| `effects_on` (the section switch) | Off draws the effects as if there were no material. Off by default |
| `effects_dither_transparency` | Each pixel is drawn at full strength or not at all, by comparing its transparency with the dither pattern's threshold, so glows, tails and fades become dots |
| `effects_damage_numbers` | With the effects, or like the value pills: `VfxDriver` then draws the numbers on its `Numbers` child through the element material, which keeps their colour |

The comparison of these options is in [`../plans/effects_look.md`](../plans/effects_look.md).

## Picture wear

The Picture Wear section of the panel, off by default, draws [panel wear](panel_wear.md) on the images
themselves: faded areas, specks, edge wear and creases, without folds, in the same mark colours
(`Colours.UI_PANEL_WEAR` and `UI_PANEL_WEAR_LIGHT`, pushed by `InterfaceLook.push_wear_colours()` at
start and when an interface palette changes).

- It uses `print_panel_wear()` from `print_wear.gdshaderinc`, laid out in the node's own pixels as panel
  wear is, so the same numbers give marks of the same size. Its settings (`picture_*` in
  `interface_look.gdshader`) are separate from panel wear's and start at panel wear's defaults.
- Marks only show where the image is opaque, so a picture without a background wears on the figure,
  not around it. It also applies to the HP bars.
- Pictures inside a `PanelSlot` frame (the portraits and the item cell icons) take no picture wear:
  they are drawn through `framed_material`, and the frame around them has its own
  [panel wear](panel_wear.md).
- The image's average colour picks the arrangement of marks, so the same picture always wears the same
  way and its marks do not move while the node is animated.
- The corridor look has no picture wear, so the copy buttons leave it alone.
- The Picture Wear switch turns all picture wear on or off, including the faded areas, specks, edge wear
  and creases sections, whose own switches do nothing while it is off. The section headings say what the
  wear applies to, because the borders around icons are panels and their wear is panel wear, set in the
  Print tab.

## The Interface tab

F2 opens the [debug panel](debug_panel.md) on this tab. It is built like the
[Corridor tab](corridor_look.md#the-corridor-tab) from the interface look shader, plus two buttons:

| Button | Does |
|---|---|
| Copy from corridor look | Every interface look setting the corridor look also has takes the corridor look's value |
| Copy to corridor look | The reverse; corridor-only settings (bloom) and each look's own dithering switch are left alone |

In a preset, the interface part has an `interface_shader` section listing every setting and an
`interface_glow` section for the glow settings.

## Public API

| Member | Use |
|---|---|
| `InterfaceLook.material` | The material the pictures outside a panel frame are drawn through |
| `InterfaceLook.framed_material` | The material the item cell icons, inside a `PanelSlot` frame, are drawn through |
| `InterfaceLook.portrait_material` | The framed material's settings on the breathing portraits, with `picture_zoom` |
| `InterfaceLook.picture_materials` | The three picture materials, which the palette clamp is written to |
| `InterfaceLook.element_material` | The material the interface elements that are not pictures are drawn through |
| `InterfaceLook.effects_material` | The material the combat effects are drawn through ([The combat effects](#the-combat-effects)) |
| `InterfaceLook.clamp_materials` | The picture materials and the effects material, which the clamp's matching, dithering switch and dither texture are written to |
| `InterfaceLook.set_setting(uniform, value)` | Set one setting on all five materials, except each material's off list |
| `picture_zoom` | Per-node instance uniform on `interface_portrait.gdshader` only: zoom on the image, driven by `PortraitBreath` |
| `InterfaceLook.defaults() -> Dictionary` | Setting name -> default, read from the shader and include code (the shared effects, the palette clamp's dither settings, picture wear) |
| `InterfaceLook.reset()`, `write_look(file)`, `read_look(file)` | Reset, and the interface part of a preset |
| `InterfaceLook.copy_from_corridor()`, `copy_to_corridor()` | Copy shared settings between the looks |

Start-up arguments `--interface-set=` and `--interface-panel` are listed in
[dev_tools.md](dev_tools.md#look-arguments). `DebugPanels.reset_settings()` resets the interface
look.

Tests: `tests/debug/test_interface_look.gd`.
